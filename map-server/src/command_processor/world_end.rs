// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `worldend`: the last days of 1.0 as a GM event. In the 1.23b finale
//! (November 2012) Square Enix filled the cities and the land outside their
//! gates with level 65-80 monsters: Nael van Darnus and his Imperials, Atomos,
//! the chimera Bixie, the golems Number 126 and 128, the Great Oak, the
//! Imperial juggernaut and the Bombard King, a bomb nobody could hurt except
//! by doing /firedance at it. The first `worldend` spawns that around the GM
//! and in each city; the next one takes every one of them away again.
//!
//! The monsters are built straight from their actor classes (no
//! `server_battlenpc_*` rows): the classes and their looks are already in the
//! game data, the combat numbers are set here.
//!
//! None of this is retail behavior, so it lives in the `finaldays` module:
//! with the module off (the default) the command doesn't exist.

use std::collections::{HashMap, HashSet};

use super::{Args, CommandProcessor};
use crate::database::BattleNpcSpawn;

/// The module these commands come with (modules/finaldays). Off by default:
/// until an operator enables it the commands don't exist.
pub(crate) const MODULE: &str = "finaldays";

/// The commands of the finaldays module.
pub(crate) const COMMANDS: &[&str] = &["worldend"];

/// How a spawned actor behaves.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Role {
    /// Hunts players.
    Hostile,
    /// The Bombard King: harmless, and only /firedance hurts it.
    FiredanceOnly,
    /// The goobbue wall: stands its ground, never attacks, never falls.
    Defender,
}

/// The red sky of 1.0's last days: Dalamud overhead, lightning now and
/// then (8030 is the same sky without the lightning).
const WEATHER_DALAMUD_THUNDER: u16 = 8032;
/// Weather transition when the sky changes in place.
const WEATHER_FADE: u16 = 5;

/// One kind of actor in the event.
struct Foe {
    /// gamedata_actor_class id (its displayNameId gives the name).
    class_id: u32,
    tag: &'static str,
    level: u32,
    hp: u32,
    count: u32,
    role: Role,
}

const fn foe(class_id: u32, tag: &'static str, level: u32, hp: u32, count: u32) -> Foe {
    Foe {
        class_id,
        tag,
        level,
        hp,
        count,
        role: Role::Hostile,
    }
}

/// What spawns around each spot, in ring order: each Nael van Darnus comes
/// with two centurions beside him.
const ROSTER: &[Foe] = &[
    foe(2210901, "worldend_nael", 80, 30000, 1), // Nael van Darnus
    foe(2207001, "worldend_centurion", 70, 12000, 2), // Imperial centurion
    foe(2111001, "worldend_atomos", 78, 28000, 1), // Atomos
    foe(2210901, "worldend_nael", 80, 30000, 1),
    foe(2207001, "worldend_centurion", 70, 12000, 2),
    foe(2208701, "worldend_bixie", 72, 16000, 1), // Bixie (chimera)
    foe(2108904, "worldend_golem", 74, 20000, 1), // Number 126 (golem)
    foe(2210901, "worldend_nael", 80, 30000, 1),
    foe(2207001, "worldend_centurion", 70, 12000, 2),
    foe(2108901, "worldend_golem", 74, 20000, 1), // Number 128 (golem)
    foe(2102806, "worldend_great_oak", 76, 26000, 1), // Great Oak (treant)
    foe(2202401, "worldend_juggernaut", 72, 20000, 1), // Imperial juggernaut
    foe(2208701, "worldend_bixie", 72, 16000, 1),
    Foe {
        class_id: 2201607, // Bombard King
        tag: "worldend_bombard_king",
        level: 80,
        hp: 30000,
        count: 1,
        role: Role::FiredanceOnly,
    },
];

/// The Great Goobbue Wall: on 1.0's last night players lined their goobbue
/// mounts up outside Ul'dah's gates against the onslaught. Those were
/// players' mounts; the wall here is goobbues on their own (an NPC can't be
/// shown riding one), standing in a row where the Gate of Nald opens onto
/// Central Thanalan.
const GOOBBUE: Foe = Foe {
    class_id: 2203302, // Goobbue
    tag: "worldend_goobbue",
    level: 50,
    hp: 5000,
    count: 12,
    role: Role::Defender,
};

/// (zone, x, y, z, rotation) of the middle of the wall: Central Thanalan's
/// arrival point from Ul'dah, facing out of the city.
const GOOBBUE_WALL: (u32, f32, f32, f32, f32) = (170, -27.015, 181.798, -79.72, 2.513);

/// Yalms between goobbues in the wall.
const WALL_SPACING: f32 = 3.0;

/// Where the cities get their share: (zone, x, y, z). The aetheryte plazas
/// (the `camp` spots) and a busy square in the other half of each city.
const CITY_SPOTS: &[(u32, f32, f32, f32)] = &[
    (230, -407.0, 42.5, 337.0),    // Limsa Lominsa, aetheryte plaza
    (133, -438.0, 40.0, 190.0),    // Limsa Lominsa, the Drowning Wench
    (206, -120.0, 16.0, -1332.0),  // Gridania, aetheryte plaza
    (155, 58.0, 4.0, -1213.0),     // Gridania, Carline Canopy
    (175, -235.0, 185.0, -3.9),    // Ul'dah, aetheryte plaza
    (209, -192.85, 194.6, 182.58), // Ul'dah, Sapphire Avenue
];

/// /firedances it takes to bring down a Bombard King.
const FIREDANCES_TO_FELL: u32 = 10;

/// The Fire Dance emote's animation id, as EmoteStandardCommand.lua passes
/// it to `doEmote` (emote 156 → animId 55).
pub(crate) const FIRE_DANCE_ANIM: u32 = 55;

/// Actor numbers for event monsters: clear of the zone-load monsters
/// (0x20000 up) and of the content-instance band (0x40000).
const FIRST_NUMBER: u32 = 0x3_0000;
const LAST_NUMBER: u32 = 0x3_FFFF;

fn actor_id(zone: u32, number: u32) -> u32 {
    (4u32 << 28) | (zone << 19) | number
}

/// What the event has out in the world. Kept apart from the spawning so the
/// on/off bookkeeping can be tested without a server.
#[derive(Debug, Default)]
pub(crate) struct WorldEnd {
    active: bool,
    spawned: Vec<u32>,
    /// Bombard King actor id → /firedances still needed.
    kings: HashMap<u32, u32>,
    /// Zone → the next actor number to try.
    next: HashMap<u32, u32>,
}

impl WorldEnd {
    /// Starts the event; false when it is already on.
    fn begin(&mut self) -> bool {
        !std::mem::replace(&mut self.active, true)
    }

    /// A free actor id in `zone` for the next monster. Numbers keep moving
    /// forward across events (wrapping inside the band), so a client never
    /// sees a new monster under an id it was just told to remove.
    fn next_actor_id(&mut self, zone: u32, in_use: &HashSet<u32>) -> Option<u32> {
        let next = self.next.entry(zone).or_insert(FIRST_NUMBER);
        for _ in FIRST_NUMBER..=LAST_NUMBER {
            let number = *next;
            *next = if number >= LAST_NUMBER {
                FIRST_NUMBER
            } else {
                number + 1
            };
            let id = actor_id(zone, number);
            if !in_use.contains(&id) && !self.spawned.contains(&id) {
                return Some(id);
            }
        }
        None
    }

    fn record(&mut self, actor_id: u32, firedance_only: bool) {
        self.spawned.push(actor_id);
        if firedance_only {
            self.kings.insert(actor_id, FIREDANCES_TO_FELL);
        }
    }

    /// Ends the event: every actor id it spawned, to be removed.
    fn end(&mut self) -> Vec<u32> {
        self.active = false;
        self.kings.clear();
        std::mem::take(&mut self.spawned)
    }

    /// A /firedance at `actor_id`: None when that isn't a Bombard King,
    /// otherwise the dances it still needs (0: it falls).
    fn firedance(&mut self, actor_id: u32) -> Option<u32> {
        let left = self.kings.get_mut(&actor_id)?;
        *left = left.saturating_sub(1);
        let left = *left;
        if left == 0 {
            self.kings.remove(&actor_id);
        }
        Some(left)
    }
}

fn state() -> &'static tokio::sync::Mutex<WorldEnd> {
    static STATE: std::sync::OnceLock<tokio::sync::Mutex<WorldEnd>> = std::sync::OnceLock::new();
    STATE.get_or_init(Default::default)
}

/// Spots around (x, z) for `n` monsters: two rings, the inner one first.
fn ring(x: f32, z: f32, n: usize) -> Vec<(f32, f32, f32)> {
    (0..n)
        .map(|i| {
            let angle = i as f32 * std::f32::consts::TAU / n as f32;
            let radius = if i % 2 == 0 { 12.0 } else { 18.0 };
            // face the middle
            let rotation = (-angle.cos()).atan2(-angle.sin());
            (x + radius * angle.cos(), z + radius * angle.sin(), rotation)
        })
        .collect()
}

/// Spots for `n` goobbues in a row through (x, z), side by side, all facing
/// `rotation` (forward is (sin r, cos r), as for the ring).
fn wall(x: f32, z: f32, rotation: f32, n: usize) -> Vec<(f32, f32, f32)> {
    let (side_x, side_z) = (rotation.cos(), -rotation.sin());
    let middle = (n as f32 - 1.0) / 2.0;
    (0..n)
        .map(|i| {
            let off = (i as f32 - middle) * WALL_SPACING;
            (x + side_x * off, z + side_z * off, rotation)
        })
        .collect()
}

/// A /firedance by `dancer` at `target`: when that's a Bombard King of the
/// event, it takes the hit, and the tenth one brings it down. Called from
/// both emote paths.
pub(crate) async fn on_emote(
    dancer: u32,
    target: u32,
    anim_id: u32,
    registry: &crate::runtime::actor_registry::ActorRegistry,
    world: &crate::world_manager::WorldManager,
) {
    if anim_id != FIRE_DANCE_ANIM || target == 0 {
        return;
    }
    let Some(left) = state().lock().await.firedance(target) else {
        return;
    };
    let Some(king) = registry.get(target).await else {
        return;
    };
    {
        let mut c = king.character.write().await;
        let max = i32::from(c.chara.max_hp.max(1));
        let hp = max * left as i32 / FIREDANCES_TO_FELL as i32;
        if left == 0 {
            c.chara.mods.set(crate::actor::Modifier::MinimumHpLock, 0.0);
            c.chara.hp = 0;
        } else {
            c.chara.hp = hp.max(1) as i16;
        }
    }
    tracing::info!(
        dancer,
        king = target,
        left,
        "worldend: firedance at the Bombard King"
    );
    if left == 0
        && let Some(zone) = world.zone(king.zone_id).await
    {
        crate::runtime::dispatcher::apply_die(target, registry, world, &zone, None, None).await;
    }
}

impl CommandProcessor {
    /// `worldend`: start the end of the world, or, while it runs, end it.
    pub(super) async fn handle_worldend(&self, args: &Args<'_>) -> String {
        let mut st = state().lock().await;
        if !st.begin() {
            let ids = st.end();
            let n = ids.len();
            for id in ids {
                // gone already when it died and its corpse faded
                crate::runtime::quest_apply::apply_despawn_actor(
                    0,
                    id,
                    &self.registry,
                    &self.world,
                )
                .await;
            }
            drop(st);
            let weather = self.world.set_weather_override(None);
            self.set_weather_all(weather).await;
            self.announce_all("The skies clear. Dalamud's onslaught is over... for now.")
                .await;
            return format!("worldend off: {n} actor(s) removed");
        }

        // around the GM, then each city (except the zone the GM is in)
        let mut spots: Vec<(u32, f32, f32, f32)> = Vec::new();
        if args.invoker.is_some() {
            let me = match self.invoker_id(args).await {
                Ok(id) => id,
                Err(e) => {
                    st.end();
                    return e;
                }
            };
            if let Some((zone, x, y, z, _)) = self.spot_of(me).await {
                spots.push((zone, x, y, z));
            }
        }
        for &(zone, x, y, z) in CITY_SPOTS {
            if !spots.iter().any(|s| s.0 == zone) {
                spots.push((zone, x, y, z));
            }
        }

        let per_spot: usize = ROSTER.iter().map(|f| f.count as usize).sum();
        let mut zones = 0;
        for (zone, x, y, z) in spots {
            if self.world.zone(zone).await.is_none() {
                continue;
            }
            let in_use: HashSet<u32> = self
                .registry
                .actors_in_zone(zone)
                .await
                .iter()
                .map(|h| h.actor_id)
                .collect();
            let places = ring(x, z, per_spot);
            let foes = ROSTER
                .iter()
                .flat_map(|f| std::iter::repeat_n(f, f.count as usize));
            let mut any = false;
            for (foe, &(px, pz, rot)) in foes.zip(places.iter()) {
                let Some(id) = st.next_actor_id(zone, &in_use) else {
                    break;
                };
                if self.spawn_foe(foe, zone, id, (px, y, pz, rot)).await {
                    st.record(id, foe.role == Role::FiredanceOnly);
                    any = true;
                }
            }
            if any {
                zones += 1;
            }
        }
        let n = st.spawned.len();
        if n == 0 {
            st.end();
            return "worldend: nothing could be spawned (no zones loaded?)".into();
        }

        // and the goobbues lined up at Ul'dah's gate
        let (wz, wx, wy, wzz, wrot) = GOOBBUE_WALL;
        let mut goobbues = 0;
        if self.world.zone(wz).await.is_some() {
            let in_use: HashSet<u32> = self
                .registry
                .actors_in_zone(wz)
                .await
                .iter()
                .map(|h| h.actor_id)
                .collect();
            for (px, pz, rot) in wall(wx, wzz, wrot, GOOBBUE.count as usize) {
                let Some(id) = st.next_actor_id(wz, &in_use) else {
                    break;
                };
                if self.spawn_foe(&GOOBBUE, wz, id, (px, wy, pz, rot)).await {
                    st.record(id, false);
                    goobbues += 1;
                }
            }
        }
        drop(st);
        let weather = self
            .world
            .set_weather_override(Some(WEATHER_DALAMUD_THUNDER));
        self.set_weather_all(weather).await;
        self.announce_all(
            "Dalamud's red light fills the sky. Nael van Darnus and the beasts of the \
             Seventh Umbral Era descend upon Eorzea!",
        )
        .await;
        format!(
            "worldend on: {n} monster(s) in {zones} zone(s) and {goobbues} goobbue(s) \
             at Ul'dah's gate; the Bombard King only falls to /firedance. \
             !worldend again ends it"
        )
    }

    /// Change the sky for everyone in the world, as it changes in place.
    async fn set_weather_all(&self, weather: u16) {
        for s in self.world.all_sessions().await {
            if let (Some(h), Some(client)) = (
                self.registry.by_session(s.id).await,
                self.world.client(s.id).await,
            ) {
                let mut pkt = crate::packets::send::misc::build_set_weather(
                    h.actor_id,
                    weather,
                    WEATHER_FADE,
                );
                pkt.set_target_id(s.id);
                client.send_bytes(pkt.to_bytes()).await;
            }
        }
    }

    async fn announce_all(&self, text: &str) {
        for s in self.world.all_sessions().await {
            if let Some(h) = self.registry.by_session(s.id).await {
                self.tell_player(h.actor_id, text.to_string()).await;
            }
        }
    }

    /// Builds one monster at `id` from its actor class and puts it in the
    /// zone, where the in-range streaming shows it to the players around. Mirrors the processor's
    /// `apply_spawn_battle_npc_by_id`, with the numbers from the roster in
    /// place of the server_battlenpc_* rows.
    async fn spawn_foe(&self, foe: &Foe, zone: u32, id: u32, at: (f32, f32, f32, f32)) -> bool {
        let (x, y, z, rotation) = at;
        let class = match self.db.load_actor_class(foe.class_id).await {
            Ok(Some(c)) => c,
            _ => {
                tracing::warn!(class = foe.class_id, "worldend: actor class missing");
                return false;
            }
        };
        // An empty classPath instantiates with no class name, which the
        // 1.23b client dies on (same guard as the zone spawner).
        if class.class_path.is_empty() {
            tracing::warn!(
                class = foe.class_id,
                "worldend: spawn skipped — empty classPath (client-fatal instantiate)",
            );
            return false;
        }
        let spawn = BattleNpcSpawn {
            position_x: x,
            position_y: y,
            position_z: z,
            rotation,
            script_name: foe.tag.to_string(),
            min_level: foe.level,
            max_level: foe.level,
            hp: foe.hp,
            zone_id: zone,
            actor_class_id: foe.class_id,
            combat_delay: 3000,
            // the Bombard King and the goobbues do no harm
            aggro_type: u8::from(foe.role == Role::Hostile),
            detection: 0x01 | 0x04 | 0x10, // sight, sound, any level
            ..Default::default()
        };
        let mut bnpc = crate::npc::battle_npc::BattleNpc::new(
            id & 0x7FFFF,
            &class,
            foe.tag,
            zone,
            x,
            y,
            z,
            rotation,
            0,
            0,
            None,
        );
        if bnpc.actor_id() != id {
            tracing::warn!(id, "worldend: actor id mismatch");
            return false;
        }
        {
            let chara = &mut bnpc.npc.character.chara;
            let hp = foe.hp.min(i16::MAX as u32) as i16;
            chara.hp = hp;
            chara.max_hp = hp;
            chara.level = foe.level as i16;
            if let Ok(Some(app)) = self.db.load_npc_appearance(foe.class_id).await {
                let (model_id, slots) = app.pack();
                chara.model_id = model_id;
                chara.appearance_ids = slots;
            }
        }
        bnpc.apply_spawn_metadata(&spawn, 0, id, None);
        let mut character = bnpc.npc.character.clone();
        character.chara.respawn_disabled = true;
        if foe.role != Role::Hostile {
            // weapons and spells leave it at 1 HP (the Bombard King falls to
            // /firedance; the goobbue wall doesn't fall)
            character
                .chara
                .mods
                .set(crate::actor::Modifier::MinimumHpLock, 1.0);
        }

        let Some(zone_arc) = self.world.zone(zone).await else {
            return false;
        };
        {
            let mut zw = zone_arc.write().await;
            let mut ob = crate::zone::outbox::AreaOutbox::new();
            let pos = common::Vector3::new(x, y, z);
            zw.core.add_actor(
                crate::zone::area::StoredActor {
                    actor_id: id,
                    kind: crate::zone::area::ActorKind::BattleNpc,
                    position: pos,
                    grid: (0, 0),
                    is_alive: true,
                },
                &mut ob,
            );
            zw.core.update_actor_position(id, pos, &mut ob);
        }
        self.registry
            .insert(crate::runtime::actor_registry::ActorHandle::new(
                id,
                crate::runtime::actor_registry::ActorKindTag::BattleNpc,
                zone,
                0,
                character,
            ))
            .await;
        // Players nearby get it from the regular in-range streaming; sending
        // the spawn bundle here as well adds the actor twice, which crashes
        // the client.
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn toggles_on_then_off_and_hands_back_everything() {
        let mut we = WorldEnd::default();
        assert!(we.begin(), "first call starts it");
        let none = HashSet::new();
        let a = we.next_actor_id(230, &none).unwrap();
        let b = we.next_actor_id(230, &none).unwrap();
        let c = we.next_actor_id(175, &none).unwrap();
        we.record(a, false);
        we.record(b, true);
        we.record(c, false);
        assert!(!we.begin(), "second call ends it");
        let mut gone = we.end();
        gone.sort();
        let mut want = vec![a, b, c];
        want.sort();
        assert_eq!(gone, want);
        assert!(we.end().is_empty(), "nothing left over");
        assert!(we.kings.is_empty());
        assert!(we.begin(), "and it can start again");
    }

    #[test]
    fn repeated_toggles_never_reuse_a_live_id() {
        let mut we = WorldEnd::default();
        let mut taken = HashSet::new();
        for _ in 0..5 {
            assert!(we.begin());
            for _ in 0..17 {
                let id = we.next_actor_id(133, &taken).unwrap();
                assert_eq!(id >> 28, 4);
                assert_eq!((id >> 19) & 0x1FF, 133);
                let number = id & 0x7FFFF;
                assert!((FIRST_NUMBER..=LAST_NUMBER).contains(&number));
                assert!(taken.insert(id), "id handed out twice: {id:#X}");
                we.record(id, false);
            }
            assert_eq!(we.end().len(), 17);
        }
    }

    #[test]
    fn ids_in_use_are_skipped_and_the_band_wraps() {
        let mut we = WorldEnd::default();
        we.next.insert(1, LAST_NUMBER);
        let busy: HashSet<u32> = [actor_id(1, FIRST_NUMBER)].into();
        assert_eq!(we.next_actor_id(1, &busy), Some(actor_id(1, LAST_NUMBER)));
        assert_eq!(
            we.next_actor_id(1, &busy),
            Some(actor_id(1, FIRST_NUMBER + 1))
        );
    }

    #[test]
    fn only_firedance_brings_down_the_bombard_king() {
        let mut we = WorldEnd::default();
        we.begin();
        we.record(7, true);
        we.record(8, false);
        assert_eq!(we.firedance(8), None, "not a Bombard King");
        for left in (0..FIREDANCES_TO_FELL).rev() {
            assert_eq!(we.firedance(7), Some(left));
        }
        assert_eq!(we.firedance(7), None, "already down");
    }

    /// The whole command against a loaded city zone: every toggle on puts
    /// the roster there, every toggle off takes all of it away again.
    #[tokio::test]
    async fn worldend_command_spawns_and_removes_without_leaking() {
        use std::sync::Arc;
        let world = Arc::new(crate::world_manager::WorldManager::new());
        let registry = Arc::new(crate::runtime::actor_registry::ActorRegistry::new());
        let db = Arc::new(
            crate::database::Database::open(common::test_db::fresh().await.unwrap())
                .await
                .unwrap(),
        );
        // Seed class paths the way seed/106 does, all but Atomos's, which
        // has none: a class without one must be skipped, not sent.
        {
            use common::db::ConnCallExt;
            db.conn_for_test()
                .call_db(|c| {
                    c.execute(
                        "UPDATE gamedata_actor_class SET classPath = '/Chara/Npc/Monster/Test'
                         WHERE id IN (2210901, 2207001, 2208701, 2108904, 2108901,
                                      2102806, 2202401, 2201607, 2203302)",
                        [],
                    )
                })
                .await
                .unwrap();
        }
        let lua = Arc::new(crate::lua::LuaEngine::new("/nonexistent"));
        world
            .register_zone(crate::zone::zone::Zone::new(
                230,
                "sea0Town01a",
                101,
                "/Area/Zone/ZoneMasterSeaS0",
                0,
                0,
                0,
                false,
                false,
                false,
                false,
                false,
                None,
            ))
            .await;
        world
            .register_zone(crate::zone::zone::Zone::new(
                170,
                "wil0Field01",
                104,
                "/Area/Zone/ZoneMasterWilW0",
                0,
                0,
                0,
                false,
                false,
                false,
                false,
                false,
                None,
            ))
            .await;
        let mut cmd = CommandProcessor::new(world.clone(), registry.clone(), db, lua);
        // module off (the default): no such command, nothing spawned
        let off = cmd.run("worldend").await.unwrap();
        assert!(off.starts_with("unknown command: worldend"), "{off}");
        let chat = cmd.run_as_player("worldend", "Some One", 4).await.unwrap();
        assert_eq!(chat, "unknown command: !worldend (!help lists yours)");
        assert!(!cmd.run("help").await.unwrap().contains("worldend"));
        assert!(registry.actors_in_zone(230).await.is_empty());

        cmd.final_days = true;
        assert!(cmd.run("help").await.unwrap().contains("worldend"));
        let atomos = ROSTER.iter().find(|f| f.class_id == 2111001).unwrap();
        let per_spot =
            ROSTER.iter().map(|f| f.count as usize).sum::<usize>() - atomos.count as usize;
        for _ in 0..3 {
            let on = cmd.run("worldend").await.unwrap();
            assert!(on.starts_with("worldend on"), "{on}");
            assert_eq!(world.weather_id(), WEATHER_DALAMUD_THUNDER);
            let here = registry.actors_in_zone(230).await;
            assert_eq!(here.len(), per_spot, "{on}");
            let wall = registry.actors_in_zone(170).await;
            assert_eq!(wall.len(), GOOBBUE.count as usize, "{on}");
            let off = cmd.run("worldend").await.unwrap();
            let all = per_spot + GOOBBUE.count as usize;
            assert_eq!(off, format!("worldend off: {all} actor(s) removed"));
            assert!(registry.actors_in_zone(230).await.is_empty());
            assert!(registry.actors_in_zone(170).await.is_empty());
            assert_eq!(world.weather_id(), 1, "the configured sky comes back");
        }
    }

    #[test]
    fn the_goobbue_wall_is_a_straight_row_across_the_facing() {
        let rot = 0.7_f32;
        let row = wall(10.0, 20.0, rot, 4);
        assert_eq!(row.len(), 4);
        let (fx, fz) = (rot.sin(), rot.cos());
        for w in row.windows(2) {
            let (dx, dz) = (w[1].0 - w[0].0, w[1].1 - w[0].1);
            assert!(((dx * dx + dz * dz).sqrt() - WALL_SPACING).abs() < 1e-4);
            assert!((dx * fx + dz * fz).abs() < 1e-4, "sideways, not forward");
        }
        let (mx, mz) = row.iter().fold((0.0, 0.0), |a, p| (a.0 + p.0, a.1 + p.1));
        assert!((mx / 4.0 - 10.0).abs() < 1e-4 && (mz / 4.0 - 20.0).abs() < 1e-4);
        assert!(row.iter().all(|p| p.2 == rot));
    }

    #[test]
    fn the_roster_has_one_bombard_king_and_three_naels() {
        let count = |id| -> u32 {
            ROSTER
                .iter()
                .filter(|f| f.class_id == id)
                .map(|f| f.count)
                .sum()
        };
        assert_eq!(count(2201607), 1);
        assert_eq!(count(2210901), 3);
        assert_eq!(count(2207001), 6);
        assert_eq!(ring(0.0, 0.0, 17).len(), 17);
    }
}
