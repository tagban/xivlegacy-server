// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Opening and closing a dungeon copy's doors and barriers
//! (`crate::dungeon_gates`) for the players inside it.

use crate::world_manager::WorldManager;

/// Player actor ids standing in one copy of `zone_id`.
pub async fn players_in_copy(world: &WorldManager, zone_id: u32, instance_id: u32) -> Vec<u32> {
    let Some(zone) = world.zone(zone_id).await else {
        return Vec::new();
    };
    let sessions = world.all_sessions().await;
    let z = zone.read().await;
    sessions
        .iter()
        .filter(|s| s.current_zone_id == zone_id && z.core.instance_of(s.id) == instance_id)
        .map(|s| s.id)
        .collect()
}

/// Open or close one gate of a copy by its unique id and show it to the
/// copy's players. Returns false when the copy has no such gate.
pub async fn set_gate(
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
    unique_id: &str,
    open: bool,
) -> bool {
    let Some((actor_id, _class)) = crate::dungeon_gates::find(instance_id, unique_id) else {
        return false;
    };
    if let Some(schedule) = crate::dungeon_gates::set_open(actor_id, open) {
        send_schedule(world, zone_id, instance_id, actor_id, schedule).await;
        tracing::info!(
            zone = zone_id,
            instance = instance_id,
            gate = unique_id,
            schedule,
            "dungeon gate {}",
            if open { "opened" } else { "closed" },
        );
    }
    true
}

async fn send_schedule(
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
    actor_id: u32,
    schedule: &str,
) {
    for player in players_in_copy(world, zone_id, instance_id).await {
        let Some(client) = world.client(player).await else {
            continue;
        };
        let mut pkt = crate::packets::send::actor::build_play_bg_animation(actor_id, schedule);
        pkt.set_target_id(player);
        client.send_bytes(pkt.to_bytes()).await;
    }
}

/// Unique ids of every gate of a copy.
pub fn gates_of(instance_id: u32) -> Vec<String> {
    crate::dungeon_gates::unique_ids(instance_id)
}

// ---------------------------------------------------------------------------
// Boss fights
// ---------------------------------------------------------------------------

/// Seconds a boss room's gate stays open after the fight starts, so the
/// rest of the party can come in, before it closes behind them. The
/// 1.23b client holds no number for it (its `RaidDungeonBarrier` and
/// occupancy directors only open and close what the server tells them),
/// so this is our choice.
pub const BOSS_GATE_DELAY_MS: u64 = 15_000;

/// A fight is lost when every fighter has been down at once for this
/// long (and none has a Reraise waiting). Until then a fallen fighter
/// stays where they fell and can be raised there.
pub const LOSS_AFTER_ALL_DOWN_MS: u64 = 30_000;

/// A boss's room in a dungeon: the gates that shut it, the round room
/// (centre and radius, inside the gates), and a spot just outside them
/// for anyone who isn't in the fight.
#[derive(Debug, Clone, Copy)]
pub struct BossRoom {
    pub zone_id: u32,
    pub name: &'static str,
    /// `server_battlenpc_spawn_locations.bnpcId` the dungeon spawns
    /// (`scripts/lua/dungeon_spawns.lua`).
    pub bnpc_id: u32,
    pub gates: &'static [&'static str],
    pub centre: (f32, f32, f32),
    /// Inside the room: closer than this to `centre` and within
    /// `ROOM_FLOOR_SPAN` of its floor.
    pub radius: f32,
    pub outside: Spot,
}

const ROOM_FLOOR_SPAN: f32 = 6.0;

/// Boss rooms. Toto-Rak's: each chamber is a round room (radius 22, from
/// the layout's floor) behind its door; the radius reaches to just inside
/// the door. New bosses get a row here once they are placed.
pub const BOSS_ROOMS: &[BossRoom] = &[
    BossRoom {
        zone_id: 159,
        name: "Antares",
        bnpc_id: 3457,
        gates: &["fstdun3_door_confessionchamber"],
        centre: (1250.4, -46.9, 928.8),
        radius: 36.5,
        outside: (1212.5, -47.9, 910.3, -2.0),
    },
    BossRoom {
        zone_id: 159,
        name: "Sargas",
        bnpc_id: 3458,
        gates: &["fstdun3_door_executionchamber"],
        centre: (1472.2, -58.9, 642.1),
        radius: 32.0,
        outside: (1454.1, -59.9, 675.1, 2.6),
    },
    BossRoom {
        zone_id: 159,
        name: "Shaula",
        bnpc_id: 3459,
        gates: &["fstdun3_door_interrogatiochamber"],
        centre: (1345.1, -62.9, 545.2),
        radius: 34.5,
        outside: (1308.4, -63.9, 561.6, -1.2),
    },
    BossRoom {
        zone_id: 231,
        name: "Batraal",
        bnpc_id: 2000,
        gates: &[],
        centre: (69.0, 148.7, -141.0),
        radius: 30.0,
        outside: (43.0, 151.5, -119.0, 2.27),
    },
    BossRoom {
        zone_id: 231,
        name: "All-seeing Eye",
        bnpc_id: 2001,
        gates: &[],
        centre: (-219.0, 169.7, -11.0),
        radius: 15.0,
        outside: (-215.0, 173.1, 15.0, -2.99),
    },
    BossRoom {
        zone_id: 231,
        name: "Soulgazer",
        bnpc_id: 2002,
        gates: &[],
        centre: (-111.0, 153.6, -275.0),
        radius: 15.0,
        outside: (-109.0, 153.2, -255.0, -3.04),
    },
];

/// Where a dungeon copy starts (`DUNGEONS[..].entry` in
/// `scripts/lua/dungeon.lua`): a lost boss fight brings the party here.
/// A spot and facing: x, y, z, rotation.
pub type Spot = (f32, f32, f32, f32);

pub const ENTRANCES: &[(u32, Spot)] = &[
    (159, (885.0, -22.7, 651.0, 1.57)),
    (231, (64.0, 181.25, 192.0, std::f32::consts::PI)),
    (245, (-686.9, 171.3, 1359.9, 0.0)),
    (246, (-1402.0, 252.2, -1455.0, 0.0)),
];

pub fn entrance(zone_id: u32) -> Option<Spot> {
    ENTRANCES
        .iter()
        .find(|(z, _)| *z == zone_id)
        .map(|(_, e)| *e)
}

impl BossRoom {
    pub fn contains(&self, x: f32, y: f32, z: f32) -> bool {
        let (cx, cy, cz) = self.centre;
        (y - cy).abs() <= ROOM_FLOOR_SPAN && (x - cx).hypot(z - cz) <= self.radius
    }

    /// The boss's actor id in a copy (the `SpawnBattleNpcById` formula).
    pub fn boss_actor_id(&self, slot: u32) -> u32 {
        let n = crate::content_instance::bnpc_actor_number(slot, self.bnpc_id);
        (4u32 << 28) | (self.zone_id << 19) | (n & 0x7FFFF)
    }
}

/// Where one boss fight of one copy stands.
#[derive(Debug, Clone, PartialEq)]
pub enum Phase {
    /// The boss was hit or engaged; the gates close at `close_at_ms`.
    Joining { close_at_ms: u64 },
    /// Gates closed on `fighters`. `wiped_at_ms` is set once none of them
    /// is standing.
    Sealed {
        fighters: Vec<u32>,
        wiped_at_ms: Option<u64>,
    },
    /// The boss is down; the gates stay open.
    Won,
}

/// What a tick decided for one fight.
#[derive(Debug, Clone, PartialEq)]
pub enum Step {
    None,
    CloseGates {
        fighters: Vec<u32>,
    },
    OpenGates,
    /// Lost: bring these players to the entrance and reset the boss.
    Wipe {
        players: Vec<u32>,
    },
    /// Players who aren't in the fight but got into the sealed room.
    PushOut {
        players: Vec<u32>,
    },
}

/// One player of the copy, as a tick sees them.
#[derive(Debug, Clone, Copy)]
pub struct Fighter {
    pub actor_id: u32,
    pub alive: bool,
    pub in_room: bool,
    /// Knocked out with a Reraise waiting (`Modifier::Raise`): not down
    /// for the loss check.
    pub raise_pending: bool,
}

impl Fighter {
    fn down(&self) -> bool {
        !self.alive && !self.raise_pending
    }
}

/// What a tick sees of the boss.
#[derive(Debug, Clone, Copy)]
pub struct BossView {
    /// Dead, or gone from the copy.
    pub down: bool,
    /// Engaged, or below full HP.
    pub fighting: bool,
}

/// The fight's state machine, without I/O.
pub fn advance(
    phase: Option<Phase>,
    boss: BossView,
    players: &[Fighter],
    now_ms: u64,
) -> (Option<Phase>, Step) {
    match phase {
        Some(Phase::Won) => (Some(Phase::Won), Step::None),
        _ if boss.down => {
            let step = if matches!(phase, Some(Phase::Sealed { .. })) {
                Step::OpenGates
            } else {
                Step::None
            };
            (Some(Phase::Won), step)
        }
        None => {
            if boss.fighting {
                (
                    Some(Phase::Joining {
                        close_at_ms: now_ms + BOSS_GATE_DELAY_MS,
                    }),
                    Step::None,
                )
            } else {
                (None, Step::None)
            }
        }
        Some(Phase::Joining { close_at_ms }) => {
            let standing_inside: Vec<u32> = players
                .iter()
                .filter(|p| p.alive && p.in_room)
                .map(|p| p.actor_id)
                .collect();
            if !boss.fighting && standing_inside.is_empty() {
                // The boss let go (no one left to fight) before the gates
                // closed: back to waiting.
                return (None, Step::None);
            }
            if !players.is_empty() && players.iter().all(Fighter::down) {
                // Everyone fell before the gates closed.
                let dead: Vec<u32> = players.iter().map(|p| p.actor_id).collect();
                return (
                    Some(Phase::Sealed {
                        fighters: dead,
                        wiped_at_ms: Some(now_ms),
                    }),
                    Step::None,
                );
            }
            if now_ms < close_at_ms {
                return (Some(Phase::Joining { close_at_ms }), Step::None);
            }
            if standing_inside.is_empty() {
                // Nobody inside to shut in: keep the gates open and wait.
                return (Some(Phase::Joining { close_at_ms }), Step::None);
            }
            (
                Some(Phase::Sealed {
                    fighters: standing_inside.clone(),
                    wiped_at_ms: None,
                }),
                Step::CloseGates {
                    fighters: standing_inside,
                },
            )
        }
        Some(Phase::Sealed {
            fighters,
            wiped_at_ms,
        }) => {
            // Only fighters still in the room hold the fight: one who took
            // Return to the entrance (or left the copy) is out of it.
            let standing = players
                .iter()
                .any(|p| !p.down() && p.in_room && fighters.contains(&p.actor_id));
            if standing {
                let intruders: Vec<u32> = players
                    .iter()
                    .filter(|p| p.alive && p.in_room && !fighters.contains(&p.actor_id))
                    .map(|p| p.actor_id)
                    .collect();
                let step = if intruders.is_empty() {
                    Step::None
                } else {
                    Step::PushOut { players: intruders }
                };
                return (
                    Some(Phase::Sealed {
                        fighters,
                        wiped_at_ms: None,
                    }),
                    step,
                );
            }
            let wiped_at = wiped_at_ms.unwrap_or(now_ms);
            if now_ms < wiped_at + LOSS_AFTER_ALL_DOWN_MS {
                return (
                    Some(Phase::Sealed {
                        fighters,
                        wiped_at_ms: Some(wiped_at),
                    }),
                    Step::None,
                );
            }
            // Lost: the fighters, and anyone else of the copy lying dead,
            // go back to the entrance.
            let back: Vec<u32> = fighters
                .into_iter()
                .filter(|f| players.iter().any(|p| p.actor_id == *f))
                .collect();
            (None, Step::Wipe { players: back })
        }
    }
}

fn fights() -> &'static std::sync::Mutex<std::collections::HashMap<(u32, u32), Phase>> {
    static F: std::sync::OnceLock<std::sync::Mutex<std::collections::HashMap<(u32, u32), Phase>>> =
        std::sync::OnceLock::new();
    F.get_or_init(Default::default)
}

/// The two sides of a sealed fight: the fighters with their boss, and the
/// copy's other players.
#[derive(Debug, Clone, Default)]
struct Sides {
    inside: Vec<u32>,
    outside: Vec<u32>,
}

type SideMap = std::collections::HashMap<(u32, u32), Sides>;

fn sides() -> &'static std::sync::Mutex<SideMap> {
    static S: std::sync::OnceLock<std::sync::Mutex<SideMap>> = std::sync::OnceLock::new();
    S.get_or_init(Default::default)
}

fn record_sides(
    instance_id: u32,
    bnpc_id: u32,
    boss_id: u32,
    phase: Option<&Phase>,
    copy_players: &[u32],
) {
    let mut map = sides().lock().unwrap_or_else(|e| e.into_inner());
    match phase {
        Some(Phase::Sealed { fighters, .. }) => {
            let mut inside = fighters.clone();
            inside.push(boss_id);
            let outside = copy_players
                .iter()
                .copied()
                .filter(|p| !fighters.contains(p))
                .collect();
            map.insert((instance_id, bnpc_id), Sides { inside, outside });
        }
        _ => {
            map.remove(&(instance_id, bnpc_id));
        }
    }
}

/// Whether `a` may act on `b` (attack, heal, buff, raise). While a boss
/// room is sealed, its fighters and boss on one side and the copy's other
/// players on the other can't touch each other; adds, and everything
/// that isn't a battle action (party chat), are untouched.
pub fn may_interact(a: u32, b: u32) -> bool {
    if a == b {
        return true;
    }
    let map = sides().lock().unwrap_or_else(|e| e.into_inner());
    map.values().all(|s| {
        let side = |x: u32| {
            if s.inside.contains(&x) {
                1
            } else if s.outside.contains(&x) {
                2
            } else {
                0
            }
        };
        let (sa, sb) = (side(a), side(b));
        sa == 0 || sb == 0 || sa == sb
    })
}

/// Forget a finished copy's fights.
pub fn release_instance(instance_id: u32) {
    fights()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .retain(|(i, _), _| *i != instance_id);
    sides()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .retain(|(i, _), _| *i != instance_id);
}

/// Run the boss fights of one copy (every content tick, from its owner's
/// session).
pub async fn tick_boss_fights(
    now_ms: u64,
    registry: &crate::runtime::actor_registry::ActorRegistry,
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
) {
    if instance_id == 0 || !BOSS_ROOMS.iter().any(|r| r.zone_id == zone_id) {
        return;
    }
    let Some(slot) = crate::content_instance::get(instance_id).map(|i| i.slot) else {
        return;
    };
    let player_ids = players_in_copy(world, zone_id, instance_id).await;
    for room in BOSS_ROOMS.iter().filter(|r| r.zone_id == zone_id) {
        let boss_id = room.boss_actor_id(slot);
        let boss = match registry.get(boss_id).await {
            Some(h) => {
                let c = h.character.read().await;
                BossView {
                    down: c.base.current_main_state == crate::actor::MAIN_STATE_DEAD,
                    fighting: c.ai_container.is_engaged() || c.chara.hp < c.chara.max_hp,
                }
            }
            None => BossView {
                down: true,
                fighting: false,
            },
        };
        let mut players = Vec::with_capacity(player_ids.len());
        for &pid in &player_ids {
            let Some(h) = registry.get(pid).await else {
                continue;
            };
            let c = h.character.read().await;
            players.push(Fighter {
                actor_id: pid,
                alive: c.base.current_main_state != crate::actor::MAIN_STATE_DEAD,
                in_room: room.contains(c.base.position_x, c.base.position_y, c.base.position_z),
                raise_pending: c.chara.mods.get(crate::actor::Modifier::Raise) > 0.0,
            });
        }
        let key = (instance_id, room.bnpc_id);
        let (next, step) = {
            let mut map = fights().lock().unwrap_or_else(|e| e.into_inner());
            let before = map.get(&key).cloned();
            let (next, step) = advance(before.clone(), boss, &players, now_ms);
            if before != next {
                tracing::info!(
                    zone = zone_id,
                    instance = instance_id,
                    boss = room.name,
                    ?before,
                    ?next,
                    "boss fight phase",
                );
            }
            match &next {
                Some(p) => {
                    map.insert(key, p.clone());
                }
                None => {
                    map.remove(&key);
                }
            }
            (next, step)
        };
        record_sides(
            instance_id,
            room.bnpc_id,
            boss_id,
            next.as_ref(),
            &player_ids,
        );
        match step {
            Step::None => {}
            Step::CloseGates { fighters } => {
                tracing::info!(boss = room.name, ?fighters, "boss gates close");
                for g in room.gates {
                    set_gate(world, zone_id, instance_id, g, false).await;
                }
            }
            Step::OpenGates => {
                for g in room.gates {
                    set_gate(world, zone_id, instance_id, g, true).await;
                }
            }
            Step::PushOut { players } => {
                let (x, y, z, rot) = room.outside;
                for p in players {
                    crate::runtime::quest_apply::apply_warp_to_position_runtime(
                        p, x, y, z, rot, 0x11, registry, world,
                    )
                    .await;
                }
            }
            Step::Wipe { players } => {
                wipe_return(
                    registry,
                    world,
                    zone_id,
                    instance_id,
                    room,
                    boss_id,
                    &players,
                )
                .await;
            }
        }
    }
}

/// A lost boss fight: everyone back on their feet at the entrance, the
/// boss whole again at its spot, the gates open.
async fn wipe_return(
    registry: &crate::runtime::actor_registry::ActorRegistry,
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
    room: &BossRoom,
    boss_id: u32,
    players: &[u32],
) {
    let Some(zone) = world.zone(zone_id).await else {
        return;
    };
    tracing::info!(
        boss = room.name,
        ?players,
        "boss fight lost: back to the entrance"
    );
    let (x, y, z, rot) = entrance(zone_id).unwrap_or(room.outside);
    for &p in players {
        crate::runtime::dispatcher::apply_revive(p, registry, world, &zone).await;
        if let Some(h) = registry.get(p).await {
            let mut c = h.character.write().await;
            let (hp, mp) = (c.chara.max_hp as i32, c.chara.max_mp as i32);
            c.set_hp(hp);
            c.set_mp(mp);
        }
        crate::runtime::dispatcher::sync_pools_after_tick(registry, world, p).await;
        crate::runtime::quest_apply::apply_warp_to_position_runtime(
            p, x, y, z, rot, 0x11, registry, world,
        )
        .await;
    }
    if let Some(h) = registry.get(boss_id).await {
        let spawn = {
            let mut c = h.character.write().await;
            let mut outbox = crate::battle::outbox::BattleOutbox::new();
            c.ai_container.internal_disengage(&mut outbox);
            c.hate.clear_hate(None);
            let max_hp = c.chara.max_hp as i32;
            let max_mp = c.chara.max_mp as i32;
            c.set_hp(max_hp);
            c.set_mp(max_mp);
            c.chara.tp = 0;
            c.base.current_main_state = crate::actor::MAIN_STATE_PASSIVE;
            c.chara.new_main_state = crate::actor::MAIN_STATE_PASSIVE;
            let (sx, sy, sz) = (c.chara.spawn_x, c.chara.spawn_y, c.chara.spawn_z);
            c.base.position_x = sx;
            c.base.position_y = sy;
            c.base.position_z = sz;
            common::Vector3::new(sx, sy, sz)
        };
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        zone.write()
            .await
            .core
            .update_actor_position(boss_id, spawn, &mut ob);
        // Clients drop and re-stream it: whole, calm, at its spot.
        world.forget_actor_for_all_sessions(boss_id).await;
    }
    for g in room.gates {
        set_gate(world, zone_id, instance_id, g, true).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIGHTING: BossView = BossView {
        down: false,
        fighting: true,
    };

    fn p(id: u32, alive: bool, in_room: bool) -> Fighter {
        Fighter {
            actor_id: id,
            alive,
            in_room,
            raise_pending: false,
        }
    }

    #[test]
    fn gates_close_after_the_delay_on_whoever_is_inside() {
        let (ph, st) = advance(None, FIGHTING, &[p(1, true, true)], 1_000);
        assert_eq!(
            ph,
            Some(Phase::Joining {
                close_at_ms: 1_000 + BOSS_GATE_DELAY_MS
            })
        );
        assert_eq!(st, Step::None);
        let players = [p(1, true, true), p(2, true, true), p(3, true, false)];
        let (ph, st) = advance(ph, FIGHTING, &players, 1_000 + BOSS_GATE_DELAY_MS - 1);
        assert_eq!(st, Step::None);
        let (ph, st) = advance(ph, FIGHTING, &players, 1_000 + BOSS_GATE_DELAY_MS);
        assert_eq!(
            st,
            Step::CloseGates {
                fighters: vec![1, 2]
            }
        );
        // Player 3 slips in later: pushed back out.
        let late = [p(1, true, true), p(2, true, true), p(3, true, true)];
        let (_, st) = advance(ph, FIGHTING, &late, 20_000);
        assert_eq!(st, Step::PushOut { players: vec![3] });
    }

    #[test]
    fn killing_the_boss_opens_the_gates_for_good() {
        let sealed = Some(Phase::Sealed {
            fighters: vec![1],
            wiped_at_ms: None,
        });
        let down = BossView {
            down: true,
            fighting: false,
        };
        let (ph, st) = advance(sealed, down, &[p(1, true, true)], 5);
        assert_eq!((ph.clone(), st), (Some(Phase::Won), Step::OpenGates));
        assert_eq!(
            advance(ph, FIGHTING, &[], 6),
            (Some(Phase::Won), Step::None)
        );
    }

    #[test]
    fn a_wipe_returns_the_party_after_the_grace() {
        let sealed = Some(Phase::Sealed {
            fighters: vec![1, 2],
            wiped_at_ms: None,
        });
        let dead = [p(1, false, true), p(2, false, true), p(3, false, false)];
        let (ph, st) = advance(sealed, FIGHTING, &dead, 100);
        assert_eq!(st, Step::None);
        let (ph, st) = advance(ph, FIGHTING, &dead, 100 + LOSS_AFTER_ALL_DOWN_MS - 1);
        assert_eq!(st, Step::None);
        let (ph, st) = advance(ph, FIGHTING, &dead, 100 + LOSS_AFTER_ALL_DOWN_MS);
        assert_eq!(ph, None);
        // Only fight members go back; player 3 was never in the fight.
        assert_eq!(
            st,
            Step::Wipe {
                players: vec![1, 2]
            }
        );
    }

    #[test]
    fn a_raise_in_the_grace_restarts_the_count() {
        let sealed = Some(Phase::Sealed {
            fighters: vec![1, 2],
            wiped_at_ms: None,
        });
        let dead = [p(1, false, true), p(2, false, true)];
        let (ph, _) = advance(sealed, FIGHTING, &dead, 0);
        let (ph, _) = advance(ph, FIGHTING, &[p(1, true, true), p(2, false, true)], 10_000);
        let (ph, st) = advance(ph, FIGHTING, &dead, 20_000);
        assert_eq!(st, Step::None);
        let (_, st) = advance(ph, FIGHTING, &dead, 20_000 + LOSS_AFTER_ALL_DOWN_MS - 1);
        assert_eq!(st, Step::None);
    }

    #[test]
    fn a_pending_reraise_is_not_down() {
        let sealed = Some(Phase::Sealed {
            fighters: vec![1, 2],
            wiped_at_ms: Some(0),
        });
        let mut reraise = p(2, false, true);
        reraise.raise_pending = true;
        let (_, st) = advance(sealed, FIGHTING, &[p(1, false, true), reraise], 1_000_000);
        assert_eq!(st, Step::None);
    }

    #[test]
    fn outsiders_and_fighters_cannot_touch_each_other() {
        record_sides(
            7_001,
            3457,
            0x4AAA_0001,
            Some(&Phase::Sealed {
                fighters: vec![1, 2],
                wiped_at_ms: None,
            }),
            &[1, 2, 3],
        );
        assert!(may_interact(1, 2));
        assert!(may_interact(1, 0x4AAA_0001));
        assert!(!may_interact(3, 1), "outsider heals a fighter");
        assert!(!may_interact(1, 3), "fighter buffs an outsider");
        assert!(!may_interact(3, 0x4AAA_0001), "outsider hits the boss");
        assert!(!may_interact(0x4AAA_0001, 3), "boss hits an outsider");
        assert!(may_interact(3, 3));
        assert!(may_interact(1, 0x4BBB_0009), "fighter hits an add");
        release_instance(7_001);
        assert!(may_interact(3, 1));
    }

    #[test]
    fn one_fighter_standing_is_not_a_wipe() {
        let sealed = Some(Phase::Sealed {
            fighters: vec![1, 2],
            wiped_at_ms: None,
        });
        let (_, st) = advance(
            sealed,
            FIGHTING,
            &[p(1, false, true), p(2, true, true)],
            1_000_000,
        );
        assert_eq!(st, Step::None);
    }

    #[test]
    fn a_boss_that_lets_go_before_the_gates_close_resets_the_wait() {
        let joining = Some(Phase::Joining { close_at_ms: 50 });
        let calm = BossView {
            down: false,
            fighting: false,
        };
        assert_eq!(
            advance(joining, calm, &[p(1, true, false)], 10),
            (None, Step::None)
        );
    }

    #[test]
    fn toto_rak_rooms_hold_their_boss_and_not_the_outside_spot() {
        for r in BOSS_ROOMS {
            let (cx, cy, cz) = r.centre;
            assert!(r.contains(cx, cy, cz), "{}", r.name);
            let (ox, oy, oz, _) = r.outside;
            assert!(!r.contains(ox, oy, oz), "{} outside spot is inside", r.name);
        }
        // Boss spawns from server_battlenpc_spawn_locations.
        assert!(BOSS_ROOMS[0].contains(1251.0, -46.9, 928.1));
        assert!(BOSS_ROOMS[1].contains(1472.1, -58.9, 641.3));
        assert!(BOSS_ROOMS[2].contains(1344.5, -62.9, 544.6));
    }
}
