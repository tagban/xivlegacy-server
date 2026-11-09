//! Content instances: several copies of one piece of content (a dungeon run,
//! a quest duty) running at once in the same zone, one per party or solo
//! player.
//!
//! Every copy's actors share the parent zone's actor pool at the same
//! coordinates, so each copy gets:
//! * an **instance id** (process-unique, never reused), which tags its actors
//!   and players in the zone core (`AreaCore::set_instance`) so range queries
//!   (streaming, broadcasts, aggro, area attacks) only pair actors of the
//!   same copy;
//! * a **slot** (0..`MAX_SLOTS`, per zone, reused once the copy ends), folded
//!   into its actor numbers so two copies spawning the same battle npc get
//!   different actor ids.
//!
//! Slot 0 keeps the historical numbering (`0x40000 | bnpc_id` and friends),
//! so a lone copy is numbered exactly as before.
//!
//! The registry is synchronous (a mutex) because the Lua bindings must hand
//! back actor ids before their commands are applied.

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Mutex, OnceLock};

/// Copies of content that may run at once in one zone.
pub const MAX_SLOTS: u32 = 32;
/// Battle npc ids a content script may spawn (`SpawnBattleNpcById`): the
/// low 12 bits of the actor number; the slot sits above them.
pub const MAX_CONTENT_BNPC_ID: u32 = 0xFFF;

static NEXT_INSTANCE_ID: AtomicU32 = AtomicU32::new(1);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Instance {
    pub id: u32,
    pub zone_id: u32,
    pub slot: u32,
}

#[derive(Default)]
struct Registry {
    /// zone -> instance id per slot (0 = free)
    slots: HashMap<u32, [u32; MAX_SLOTS as usize]>,
    by_id: HashMap<u32, Instance>,
    /// Copies entered as a party (`DoZoneChangeContentParty`: the
    /// dungeons and the Grand Company duties). Leaving their zone by any
    /// zone change leaves the copy.
    party: HashSet<u32>,
}

fn registry() -> &'static Mutex<Registry> {
    static R: OnceLock<Mutex<Registry>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(Registry::default()))
}

/// Open a new copy in `zone_id`. `None` when every slot is taken.
pub fn allocate(zone_id: u32) -> Option<Instance> {
    let mut r = registry().lock().unwrap_or_else(|e| e.into_inner());
    let slots = r.slots.entry(zone_id).or_insert([0; MAX_SLOTS as usize]);
    let slot = slots.iter().position(|&id| id == 0)? as u32;
    let id = NEXT_INSTANCE_ID.fetch_add(1, Ordering::Relaxed);
    slots[slot as usize] = id;
    let inst = Instance { id, zone_id, slot };
    r.by_id.insert(id, inst);
    Some(inst)
}

/// Close a copy, freeing its slot. Unknown ids are ignored.
pub fn release(instance_id: u32) {
    let mut r = registry().lock().unwrap_or_else(|e| e.into_inner());
    r.party.remove(&instance_id);
    if let Some(inst) = r.by_id.remove(&instance_id)
        && let Some(slots) = r.slots.get_mut(&inst.zone_id)
        && slots[inst.slot as usize] == instance_id
    {
        slots[inst.slot as usize] = 0;
    }
}

/// Mark a live copy as entered by a party (`DoZoneChangeContentParty`).
pub fn mark_party(instance_id: u32) {
    let mut r = registry().lock().unwrap_or_else(|e| e.into_inner());
    if r.by_id.contains_key(&instance_id) {
        r.party.insert(instance_id);
    }
}

/// Whether a live copy was entered by a party ([`mark_party`]).
pub fn is_party(instance_id: u32) -> bool {
    let r = registry().lock().unwrap_or_else(|e| e.into_inner());
    r.party.contains(&instance_id)
}

pub fn get(instance_id: u32) -> Option<Instance> {
    let r = registry().lock().unwrap_or_else(|e| e.into_inner());
    r.by_id.get(&instance_id).copied()
}

/// Actor number of a content-spawned battle npc: the content band, the
/// copy's slot, the battle npc id.
pub fn bnpc_actor_number(slot: u32, bnpc_id: u32) -> u32 {
    0x40000 | ((slot % MAX_SLOTS) << 12) | (bnpc_id & MAX_CONTENT_BNPC_ID)
}

/// Actor number of a content `SpawnActor` (its 12-bit name hash already in
/// `hashed`, `0x60000 | hash`): the slot goes into bits 12..16.
pub fn spawn_actor_number(slot: u32, hashed: u32) -> u32 {
    hashed | ((slot % MAX_SLOTS) << 12)
}

/// Local id of a copy's content director (slot 0 keeps the historical 1).
pub fn director_local_id(slot: u32) -> u32 {
    if slot == 0 { 1 } else { 0x1000 + slot }
}

/// Local id of a copy's private-area master (slot 0 keeps `0x40000`).
pub fn area_master_local_id(slot: u32) -> u32 {
    0x40000 | slot
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn copies_in_one_zone_get_distinct_slots_and_actor_numbers() {
        let a = allocate(9001).unwrap();
        let b = allocate(9001).unwrap();
        assert_ne!(a.id, b.id);
        assert_ne!(a.slot, b.slot);
        assert_ne!(bnpc_actor_number(a.slot, 57), bnpc_actor_number(b.slot, 57));
        release(a.id);
        release(b.id);
    }

    #[test]
    fn slot_zero_keeps_the_historical_numbering() {
        assert_eq!(bnpc_actor_number(0, 57), 0x40000 | 57);
        assert_eq!(director_local_id(0), 1);
        assert_eq!(area_master_local_id(0), 0x40000);
    }

    #[test]
    fn released_slots_are_reused_but_ids_are_not() {
        let a = allocate(9002).unwrap();
        release(a.id);
        let b = allocate(9002).unwrap();
        assert_eq!(a.slot, b.slot);
        assert_ne!(a.id, b.id);
        assert!(get(a.id).is_none());
        release(b.id);
    }

    #[test]
    fn party_marks_live_with_the_copy() {
        let a = allocate(9004).unwrap();
        assert!(!is_party(a.id));
        mark_party(a.id);
        assert!(is_party(a.id));
        release(a.id);
        assert!(!is_party(a.id));
        mark_party(a.id);
        assert!(!is_party(a.id), "a closed copy can't be marked");
    }

    #[test]
    fn a_full_zone_refuses_another_copy() {
        let all: Vec<_> = (0..MAX_SLOTS).map(|_| allocate(9003).unwrap()).collect();
        assert!(allocate(9003).is_none());
        for i in all {
            release(i.id);
        }
    }
}
