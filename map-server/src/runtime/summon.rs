//! Boss moves that call adds into the fight.
//!
//! A boss's summoning move brings its adds in when the move lands rather than
//! having them stand in the room from the start: they appear around the boss,
//! in the boss's dungeon copy, and go straight for whoever the boss is
//! fighting. Each boss keeps at most `cap` of its adds alive at a time, so a
//! long fight doesn't flood the room.
//!
//! The adds are the client's own classes for that dungeon (their names come
//! from the 1.23b monster name sheet), with pools in
//! `server_battlenpc_pools`.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use tokio::sync::RwLock;

use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;
use crate::zone::zone::Zone;

/// One summoning move: who it calls, how many per use, and the most alive
/// at once for one boss.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Summon {
    pub command_id: u16,
    pub class_id: u32,
    pub level: u32,
    pub count: u32,
    pub cap: u32,
}

/// Myrmidon Princess (Cutter's Cry): Formic Pheromones, her self-targeted
/// move with a 4.5 s wind-up, calls Myrmidon Soldiers (level 45 in the 1.0
/// records).
pub const SUMMONS: &[Summon] = &[Summon {
    command_id: 23560,
    class_id: 2303001,
    level: 45,
    count: 3,
    cap: 6,
}];

pub fn summon_for(command_id: u16) -> Option<Summon> {
    SUMMONS.iter().copied().find(|s| s.command_id == command_id)
}

/// Adds each boss has called, by boss actor id.
static CALLED: Mutex<Option<HashMap<u32, Vec<u32>>>> = Mutex::new(None);

/// How many more adds the boss may call now, given which of its earlier adds
/// are still alive.
pub fn room_for(summon: &Summon, alive: usize) -> u32 {
    summon.cap.saturating_sub(alive as u32).min(summon.count)
}

/// Spots in a ring `radius` yalms around (x, z), facing the centre.
pub fn ring(x: f32, z: f32, radius: f32, n: u32, start: f32) -> Vec<(f32, f32, f32)> {
    (0..n)
        .map(|k| {
            let a = start + std::f32::consts::TAU * k as f32 / n.max(1) as f32;
            let (px, pz) = (x + radius * a.sin(), z + radius * a.cos());
            (px, pz, (x - px).atan2(z - pz))
        })
        .collect()
}

/// Called after a monster's move resolves. If the move summons, spawn the
/// adds next to the boss and set them on its target.
#[allow(clippy::too_many_arguments)]
pub async fn on_move(
    boss_id: u32,
    command_id: u16,
    target_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    zone: &Arc<RwLock<Zone>>,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
) {
    let Some(summon) = summon_for(command_id) else {
        return;
    };
    let Some(boss) = registry.get(boss_id).await else {
        return;
    };
    if boss.is_player() {
        return;
    }
    let (x, y, z, rot) = {
        let c = boss.character.read().await;
        if !c.is_alive() {
            return;
        }
        (
            c.base.position_x,
            c.base.position_y,
            c.base.position_z,
            c.base.rotation,
        )
    };
    let zone_id = boss.zone_id;
    let instance_id = zone.read().await.core.instance_of(boss_id);

    // drop adds that died or were removed
    let earlier = {
        let mut called = CALLED.lock().unwrap();
        called
            .get_or_insert_with(HashMap::new)
            .get(&boss_id)
            .cloned()
            .unwrap_or_default()
    };
    let mut alive = Vec::new();
    for id in earlier {
        if let Some(h) = registry.get(id).await
            && h.character.read().await.is_alive()
        {
            alive.push(id);
        }
    }
    let n = room_for(&summon, alive.len());
    if n == 0 {
        set_called(boss_id, alive);
        return;
    }

    let class = match db.load_actor_class(summon.class_id).await {
        Ok(Some(c)) => c,
        _ => {
            tracing::warn!(class = summon.class_id, "summon: actor class missing");
            return;
        }
    };
    let genus = crate::processor::gm_spawn::genus_for(db, summon.class_id, &class.class_path).await;
    let spots: Vec<_> = ring(x, z, 4.0, n, rot)
        .into_iter()
        .map(|(px, pz, r)| (px, y, pz, r))
        .collect();
    let (bnpc_ids, group_id, pool_id) = match db
        .gm_spawn_insert(
            summon.class_id,
            summon.class_id.to_string(),
            genus,
            zone_id,
            summon.level,
            spots,
        )
        .await
    {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!(error = %e, "summon: spawn rows failed");
            return;
        }
    };
    let mut spawned = Vec::new();
    for bnpc_id in &bnpc_ids {
        let actor_id = (4 << 28) | (zone_id << 19) | crate::processor::gm_spawn::next_number();
        if crate::runtime::bnpc_spawn::spawn_battle_npc_as(
            *bnpc_id,
            zone_id,
            actor_id,
            Some(None),
            None,
            None,
            instance_id,
            db,
            world,
            registry,
            lua,
        )
        .await
        {
            spawned.push(actor_id);
        }
    }
    if let Err(e) = db.gm_spawn_delete(bnpc_ids, group_id, pool_id).await {
        tracing::warn!(error = %e, "summon: removing the temporary spawn rows failed");
    }
    // target 0: nobody to fight yet; the adds wait by the boss
    for id in spawned.iter().filter(|_| target_id != 0) {
        crate::runtime::quest_apply::apply_actor_engage(*id, target_id, registry, world).await;
    }
    tracing::info!(
        boss = format!("0x{boss_id:08X}"),
        command = command_id,
        class = summon.class_id,
        called = spawned.len(),
        alive_before = alive.len(),
        instance = instance_id,
        "battle: boss called adds",
    );
    alive.extend(spawned);
    set_called(boss_id, alive);
}

fn set_called(boss_id: u32, adds: Vec<u32>) {
    let mut called = CALLED.lock().unwrap();
    called
        .get_or_insert_with(HashMap::new)
        .insert(boss_id, adds);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn princess_pheromones_call_soldiers() {
        let s = summon_for(23560).expect("Formic Pheromones summons");
        assert_eq!(s.class_id, 2303001);
        // the ant family's own Formic Pheromones calls nobody
        assert!(summon_for(23229).is_none());
    }

    #[test]
    fn adds_stop_at_the_cap() {
        let s = summon_for(23560).unwrap();
        assert_eq!(room_for(&s, 0), 3);
        assert_eq!(room_for(&s, 4), 2);
        assert_eq!(room_for(&s, 6), 0);
        assert_eq!(room_for(&s, 9), 0);
    }

    #[test]
    fn ring_faces_the_boss() {
        let spots = ring(10.0, 20.0, 4.0, 3, 0.0);
        assert_eq!(spots.len(), 3);
        for (x, z, r) in spots {
            let d = ((x - 10.0).powi(2) + (z - 20.0).powi(2)).sqrt();
            assert!((d - 4.0).abs() < 1e-4);
            // facing: a step along the rotation heads back to the centre
            let (nx, nz) = (x + d * r.sin(), z + d * r.cos());
            assert!((nx - 10.0).abs() < 1e-3 && (nz - 20.0).abs() < 1e-3);
        }
    }
}
