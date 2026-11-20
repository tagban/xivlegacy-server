// garlemald-server — Rust port of a FINAL FANTASY XIV v1.23b server emulator (lobby/world/map)
// Copyright (C) 2026  Samuel Stegall
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! NPC helper (ally) fights run through the real ticker (#334). Each fight
//! spawns its allies and foes from the seed rows the content scripts use
//! (`server_battlenpc_spawn_locations`), equipped the way the spawn path
//! equips them, engages them the way the scripts do (the foes on the
//! player, the allies on the first foe), and runs a minute of 100 ms ticks
//! with a player who keeps hitting their target. It then reports who the
//! foes went after, what the allies used and how the player came out:
//!
//! ```sh
//! cargo test -p map-server ally_behavior -- --nocapture
//! ```

#![cfg(test)]

use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;

use common::Vector3;

use super::actor_registry::{ActorHandle, ActorKindTag, ActorRegistry};
use super::battle_audit_tests::{script_root, tempdb};
use super::ticker::{GameTicker, TickerConfig};
use crate::actor::Character;
use crate::database::Database;
use crate::world_manager::WorldManager;
use crate::zone::area::{ActorKind, StoredActor};
use crate::zone::navmesh::StubNavmeshLoader;
use crate::zone::outbox::AreaOutbox;
use crate::zone::zone::Zone;

const ZONE: u32 = 100;
const PLAYER: u32 = 1;
const SESSION: u32 = 42;
/// Protect's status (`server_battle_commands` 27351 → status 223129).
const PROTECT_STATUS: u32 = 223129;

/// One fight: the seed spawns on each side and the player's level.
struct Fight {
    name: &'static str,
    allies: &'static [u32],
    foes: &'static [u32],
    player_level: i16,
}

const FIGHTS: &[Fight] = &[
    Fight {
        name: "Gridania opening (Yda, Papalymo vs 3 wolves)",
        allies: &[6, 7],
        foes: &[3, 4, 5],
        player_level: 1,
    },
    Fight {
        name: "Limsa opening (Sthalmann, Y'shtola vs 3 aurelia)",
        allies: &[11, 12],
        foes: &[8, 9, 10],
        player_level: 1,
    },
    Fight {
        name: "Ul'dah opening (Thancred, Niellefresne vs goobbue)",
        allies: &[14, 15],
        foes: &[13],
        player_level: 1,
    },
    Fight {
        name: "MSQ man2g0 (Grinnaux, Handeloup, T'kebbe vs Spirit of the Wood)",
        allies: &[3463, 3464, 3465],
        foes: &[3462],
        player_level: 16,
    },
    Fight {
        name: "MSQ man2u0 (Niellefresne, Greinfarr vs 6 minemites)",
        allies: &[3472, 3473],
        foes: &[3466, 3467, 3468, 3469, 3470, 3471],
        player_level: 16,
    },
    Fight {
        name: "Escort man0l1 (Sisipu vs ankle biters)",
        allies: &[16],
        foes: &[17, 18, 19],
        player_level: 5,
    },
    Fight {
        name: "Escort man206 Together We Stand (Path companion vs troopers)",
        allies: &[52],
        foes: &[53, 54, 55, 56],
        player_level: 22,
    },
];

/// What a fight came to.
#[derive(Debug, Default)]
struct Report {
    /// Samples (one per second per live foe) with the foe on the player.
    foe_on_player: u32,
    /// Samples with the foe on an ally.
    foe_on_ally: u32,
    player_hp_lost: i32,
    player_min_hpp: i32,
    /// Command name → uses, per ally (by its script name).
    used: BTreeMap<String, BTreeMap<String, u32>>,
    /// Statuses on the player at the end.
    player_statuses: BTreeSet<u32>,
}

impl Report {
    fn on_player_pct(&self) -> u32 {
        (self.foe_on_player * 100)
            .checked_div(self.foe_on_player + self.foe_on_ally)
            .unwrap_or(0)
    }
    fn uses(&self, ally: &str, command: &str) -> u32 {
        self.used
            .get(ally)
            .and_then(|m| m.get(command))
            .copied()
            .unwrap_or(0)
    }
    fn any_uses(&self, command: &str) -> u32 {
        self.used.values().filter_map(|m| m.get(command)).sum()
    }
}

async fn lua_and_db() -> (Arc<Database>, Arc<crate::lua::LuaEngine>) {
    let db = Arc::new(Database::open(tempdb()).await.expect("seeded db"));
    let lua = Arc::new(crate::lua::LuaEngine::new(script_root()));
    let (catalog, by_level) = db.load_global_battle_command_list().await.unwrap();
    lua.catalogs()
        .install_battle_commands_with_level_index(catalog, by_level);
    lua.catalogs()
        .install_status_effects(db.load_global_status_effect_list().await.unwrap());
    lua.catalogs()
        .install_battle_traits(db.load_global_battle_trait_list().await.unwrap().0);
    lua.catalogs()
        .install_monster_skill_lists(db.load_monster_skill_lists().await.unwrap());
    (db, lua)
}

/// A seed spawn built and equipped the way `bnpc_spawn` does it. Returns
/// its actor id, character, script name and spawn position.
async fn build_npc(
    db: &Database,
    lua: &crate::lua::LuaEngine,
    bnpc_id: u32,
    level: Option<u32>,
) -> (u32, Character, String, Vector3) {
    let mut spawn = db
        .load_battle_npc_spawn(bnpc_id)
        .await
        .unwrap()
        .unwrap_or_else(|| panic!("bnpc {bnpc_id} seeded"));
    if let Some(level) = level {
        spawn.min_level = level;
        spawn.max_level = level;
    }
    let class = db
        .load_actor_class(spawn.actor_class_id)
        .await
        .unwrap()
        .expect("actor class");
    let mut bnpc = crate::npc::battle_npc::BattleNpc::new(
        bnpc_id,
        &class,
        spawn.script_name.clone(),
        ZONE,
        spawn.position_x,
        spawn.position_y,
        spawn.position_z,
        spawn.rotation,
        spawn.actor_state,
        spawn.animation_id,
        None,
    );
    let hp = if spawn.hp > 0 {
        spawn.hp
    } else {
        spawn.min_level.max(1) * 100
    };
    let c = &mut bnpc.npc.character.chara;
    c.hp = hp as i16;
    c.max_hp = hp as i16;
    if spawn.mp > 0 {
        c.mp = spawn.mp as i16;
        c.max_mp = spawn.mp as i16;
    }
    c.level = spawn.min_level.max(1) as i16;
    let actor_id = bnpc.actor_id();
    super::bnpc_spawn::equip_battle_npc(
        &mut bnpc,
        &spawn,
        bnpc_id,
        actor_id,
        &class.class_path,
        Some(lua.catalogs()),
    );
    let pos = Vector3::new(spawn.position_x, spawn.position_y, spawn.position_z);
    (actor_id, bnpc.npc.character, spawn.script_name, pos)
}

/// Player hit points by level (a little over a fresh character's).
fn player_hp(level: i16) -> i16 {
    200 + level * 40
}

/// The enmity a player's swings and weaponskills build each second
/// (about a same-level player's damage per second).
fn player_enmity_per_second(level: i16) -> i32 {
    3 + 2 * i32::from(level)
}

struct Scene {
    ticker: GameTicker,
    /// The player's client: the command results it sees tell what the
    /// allies used.
    rx: tokio::sync::Mutex<tokio::sync::mpsc::Receiver<Vec<u8>>>,
    allies: Vec<(u32, String)>,
    foes: Vec<u32>,
    player_level: i16,
}

async fn scene(fight: &Fight) -> Scene {
    scene_at(fight, None).await
}

/// [`scene`] with every ally at `ally_level` instead of its seed level.
async fn scene_at(fight: &Fight, ally_level: Option<u32>) -> Scene {
    let (db, lua) = lua_and_db().await;
    let world = Arc::new(WorldManager::new());
    let registry = Arc::new(ActorRegistry::new());

    let mut allies = Vec::new();
    let mut foes = Vec::new();
    for id in fight.allies {
        allies.push(build_npc(&db, &lua, *id, ally_level).await);
    }
    for id in fight.foes {
        foes.push(build_npc(&db, &lua, *id, None).await);
    }
    // The player stands just in front of the first ally, as the scripts
    // warp them in beside their helpers.
    let a0 = allies[0].3;
    let player_pos = Vector3::new(a0.x + 1.5, a0.y, a0.z);

    let mut zone = Zone::new(
        ZONE,
        "test",
        1,
        "/Area/Zone/Test",
        0,
        0,
        0,
        false,
        false,
        false,
        false,
        false,
        Some(&StubNavmeshLoader),
    );
    let mut ob = AreaOutbox::new();
    zone.core.add_actor(
        StoredActor {
            actor_id: PLAYER,
            kind: ActorKind::Player,
            position: player_pos,
            grid: (0, 0),
            is_alive: true,
        },
        &mut ob,
    );
    for (id, _, _, pos) in &allies {
        zone.core.add_actor(
            StoredActor {
                actor_id: *id,
                kind: ActorKind::Ally,
                position: *pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
    }
    for (id, _, _, pos) in &foes {
        zone.core.add_actor(
            StoredActor {
                actor_id: *id,
                kind: ActorKind::BattleNpc,
                position: *pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
    }
    for id in std::iter::once(PLAYER)
        .chain(allies.iter().map(|a| a.0))
        .chain(foes.iter().map(|f| f.0))
    {
        let pos = if id == PLAYER {
            player_pos
        } else {
            allies
                .iter()
                .chain(foes.iter())
                .find(|a| a.0 == id)
                .unwrap()
                .3
        };
        zone.core.update_actor_position(id, pos, &mut ob);
    }
    world.register_zone(zone).await;
    let (tx, rx) = tokio::sync::mpsc::channel::<Vec<u8>>(1 << 16);
    world
        .register_client(SESSION, crate::data::ClientHandle::new(SESSION, tx))
        .await;
    world
        .upsert_session(crate::data::Session {
            id: SESSION,
            current_zone_id: ZONE,
            ..crate::data::Session::default()
        })
        .await;

    let first_foe = foes[0].0;
    let mut player = Character::new(PLAYER);
    player.chara.level = fight.player_level;
    player.chara.hp = player_hp(fight.player_level);
    player.chara.max_hp = player_hp(fight.player_level);
    player.base.zone_id = ZONE;
    player.base.position_x = player_pos.x;
    player.base.position_y = player_pos.y;
    player.base.position_z = player_pos.z;
    player.chara.current_target = first_foe;
    player.ai_container.internal_engage(first_foe, 0, 2500);
    registry
        .insert(ActorHandle::new(
            PLAYER,
            ActorKindTag::Player,
            ZONE,
            SESSION,
            player,
        ))
        .await;

    let ally_ids: Vec<(u32, String)> = allies.iter().map(|a| (a.0, a.2.clone())).collect();
    for (id, mut c, _, _) in allies {
        c.base.zone_id = ZONE;
        // allyGlobal.EngageTarget: Engage + AddBaseHate on the first foe.
        c.hate.update_hate(first_foe, 1);
        c.ai_container.internal_engage(first_foe, 0, 2500);
        registry
            .insert(ActorHandle::new(id, ActorKindTag::Ally, ZONE, 0, c))
            .await;
    }
    let foe_ids: Vec<u32> = foes.iter().map(|f| f.0).collect();
    for (id, mut c, _, _) in foes {
        c.base.zone_id = ZONE;
        // The scripts engage every foe on the player.
        c.hate.update_hate(PLAYER, 1);
        c.ai_container.internal_engage(PLAYER, 0, 2500);
        registry
            .insert(ActorHandle::new(id, ActorKindTag::BattleNpc, ZONE, 0, c))
            .await;
    }

    let ticker = GameTicker::with_lua(TickerConfig::default(), world, registry, db, Some(lua));
    Scene {
        ticker,
        rx: tokio::sync::Mutex::new(rx),
        allies: ally_ids,
        foes: foe_ids,
        player_level: fight.player_level,
    }
}

/// `(actor, command)` of each command result (0x0139-0x013C, command id
/// at +0x24) the client got, skipping begin-cast rows (animation
/// 0x6F000002).
fn command_results(rx: &mut tokio::sync::mpsc::Receiver<Vec<u8>>) -> Vec<(u32, u16)> {
    use crate::packets::opcodes::{
        OP_COMMAND_RESULT_X00, OP_COMMAND_RESULT_X01, OP_COMMAND_RESULT_X10, OP_COMMAND_RESULT_X18,
    };
    let mut out = Vec::new();
    while let Ok(bytes) = rx.try_recv() {
        let mut offset = 0;
        while offset < bytes.len() {
            let Ok(sub) = common::subpacket::SubPacket::parse(&bytes, &mut offset) else {
                break;
            };
            if !matches!(
                sub.game_message.opcode,
                OP_COMMAND_RESULT_X00
                    | OP_COMMAND_RESULT_X01
                    | OP_COMMAND_RESULT_X10
                    | OP_COMMAND_RESULT_X18
            ) || sub.data.len() < 0x26
            {
                continue;
            }
            let anim = u32::from_le_bytes(sub.data[0x04..0x08].try_into().unwrap());
            let cmd = u16::from_le_bytes(sub.data[0x24..0x26].try_into().unwrap());
            if anim != 0x6F00_0002 && cmd != 0 {
                out.push((sub.header.source_id, cmd));
            }
        }
    }
    out
}

fn command_name(lua_names: &BTreeMap<u16, String>, id: u16) -> String {
    lua_names
        .get(&id)
        .cloned()
        .unwrap_or_else(|| id.to_string())
}

/// Run `seconds` of fight. Each second the player's damage adds its
/// enmity to the foe they are on (the first live one).
async fn run(sc: &Scene, seconds: u64) -> Report {
    let names: BTreeMap<u16, String> = sc
        .ticker
        .catalogs
        .battle_commands
        .read()
        .unwrap()
        .iter()
        .map(|(id, c)| (*id, c.name.clone()))
        .collect();
    let mut report = Report {
        player_min_hpp: 100,
        ..Report::default()
    };
    let mut last_hp = {
        let h = sc.ticker.registry.get(PLAYER).await.unwrap();
        h.character.read().await.chara.hp
    };
    let mut player_target = sc.foes[0];
    for i in 1..=seconds * 10 {
        let now = i * 100;
        sc.ticker.tick_once(now).await;
        // What each ally used: the command results the player sees
        // (begin-cast rows aside), once per command per tick.
        {
            let mut rx = sc.rx.lock().await;
            let mut this_tick = BTreeSet::new();
            for (source, cmd) in command_results(&mut rx) {
                // Commands outside the catalog are the swings.
                if let Some((_, script)) = sc.allies.iter().find(|(id, _)| *id == source)
                    && names.contains_key(&cmd)
                    && this_tick.insert((source, cmd))
                {
                    *report
                        .used
                        .entry(script.clone())
                        .or_default()
                        .entry(command_name(&names, cmd))
                        .or_default() += 1;
                }
            }
        }
        let (hp, max_hp) = {
            let h = sc.ticker.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            (c.chara.hp, c.chara.max_hp)
        };
        if hp < last_hp {
            report.player_hp_lost += i32::from(last_hp - hp);
        }
        last_hp = hp;
        report.player_min_hpp = report
            .player_min_hpp
            .min(i32::from(hp) * 100 / i32::from(max_hp.max(1)));
        if i % 10 != 0 {
            continue;
        }
        // Once a second: the player's damage on their foe, and who
        // each live foe is after.
        let mut live = Vec::new();
        for f in &sc.foes {
            let h = sc.ticker.registry.get(*f).await.unwrap();
            let c = h.character.read().await;
            if c.is_alive() {
                live.push(*f);
                match c.hate.most_hated() {
                    Some(PLAYER) => report.foe_on_player += 1,
                    Some(_) => report.foe_on_ally += 1,
                    None => {}
                }
            }
        }
        if !live.contains(&player_target)
            && let Some(f) = live.first()
        {
            player_target = *f;
        }
        if live.contains(&player_target) {
            let h = sc.ticker.registry.get(player_target).await.unwrap();
            let mut c = h.character.write().await;
            c.hate
                .update_hate(PLAYER, player_enmity_per_second(sc.player_level));
        }
    }
    let h = sc.ticker.registry.get(PLAYER).await.unwrap();
    let c = h.character.read().await;
    report.player_statuses = c.status_effects.iter().map(|s| s.id).collect();
    report
}

/// Every fight, reported, and what each role must do in it. Run with
/// `--nocapture` to see the table.
#[tokio::test]
async fn ally_behavior_fights_report() {
    let mut problems: Vec<String> = Vec::new();
    for fight in FIGHTS {
        let sc = scene(fight).await;
        let r = run(&sc, 60).await;
        println!(
            "{}\n  foes on player {}% ({} on player / {} on allies), player HP lost {}, \
             lowest {}%, statuses {:?}\n  used {:?}",
            fight.name,
            r.on_player_pct(),
            r.foe_on_player,
            r.foe_on_ally,
            r.player_hp_lost,
            r.player_min_hpp,
            r.player_statuses,
            r.used,
        );
        let enmity = r.any_uses("provoke") + r.any_uses("flash") + r.any_uses("taunt");
        let escort = fight.name.starts_with("Escort");
        if escort {
            // An escort's charge never pulls foes onto itself.
            if enmity > 0 {
                problems.push(format!("{}: the escortee used enmity moves", fight.name));
            }
        } else {
            // Every other fight has a tank: it pulls, and the foes spend
            // most of the fight off the player.
            if enmity == 0 {
                problems.push(format!("{}: no enmity move used", fight.name));
            }
            // One tank can't hold a big pack from the first second.
            let limit = if fight.foes.len() > 3 { 60 } else { 40 };
            if r.on_player_pct() > limit {
                problems.push(format!(
                    "{}: foes on the player {}% of the time",
                    fight.name,
                    r.on_player_pct()
                ));
            }
        }
        // Every helper uses its job's moves or spells, not just swings
        // (an escort's charge fights only when the escort loop has it).
        for (_, script) in sc.allies.iter().filter(|_| !escort) {
            if r.used.get(script).is_none_or(|m| m.is_empty()) {
                problems.push(format!("{}: {script} used nothing", fight.name));
            }
        }
        // Level 16 healers put Protect up.
        if fight.player_level >= 16 && !escort {
            if r.any_uses("protect") == 0 {
                problems.push(format!("{}: no Protect", fight.name));
            }
            if !r.player_statuses.contains(&PROTECT_STATUS) {
                problems.push(format!("{}: the player has no Protect", fight.name));
            }
        }
    }
    assert!(problems.is_empty(), "{problems:#?}");
}

/// A level-22 healer raises a fallen player (Raise is level 18), and a
/// level-30 one cures with Cura.
#[tokio::test]
async fn healer_ally_raises_a_fallen_player_and_cures_by_level() {
    let fight = &FIGHTS[3];
    let sc = scene_at(fight, Some(22)).await;
    {
        let h = sc.ticker.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.hp = 0;
        c.base.current_main_state = crate::actor::MAIN_STATE_DEAD;
    }
    // Raise is a 10 s cast.
    let r = run(&sc, 15).await;
    let (hp, state) = {
        let h = sc.ticker.registry.get(PLAYER).await.unwrap();
        let c = h.character.read().await;
        (c.chara.hp, c.base.current_main_state)
    };
    assert!(r.uses("man2g0_tkebbe", "raise") >= 1, "{:?}", r.used);
    assert!(hp > 0, "the player is back up (HP {hp})");
    assert_ne!(state, crate::actor::MAIN_STATE_DEAD);

    let sc = scene_at(fight, Some(30)).await;
    {
        let h = sc.ticker.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.hp = c.chara.max_hp / 4;
    }
    let r = run(&sc, 5).await;
    assert!(r.uses("man2g0_tkebbe", "cura") >= 1, "{:?}", r.used);
    assert_eq!(r.uses("man2g0_tkebbe", "cure"), 0, "{:?}", r.used);
}
