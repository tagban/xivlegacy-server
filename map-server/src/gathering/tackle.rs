// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Fishing tackle: the bait or lure in the Pack gear slot.
//!
//! In 1.0 a cast needs bait or a lure in the Pack slot (client sheet line
//! "You do not have bait or a lure equipped."). A cast uses one bait; a
//! lure is lost only when a hooked fish breaks away ("Your lure is lost.").
//! DummyCommand.lua decides when; [`use_tackle`] takes one off the stack.
//!
//! The stack is a bag item that the Pack slot points at. When the last
//! one goes, the equipment rows go first (every class that linked it), then
//! the bag row; the bag is packed like any removal, and the client hears
//! the Pack slot unlinked before the bag changes, then the gear links again
//! (packing moves bag slots the other gear points at).

use crate::actor::player::SLOT_PACK;
use crate::database::Database;
use crate::packets::send::actor_inventory as inv;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// gamedata_items.kind of bait (Lugworm, Moth Pupa, the balls...).
pub const KIND_BAIT: i64 = 6112;
/// gamedata_items.kind of lures (the flies, minnows, Spoon Lure...).
pub const KIND_LURE: i64 = 6113;

/// The gear package: 35 slots, code 0x00FE.
const EQUIPMENT_CAPACITY: u16 = 35;
const EQUIPMENT_CODE: u16 = 0x00FE;

/// Is an item kind fishing tackle? `Some(true)` for a lure, `Some(false)`
/// for bait, `None` for anything else.
pub fn tackle_kind(kind: i64) -> Option<bool> {
    match kind {
        KIND_BAIT => Some(false),
        KIND_LURE => Some(true),
        _ => None,
    }
}

/// The tackle stack in a Pack slot.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackTackle {
    pub server_item_id: u64,
    pub catalog_id: u32,
    pub quantity: i32,
    pub is_lure: bool,
    /// Where the stack sits in the bag.
    pub package: u16,
    pub slot: u16,
}

/// What [`use_tackle`] did.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TackleUse {
    /// One taken; this many are left in the Pack slot.
    Left(i32),
    /// That was the last one: the Pack slot and the bag no longer hold it.
    RanOut,
    /// The Pack slot doesn't hold that item (nothing changed).
    NotEquipped,
}

async fn current_class(registry: &ActorRegistry, player_id: u32) -> u8 {
    let Some(handle) = registry.get(player_id).await else {
        return 0;
    };
    let c = handle.character.read().await;
    if c.chara.current_job != 0 {
        c.chara.current_job as u8
    } else {
        c.chara.class.max(0) as u8
    }
}

/// Take one `catalog_id` off the Pack slot stack. With `world`, the client
/// is told; without it (tests), only the database changes.
pub async fn use_tackle(
    player_id: u32,
    catalog_id: u32,
    registry: &ActorRegistry,
    world: Option<&WorldManager>,
    db: &Database,
) -> TackleUse {
    let class_id = current_class(registry, player_id).await;
    use_tackle_for_class(player_id, class_id, catalog_id, registry, world, db).await
}

pub async fn use_tackle_for_class(
    player_id: u32,
    class_id: u8,
    catalog_id: u32,
    registry: &ActorRegistry,
    world: Option<&WorldManager>,
    db: &Database,
) -> TackleUse {
    let tackle = match db.pack_tackle(player_id, class_id).await {
        Ok(Some(t)) if t.catalog_id == catalog_id && t.quantity > 0 => t,
        Ok(other) => {
            tracing::debug!(
                player = player_id,
                item = catalog_id,
                ?other,
                "fishing tackle: not in the Pack slot"
            );
            return TackleUse::NotEquipped;
        }
        Err(e) => {
            tracing::warn!(player = player_id, err = %e, "fishing tackle: reading the Pack slot failed");
            return TackleUse::NotEquipped;
        }
    };
    if tackle.quantity > 1 {
        let left = tackle.quantity - 1;
        if let Err(e) = db.set_quantity(tackle.server_item_id, left).await {
            tracing::warn!(player = player_id, err = %e, "fishing tackle: set_quantity failed");
            return TackleUse::NotEquipped;
        }
        if let Some(world) = world {
            let rows = db
                .get_item_package(player_id, tackle.package as u32)
                .await
                .unwrap_or_default();
            let middle: Vec<_> = rows
                .iter()
                .filter(|r| r.unique_id == tackle.server_item_id)
                .map(|r| inv::build_inventory_list_x01(player_id, r))
                .collect();
            let cap = crate::inventory::default_capacity(tackle.package);
            let mut subs = vec![inv::build_inventory_begin_change(player_id, false)];
            subs.push(inv::build_inventory_set_begin(
                player_id,
                cap,
                tackle.package,
            ));
            subs.extend(middle);
            subs.push(inv::build_inventory_set_end(player_id));
            subs.push(inv::build_inventory_end_change(player_id));
            send(registry, world, player_id, subs).await;
        }
        tracing::info!(
            player = player_id,
            item = catalog_id,
            left,
            "fishing tackle used"
        );
        return TackleUse::Left(left);
    }

    // The last one: equipment rows first, then the bag row.
    let rows = db
        .get_item_package(player_id, tackle.package as u32)
        .await
        .unwrap_or_default();
    if let Err(e) = db
        .unequip_item_everywhere(player_id, tackle.server_item_id)
        .await
    {
        tracing::warn!(player = player_id, err = %e, "fishing tackle: unequip failed");
        return TackleUse::NotEquipped;
    }
    if let Err(e) = db.remove_item(player_id, tackle.server_item_id).await {
        tracing::warn!(player = player_id, err = %e, "fishing tackle: remove_item failed");
    }
    let packed =
        crate::runtime::quest_apply::realign_after_remove(&rows, &[], &[tackle.server_item_id]);
    if !packed.moved.is_empty()
        && let Err(e) = db.update_item_positions(&packed.moved).await
    {
        tracing::warn!(player = player_id, err = %e, "fishing tackle: packing the bag failed");
    }
    if let Some(world) = world {
        let links =
            crate::runtime::quest_apply::load_initial_equipment_pairs(db, player_id, class_id)
                .await;
        let cap = crate::inventory::default_capacity(tackle.package);
        let mut subs = vec![inv::build_inventory_begin_change(player_id, false)];
        // The Pack slot lets go of the stack before the bag loses it.
        subs.push(inv::build_inventory_set_begin(
            player_id,
            EQUIPMENT_CAPACITY,
            EQUIPMENT_CODE,
        ));
        subs.push(inv::build_inventory_remove_x01(player_id, SLOT_PACK));
        subs.push(inv::build_inventory_set_end(player_id));
        subs.push(inv::build_inventory_set_begin(
            player_id,
            cap,
            tackle.package,
        ));
        for r in &packed.changed {
            subs.push(inv::build_inventory_list_x01(player_id, r));
        }
        for slot in &packed.tail_slots {
            subs.push(inv::build_inventory_remove_x01(player_id, *slot));
        }
        subs.push(inv::build_inventory_set_end(player_id));
        // Packing moved bag slots: the gear links again.
        subs.push(inv::build_inventory_set_begin(
            player_id,
            EQUIPMENT_CAPACITY,
            EQUIPMENT_CODE,
        ));
        subs.extend(inv::build_set_initial_equipment(player_id, &links));
        subs.push(inv::build_inventory_set_end(player_id));
        subs.push(inv::build_inventory_end_change(player_id));
        send(registry, world, player_id, subs).await;
    }
    tracing::info!(
        player = player_id,
        item = catalog_id,
        "fishing tackle ran out: Pack slot cleared"
    );
    TackleUse::RanOut
}

async fn send(
    registry: &ActorRegistry,
    world: &WorldManager,
    player_id: u32,
    subs: Vec<common::subpacket::SubPacket>,
) {
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    if handle.session_id == 0 {
        return;
    }
    let Some(client) = world.client(handle.session_id).await else {
        return;
    };
    for mut sub in subs {
        sub.set_target_id(handle.session_id);
        client.send_bytes(sub.to_bytes()).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::actor::player::SLOT_MAINHAND;

    const LUGWORM: u32 = 3_940_002;
    const CHOCOBO_FLY: u32 = 3_940_101;
    const MAPLE_ROD: u32 = 7_030_009;
    const CRAYFISH: u32 = 3_011_103;
    const FISHER: u8 = 41;

    async fn db() -> Database {
        Database::open(common::test_db::fresh().await.expect("test db url"))
            .await
            .expect("test db")
    }

    /// Bag: rod (slot 0), the tackle stack (slot 1), a fish (slot 2); rod in
    /// the main hand, the stack in the Pack slot.
    async fn fisher_with(db: &Database, chara: u32, tackle: u32, qty: i32) -> (u64, u64, u64) {
        db.add_harvest_item(chara, MAPLE_ROD, 1, 1).await.unwrap();
        db.add_harvest_item(chara, tackle, qty, 1).await.unwrap();
        db.add_harvest_item(chara, CRAYFISH, 3, 1).await.unwrap();
        let sid = |slot| async move {
            db.resolve_bag_slot_item_id(chara, 0, slot)
                .await
                .unwrap()
                .unwrap()
                .0
        };
        let (rod, stack, fish) = (sid(0).await, sid(1).await, sid(2).await);
        db.equip_item(chara, FISHER, SLOT_MAINHAND, rod, false)
            .await
            .unwrap();
        db.equip_item(chara, FISHER, SLOT_PACK, stack, false)
            .await
            .unwrap();
        (rod, stack, fish)
    }

    #[tokio::test]
    async fn pack_tackle_reads_bait_and_lures_only() {
        let db = db().await;
        fisher_with(&db, 61, LUGWORM, 5).await;
        let t = db
            .pack_tackle(61, FISHER)
            .await
            .unwrap()
            .expect("bait in the Pack slot");
        assert_eq!(
            (t.catalog_id, t.quantity, t.is_lure, t.slot),
            (LUGWORM, 5, false, 1)
        );
        fisher_with(&db, 62, CHOCOBO_FLY, 2).await;
        let t = db
            .pack_tackle(62, FISHER)
            .await
            .unwrap()
            .expect("lure in the Pack slot");
        assert!(t.is_lure);
        // Nothing in the Pack slot: no tackle.
        assert_eq!(db.pack_tackle(63, FISHER).await.unwrap(), None);
    }

    #[tokio::test]
    async fn the_last_bait_leaves_the_pack_slot_and_the_bag() {
        let db = db().await;
        let registry = ActorRegistry::new();
        let (rod, stack, fish) = fisher_with(&db, 64, LUGWORM, 2).await;
        // The same stack linked by a second class too.
        db.equip_item(64, 3, SLOT_PACK, stack, false).await.unwrap();

        let used = use_tackle_for_class(64, FISHER, LUGWORM, &registry, None, &db).await;
        assert_eq!(used, TackleUse::Left(1));
        assert_eq!(
            db.pack_tackle(64, FISHER).await.unwrap().unwrap().quantity,
            1
        );

        // Another item id than the one in the slot changes nothing.
        let used = use_tackle_for_class(64, FISHER, CHOCOBO_FLY, &registry, None, &db).await;
        assert_eq!(used, TackleUse::NotEquipped);

        let used = use_tackle_for_class(64, FISHER, LUGWORM, &registry, None, &db).await;
        assert_eq!(used, TackleUse::RanOut);
        assert_eq!(db.pack_tackle(64, FISHER).await.unwrap(), None);
        // No equipment row of any class points at it any more.
        assert_eq!(db.equipped_item(64, FISHER, SLOT_PACK).await.unwrap(), None);
        assert_eq!(db.equipped_item(64, 3, SLOT_PACK).await.unwrap(), None);
        // The bag lost it and closed the hole: the fish moved up to slot 1.
        let bag = db.get_item_package(64, 0).await.unwrap();
        assert!(bag.iter().all(|i| i.unique_id != stack), "{bag:?}");
        let fish_row = bag.iter().find(|i| i.unique_id == fish).expect("fish");
        assert_eq!(fish_row.slot, 1);
        assert!(bag.iter().all(|i| i.slot < 2), "{bag:?}");
        // The rod is still in the main hand, linked to bag slot 0.
        let links = db.equipment_links(64, FISHER).await.unwrap();
        assert_eq!(links, vec![(SLOT_MAINHAND, 0, 0)]);
        assert_eq!(
            db.equipped_item(64, FISHER, SLOT_MAINHAND)
                .await
                .unwrap()
                .map(|e| e.0),
            Some(rod)
        );
        // Nothing left to use.
        let used = use_tackle_for_class(64, FISHER, LUGWORM, &registry, None, &db).await;
        assert_eq!(used, TackleUse::NotEquipped);
    }

    #[test]
    fn only_bait_and_lures_are_tackle() {
        assert_eq!(tackle_kind(KIND_BAIT), Some(false));
        assert_eq!(tackle_kind(KIND_LURE), Some(true));
        assert_eq!(tackle_kind(6107), None); // a fishing rod
        assert_eq!(tackle_kind(2032), None); // a fish
    }
}
