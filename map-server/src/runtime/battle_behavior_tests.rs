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

/// HP of a level-`level` monster in `server_battlenpc_groups` (median by
/// level: 80 at 1, 210 at 10, 410 at 20).
fn mob_hp(level: i16) -> i32 {
    80 + 16 * i32::from(level)
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
        ],
        3 => &[(1, 4030010), (7, 4030001), (10, 4030706), (18, 4030006)],
        4 => &[
            (1, 4040001),
            (5, 4040004),
            (10, 4040007),
            (15, 4040009),
            (20, 4040010),
        ],
        7 => &[(1, 4070001), (8, 4070204), (16, 4070010), (19, 4070208)],
        8 => &[
            (1, 4080201),
            (8, 4080205),
            (12, 4080008),
            (16, 4080206),
            (20, 4080104),
        ],
        22 => &[(1, 5020001), (5, 5020106), (12, 5020108), (15, 5020102)],
        _ => &[(1, 5030101), (6, 5030102), (11, 5030103), (17, 5030107)],
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
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        c.chara.level = level;
        c.chara.class = i16::from(class);
    }
    // Real gear in the DB, so every stat rebuild (status gain/loss) keeps it.
    let _ = env.db.unequip_item(PLAYER, class, 0).await;
    let _ = env.db.unequip_item(PLAYER, class, 1).await;
    let w = env
        .db
        .create_item(weapon_for(class, level), 1, 1, None)
        .await
        .unwrap();
    env.db
        .equip_item(
            PLAYER,
            class,
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
                class,
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
        let l = f64::from(level);
        c.chara.mods.set(Modifier::Strength, 5.0 + 2.0 * l);
        c.chara.mods.set(Modifier::Attack, 2.0 + l);
        c.chara.mods.set(Modifier::WeaponDamagePower, 2.0 + l);
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
    let mut v: Vec<BattleCommand> = env
        .catalog
        .values()
        .filter(|c| CLASSES.contains(&c.job) && c.level <= 20)
        .cloned()
        .collect();
    v.sort_by_key(|c| (c.job, c.level, c.id));
    v
}

/// Damage, healing, costs, recast and status duration for every level
/// 1-20 command, with the real stat pipeline. Prints a table.
#[tokio::test]
async fn battle_behavior_l20_numbers() {
    let env = env().await;
    let cmds = l20_commands(&env);
    assert_eq!(cmds.len(), 51, "level 1-20 commands of the seven classes");
    let mut problems = Vec::new();
    println!(
        "\n{:<6} {:<18} {:>3} {:>3} {:>7} {:>6} {:>6} {:>5} {:>5} {:>5} {:>6}",
        "id", "name", "cls", "lvl", "median", "share", "mp", "tp", "rec", "dur", "mobhp"
    );
    for cmd in &cmds {
        let rcpt = recipient(cmd);
        let mut sc = real_scene(&env, cmd, rcpt).await;
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
            // A weaponskill or attack spell takes 4-200% of a same-level
            // monster. (Low-level weaponskills one-shot: the multipliers
            // are fitted to level 26 captures; see battle-1-20.md.)
            if !(0.04..=2.0).contains(&share) {
                problems.push(format!(
                    "{} dmg median {med} = {:.0}% of a level {level} monster ({})",
                    cmd.name,
                    share * 100.0,
                    mob_hp(level)
                ));
            }
        }
        if cmd.action_type == 3 && !(0.05..=0.70).contains(&share) {
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
    assert!(problems.is_empty(), "level 1-20 numbers:\n{problems:#?}");
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
        ("pummel", "front", "rear", 1.15),
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
        let skill = catalog
            .values()
            .find(|c| {
                c.job == 0
                    && c.action_type == 1
                    && c.id >= 23000
                    && c.aoe_type == 0
                    && c.status_id == 0
            })
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
        land_self_buff(&mut sc, &rs).await;
        for _ in 0..5 {
            press(&mut sc, &ls).await;
        }
        let tier = {
            let h = sc.registry.get(PLAYER).await.unwrap();
            let c = h.character.read().await;
            c.status_effects.get(rs.status_id).map(|e| e.tier)
        };
        println!("raging_strike: tier after 5 light shots {tier:?}");
        if !matches!(tier, Some(2..=3)) {
            problems.push(format!("raging_strike stacks: {tier:?}"));
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
