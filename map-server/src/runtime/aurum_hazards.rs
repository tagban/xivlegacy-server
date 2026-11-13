//! The Aurum Vale's hazards: Gold Lung gas and goldbile pools.
//!
//! Where they are comes from the client's own layout for the dungeon
//! (`roc_r0_dun04`, moved to server coordinates by the layout offset
//! (-943.3, 196.0, 1376.25), fitted to the dungeon's five barrier rows):
//!
//! * Gold Lung gas: the dungeon's 146 gold-smoke effects (`sgrp_vfx_gok_smk`,
//!   used nowhere else) sit in four rooms. Breathing it adds a stack of Gold
//!   Lung, a damage-over-time status that grows with each stack.
//! * Goldbile pools: the liquid-surface meshes of the pool pieces
//!   (`sgrp_r0d0_rob_*_w`) under that smoke, as 1-yalm cells (`aurum_pools`).
//!   Standing in one poisons you with Goldbile for about a minute, renewed
//!   while you stay in it.
//!
//! Both are client statuses (`DotAurumStatus`, ids 223258/223259). The client
//! keeps them through death, so neither has the lose-on-death flag; both go
//! when you leave the copy (lose on zoning).

use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};

use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The Aurum Vale copy's zone id.
pub const ZONE_ID: u32 = 245;
pub const STATUS_GOLD_LUNG: u32 = 223_258;
pub const STATUS_GOLDBILE: u32 = 223_259;

/// How often the hazards are checked for each copy.
const TICK_MS: u64 = 3_000;
/// A breath of gas adds one stack this often while you stay in it.
const GAS_STACK_EVERY_MS: u64 = 9_000;
/// Gold Lung stacks top out here.
pub const GOLD_LUNG_MAX_STACKS: u8 = 10;
/// Gold Lung wears off this long after your last breath of gas.
const GOLD_LUNG_DURATION_S: u32 = 180;
/// Goldbile lasts about a minute after you step out of the pool.
const GOLDBILE_DURATION_S: u32 = 60;

/// A box of gold gas: (min x, max x, min y, max y, min z, max z).
pub struct GasRoom {
    pub name: &'static str,
    pub bounds: (f32, f32, f32, f32, f32, f32),
}

/// The four rooms with gold smoke: the smoke's extent plus 6 yalms, from a
/// little under the floor to well above the smoke.
pub const GAS_ROOMS: &[GasRoom] = &[
    GasRoom {
        name: "east pool room",
        bounds: (-764.0, -675.0, 165.0, 179.0, 1234.0, 1328.0),
    },
    GasRoom {
        name: "south pool room",
        bounds: (-958.0, -861.0, 174.0, 188.0, 1519.0, 1613.0),
    },
    GasRoom {
        name: "central pool room",
        bounds: (-993.0, -861.0, 189.0, 204.0, 1358.0, 1458.0),
    },
    GasRoom {
        name: "west pool",
        bounds: (-1308.0, -1259.0, 189.0, 204.0, 1407.0, 1446.0),
    },
];

/// How far under / over the liquid's surface still counts as standing in it
/// (the client puts you about 0.1 above it).
const POOL_BELOW: f32 = 2.0;
const POOL_ABOVE: f32 = 2.5;

pub fn gas_room_at(x: f32, y: f32, z: f32) -> Option<&'static GasRoom> {
    GAS_ROOMS.iter().find(|r| {
        let (x0, x1, y0, y1, z0, z1) = r.bounds;
        (x0..=x1).contains(&x) && (y0..=y1).contains(&y) && (z0..=z1).contains(&z)
    })
}

/// The liquid surface's height under (x, z), if there is goldbile there.
pub fn pool_surface(x: f32, z: f32) -> Option<f32> {
    let (cx, cz) = (x.floor(), z.floor());
    if !(f32::from(i16::MIN)..f32::from(i16::MAX)).contains(&cx)
        || !(f32::from(i16::MIN)..f32::from(i16::MAX)).contains(&cz)
    {
        return None;
    }
    let (cx, cz) = (cx as i16, cz as i16);
    let runs = crate::runtime::aurum_pools::POOL_RUNS;
    let start = runs.partition_point(|r| r.0 < cz);
    runs[start..]
        .iter()
        .take_while(|r| r.0 == cz)
        .find(|r| (r.1..=r.2).contains(&cx))
        .map(|r| r.3)
}

pub fn in_pool(x: f32, y: f32, z: f32) -> bool {
    pool_surface(x, z).is_some_and(|s| y >= s - POOL_BELOW && y <= s + POOL_ABOVE)
}

/// HP lost per status tick for each Gold Lung stack: a tenth of the level, so
/// ten stacks at level 50 hurt like two poisons.
pub fn gold_lung_tick(level: i32, stacks: u8) -> f64 {
    (f64::from(level.max(10)) / 10.0).floor() * f64::from(stacks)
}

/// Goldbile hurts like a monster poison: half the level per tick.
pub fn goldbile_tick(level: i32) -> f64 {
    (f64::from(level.max(2)) / 2.0).floor()
}

/// Each player's last breath of gas, by (instance, player).
fn last_breath() -> &'static Mutex<HashMap<(u32, u32), u64>> {
    static M: OnceLock<Mutex<HashMap<(u32, u32), u64>>> = OnceLock::new();
    M.get_or_init(|| Mutex::new(HashMap::new()))
}

/// When each copy's hazards were last checked.
fn last_tick() -> &'static Mutex<HashMap<u32, u64>> {
    static M: OnceLock<Mutex<HashMap<u32, u64>>> = OnceLock::new();
    M.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Forget a finished copy.
pub fn release_instance(instance_id: u32) {
    last_tick()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&instance_id);
    last_breath()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .retain(|(i, _), _| *i != instance_id);
}

/// Whether a breath now adds a stack (the first breath always does).
fn breath_due(instance_id: u32, player_id: u32, now_ms: u64) -> bool {
    let mut map = last_breath().lock().unwrap_or_else(|e| e.into_inner());
    match map.get(&(instance_id, player_id)) {
        Some(&t) if now_ms.saturating_sub(t) < GAS_STACK_EVERY_MS => false,
        _ => {
            map.insert((instance_id, player_id), now_ms);
            true
        }
    }
}

/// Run the hazards for one Aurum Vale copy. Called from the content tick.
pub async fn tick(
    now_ms: u64,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: &Arc<LuaEngine>,
    zone_id: u32,
    instance_id: u32,
) {
    if zone_id != ZONE_ID || instance_id == 0 {
        return;
    }
    {
        let mut map = last_tick().lock().unwrap_or_else(|e| e.into_inner());
        let last = map.entry(instance_id).or_insert(0);
        if now_ms.saturating_sub(*last) < TICK_MS {
            return;
        }
        *last = now_ms;
    }
    let player_ids =
        crate::runtime::dungeon_fight::players_in_copy(world, zone_id, instance_id).await;
    for pid in player_ids {
        let Some(h) = registry.get(pid).await else {
            continue;
        };
        let (x, y, z, level, alive, stacks) = {
            let c = h.character.read().await;
            let stacks = c
                .status_effects
                .get(STATUS_GOLD_LUNG)
                .map(|e| e.tier)
                .unwrap_or(0);
            (
                c.base.position_x,
                c.base.position_y,
                c.base.position_z,
                i32::from(c.chara.level),
                c.base.current_main_state != crate::actor::MAIN_STATE_DEAD,
                stacks,
            )
        };
        if !alive {
            continue;
        }
        if let Some(room) = gas_room_at(x, y, z)
            && breath_due(instance_id, pid, now_ms)
        {
            let stacks = stacks.saturating_add(1).min(GOLD_LUNG_MAX_STACKS);
            let landed = crate::runtime::quest_apply::apply_try_status(
                pid,
                pid,
                STATUS_GOLD_LUNG,
                GOLD_LUNG_DURATION_S,
                gold_lung_tick(level, stacks),
                0,
                stacks,
                registry,
                db,
                world,
                Some(lua),
            )
            .await;
            if landed {
                tracing::info!(
                    player = pid,
                    instance = instance_id,
                    room = room.name,
                    stacks,
                    "aurum vale: gold lung",
                );
            }
        }
        if in_pool(x, y, z) {
            let fresh = {
                let c = h.character.read().await;
                !c.status_effects.has(STATUS_GOLDBILE)
            };
            crate::runtime::quest_apply::apply_try_status(
                pid,
                pid,
                STATUS_GOLDBILE,
                GOLDBILE_DURATION_S,
                goldbile_tick(level),
                0,
                1,
                registry,
                db,
                world,
                Some(lua),
            )
            .await;
            if fresh {
                tracing::info!(player = pid, instance = instance_id, "aurum vale: goldbile",);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pool_runs_are_sorted_and_inside_gas_rooms() {
        let runs = crate::runtime::aurum_pools::POOL_RUNS;
        assert!(runs.windows(2).all(|w| w[0].0 <= w[1].0));
        for &(z, x0, x1, y) in runs {
            assert!(x0 <= x1);
            let (x, z) = (f32::from(x0) + 0.5, f32::from(z) + 0.5);
            assert!(
                gas_room_at(x, y + 0.5, z).is_some(),
                "pool cell ({x}, {y}, {z}) has no gas room"
            );
            assert!(in_pool(x, y + 0.1, z));
        }
    }

    #[test]
    fn client_checked_spots() {
        // Stood in the pool in the client at (-922, 195.3, 1432).
        assert!(in_pool(-922.0, 195.3, 1432.0));
        // Stood on the bank just south of it at (-922, 195.7, 1425).
        assert!(!in_pool(-922.0, 195.7, 1425.0));
        assert!(gas_room_at(-922.0, 195.7, 1425.0).is_some());
    }

    #[test]
    fn outside_the_rooms_is_clear() {
        // Coincounter's room and Miser's Mistress's room.
        assert!(gas_room_at(-1081.5, 189.0, 1282.5).is_none());
        assert!(!in_pool(-1081.5, 189.0, 1282.5));
        assert!(gas_room_at(-969.5, 173.2, 1046.5).is_none());
        // Well above or below the pool surface.
        assert!(!in_pool(-922.0, 205.0, 1432.0));
        assert!(!in_pool(-922.0, 185.0, 1432.0));
    }

    #[test]
    fn gold_lung_grows_with_stacks() {
        assert_eq!(gold_lung_tick(50, 1), 5.0);
        assert_eq!(gold_lung_tick(50, 10), 50.0);
        assert_eq!(gold_lung_tick(1, 1), 1.0);
        assert_eq!(goldbile_tick(50), 25.0);
    }

    #[test]
    fn a_breath_stacks_once_per_interval() {
        let inst = 0xA0A0;
        assert!(breath_due(inst, 7, 1_000));
        assert!(!breath_due(inst, 7, 1_000 + GAS_STACK_EVERY_MS - 1));
        assert!(breath_due(inst, 7, 1_000 + GAS_STACK_EVERY_MS));
        release_instance(inst);
        assert!(breath_due(inst, 7, 1_000 + GAS_STACK_EVERY_MS + 1));
        release_instance(inst);
    }
}
