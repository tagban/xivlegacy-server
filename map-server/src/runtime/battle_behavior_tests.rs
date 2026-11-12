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

//! Level 1-20 battle behavior checks. The audit next door presses every
//! command once and checks that it fires; these check that each level 1-20
//! command of the seven Disciple of War / Magic classes does what its
//! description says, for a character with real stats and a real weapon
//! against a monster of its own level:
//!
//! * damage and healing land in a sane share of a same-level monster's
//!   (or the player's) HP,
//! * MP / TP costs and recast timers match the row,
//! * statuses land for their duration, their stat changes come on and go
//!   back off on expiry, damage-over-time ticks,
//! * combos and positionals change what they say,
//! * Stun, Bind, Heavy and Pacification change what the monster can do,
//! * the status hooks (Bloodbath, Blindside, Featherfoot, Foresight, Dark
//!   Seal, Parsimony, Necrogenesis, Blood for Blood, Aegis Boon...) fire,
//! * the "only after an evade / block / parry / miss" weaponskills follow
//!   their proc,
//! * and monster statuses on the player (Poison, Slow, Heavy, Blind, Bind)
//!   change the player.
//!
//! ```sh
//! cargo test -p map-server battle_behavior -- --nocapture
//! ```

#![cfg(test)]

use std::collections::HashMap;
use std::sync::Arc;

use super::battle_audit_tests::{
    ENEMY, FRIEND, PLAYER, PLAYER_SESSION, Recipient, Scene, error_texts, event_start_body, hp,
    press_once, recipient, scene, script_root, tempdb,
};
use crate::actor::modifier::Modifier;
use crate::gamedata::BattleCommand;

const CLASSES: [u8; 7] = [2, 3, 4, 7, 8, 22, 23];

/// Each job and the class it is built on (MNK, PLD, WAR, BRD, DRG, BLM, WHM).
const JOBS: [(u8, u8); 7] = [
    (15, 2),
    (16, 3),
    (17, 4),
    (18, 7),
    (19, 8),
    (26, 22),
    (27, 23),
];

/// The class a command's class or job is played on.
fn base_class(job: u8) -> u8 {
    JOBS.iter()
        .find(|(j, _)| *j == job)
        .map_or(job, |(_, c)| *c)
}

/// HP of a level-`level` monster: the retail capture medians
/// (`tools/world_spawns/data/xivl_mob_level_hp.csv`, the curve the spawn
/// groups use), log-linear between them. 80 at 1, 210 at 10, 723 at 30,
/// 1946 at 41; 50 follows the 41-67 slope.
fn mob_hp(level: i16) -> i32 {
    const PTS: [(f64, f64); 8] = [
        (1.0, 80.0),
        (10.0, 210.0),
        (20.0, 410.0),
        (25.0, 565.0),
        (30.0, 723.0),
        (36.0, 1077.0),
        (41.0, 1946.0),
        (50.0, 3216.0),
    ];
    let l = f64::from(level.clamp(1, 50));
    let i = PTS
        .windows(2)
        .position(|w| l <= w[1].0)
        .unwrap_or(PTS.len() - 2);
    let ((l0, h0), (l1, h1)) = (PTS[i], PTS[i + 1]);
    let t = (l - l0) / (l1 - l0);
    (h0.ln() + t * (h1.ln() - h0.ln())).exp().round() as i32
}

/// The best weapon of the class at or below `level` (item data).
fn weapon_for(class: u8, level: i16) -> u32 {
    let table: &[(i16, u32)] = match class {
        2 => &[
            (1, 4020001),
            (8, 4020107),
            (12, 4020206),
            (16, 4020207),
            (19, 4020108),
            (23, 4020208),
            (26, 4020109),
            (29, 4020302),
            (32, 4020006),
            (35, 4020110),
            (38, 4020307),
            (40, 4020306),
            (43, 4020209),
            (46, 4020111),
            (49, 4020309),
        ],
        3 => &[
            (1, 4030010),
            (7, 4030001),
            (10, 4030706),
            (18, 4030006),
            (21, 4030203),
            (23, 4030008),
            (26, 4030115),
            (28, 4030707),
            (30, 4030015),
            (31, 4030304),
            (34, 4030708),
            (36, 4030405),
            (40, 4030305),
            (43, 4030204),
            (46, 4030506),
            (49, 4030406),
        ],
        4 => &[
            (1, 4040001),
            (5, 4040004),
            (10, 4040007),
            (15, 4040009),
            (20, 4040010),
            (23, 4040405),
            (25, 4040012),
            (28, 4040107),
            (30, 4040110),
            (31, 4040304),
            (34, 4040205),
            (35, 4040303),
            (38, 4040108),
            (40, 4040407),
            (45, 4040305),
            (48, 4040207),
        ],
        7 => &[
            (1, 4070001),
            (8, 4070204),
            (16, 4070010),
            (19, 4070208),
            (24, 4070210),
            (28, 4070306),
            (30, 4070305),
            (32, 4070302),
            (35, 4070212),
            (38, 4070207),
            (40, 4070215),
            (43, 4070203),
            (46, 4070213),
            (49, 4070308),
        ],
        8 => &[
            (1, 4080201),
            (8, 4080205),
            (12, 4080008),
            (16, 4080206),
            (20, 4080104),
            (23, 4080406),
            (26, 4080208),
            (29, 4080304),
            (30, 4080110),
            (34, 4080105),
            (38, 4080102),
            (40, 4080408),
            (43, 4080305),
            (46, 4080210),
            (49, 4080407),
        ],
        22 => &[
            (1, 5020001),
            (5, 5020106),
            (12, 5020108),
            (15, 5020102),
            (25, 5020103),
            (30, 5020114),
            (35, 5020105),
            (39, 5020109),
            (40, 5020112),
            (44, 5020303),
            (49, 5020110),
        ],
        _ => &[
            (1, 5030101),
            (6, 5030102),
            (11, 5030103),
            (17, 5030107),
            (21, 5030306),
            (25, 5030207),
            (30, 5030305),
            (32, 5030208),
            (35, 5030112),
            (38, 5030109),
            (40, 5030307),
            (45, 5030209),
            (48, 5030205),
        ],
    };
    table
        .iter()
        .rev()
        .find(|(l, _)| *l <= level)
        .map(|(_, id)| *id)
        .unwrap_or(table[0].1)
}
const SHIELD: u32 = 4100001;

struct Env {
    db: Arc<crate::database::Database>,
    lua: Arc<crate::lua::LuaEngine>,
    catalog: HashMap<u16, BattleCommand>,
}

async fn env() -> Env {
    let db = Arc::new(
        crate::database::Database::open(tempdb())
            .await
            .expect("seeded db"),
    );
    let lua = Arc::new(crate::lua::LuaEngine::new(script_root()));
    let (catalog, by_level) = db.load_global_battle_command_list().await.unwrap();
    lua.catalogs()
        .install_battle_commands_with_level_index(catalog.clone(), by_level);
    lua.catalogs()
        .install_status_effects(db.load_global_status_effect_list().await.unwrap());
    lua.catalogs()
        .install_battle_traits(db.load_global_battle_trait_list().await.unwrap().0);
    lua.catalogs()
        .install_items(db.get_item_gamedata().await.unwrap());
    Env { db, lua, catalog }
}

fn by_name<'a>(env: &'a Env, name: &str) -> &'a BattleCommand {
    // Player rows first: some monster moves share a player command's name.
    env.catalog
        .values()
        .filter(|c| c.name == name)
        .min_by_key(|c| (!CLASSES.contains(&c.job), c.id))
        .unwrap_or_else(|| panic!("no command {name}"))
}

/// A scene whose player has the class's real stats, traits and weapon at
/// the command's level, full HP/MP, and a monster of the same level.
async fn real_scene(env: &Env, cmd: &BattleCommand, rcpt: Recipient) -> Scene {
    real_scene_at(env, cmd, rcpt, i16::from(cmd.level.max(1)), cmd.job).await
}

async fn real_scene_at(
    env: &Env,
    cmd: &BattleCommand,
    rcpt: Recipient,
    level: i16,
    class: u8,
) -> Scene {
    let sc = scene(&env.db, &env.lua, cmd, rcpt).await;
    // A job plays on its class; its gear is kept under the job's id (the
    // server equips by the current job).
    let job = class;
    let class = base_class(job);
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.level = level;
        c.chara.class = i16::from(class);
        c.chara.current_job = if job != class { u16::from(job) } else { 0 };
    }
    let gear_class = job;
    // Real gear in the DB, so every stat rebuild (status gain/loss) keeps it.
    let _ = env.db.unequip_item(PLAYER, gear_class, 0).await;
    let _ = env.db.unequip_item(PLAYER, gear_class, 1).await;
    let w = env
        .db
        .create_item(weapon_for(class, level), 1, 1, None)
        .await
        .unwrap();
    env.db
        .equip_item(
            PLAYER,
            gear_class,
            crate::actor::player::SLOT_MAINHAND,
            w.unique_id,
            false,
        )
        .await
        .unwrap();
    if class == 3 {
        let s = env.db.create_item(SHIELD, 1, 1, None).await.unwrap();
        env.db
            .equip_item(
                PLAYER,
                gear_class,
                crate::actor::player::SLOT_OFFHAND,
                s.unique_id,
                false,
            )
            .await
            .unwrap();
    }
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.max_hp = 0;
        c.chara.max_mp = 0;
    }
    crate::runtime::dispatcher::recalc_stats_at_login(
        &sc.registry,
        &sc.processor.world,
        env.lua.catalogs(),
        &env.db,
        PLAYER,
    )
    .await;
    for id in [ENEMY, super::battle_audit_tests::ENEMY2] {
        let h = sc.registry.get(id).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.level = level;
        // The live spawn's fallback stats (`BattleNpc::apply_spawn_metadata`).
        for (m, v) in crate::battle::utils::monster_melee_stats(level) {
            c.chara.mods.set(m, v);
        }
        c.chara.mods.set(Modifier::MovementSpeed, 5.0);
    }
    sc
}

async fn set_hp(sc: &Scene, id: u32, v: i32) {
    let h = sc.registry.get(id).await.unwrap();
    let mut c = h.character.write().await;
    c.chara.hp = v as i16;
}

async fn mod_of(sc: &Scene, id: u32, m: Modifier) -> f64 {
    sc.registry
        .get(id)
        .await
        .unwrap()
        .character
        .read()
        .await
        .chara
        .mods
        .get(m)
}

async fn has_status(sc: &Scene, id: u32, status: u32) -> bool {
    sc.registry
        .get(id)
        .await
        .unwrap()
        .character
        .read()
        .await
        .status_effects
        .has(status)
}

async fn clear_status(sc: &Scene, id: u32, status: u32) {
    {
        let h = sc.registry.get(id).await.unwrap();
        let mut c = h.character.write().await;
        if let Some(e) = c.status_effects.get_mut(status) {
            e.end_time = 1;
        }
    }
    let base = crate::runtime::clock::server_now_ms();
    Box::pin(sc.ticker.tick_once(base + 5_000)).await;
}

/// Put `status` on an actor the way a landed command does.
async fn give_status(env: &Env, sc: &Scene, id: u32, status: u32, secs: u32, magnitude: f64) {
    let mut cmd = crate::battle::command::BattleCommand::new(0, "");
    cmd.status_id = status;
    cmd.status_duration = secs;
    cmd.status_magnitude = magnitude;
    crate::runtime::dispatcher::test_add_status(
        &sc.registry,
        &sc.processor.world,
        Some(&env.lua),
        Some(&env.db),
        id,
        &cmd,
    )
    .await;
}

fn median(v: &mut [i32]) -> i32 {
    if v.is_empty() {
        return 0;
    }
    v.sort_unstable();
    v[v.len() / 2]
}

/// Every level 1-20 command of the seven classes.
fn l20_commands(env: &Env) -> Vec<BattleCommand> {
    band_commands(env, 1, 20)
}

/// The seven classes' and their jobs' commands from level `lo` to `hi`.
fn band_commands(env: &Env, lo: u8, hi: u8) -> Vec<BattleCommand> {
    let mut v: Vec<BattleCommand> = env
        .catalog
        .values()
        .filter(|c| {
            (CLASSES.contains(&c.job) || JOBS.iter().any(|(j, _)| *j == c.job))
                && (lo..=hi).contains(&c.level)
        })
        .cloned()
        .collect();
    v.sort_by_key(|c| (base_class(c.job), c.level, c.id));
    v
}

/// Damage, healing, costs, recast and status duration for every level
/// 1-20 command, with the real stat pipeline. Prints a table.
#[tokio::test]
async fn battle_behavior_l20_numbers() {
    band_numbers(1, 20, 51).await;
}

/// The same for levels 21-30 (classes, and the jobs' level 30 actions).
#[tokio::test]
async fn battle_behavior_l30_numbers() {
    band_numbers(21, 30, 28).await;
}

/// The same for levels 31-40.
#[tokio::test]
async fn battle_behavior_l40_numbers() {
    band_numbers(31, 40, 28).await;
}

/// The same for levels 41-50.
#[tokio::test]
async fn battle_behavior_l50_numbers() {
    band_numbers(41, 50, 35).await;
}

async fn band_numbers(lo: u8, hi: u8, count: usize) {
    let env = env().await;
    let cmds = band_commands(&env, lo, hi);
    assert_eq!(
        cmds.len(),
        count,
        "level {lo}-{hi} commands of the seven classes and jobs"
    );
    let mut problems = Vec::new();
    println!(
        "\n{:<6} {:<18} {:>3} {:>3} {:>7} {:>6} {:>6} {:>5} {:>5} {:>5} {:>6}",
        "id", "name", "cls", "lvl", "median", "share", "mp", "tp", "rec", "dur", "mobhp"
    );
    for cmd in &cmds {
        let rcpt = recipient(cmd);
        let mut sc = real_scene(&env, cmd, rcpt).await;
        // At exactly the TP it costs: the surplus bonus has its own test
        // (battle_behavior_ws_tp_surplus).
        if cmd.tp_cost > 0 {
            sc.press_tp = cmd.tp_cost as u16;
        }
        let level = i16::from(cmd.level.max(1));
        let (player_max, player_max_mp) = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            (i32::from(c.chara.max_hp), i32::from(c.chara.max_mp))
        };
        let mut dmg = Vec::new();
        let mut heals = Vec::new();
        let mut mp_spent = None;
        let mut tp_spent = None;
        let mut recast = None;
        let mut duration = None;
        for _ in 0..10 {
            // The friend and caster start at half HP for heals.
            set_hp(&sc, PLAYER, player_max / 2).await;
            if rcpt != Recipient::DeadFriend {
                set_hp(&sc, FRIEND, player_max / 2).await;
                let h = sc.registry.get(FRIEND).await.unwrap();
                h.character.write().await.chara.max_hp = player_max as i16;
            }
            if cmd.status_id != 0 {
                for id in [PLAYER, ENEMY, FRIEND] {
                    clear_status(&sc, id, cmd.status_id).await;
                }
            }
            let o = Box::pin(press_once(&mut sc, cmd, rcpt)).await;
            if !o.errors.is_empty() {
                // Proc commands are refused without their proc: covered
                // by the proc test.
                break;
            }
            if o.damage_main > 0 {
                dmg.push(o.damage_main);
            }
            if o.heal > 0 {
                heals.push(o.heal);
            }
            mp_spent.get_or_insert(o.mp_spent);
            tp_spent.get_or_insert(o.tp_spent);
            if recast.is_none() {
                let h = sc.registry.get(PLAYER).await.unwrap();
                let c = h.character.read().await;
                let now = common::utils::unix_timestamp() as u32;
                recast = c
                    .chara
                    .hotbar
                    .first()
                    .map(|e| e.recast_time.saturating_sub(now) as i32);
            }
            if duration.is_none() && o.status_on.is_some() {
                let rid = super::battle_audit_tests::status_recipient_id(cmd, rcpt);
                let h = sc.registry.get(rid).await.unwrap();
                let c = h.character.read().await;
                duration = c.status_effects.get(cmd.status_id).map(|e| e.duration);
            }
        }
        let med = median(&mut dmg);
        let heal_med = median(&mut heals);
        let share = if med > 0 {
            f64::from(med) / f64::from(mob_hp(level))
        } else if heal_med > 0 {
            f64::from(heal_med) / f64::from(player_max.max(1))
        } else {
            0.0
        };
        println!(
            "{:<6} {:<18} {:>3} {:>3} {:>7} {:>5.0}% {:>6} {:>5} {:>5} {:>5} {:>6}",
            cmd.id,
            cmd.name,
            cmd.job,
            cmd.level,
            if med > 0 { med } else { heal_med },
            share * 100.0,
            mp_spent.unwrap_or(-1),
            tp_spent.unwrap_or(-1),
            recast.unwrap_or(-1),
            duration.map_or(-1, |d| d as i64),
            mob_hp(level),
        );
        let damaging = matches!(cmd.action_type, 1 | 2);
        let proc_gated = cmd.proc_requirement != 0;
        if proc_gated {
            continue;
        }
        if damaging {
            // A weaponskill or attack spell takes 4-80% of a same-level
            // monster: none ends a fight on its own. (PUG's retail 5-6x
            // multipliers are at the top.) Rage of Halone's five hits each
            // take -40% accuracy outside its combo (its script), so most
            // miss here: 2% is its floor.
            let floor = if cmd.name == "rage_of_halone" {
                0.02
            } else {
                0.04
            };
            if !(floor..=0.80).contains(&share) {
                problems.push(format!(
                    "{} dmg median {med} = {:.0}% of a level {level} monster ({})",
                    cmd.name,
                    share * 100.0,
                    mob_hp(level)
                ));
            }
        }
        // Benediction restores all HP.
        let heal_cap = if cmd.name == "benediction" { 1.0 } else { 0.70 };
        if cmd.action_type == 3 && !(0.05..=heal_cap).contains(&share) {
            problems.push(format!(
                "{} heal median {heal_med} = {:.0}% of max HP {player_max}",
                cmd.name,
                share * 100.0
            ));
        }
        if cmd.tp_cost > 0 && tp_spent != Some(i32::from(cmd.tp_cost)) {
            problems.push(format!(
                "{} tp spent {tp_spent:?}, row {}",
                cmd.name, cmd.tp_cost
            ));
        }
        if cmd.command_type == 4 {
            let want = i32::from(cmd.to_battle_command().calculate_mp_cost(level, 0.0));
            if mp_spent != Some(want) {
                problems.push(format!(
                    "{} mp spent {mp_spent:?}, want {want} (max MP {player_max_mp})",
                    cmd.name
                ));
            }
            if want > player_max_mp {
                problems.push(format!(
                    "{} costs {want} MP, more than a level {level}'s {player_max_mp}",
                    cmd.name
                ));
            }
        }
        if cmd.max_recast_time_seconds > 0 {
            let want = cmd.max_recast_time_seconds as i32;
            match recast {
                Some(r) if (r - want).abs() <= 1 => {}
                other => problems.push(format!("{} recast {other:?} s, row {want} s", cmd.name)),
            }
        }
        if cmd.status_id != 0
            && cmd.status_chance > 0.0
            && cmd.status_duration != u32::MAX
            && let Some(d) = duration
            && d != cmd.status_duration
        {
            problems.push(format!(
                "{} status {} lasts {d} s, row {} s",
                cmd.name, cmd.status_id, cmd.status_duration
            ));
        }
    }
    assert!(
        problems.is_empty(),
        "level {lo}-{hi} numbers:\n{problems:#?}"
    );
}

// ---------------------------------------------------------------------------
// Shared helpers for the behavior checks below.
// ---------------------------------------------------------------------------

/// Put `cmd` on the hotbar (if it isn't) and press it like `press_once`.
async fn press(sc: &mut Scene, cmd: &BattleCommand) -> super::battle_audit_tests::Outcome {
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        if !c
            .chara
            .hotbar
            .iter()
            .any(|e| e.command_id == u32::from(cmd.id))
        {
            let slot = c.chara.hotbar.len() as u16;
            c.chara.hotbar.push(crate::gamedata::HotbarEntry {
                hotbar_slot: slot,
                command_id: u32::from(cmd.id),
                recast_time: 0,
            });
        }
    }
    Box::pin(press_once(sc, cmd, recipient(cmd))).await
}

async fn reset_enemy(sc: &Scene) {
    let h = sc.registry.get(ENEMY).await.unwrap();
    let mut c = h.character.write().await;
    c.chara.max_hp = 30000;
    c.chara.hp = 30000;
}

/// End the player's combo (as the Combo status wearing off does).
async fn end_combo(sc: &Scene) {
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        h.character.write().await.combo_next = [0, 0];
    }
    clear_status(sc, PLAYER, 223205).await;
}

/// Median damage of `cmd` over `n` landed presses; `before` runs first
/// each time (a combo opener) when given.
async fn median_damage(
    sc: &mut Scene,
    cmd: &BattleCommand,
    before: Option<&BattleCommand>,
    n: usize,
) -> i32 {
    let mut v = Vec::new();
    for _ in 0..n * 3 {
        if v.len() >= n {
            break;
        }
        end_combo(sc).await;
        reset_enemy(sc).await;
        if let Some(b) = before {
            let o = press(sc, b).await;
            // Only a cleanly landed opener starts the combo (a partial
            // resist deals damage but doesn't count).
            let next = sc
                .registry
                .get(PLAYER)
                .await
                .unwrap()
                .character
                .read()
                .await
                .combo_next;
            if o.damage_main <= 0 || !next.contains(&i32::from(cmd.id)) {
                continue;
            }
        }
        let o = press(sc, cmd).await;
        if o.damage_main > 0 {
            v.push(o.damage_main);
        }
    }
    median(&mut v)
}

/// Turn the enemy so the player (at the origin) stands at its `side`.
async fn stand_at(sc: &Scene, side: &str) {
    use crate::runtime::ticker::look_at_rotation;
    let (ex, ez) = (3.0f32, 0.0f32);
    // Facing the player = player in front; facing away = player behind.
    let rot = match side {
        "front" => look_at_rotation(ex, ez, 0.0, 0.0),
        "rear" => look_at_rotation(ex, ez, 6.0, 0.0),
        _ => look_at_rotation(ex, ez, 3.0, 3.0),
    };
    let h = sc.registry.get(ENEMY).await.unwrap();
    h.character.write().await.base.rotation = rot;
}

/// How often `status` lands on the enemy from `cmd` (out of `n`).
async fn status_hits(sc: &mut Scene, cmd: &BattleCommand, status: u32, n: usize) -> usize {
    let mut hits = 0;
    for _ in 0..n {
        end_combo(sc).await;
        reset_enemy(sc).await;
        clear_status(sc, ENEMY, status).await;
        press(sc, cmd).await;
        if has_status(sc, ENEMY, status).await {
            hits += 1;
        }
    }
    hits
}

async fn tick_for(sc: &Scene, ms: u64) {
    let base = crate::runtime::clock::server_now_ms();
    let mut t = 0;
    while t < ms {
        t += 100;
        Box::pin(sc.ticker.tick_once(base + t)).await;
    }
}

// ---------------------------------------------------------------------------
// Statuses: stat changes on, then off on expiry; damage/TP over time.
// ---------------------------------------------------------------------------

#[tokio::test]
async fn battle_behavior_status_stat_changes() {
    let env = env().await;
    // (command, who carries it, modifier, check on the delta)
    type Check = fn(f64, i16) -> bool;
    let cases: &[(&str, u32, Modifier, Check, &str)] = &[
        (
            "featherfoot",
            PLAYER,
            Modifier::RawEvadeRate,
            |d, _| d >= 15.0,
            "evasion up",
        ),
        (
            "rampart",
            PLAYER,
            Modifier::Defense,
            |d, l| d == f64::from(2 * l + 5),
            "defense +2L+5",
        ),
        (
            "foresight",
            PLAYER,
            Modifier::Parry,
            |d, _| d >= 200.0,
            "parry up",
        ),
        (
            "hawks_eye",
            PLAYER,
            Modifier::Accuracy,
            |d, _| d > 0.0,
            "accuracy up",
        ),
        (
            "protect",
            PLAYER,
            Modifier::Defense,
            |d, _| d > 0.0,
            "defense up",
        ),
        (
            "invigorate",
            PLAYER,
            Modifier::Regain,
            |d, _| d >= 100.0,
            "TP per tick",
        ),
        (
            "cleric_stance",
            PLAYER,
            Modifier::AttackMagicPotency,
            |d, _| d > 0.0,
            "attack magic up",
        ),
        (
            "blizzard",
            ENEMY,
            Modifier::MovementSpeed,
            |d, _| d < 0.0,
            "Heavy slows",
        ),
        (
            "leaden_arrow",
            ENEMY,
            Modifier::MovementSpeed,
            |d, _| d < 0.0,
            "Heavy slows",
        ),
        (
            "stone",
            ENEMY,
            Modifier::MagicEvasion,
            |d, _| d < 0.0,
            "magic evasion down",
        ),
        (
            "aero",
            ENEMY,
            Modifier::RegenDown,
            |d, _| d > 0.0,
            "damage over time",
        ),
    ];
    let mut problems = Vec::new();
    for (name, who, m, check, what) in cases {
        let cmd = by_name(&env, name).clone();
        let mut sc = real_scene(&env, &cmd, recipient(&cmd)).await;
        reset_enemy(&sc).await;
        let level = i16::from(cmd.level.max(1));
        // Heavy multiplies the run speed: start from the default.
        if *m == Modifier::MovementSpeed {
            let h = sc.registry.get(*who).await.unwrap();
            h.character
                .write()
                .await
                .chara
                .mods
                .set(Modifier::MovementSpeed, 5.0);
        }
        let before = mod_of(&sc, *who, *m).await;
        let mut landed = false;
        for _ in 0..12 {
            press(&mut sc, &cmd).await;
            if has_status(&sc, *who, cmd.status_id).await {
                landed = true;
                break;
            }
        }
        if !landed {
            problems.push(format!("{name}: status {} never landed", cmd.status_id));
            continue;
        }
        let during = mod_of(&sc, *who, *m).await;
        let d = during - before;
        if !check(d, level) {
            problems.push(format!("{name}: {m:?} {before} -> {during} ({what})"));
        }
        clear_status(&sc, *who, cmd.status_id).await;
        let after = mod_of(&sc, *who, *m).await;
        if has_status(&sc, *who, cmd.status_id).await {
            problems.push(format!("{name}: status still on after expiry"));
        }
        if (after - before).abs() > 1e-6 {
            problems.push(format!(
                "{name}: {m:?} {before} -> {during} -> {after} after expiry"
            ));
        }
        println!("{name:<14} {m:?}: {before} -> {during} -> {after}");
    }
    assert!(problems.is_empty(), "status stat changes:\n{problems:#?}");
}

/// Aero's bleed takes HP every 3 s and stops when it wears off; Invigorate
/// gives TP every tick.
#[tokio::test]
async fn battle_behavior_dot_and_regain_tick() {
    let env = env().await;
    let aero = by_name(&env, "aero").clone();
    let mut sc = real_scene(&env, &aero, Recipient::Enemy).await;
    // Fighting (a monster out of combat regenerates).
    hostile_enemy(&sc, 2.0).await;
    reset_enemy(&sc).await;
    for _ in 0..12 {
        press(&mut sc, &aero).await;
        if has_status(&sc, ENEMY, aero.status_id).await {
            break;
        }
    }
    assert!(
        has_status(&sc, ENEMY, aero.status_id).await,
        "Aero's bleed lands"
    );
    let hp0 = hp(&sc.registry, ENEMY).await;
    tick_for(&sc, 9_100).await;
    let hp1 = hp(&sc.registry, ENEMY).await;
    assert!(hp1 < hp0, "bleed ticks: {hp0} -> {hp1}");
    println!("aero bleed over 9 s: {}", hp0 - hp1);
    clear_status(&sc, ENEMY, aero.status_id).await;
    let hp2 = hp(&sc.registry, ENEMY).await;
    tick_for(&sc, 9_100).await;
    let hp3 = hp(&sc.registry, ENEMY).await;
    assert_eq!(hp2, hp3, "no bleed after it wears off");

    let inv = by_name(&env, "invigorate").clone();
    let mut sc = real_scene(&env, &inv, Recipient::Caster).await;
    press(&mut sc, &inv).await;
    assert!(
        has_status(&sc, PLAYER, inv.status_id).await,
        "Invigorate lands"
    );
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        h.character.write().await.chara.tp = 0;
    }
    tick_for(&sc, 6_100).await;
    let tp = sc
        .registry
        .get(PLAYER)
        .await
        .unwrap()
        .character
        .read()
        .await
        .chara
        .tp;
    assert!(tp >= 100, "Invigorate grants TP each tick, got {tp}");
}

// ---------------------------------------------------------------------------
// Combos and positionals.
// ---------------------------------------------------------------------------

#[tokio::test]
async fn battle_behavior_combos() {
    let env = env().await;
    let mut problems = Vec::new();
    // Damage bonuses: (opener, finisher, min ratio)
    for (a, b, ratio) in [
        ("fast_blade", "savage_blade", 1.15),
        ("pummel", "concussive_blow", 1.35),
        ("thunder", "thundara", 1.35),
    ] {
        let opener = by_name(&env, a).clone();
        let fin = by_name(&env, b).clone();
        let mut sc = real_scene(&env, &fin, Recipient::Enemy).await;
        stand_at(&sc, "rear").await; // no positional bonus either way
        let alone = median_damage(&mut sc, &fin, None, 15).await;
        let combo = median_damage(&mut sc, &fin, Some(&opener), 15).await;
        let r = f64::from(combo) / f64::from(alone.max(1));
        println!("{a} -> {b}: {alone} alone, {combo} in combo ({r:.2}x)");
        if r < ratio {
            problems.push(format!(
                "{a} -> {b}: {alone} -> {combo} ({r:.2}x, want {ratio}x)"
            ));
        }
    }
    // Thundara in combo: no Stun, half the recast.
    {
        let thunder = by_name(&env, "thunder").clone();
        let thundara = by_name(&env, "thundara").clone();
        let mut sc = real_scene(&env, &thundara, Recipient::Enemy).await;
        let mut stuns = 0;
        let mut recast = 0;
        for _ in 0..10 {
            end_combo(&sc).await;
            reset_enemy(&sc).await;
            clear_status(&sc, ENEMY, thundara.status_id).await;
            // Only a landed opener starts the combo.
            let t = press(&mut sc, &thunder).await;
            if t.damage_main <= 0 {
                continue;
            }
            // A partial resist doesn't count as landed: no combo.
            let combo_next = sc
                .registry
                .get(PLAYER)
                .await
                .unwrap()
                .character
                .read()
                .await
                .combo_next;
            if !combo_next.contains(&i32::from(thundara.id)) {
                continue;
            }
            press(&mut sc, &thundara).await;
            if has_status(&sc, ENEMY, thundara.status_id).await {
                stuns += 1;
            }
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            let now = common::utils::unix_timestamp() as u32;
            recast = c
                .chara
                .hotbar
                .iter()
                .find(|e| e.command_id == u32::from(thundara.id))
                .map_or(0, |e| e.recast_time.saturating_sub(now));
        }
        if stuns > 0 {
            problems.push(format!("thundara in combo stunned {stuns}/10"));
        }
        if recast > thundara.max_recast_time_seconds / 2 + 1 {
            problems.push(format!(
                "thundara in combo recast {recast} s, row {} s",
                thundara.max_recast_time_seconds
            ));
        }
    }
    // Duration bonuses: (opener, finisher, combo duration)
    for (a, b, secs) in [
        ("heavy_shot", "leaden_arrow", 60u32),
        ("piercing_arrow", "shadowbind", 30),
        ("true_thrust", "heavy_thrust", 10),
    ] {
        let opener = by_name(&env, a).clone();
        let fin = by_name(&env, b).clone();
        let mut sc = real_scene(&env, &fin, Recipient::Enemy).await;
        // Archer combos need 8 yalms between archer and target.
        if fin.job == 7 {
            let h = sc.registry.get(ENEMY).await.unwrap();
            h.character.write().await.base.position_x = 10.0;
            let z = sc
                .processor
                .world
                .zone(super::battle_audit_tests::ZONE)
                .await
                .unwrap();
            let mut ob = crate::zone::outbox::AreaOutbox::new();
            z.write().await.core.update_actor_position(
                ENEMY,
                common::Vector3::new(10.0, 0.0, 0.0),
                &mut ob,
            );
        }
        let mut got = None;
        for _ in 0..12 {
            end_combo(&sc).await;
            reset_enemy(&sc).await;
            clear_status(&sc, ENEMY, fin.status_id).await;
            if press(&mut sc, &opener).await.damage_main <= 0 {
                continue;
            }
            press(&mut sc, &fin).await;
            let h = sc.registry.get(ENEMY).await.unwrap();
            let c = h.character.read().await;
            if let Some(e) = c.status_effects.get(fin.status_id) {
                got = Some(e.duration);
                break;
            }
        }
        println!("{a} -> {b}: status lasts {got:?} s");
        if got != Some(secs) {
            problems.push(format!("{a} -> {b}: status lasts {got:?} s, want {secs}"));
        }
    }
    // Inside 8 yalms Heavy Shot and Piercing Arrow start no combo: the
    // finisher keeps its plain duration.
    for (a, b, combo_secs) in [
        ("heavy_shot", "leaden_arrow", 60u32),
        ("piercing_arrow", "shadowbind", 30),
    ] {
        let opener = by_name(&env, a).clone();
        let fin = by_name(&env, b).clone();
        let mut sc = real_scene(&env, &fin, Recipient::Enemy).await;
        let mut got = None;
        for _ in 0..12 {
            end_combo(&sc).await;
            reset_enemy(&sc).await;
            clear_status(&sc, ENEMY, fin.status_id).await;
            if press(&mut sc, &opener).await.damage_main <= 0 {
                continue;
            }
            press(&mut sc, &fin).await;
            let h = sc.registry.get(ENEMY).await.unwrap();
            let c = h.character.read().await;
            if let Some(e) = c.status_effects.get(fin.status_id) {
                got = Some(e.duration);
                break;
            }
        }
        println!("{a} -> {b} at 3 yalms: status lasts {got:?} s");
        if got == Some(combo_secs) {
            problems.push(format!("{a} -> {b} from 3 yalms: status {got:?} s"));
        }
    }
    // Skull Sunder in combo draws more enmity.
    {
        let opener = by_name(&env, "heavy_swing").clone();
        let fin = by_name(&env, "skull_sunder").clone();
        let mut sc = real_scene(&env, &fin, Recipient::Enemy).await;
        let mut ratio = Vec::new();
        for combo in [false, true] {
            let mut per_dmg = Vec::new();
            for _ in 0..12 {
                end_combo(&sc).await;
                reset_enemy(&sc).await;
                if combo {
                    let o = press(&mut sc, &opener).await;
                    if o.damage_main <= 0 {
                        continue;
                    }
                }
                let before = {
                    let h = sc.registry.get(ENEMY).await.unwrap();
                    let c = h.character.read().await;
                    c.hate.get(PLAYER).map_or(0, |e| e.cumulative_enmity as i32)
                };
                let o = press(&mut sc, &fin).await;
                if o.damage_main <= 0 {
                    continue;
                }
                let after = {
                    let h = sc.registry.get(ENEMY).await.unwrap();
                    let c = h.character.read().await;
                    c.hate.get(PLAYER).map_or(0, |e| e.cumulative_enmity as i32)
                };
                per_dmg.push(((after - before) * 100) / o.damage_main.max(1));
            }
            ratio.push(median(&mut per_dmg));
        }
        println!(
            "skull_sunder enmity per 100 damage: {} alone, {} in combo",
            ratio[0], ratio[1]
        );
        if ratio[1] < ratio[0] * 2 {
            problems.push(format!("skull_sunder combo enmity {ratio:?} (want 2.75x)"));
        }
    }
    assert!(problems.is_empty(), "combos:\n{problems:#?}");
}

#[tokio::test]
async fn battle_behavior_positionals() {
    let env = env().await;
    let mut problems = Vec::new();
    // Damage: (command, bonus side, other side, min ratio)
    for (name, good, bad, ratio) in [
        ("fast_blade", "front", "rear", 1.15),
        // Pummel's front bonus is +15%; whole-number hits round it down.
        ("pummel", "front", "rear", 1.10),
        ("brutal_swing", "flank", "front", 1.35),
        ("impulse_drive", "flank", "front", 1.15),
    ] {
        let cmd = by_name(&env, name).clone();
        let mut sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        stand_at(&sc, good).await;
        let g = median_damage(&mut sc, &cmd, None, 15).await;
        stand_at(&sc, bad).await;
        let b = median_damage(&mut sc, &cmd, None, 15).await;
        let r = f64::from(g) / f64::from(b.max(1));
        println!("{name}: {g} from the {good}, {b} from the {bad} ({r:.2}x)");
        if r < ratio {
            problems.push(format!(
                "{name}: {good} {g} vs {bad} {b} ({r:.2}x, want {ratio}x)"
            ));
        }
    }
    // Statuses only from the right side: (command, side, status)
    for (name, good, bad) in [
        ("pounce", "rear", "front"),
        ("concussive_blow", "flank", "front"),
    ] {
        let cmd = by_name(&env, name).clone();
        let mut sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        stand_at(&sc, good).await;
        let g = status_hits(&mut sc, &cmd, cmd.status_id, 12).await;
        stand_at(&sc, bad).await;
        let b = status_hits(&mut sc, &cmd, cmd.status_id, 12).await;
        println!("{name}: status {g}/12 from the {good}, {b}/12 from the {bad}");
        if g == 0 || b != 0 {
            problems.push(format!("{name}: status {g}/12 {good}, {b}/12 {bad}"));
        }
    }
    assert!(problems.is_empty(), "positionals:\n{problems:#?}");
}

// ---------------------------------------------------------------------------
// Crowd control on monsters: Stun, Bind, Heavy, Pacification.
// ---------------------------------------------------------------------------

/// Give the enemy a monster AI fighting the player, `dist` yalms away.
async fn hostile_enemy(sc: &Scene, dist: f32) {
    let now = crate::runtime::clock::server_now_ms();
    {
        let h = sc.registry.get(ENEMY).await.unwrap();
        let mut c = h.character.write().await;
        c.base.position_x = dist;
        c.ai_container.controller = Some(crate::battle::controller::BattleNpcController::new_for(
            ENEMY,
        ));
        c.hate.update_hate(PLAYER, 10);
        c.ai_container.internal_engage(PLAYER, now, 2500);
        c.chara.mods.set(Modifier::Delay, 2.5);
    }
    let z = sc
        .processor
        .world
        .zone(super::battle_audit_tests::ZONE)
        .await
        .unwrap();
    let mut ob = crate::zone::outbox::AreaOutbox::new();
    z.write().await.core.update_actor_position(
        ENEMY,
        common::Vector3::new(dist, 0.0, 0.0),
        &mut ob,
    );
}

/// The enemy's swings always connect (a low-level miss streak would read as
/// "it didn't swing").
async fn sure_hits(sc: &Scene) {
    let h = sc.registry.get(ENEMY).await.unwrap();
    h.character
        .write()
        .await
        .chara
        .mods
        .set(Modifier::RawHitRate, 100.0);
}

async fn enemy_x(sc: &Scene) -> f32 {
    sc.registry
        .get(ENEMY)
        .await
        .unwrap()
        .character
        .read()
        .await
        .base
        .position_x
}

#[tokio::test]
async fn battle_behavior_crowd_control_on_monsters() {
    let env = env().await;
    let cmd = by_name(&env, "fast_blade").clone();
    let mut problems = Vec::new();

    // Free monster: walks in from 10 yalms and hits the player.
    {
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 10.0).await;
        sure_hits(&sc).await;
        let php = hp(&sc.registry, PLAYER).await;
        tick_for(&sc, 8_000).await;
        let moved = 10.0 - enemy_x(&sc).await;
        let lost = php - hp(&sc.registry, PLAYER).await;
        println!("free monster: moved {moved:.1} y, player lost {lost} HP");
        if moved < 3.0 || lost <= 0 {
            problems.push(format!(
                "free monster moved {moved} y, dealt {lost}: harness broken"
            ));
        }
    }
    // Stun: no moving, no swinging.
    for (status, name) in [(223015u32, "stun"), (228001, "sleep")] {
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 2.0).await;
        sure_hits(&sc).await;
        give_status(&env, &sc, ENEMY, status, 30, 0.0).await;
        let php = hp(&sc.registry, PLAYER).await;
        tick_for(&sc, 8_000).await;
        let lost = php - hp(&sc.registry, PLAYER).await;
        if lost != 0 {
            problems.push(format!("{name}ned monster still dealt {lost}"));
        }
    }
    // Bind: no moving from 10 yalms; in reach it still swings.
    {
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 10.0).await;
        give_status(&env, &sc, ENEMY, 228011, 30, 0.0).await;
        tick_for(&sc, 5_000).await;
        let moved = 10.0 - enemy_x(&sc).await;
        if moved.abs() > 0.01 {
            problems.push(format!("bound monster moved {moved} y"));
        }
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 2.0).await;
        sure_hits(&sc).await;
        give_status(&env, &sc, ENEMY, 228011, 30, 0.0).await;
        let php = hp(&sc.registry, PLAYER).await;
        tick_for(&sc, 8_000).await;
        if php - hp(&sc.registry, PLAYER).await <= 0 {
            problems.push("bound monster in reach stopped swinging".into());
        }
    }
    // Heavy: slower walk.
    {
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 20.0).await;
        tick_for(&sc, 1_500).await;
        let free = 20.0 - enemy_x(&sc).await;
        let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        hostile_enemy(&sc, 20.0).await;
        give_status(&env, &sc, ENEMY, 228021, 30, 0.0).await;
        tick_for(&sc, 1_500).await;
        let heavy = 20.0 - enemy_x(&sc).await;
        println!("1.5 s walk: {free:.2} y free, {heavy:.2} y Heavy");
        if !(heavy < free * 0.9 && heavy > 0.0) {
            problems.push(format!("Heavy walk {heavy} y vs free {free} y"));
        }
    }
    // Pacification: no monster weaponskills, still swings.
    {
        let (catalog, _) = (env.catalog.clone(), ());
        // The lowest id, not the first a HashMap yields: a different move
        // each run made this flaky.
        let skill = catalog
            .values()
            .filter(|c| {
                c.job == 0
                    && c.action_type == 1
                    && c.id >= 23000
                    && c.aoe_type == 0
                    && c.status_id == 0
            })
            .min_by_key(|c| c.id)
            .cloned()
            .expect("a single-target monster attack move");
        for pacified in [false, true] {
            let sc = real_scene(&env, &cmd, Recipient::Enemy).await;
            hostile_enemy(&sc, 2.0).await;
            {
                let h = sc.registry.get(ENEMY).await.unwrap();
                let mut c = h.character.write().await;
                c.chara.tp = 1000;
                let ctrl = c.ai_container.controller.as_mut().unwrap();
                ctrl.battle.skills = vec![skill.to_battle_command()];
                ctrl.battle.next_skill_ms = 0;
                // Only the move can hurt the player.
                ctrl.auto_attack_enabled = false;
            }
            // A missed move doesn't show, and the next one is 10 s away.
            sure_hits(&sc).await;
            if pacified {
                give_status(&env, &sc, ENEMY, 223013, 30, 0.0).await;
            }
            let php = hp(&sc.registry, PLAYER).await;
            // Up to 8 s, stopping once the move goes off (a loaded test run
            // can need more than the first few ticks).
            let mut used = false;
            for _ in 0..8 {
                tick_for(&sc, 1_000).await;
                let tp = sc
                    .registry
                    .get(ENEMY)
                    .await
                    .unwrap()
                    .character
                    .read()
                    .await
                    .chara
                    .tp;
                used = tp < 1000 || hp(&sc.registry, PLAYER).await < php;
                if used {
                    break;
                }
            }
            println!("pacified={pacified}: monster used its move: {used}");
            if used == pacified {
                problems.push(format!("pacified={pacified}, monster move used={used}"));
            }
        }
    }
    assert!(problems.is_empty(), "crowd control:\n{problems:#?}");
}

// ---------------------------------------------------------------------------
// Status hooks: the buff does its thing on the next action and goes.
// ---------------------------------------------------------------------------

async fn land_self_buff(sc: &mut Scene, cmd: &BattleCommand) {
    for _ in 0..6 {
        press(sc, cmd).await;
        if has_status(sc, PLAYER, cmd.status_id).await {
            return;
        }
    }
    panic!("{} never landed", cmd.name);
}

async fn pools(sc: &Scene, id: u32) -> (i32, i32, i32) {
    let h = sc.registry.get(id).await.unwrap();
    let c = h.character.read().await;
    (
        i32::from(c.chara.hp),
        i32::from(c.chara.mp),
        i32::from(c.chara.tp),
    )
}

#[tokio::test]
async fn battle_behavior_status_hooks() {
    let env = env().await;
    let mut problems = Vec::new();

    // Bloodbath: the next weaponskill drains HP; the buff goes.
    {
        let bb = by_name(&env, "bloodbath").clone();
        let ws = by_name(&env, "heavy_swing").clone();
        let mut sc = real_scene_at(&env, &bb, Recipient::Caster, 10, 4).await;
        reset_enemy(&sc).await;
        land_self_buff(&mut sc, &bb).await;
        let max = sc
            .registry
            .get(PLAYER)
            .await
            .unwrap()
            .character
            .read()
            .await
            .chara
            .max_hp;
        set_hp(&sc, PLAYER, i32::from(max) / 2).await;
        let mut o = press(&mut sc, &ws).await;
        for _ in 0..5 {
            if o.damage_main > 0 {
                break;
            }
            o = press(&mut sc, &ws).await;
        }
        let gained = hp(&sc.registry, PLAYER).await - i32::from(max) / 2;
        if gained <= 0 || has_status(&sc, PLAYER, bb.status_id).await {
            problems.push(format!(
                "bloodbath: drained {gained} on a {} hit, still on: {}",
                o.damage_main,
                has_status(&sc, PLAYER, bb.status_id).await
            ));
        }
    }
    // Blood for Blood: the next weaponskill costs HP and hits harder.
    {
        let b4b = by_name(&env, "blood_for_blood").clone();
        let ws = by_name(&env, "true_thrust").clone();
        let mut sc = real_scene_at(&env, &b4b, Recipient::Caster, 10, 8).await;
        stand_at(&sc, "rear").await;
        // +10% is within one swing's spread: take enough of each.
        let plain = median_damage(&mut sc, &ws, None, 31).await;
        let mut boosted = Vec::new();
        let mut cost_ok = true;
        for _ in 0..21 {
            end_combo(&sc).await;
            reset_enemy(&sc).await;
            land_self_buff(&mut sc, &b4b).await;
            let (h0, _, _) = pools(&sc, PLAYER).await;
            let o = press(&mut sc, &ws).await;
            let (h1, _, _) = pools(&sc, PLAYER).await;
            if o.damage_main > 0 {
                boosted.push(o.damage_main);
                cost_ok &= h1 < h0;
            }
            if has_status(&sc, PLAYER, b4b.status_id).await && o.damage_main > 0 {
                problems.push("blood_for_blood still on after a weaponskill".into());
                break;
            }
        }
        let b = median(&mut boosted);
        println!("blood_for_blood: {plain} -> {b}");
        if b <= plain || !cost_ok {
            problems.push(format!(
                "blood_for_blood: {plain} -> {b}, HP spent each time: {cost_ok}"
            ));
        }
    }
    // Blindside: the next weaponskill from behind crits.
    {
        let bs = by_name(&env, "blindside").clone();
        let ws = by_name(&env, "pummel").clone();
        let mut sc = real_scene_at(&env, &bs, Recipient::Caster, 14, 2).await;
        stand_at(&sc, "rear").await;
        let plain = median_damage(&mut sc, &ws, None, 15).await;
        let mut v = Vec::new();
        for _ in 0..8 {
            end_combo(&sc).await;
            reset_enemy(&sc).await;
            land_self_buff(&mut sc, &bs).await;
            let o = press(&mut sc, &ws).await;
            if o.damage_main > 0 {
                v.push(o.damage_main);
            }
        }
        let crit = median(&mut v);
        println!("blindside: {plain} -> {crit}");
        // A same-level crit is x1.2 (`calculate_crit_damage`); the plain
        // median already holds some natural crits.
        if crit * 100 < plain * 110 || has_status(&sc, PLAYER, bs.status_id).await {
            problems.push(format!("blindside: {plain} -> {crit}"));
        }
    }
    // Dark Seal goes on the next spell; Parsimony halves it and gives MP;
    // Necrogenesis gives HP.
    {
        let thunder = by_name(&env, "thunder").clone();
        for (name, check) in [("dark_seal", 0), ("parsimony", 1), ("necrogenesis", 2)] {
            let buff = by_name(&env, name).clone();
            let mut sc = real_scene_at(&env, &buff, Recipient::Caster, 14, 22).await;
            reset_enemy(&sc).await;
            // The plain cost.
            let plain = press(&mut sc, &thunder).await;
            land_self_buff(&mut sc, &buff).await;
            let max = sc
                .registry
                .get(PLAYER)
                .await
                .unwrap()
                .character
                .read()
                .await
                .chara
                .max_hp;
            set_hp(&sc, PLAYER, i32::from(max) / 2).await;
            // A partly resisted spell deals damage but is no hit (the
            // `action_landed` rule combos use too), so the buff can wait for
            // the next clean one.
            let mut o = press(&mut sc, &thunder).await;
            for _ in 0..7 {
                if o.damage_main > 0 && !has_status(&sc, PLAYER, buff.status_id).await {
                    break;
                }
                o = press(&mut sc, &thunder).await;
            }
            let still = has_status(&sc, PLAYER, buff.status_id).await;
            match check {
                1 => {
                    println!(
                        "parsimony: thunder net MP {} -> {}",
                        plain.mp_spent, o.mp_spent
                    );
                    if o.mp_spent * 2 > plain.mp_spent + 1 {
                        problems.push(format!(
                            "parsimony: thunder net MP {} -> {}",
                            plain.mp_spent, o.mp_spent
                        ));
                    }
                }
                2 => {
                    let gained = hp(&sc.registry, PLAYER).await - i32::from(max) / 2;
                    println!("necrogenesis: +{gained} HP on a {} hit", o.damage_main);
                    if gained <= 0 {
                        problems.push(format!("necrogenesis: +{gained} HP"));
                    }
                }
                _ => {}
            }
            if still {
                problems.push(format!("{name} still on after a spell"));
            }
        }
    }
    assert!(problems.is_empty(), "status hooks:\n{problems:#?}");
}

/// Monster swings at the player: Featherfoot (evade), Foresight (parry)
/// and Aegis Boon (block) do their thing and go, and the evade / parry /
/// block light up Haymaker, Fracture and Phalanx; the player's own miss
/// lights up Feint. Without the proc those are refused.
#[tokio::test]
async fn battle_behavior_defensive_buffs_and_procs() {
    let env = env().await;
    let mut problems = Vec::new();
    // (buff, class, level, proc weaponskill, how the swing is forced)
    for (buff, class, level, ws, force) in [
        ("featherfoot", 2u8, 18i16, "haymaker", "evade"),
        ("foresight", 4, 18, "fracture", "parry"),
        ("aegis_boon", 3, 6, "phalanx", "block"),
    ] {
        let b = by_name(&env, buff).clone();
        let w = by_name(&env, ws).clone();
        let mut sc = real_scene_at(&env, &w, Recipient::Enemy, level, class).await;
        reset_enemy(&sc).await;
        // Without the proc: refused.
        let o = press(&mut sc, &w).await;
        if !o.errors.contains(&32556) {
            problems.push(format!(
                "{ws} without its proc: {:?}, dmg {}",
                o.errors, o.damage_main
            ));
        }
        land_self_buff(&mut sc, &b).await;
        {
            let h = sc
                .registry
                .get(match force {
                    "evade" => ENEMY,
                    _ => PLAYER,
                })
                .await
                .unwrap();
            let mut c = h.character.write().await;
            match force {
                "evade" => c.chara.mods.set(Modifier::RawHitRate, -100.0),
                "parry" => c.chara.mods.set(Modifier::RawParryRate, 100.0),
                _ => {}
            }
        }
        if force != "evade" {
            // The swing connects and doesn't crit, so the parry or block
            // gets its roll.
            let h = sc.registry.get(ENEMY).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.mods.set(Modifier::RawHitRate, 100.0);
            c.chara.mods.set(Modifier::RawCritRate, -100.0);
        }
        let (h0, m0, _) = pools(&sc, PLAYER).await;
        {
            // Make room in the pools for the buff to give back.
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.hp = c.chara.max_hp / 2;
            c.chara.mp = c.chara.max_mp / 2;
        }
        let (h0b, m0b, _) = pools(&sc, PLAYER).await;
        let _ = (h0, m0);
        crate::runtime::dispatcher::test_auto_attack(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            ENEMY,
            PLAYER,
        )
        .await;
        let (h1, m1, _) = pools(&sc, PLAYER).await;
        let still = has_status(&sc, PLAYER, b.status_id).await;
        println!("{buff}: HP {h0b} -> {h1}, MP {m0b} -> {m1}, still on {still}");
        if still {
            problems.push(format!("{buff} still on after the {force}"));
        }
        if force == "evade" && m1 <= m0b {
            problems.push(format!("featherfoot gave no MP ({m0b} -> {m1})"));
        }
        if force == "block" && h1 < h0b {
            problems.push(format!("aegis_boon: HP {h0b} -> {h1}"));
        }
        let o = press(&mut sc, &w).await;
        if !o.errors.is_empty() {
            problems.push(format!("{ws} after the {force}: refused {:?}", o.errors));
        }
        // The proc is spent.
        let o = press(&mut sc, &w).await;
        if !o.errors.contains(&32556) {
            problems.push(format!("{ws} twice on one {force}: {:?}", o.errors));
        }
    }
    // Feint after the player's own miss.
    {
        let w = by_name(&env, "feint").clone();
        let mut sc = real_scene(&env, &w, Recipient::Enemy).await;
        reset_enemy(&sc).await;
        let o = press(&mut sc, &w).await;
        if !o.errors.contains(&32556) {
            problems.push(format!("feint without a miss: {:?}", o.errors));
        }
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            h.character
                .write()
                .await
                .chara
                .mods
                .set(Modifier::RawHitRate, -100.0);
        }
        crate::runtime::dispatcher::test_auto_attack(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            PLAYER,
            ENEMY,
        )
        .await;
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            h.character
                .write()
                .await
                .chara
                .mods
                .set(Modifier::RawHitRate, 0.0);
        }
        let o = press(&mut sc, &w).await;
        if !o.errors.is_empty() {
            problems.push(format!("feint after a miss: refused {:?}", o.errors));
        }
    }
    assert!(
        problems.is_empty(),
        "defensive buffs and procs:\n{problems:#?}"
    );
}

// ---------------------------------------------------------------------------
// Monster statuses on the player.
// ---------------------------------------------------------------------------

#[tokio::test]
async fn battle_behavior_monster_statuses_on_player() {
    let env = env().await;
    let cmd = by_name(&env, "fast_blade").clone();
    let mut problems = Vec::new();

    // Poison: HP every tick, stops when it wears off.
    {
        let sc = real_scene_at(&env, &cmd, Recipient::Enemy, 10, 3).await;
        give_status(&env, &sc, PLAYER, 223011, 30, 0.0).await;
        let h0 = hp(&sc.registry, PLAYER).await;
        tick_for(&sc, 9_100).await;
        let h1 = hp(&sc.registry, PLAYER).await;
        println!("poison: {h0} -> {h1} over 9 s");
        if h1 >= h0 {
            problems.push(format!("poison: {h0} -> {h1}"));
        }
        clear_status(&sc, PLAYER, 223011).await;
        let h2 = hp(&sc.registry, PLAYER).await;
        tick_for(&sc, 6_100).await;
        if hp(&sc.registry, PLAYER).await < h2 {
            problems.push("poison kept ticking after it wore off".into());
        }
    }
    // Slow: longer swing delay; Heavy: slower run; Bind: no run; Blind:
    // less accuracy. All come back off.
    for (status, name) in [
        (223003u32, "slow"),
        (228021, "heavy"),
        (228011, "bind"),
        (223007, "blind"),
    ] {
        let sc = real_scene_at(&env, &cmd, Recipient::Enemy, 10, 3).await;
        let read = |c: &crate::actor::Character| match name {
            "slow" => f64::from(c.get_attack_delay_ms()),
            "heavy" | "bind" => f64::from(c.speed_sent),
            _ => c.chara.mods.get(Modifier::Accuracy),
        };
        let before = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            if name == "heavy" || name == "bind" {
                1.0
            } else {
                read(&c)
            }
        };
        give_status(&env, &sc, PLAYER, status, 30, 0.0).await;
        let during = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            read(&c)
        };
        clear_status(&sc, PLAYER, status).await;
        let after = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            read(&c)
        };
        println!("{name}: {before} -> {during} -> {after}");
        let ok = match name {
            "slow" => during > before,
            "heavy" => during < before && during > 0.0,
            "bind" => during == 0.0,
            _ => during < before,
        } && (after - before).abs() < 1e-3;
        if !ok {
            problems.push(format!("{name}: {before} -> {during} -> {after}"));
        }
    }
    // Silence refuses spells, Stun everything, Pacification weaponskills.
    for (status, name, cls, lvl, cmd_name) in [
        (223006u32, "silence", 22u8, 1i16, "thunder"),
        (223015, "stun", 3, 1, "fast_blade"),
        (223013, "pacification", 3, 1, "fast_blade"),
    ] {
        let c = by_name(&env, cmd_name).clone();
        let mut sc = real_scene_at(&env, &c, Recipient::Enemy, lvl, cls).await;
        give_status(&env, &sc, PLAYER, status, 30, 0.0).await;
        let o = press(&mut sc, &c).await;
        if !o.errors.contains(&32535) || o.damage_main > 0 {
            problems.push(format!(
                "{name}: {cmd_name} {:?} dmg {}",
                o.errors, o.damage_main
            ));
        }
    }
    // Sleep and Stun stop the player's swings.
    for (status, name) in [(228001u32, "sleep"), (223015, "stun")] {
        let sc = real_scene_at(&env, &cmd, Recipient::Enemy, 10, 3).await;
        reset_enemy(&sc).await;
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let now = crate::runtime::clock::server_now_ms();
            h.character
                .write()
                .await
                .ai_container
                .internal_engage(ENEMY, now, 2500);
        }
        give_status(&env, &sc, PLAYER, status, 30, 0.0).await;
        let e0 = hp(&sc.registry, ENEMY).await;
        tick_for(&sc, 8_000).await;
        let e1 = hp(&sc.registry, ENEMY).await;
        if e1 != e0 {
            problems.push(format!("{name}: the player still swung ({e0} -> {e1})"));
        }
    }
    assert!(
        problems.is_empty(),
        "monster statuses on the player:\n{problems:#?}"
    );
}

async fn enmity_on_enemy(sc: &Scene) -> i32 {
    let h = sc.registry.get(ENEMY).await.unwrap();
    let c = h.character.read().await;
    c.hate.get(PLAYER).map_or(0, |e| e.cumulative_enmity as i32)
}

#[tokio::test]
async fn battle_behavior_toggles_enmity_and_decoy() {
    let env = env().await;
    let mut problems = Vec::new();

    // Raging Strike, Cleric Stance: on, then off on reuse.
    for (name, level, class) in [("raging_strike", 14, 7), ("cleric_stance", 10, 23)] {
        let cmd = by_name(&env, name).clone();
        let mut sc = real_scene_at(&env, &cmd, Recipient::Caster, level, class).await;
        land_self_buff(&mut sc, &cmd).await;
        let o = press(&mut sc, &cmd).await;
        let on = has_status(&sc, PLAYER, cmd.status_id).await;
        println!("{name}: reuse errors {:?}, still on {on}", o.errors);
        if on {
            problems.push(format!("{name}: reuse did not end it"));
        }
    }

    // Raging Strike: each Light Shot hit adds a stack (tier), up to 3.
    {
        let rs = by_name(&env, "raging_strike").clone();
        let ls = by_name(&env, "light_shot").clone();
        let mut sc = real_scene_at(&env, &rs, Recipient::Enemy, 14, 7).await;
        reset_enemy(&sc).await;
        let atk0 = mod_of(&sc, PLAYER, Modifier::Attack).await;
        land_self_buff(&mut sc, &rs).await;
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.mods.set(Modifier::RawHitRate, 100.0);
        }
        for _ in 0..5 {
            press(&mut sc, &ls).await;
        }
        let tier = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            c.status_effects.get(rs.status_id).map(|e| e.tier)
        };
        let atk3 = mod_of(&sc, PLAYER, Modifier::Attack).await;
        // Any missed attack (here a Heavy Shot, not a Light Shot) ends
        // the effect and its stacks (1.20 notes).
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.mods.set(Modifier::RawHitRate, -100.0);
        }
        let hs = by_name(&env, "heavy_shot").clone();
        press(&mut sc, &hs).await;
        let atk_miss = mod_of(&sc, PLAYER, Modifier::Attack).await;
        if has_status(&sc, PLAYER, rs.status_id).await {
            problems.push("raging_strike survived a missed heavy_shot".to_string());
        }
        println!(
            "raging_strike: tier after 5 light shots {tier:?}, attack {atk0} -> {atk3} -> {atk_miss} after a miss"
        );
        // Lands at tier 1; three stacks make tier 4.
        if tier != Some(4) {
            problems.push(format!("raging_strike stacks: {tier:?}"));
        }
        // +10% a stack (RAGING_STRIKE_ATTACK_PER_STACK), three stacks.
        let want = 3.0 * (0.1 * atk0).round().max(1.0);
        if (atk3 - atk0 - want).abs() > 1.0 || (atk_miss - atk0).abs() > 0.5 {
            problems.push(format!(
                "raging_strike attack {atk0} -> {atk3} (want +{want}) -> {atk_miss} after a miss"
            ));
        }
    }

    // Enhanced Raging Strike (ARC 36 trait 27243): the effect is x1.5.
    for (level, want) in [(14i16, 100.0), (36, 150.0)] {
        let rs = by_name(&env, "raging_strike").clone();
        let mut sc = real_scene_at(&env, &rs, Recipient::Caster, level, 7).await;
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            c.traits = if level >= 36 { vec![27243] } else { Vec::new() };
        }
        land_self_buff(&mut sc, &rs).await;
        let mag = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            c.status_effects.get(rs.status_id).map(|e| e.magnitude)
        };
        println!("raging_strike at ARC {level}: magnitude {mag:?}");
        if mag != Some(want) {
            problems.push(format!(
                "raging_strike at ARC {level}: magnitude {mag:?}, want {want}"
            ));
        }
    }

    // Blissful Mind: costs a quarter of HP, stores MP, pays it on reuse.
    {
        let bm = by_name(&env, "blissful_mind").clone();
        let mut sc = real_scene_at(&env, &bm, Recipient::Caster, 14, 23).await;
        let (hp0, _, _) = pools(&sc, PLAYER).await;
        land_self_buff(&mut sc, &bm).await;
        let (hp1, _, _) = pools(&sc, PLAYER).await;
        // Effects tick on the wall clock: rewind the last tick, 12 times.
        for _ in 0..12 {
            {
                let h = sc.registry.get(PLAYER).await.unwrap();
                let mut c = h.character.write().await;
                if let Some(e) = c.status_effects.get_mut(bm.status_id) {
                    e.last_tick_ms = 0;
                }
            }
            tick_for(&sc, 100).await;
        }
        let stored = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.mp = 0;
            c.status_effects
                .get(bm.status_id)
                .or_else(|| c.status_effects.get(223242))
                .map_or(0.0, |e| e.extra)
        };
        // Resolve the reuse directly: a hotbar press would refill MP first.
        crate::runtime::dispatcher::test_resolve(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            PLAYER,
            PLAYER,
            &bm.to_battle_command(),
        )
        .await;
        let (_, mp2, _) = pools(&sc, PLAYER).await;
        let on =
            has_status(&sc, PLAYER, bm.status_id).await || has_status(&sc, PLAYER, 223242).await;
        println!(
            "blissful_mind: HP {hp0} -> {hp1}, stored {stored:.1} MP, paid {mp2}, still on {on}"
        );
        if hp1 * 100 > hp0 * 85 || on || stored < 1.0 || mp2 < stored as i32 - 1 {
            problems.push(format!(
                "blissful_mind: HP {hp0} -> {hp1}, stored {stored:.1}, paid {mp2}, still on {on}"
            ));
        }
    }

    // Provoke and Flash draw enmity without damage.
    for (name, level, class) in [("provoke", 14, 4), ("flash", 14, 3)] {
        let cmd = by_name(&env, name).clone();
        let mut sc = real_scene_at(&env, &cmd, Recipient::Enemy, level, class).await;
        reset_enemy(&sc).await;
        let before = enmity_on_enemy(&sc).await;
        let o = press(&mut sc, &cmd).await;
        let after = enmity_on_enemy(&sc).await;
        println!("{name}: enmity {before} -> {after} {:?}", o.errors);
        if after <= before {
            problems.push(format!("{name}: enmity {before} -> {after}"));
        }
    }

    // Decoy: the next magic attack on the player misses; Decoy goes.
    {
        let decoy = by_name(&env, "decoy").clone();
        let thunder = by_name(&env, "thunder").clone();
        let mut sc = real_scene_at(&env, &decoy, Recipient::Caster, 10, 7).await;
        hostile_enemy(&sc, 3.0).await;
        land_self_buff(&mut sc, &decoy).await;
        let before = hp(&sc.registry, PLAYER).await;
        crate::runtime::dispatcher::test_resolve(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            ENEMY,
            PLAYER,
            &thunder.to_battle_command(),
        )
        .await;
        let after = hp(&sc.registry, PLAYER).await;
        let on = has_status(&sc, PLAYER, decoy.status_id).await;
        println!("decoy: HP {before} -> {after}, still on {on}");
        if after < before || on {
            problems.push(format!("decoy: HP {before} -> {after}, still on {on}"));
        }
    }

    assert!(
        problems.is_empty(),
        "toggles, enmity and decoy:\n{problems:#?}"
    );
}

// ---------------------------------------------------------------------------
// Balance: auto-attacks both ways against the retail 1.23b captures.
// ---------------------------------------------------------------------------

/// Put a monster at `level` with the live spawn's fallback stats.
async fn set_mob_level(sc: &Scene, level: i16) {
    let h = sc.registry.get(ENEMY).await.unwrap();
    let mut c = h.character.write().await;
    c.chara.level = level;
    for (m, v) in crate::battle::utils::monster_melee_stats(level) {
        c.chara.mods.set(m, v);
    }
}

/// Median HP an auto-attack from `from` takes off `to` over `n` swings
/// that connect without a crit, block or parry.
async fn autos(sc: &Scene, env: &Env, from: u32, to: u32, n: usize) -> i32 {
    let rates = [
        Modifier::RawHitRate,
        Modifier::RawCritRate,
        Modifier::RawParryRate,
        Modifier::RawBlockRate,
    ];
    for id in [from, to] {
        let h = sc.registry.get(id).await.unwrap();
        let mut c = h.character.write().await;
        if id == from {
            c.chara.mods.set(Modifier::RawHitRate, 100.0);
            c.chara.mods.set(Modifier::RawCritRate, -100.0);
        } else {
            c.chara.mods.set(Modifier::RawParryRate, -100.0);
            c.chara.mods.set(Modifier::RawBlockRate, -100.0);
        }
    }
    let mut v = Vec::new();
    for _ in 0..n {
        {
            let h = sc.registry.get(to).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.max_hp = 30000;
            c.chara.hp = 30000;
        }
        Box::pin(crate::runtime::dispatcher::test_auto_attack(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            from,
            to,
        ))
        .await;
        v.push(30000 - hp(&sc.registry, to).await);
    }
    for id in [from, to] {
        let h = sc.registry.get(id).await.unwrap();
        let mut c = h.character.write().await;
        for m in rates {
            c.chara.mods.set(m, 0.0);
        }
    }
    median(&mut v)
}

/// Same-level fights at 1-20 for every class: a player's swing takes 5-15%
/// of the monster's HP and the monster's swing 4-10% of the player's, so no
/// side ends a fight in a few hits. Retail anchors (party_battle_leve
/// capture): a level 27 gladiator swung 18-23 on level 30 monsters and took
/// 56-63 from them; player HP was 126 at level 3, 148 at 5 and 758 at 26.
#[tokio::test]
async fn battle_balance_auto_attacks() {
    let env = env().await;
    let cmds = l20_commands(&env);
    let mut problems = Vec::new();
    for (level, want) in [(3i16, 126.0), (5, 148.0), (26, 758.0)] {
        let got = crate::battle::utils::player_base_hp(level);
        if (got - want).abs() > want * 0.05 {
            problems.push(format!("player HP at {level}: {got}, retail {want}"));
        }
    }
    println!("\ncls lvl mob  pHP mobHP p->m m->p  p%mob   m%p");
    for class in CLASSES {
        let cmd = cmds.iter().find(|c| c.job == class).unwrap().clone();
        for (lvl, mlvl) in [
            (1i16, 1i16),
            (5, 5),
            (10, 10),
            (15, 15),
            (20, 20),
            (27, 30),
            (30, 30),
            (35, 35),
            (40, 40),
            (45, 45),
            (50, 50),
        ] {
            let sc = real_scene_at(&env, &cmd, Recipient::Enemy, lvl, class).await;
            set_mob_level(&sc, mlvl).await;
            let php = {
                let h = sc.registry.get(PLAYER).await.unwrap();
                i32::from(h.character.read().await.chara.max_hp)
            };
            let pm = autos(&sc, &env, PLAYER, ENEMY, 9).await;
            let mp = autos(&sc, &env, ENEMY, PLAYER, 9).await;
            let mobhp = mob_hp(mlvl);
            let (p_share, m_share) = (
                f64::from(pm) / f64::from(mobhp),
                f64::from(mp) / f64::from(php),
            );
            println!(
                "{class:>3} {lvl:>3} {mlvl:>3} {php:>4} {mobhp:>5} {pm:>4} {mp:>4} {:>5.1}% {:>5.1}%",
                100.0 * p_share,
                100.0 * m_share
            );
            // Retail monster HP climbs fast from 40 and these players wear
            // no armor: 3% is the floor there.
            let p_floor = if lvl >= 40 { 0.03 } else { 0.05 };
            if lvl == mlvl {
                if !(p_floor..=0.15).contains(&p_share) {
                    problems.push(format!(
                        "class {class} L{lvl}: swing {pm} = {:.0}% of the monster's {mobhp}",
                        100.0 * p_share
                    ));
                }
                if !(0.04..=0.10).contains(&m_share) {
                    problems.push(format!(
                        "class {class} L{lvl}: monster swing {mp} = {:.0}% of {php} HP",
                        100.0 * m_share
                    ));
                }
            } else if class == 3 {
                if !(14..=26).contains(&pm) {
                    problems.push(format!("L27 GLA on a L30 monster: {pm}, retail 18-23"));
                }
                if !(45..=80).contains(&mp) {
                    problems.push(format!("L30 monster on a L27 GLA: {mp}, retail 56-63"));
                }
            }
        }
    }
    assert!(problems.is_empty(), "balance:\n{problems:#?}");
}

/// Every level 21-50 command's status: its stat changes go on when it
/// lands and all come off when it ends (none left behind). A self status is
/// landed by pressing the command, so the command script sizes it; a stance
/// (no timer) is ended by pressing it again, anything else by expiry. Prints
/// what each one changes.
#[tokio::test]
async fn battle_behavior_l21_50_statuses_revert() {
    // Set by the engine, not the status: MovementSpeed gets the default run
    // speed before a speed effect multiplies it, HitCount by a swing.
    const ENGINE_SET: [u32; 2] = [61, 119];
    let env = env().await;
    let mut problems = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for cmd in band_commands(&env, 21, 50) {
        if cmd.status_id == 0 || !seen.insert(cmd.status_id) {
            continue;
        }
        let rcpt = recipient(&cmd);
        let mut sc = real_scene(&env, &cmd, rcpt).await;
        reset_enemy(&sc).await;
        let rid = super::battle_audit_tests::status_recipient_id(&cmd, rcpt);
        let snapshot = |c: &crate::actor::Character| {
            let mut v: Vec<(u32, f64)> = c
                .chara
                .mods
                .iter()
                .filter(|(k, x)| *x != 0.0 && !ENGINE_SET.contains(k))
                .collect();
            v.sort_by_key(|(k, _)| *k);
            v
        };
        let before = snapshot(&*sc.registry.get(rid).await.unwrap().character.read().await);
        let by_press = rid == PLAYER && cmd.proc_requirement == 0;
        if by_press {
            for _ in 0..6 {
                {
                    let h = sc.registry.get(PLAYER).await.unwrap();
                    let mut c = h.character.write().await;
                    for e in c.chara.hotbar.iter_mut() {
                        e.recast_time = 0;
                    }
                }
                press(&mut sc, &cmd).await;
                if has_status(&sc, PLAYER, cmd.status_id).await {
                    break;
                }
            }
        } else {
            let bc = cmd.to_battle_command();
            give_status(&env, &sc, rid, cmd.status_id, 30, bc.status_magnitude).await;
        }
        let (on, stance, during) = {
            let h = sc.registry.get(rid).await.unwrap();
            let c = h.character.read().await;
            let e = c.status_effects.get(cmd.status_id);
            (e.is_some(), e.is_some_and(|e| e.is_stance()), snapshot(&c))
        };
        if stance && by_press {
            {
                let h = sc.registry.get(PLAYER).await.unwrap();
                let mut c = h.character.write().await;
                for e in c.chara.hotbar.iter_mut() {
                    e.recast_time = 0;
                }
            }
            press(&mut sc, &cmd).await;
        } else {
            clear_status(&sc, rid, cmd.status_id).await;
        }
        let still_on = has_status(&sc, rid, cmd.status_id).await;
        let after = snapshot(&*sc.registry.get(rid).await.unwrap().character.read().await);
        let changed: Vec<(u32, f64)> = during
            .iter()
            .filter(|(k, v)| before.iter().find(|(b, _)| b == k).map(|(_, x)| x) != Some(v))
            .copied()
            .collect();
        println!(
            "{:<18} status {} on={on} stance={stance} changes {changed:?}",
            cmd.name, cmd.status_id
        );
        if !on {
            problems.push(format!("{} status {} didn't land", cmd.name, cmd.status_id));
            continue;
        }
        if still_on {
            problems.push(format!("{} status {} didn't end", cmd.name, cmd.status_id));
        }
        // An ally's stats load on its first update, so there is nothing
        // before to compare with; its statuses here (Cover, Collusion) are
        // hooks only, so nothing may change while it's on.
        let leftover = if before.is_empty() {
            after != during
        } else {
            after != before
        };
        if leftover {
            problems.push(format!(
                "{} status {}: mods {before:?} -> {after:?} after it ended",
                cmd.name, cmd.status_id
            ));
        }
    }
    assert!(problems.is_empty(), "level 21-50 statuses:\n{problems:#?}");
}

/// Every proc-gated command at 21-50 (War Drum, Overpower, Full Thrust...):
/// refused without its evade/block/parry/miss, allowed once with it.
#[tokio::test]
async fn battle_behavior_l21_50_procs() {
    let env = env().await;
    let mut problems = Vec::new();
    for cmd in band_commands(&env, 21, 50) {
        if cmd.proc_requirement == 0 {
            continue;
        }
        let mut sc = real_scene(&env, &cmd, Recipient::Enemy).await;
        reset_enemy(&sc).await;
        if cmd.requirements & 16 != 0 {
            let h = sc.registry.get(PLAYER).await.unwrap();
            h.character
                .write()
                .await
                .chara
                .mods
                .set(Modifier::CanBlock, 1.0);
        }
        let without = press(&mut sc, &cmd).await;
        crate::runtime::dispatcher::test_open_proc(
            &sc.registry,
            &sc.processor.world,
            sc.processor.lua.as_ref(),
            Some(&sc.processor.db),
            PLAYER,
            cmd.proc_requirement,
        )
        .await;
        {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let mut c = h.character.write().await;
            for e in c.chara.hotbar.iter_mut() {
                e.recast_time = 0;
            }
        }
        let with = press(&mut sc, &cmd).await;
        println!(
            "{} (proc {}): without {:?}, with {:?} dmg {}",
            cmd.name, cmd.proc_requirement, without.errors, with.errors, with.damage_main
        );
        if !without.errors.contains(&32556) {
            problems.push(format!(
                "{} without its proc: {:?}",
                cmd.name, without.errors
            ));
        }
        if !with.errors.is_empty() {
            problems.push(format!("{} with its proc: {:?}", cmd.name, with.errors));
        }
    }
    assert!(problems.is_empty(), "level 21-50 procs:\n{problems:#?}");
}

/// Rage of Halone (GLA 46, five hits at -40% accuracy outside its combo):
/// alone, after Riot Blade, and with every hit forced, next to the other
/// level 46-50 gladiator weaponskills.
#[tokio::test]
async fn battle_behavior_rage_of_halone() {
    let env = env().await;
    let roh = by_name(&env, "rage_of_halone").clone();
    let riot = by_name(&env, "riot_blade").clone();
    let goring = by_name(&env, "goring_blade").clone();
    let spirits = by_name(&env, "spirits_within").clone();
    let mut sc = real_scene_at(&env, &roh, Recipient::Enemy, 50, 3).await;
    // From the rear (no parry or block). `alone` keeps its misses (that is
    // what it shows); the rest is compared with every hit landing and no
    // crits, so only the ±4% damage roll is left: misses and crits across
    // 15 presses moved the medians enough to fail CI now and then
    // (combo 298 vs Goring Blade 379).
    stand_at(&sc, "rear").await;
    let alone = median_damage(&mut sc, &roh, None, 15).await;
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.mods.set(Modifier::RawHitRate, 100.0);
        c.chara.mods.set(Modifier::RawCritRate, -100.0);
    }
    let combo = median_damage(&mut sc, &roh, Some(&riot), 15).await;
    let goring_d = median_damage(&mut sc, &goring, None, 15).await;
    let spirits_d = median_damage(&mut sc, &spirits, None, 15).await;
    let forced = median_damage(&mut sc, &roh, None, 15).await;
    let hp = mob_hp(50);
    println!(
        "L50 GLA vs L50 ({hp} HP): rage_of_halone alone {alone}, after riot_blade {combo}, all hits {forced}; goring_blade {goring_d}, spirits_within {spirits_d}"
    );
    assert!(
        f64::from(combo) >= 0.8 * f64::from(goring_d),
        "Rage of Halone in combo {combo} vs Goring Blade {goring_d}"
    );
}

/// TP above a weaponskill's cost adds WS_BONUS_PER_1000_TP_OVER_COST per
/// 1000 (Heavy Swing, 1000 TP: ×1.10 at 3000).
#[tokio::test]
async fn battle_behavior_ws_tp_surplus() {
    let env = env().await;
    let ws = by_name(&env, "heavy_swing").clone();
    let mut sc = real_scene_at(&env, &ws, Recipient::Enemy, 20, 4).await;
    // From the rear (no parry or block) and with no crits, only the ±4%
    // damage roll is left: parries and crits in some of the 21 presses
    // moved the median enough to fail CI now and then.
    stand_at(&sc, "rear").await;
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.mods.set(Modifier::RawHitRate, 100.0);
        c.chara.mods.set(Modifier::RawCritRate, -100.0);
    }
    let low = median_at_tp(&mut sc, &ws, 1000).await;
    let high = median_at_tp(&mut sc, &ws, 3000).await;
    let r = f64::from(high) / f64::from(low.max(1));
    println!("heavy_swing at 1000 TP {low}, at 3000 TP {high} ({r:.3}x)");
    let want = crate::runtime::dispatcher::ws_tp_bonus(2000);
    assert!(
        (r - want).abs() < 0.04,
        "TP surplus ratio {r:.3}, want {want:.3}"
    );
}

async fn median_at_tp(sc: &mut Scene, ws: &BattleCommand, tp: u16) -> i32 {
    let mut v = Vec::new();
    for _ in 0..21 {
        reset_enemy(sc).await;
        let o = press_at_tp(sc, ws, tp).await;
        if o.damage_main > 0 {
            v.push(o.damage_main);
        }
    }
    median(&mut v)
}

async fn press_at_tp(
    sc: &mut Scene,
    cmd: &BattleCommand,
    tp: u16,
) -> super::battle_audit_tests::Outcome {
    sc.press_tp = tp;
    let o = press(sc, cmd).await;
    sc.press_tp = 3000;
    o
}

/// The player's hit rate on the enemy as a swing computes it (the real
/// characters' mods and status share, `get_hit_rate`).
async fn player_hit_rate(sc: &Scene) -> f64 {
    let (p, e) = (
        sc.registry.get(PLAYER).await.unwrap(),
        sc.registry.get(ENEMY).await.unwrap(),
    );
    let (p, e) = (p.character.read().await, e.character.read().await);
    let (pm, ps, em, es) = (
        p.chara.mods.clone(),
        p.bonus_mod_totals(),
        e.chara.mods.clone(),
        e.bonus_mod_totals(),
    );
    let view = |id, c: &crate::actor::Character, mods, status| crate::battle::utils::CombatView {
        actor_id: id,
        level: c.chara.level,
        max_hp: c.chara.max_hp,
        mods,
        status,
        has_aegis_boon: false,
        has_protect: false,
        has_shell: false,
        has_stoneskin: false,
    };
    crate::battle::utils::get_hit_rate(
        &view(PLAYER, &p, &pm, &ps),
        &view(ENEMY, &e, &em, &es),
        None,
    )
}

/// Share of `n` player swings on the enemy that land.
async fn player_hit_share(env: &Env, sc: &Scene, n: usize) -> f64 {
    let mut hits = 0;
    for _ in 0..n {
        {
            let h = sc.registry.get(ENEMY).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.max_hp = 30000;
            c.chara.hp = 30000;
        }
        Box::pin(crate::runtime::dispatcher::test_auto_attack(
            &sc.registry,
            &sc.processor.world,
            Some(&env.lua),
            Some(&env.db),
            super::battle_audit_tests::ZONE,
            PLAYER,
            ENEMY,
        ))
        .await;
        if hp(&sc.registry, ENEMY).await < 30000 {
            hits += 1;
        }
    }
    hits as f64 / n as f64
}

/// The monster statuses a player meets, at a level in every band: what
/// each really changes for the player (swing timing, run speed, landed
/// swings, refused commands, HP), and that it all comes back after.
#[tokio::test]
async fn battle_behavior_monster_statuses_every_band() {
    const POISON: u32 = 223011;
    const SLOW: u32 = 223003;
    const HEAVY: u32 = 228021;
    const BLIND: u32 = 223007;
    const PARALYSIS: u32 = 223005;
    const SILENCE: u32 = 223006;
    const SLEEP: u32 = 228001;
    let env = env().await;
    let fast_blade = by_name(&env, "fast_blade").clone();
    let thunder = by_name(&env, "thunder").clone();
    let mut problems = Vec::new();
    for level in [10i16, 25, 35, 45] {
        let mut sc = real_scene_at(&env, &fast_blade, Recipient::Enemy, level, 3).await;
        reset_enemy(&sc).await;
        // Poison: HP each tick; none once it ends.
        {
            give_status(&env, &sc, PLAYER, POISON, 30, 0.0).await;
            let h0 = hp(&sc.registry, PLAYER).await;
            tick_for(&sc, 9_100).await;
            let h1 = hp(&sc.registry, PLAYER).await;
            clear_status(&sc, PLAYER, POISON).await;
            tick_for(&sc, 6_100).await;
            let h2 = hp(&sc.registry, PLAYER).await;
            println!("L{level} poison: {h0} -> {h1}, then {h2}");
            if h1 >= h0 || h2 < h1 {
                problems.push(format!("L{level} poison: {h0} -> {h1} -> {h2}"));
            }
        }
        // Slow: a longer swing delay. Heavy: a slower run.
        {
            let delay = |sc: &Scene| {
                let registry = sc.registry.clone();
                async move {
                    let h = registry.get(PLAYER).await.unwrap();
                    let c = h.character.read().await;
                    (c.get_attack_delay_ms(), c.speed_sent)
                }
            };
            let (d0, _) = delay(&sc).await;
            give_status(&env, &sc, PLAYER, SLOW, 30, 0.0).await;
            let (d1, _) = delay(&sc).await;
            clear_status(&sc, PLAYER, SLOW).await;
            give_status(&env, &sc, PLAYER, HEAVY, 30, 0.0).await;
            let (_, s1) = delay(&sc).await;
            clear_status(&sc, PLAYER, HEAVY).await;
            let (d2, s2) = delay(&sc).await;
            println!("L{level} slow: delay {d0} -> {d1} -> {d2}; heavy: speed {s1} -> {s2}");
            if d1 <= d0 || d2 != d0 || !(s1 > 0.0 && s1 < 1.0) || (s2 - 1.0).abs() > 1e-3 {
                problems.push(format!("L{level} slow {d0}/{d1}/{d2} heavy {s1}/{s2}"));
            }
        }
        // Blind: a lower hit rate (by its Accuracy down, 0.5% a point; the
        // status takes the level as its size). Paralysis: a quarter of the
        // swings and weaponskills fail.
        {
            let base = player_hit_rate(&sc).await;
            give_status(&env, &sc, PLAYER, BLIND, 60, 0.0).await;
            let blind = player_hit_rate(&sc).await;
            clear_status(&sc, PLAYER, BLIND).await;
            let after = player_hit_rate(&sc).await;
            let want = crate::battle::utils::HIT_RATE_PER_ACCURACY * f64::from(level);
            println!("L{level} hit rate {base:.1} -> blind {blind:.1} -> {after:.1}");
            if (base - blind - want).abs() > 1.0 && blind > 0.0 || after != base {
                problems.push(format!(
                    "L{level} blind: hit rate {base:.1} -> {blind:.1} (want -{want}) -> {after:.1}"
                ));
            }
            {
                let h = sc.registry.get(PLAYER).await.unwrap();
                h.character
                    .write()
                    .await
                    .chara
                    .mods
                    .set(Modifier::RawHitRate, 100.0);
            }
            give_status(&env, &sc, PLAYER, PARALYSIS, 60, 0.0).await;
            let para = player_hit_share(&env, &sc, 200).await;
            // 80 tries (about 20 fail): a 40-try sample fell under its
            // floor about once in 250 runs.
            let mut ws_fails = 0;
            for _ in 0..80 {
                reset_enemy(&sc).await;
                let o = press(&mut sc, &fast_blade).await;
                if o.errors.is_empty() && o.damage_main <= 0 {
                    ws_fails += 1;
                }
            }
            clear_status(&sc, PLAYER, PARALYSIS).await;
            let clean = player_hit_share(&env, &sc, 50).await;
            {
                let h = sc.registry.get(PLAYER).await.unwrap();
                h.character
                    .write()
                    .await
                    .chara
                    .mods
                    .set(Modifier::RawHitRate, 0.0);
            }
            println!(
                "L{level} paralysis: {para:.2} of sure swings land, {ws_fails}/80 WS fail, {clean:.2} after"
            );
            if !(0.6..=0.9).contains(&para) || !(6..=34).contains(&ws_fails) || clean < 0.99 {
                problems.push(format!(
                    "L{level} paralysis: {para:.2} land, WS fails {ws_fails}/80, after {clean:.2}"
                ));
            }
        }
        // Silence: no spells (a thaumaturge). Sleep: no swings, no commands.
        {
            let mut cs = real_scene_at(&env, &thunder, Recipient::Enemy, level, 22).await;
            give_status(&env, &cs, PLAYER, SILENCE, 30, 0.0).await;
            let o = press(&mut cs, &thunder).await;
            if !o.errors.contains(&32535) || o.damage_main > 0 {
                problems.push(format!(
                    "L{level} silence: {:?} dmg {}",
                    o.errors, o.damage_main
                ));
            }
            clear_status(&cs, PLAYER, SILENCE).await;
            let o = press(&mut cs, &thunder).await;
            if !o.errors.is_empty() {
                problems.push(format!("L{level} after silence: {:?}", o.errors));
            }
        }
        {
            reset_enemy(&sc).await;
            give_status(&env, &sc, PLAYER, SLEEP, 30, 0.0).await;
            let o = press(&mut sc, &fast_blade).await;
            {
                let h = sc.registry.get(PLAYER).await.unwrap();
                let now = crate::runtime::clock::server_now_ms();
                h.character
                    .write()
                    .await
                    .ai_container
                    .internal_engage(ENEMY, now, 2500);
            }
            let e0 = hp(&sc.registry, ENEMY).await;
            tick_for(&sc, 8_000).await;
            let e1 = hp(&sc.registry, ENEMY).await;
            println!("L{level} sleep: WS {:?}, enemy HP {e0} -> {e1}", o.errors);
            if !o.errors.contains(&32535) || e1 != e0 {
                problems.push(format!(
                    "L{level} sleep: WS {:?}, swings {e0} -> {e1}",
                    o.errors
                ));
            }
        }
    }
    assert!(
        problems.is_empty(),
        "monster statuses by band:\n{problems:#?}"
    );
}
