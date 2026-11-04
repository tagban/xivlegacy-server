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

//! Battle-command audit harness. Every row of `server_battle_commands`
//! (the real seed) is pressed through the live hotbar path — EventStart
//! `commandDefault` → `dispatch_hotbar_command` → battle state → ticker →
//! `resolve_action` — by a player against dummy actors, and the outcome is
//! checked against what the row says it should do (damage, heal, status,
//! revive). Static checks (Lua script, status ids, effect scripts, combo
//! links, costs) ride along. Run with
//!
//! ```sh
//! cargo test -p map-server battle_command_audit -- --nocapture
//! ```
//!
//! to print the per-command table. The test fails when a command that is
//! not on the known-gap list stops working.

#![cfg(test)]

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use tokio::sync::mpsc;

use crate::actor::Character;
use crate::data::ClientHandle;
use crate::gamedata::BattleCommand;
use crate::runtime::actor_registry::{ActorHandle, ActorKindTag, ActorRegistry};
use crate::runtime::ticker::{GameTicker, TickerConfig};
use crate::world_manager::WorldManager;
use crate::zone::area::{ActorKind, StoredActor};
use crate::zone::navmesh::StubNavmeshLoader;
use crate::zone::outbox::AreaOutbox;
use crate::zone::zone::Zone;
use common::Vector3;
use common::luaparam::LuaParam;

const PLAYER: u32 = 1;
const ENEMY: u32 = 2;
const ENEMY2: u32 = 3;
const FRIEND: u32 = 4;
const PLAYER_SESSION: u32 = 42;
const FRIEND_SESSION: u32 = 43;
const ZONE: u32 = 100;
const ENEMY_HP: i16 = 5000;
const PLAYER_HP: i16 = 2000;

fn tempdb() -> String {
    common::test_db::fresh_blocking()
}

fn script_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../scripts/lua")
}

/// Who the row says the command lands on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Recipient {
    /// The player themself (self-only buffs, and friendly spells pressed
    /// with an enemy selected).
    Caster,
    Enemy,
    /// Another (living) player — Cover / Collusion style.
    Friend,
    /// A KO'd player — Raise.
    DeadFriend,
}

fn recipient(cmd: &BattleCommand) -> Recipient {
    use crate::battle::target_find::ValidTarget as V;
    let mt = V(cmd.main_target);
    if mt.intersects(V::SELF_ONLY) {
        Recipient::Caster
    } else if mt.intersects(V::ENEMY) {
        Recipient::Enemy
    } else if mt.intersects(V::CORPSE_ONLY) {
        Recipient::DeadFriend
    } else if mt.intersects(V::SELF) {
        Recipient::Caster
    } else {
        Recipient::Friend
    }
}

/// Who carries the row's status: offensive rows put it on the monsters
/// they hit (Flare and Holy center on the caster but debuff enemies).
fn status_recipient_id(cmd: &BattleCommand, r: Recipient) -> u32 {
    use crate::battle::target_find::ValidTarget as V;
    if V(cmd.valid_target).intersects(V::ENEMY) {
        ENEMY
    } else {
        recipient_id(r)
    }
}

fn recipient_id(r: Recipient) -> u32 {
    match r {
        Recipient::Caster => PLAYER,
        Recipient::Enemy => ENEMY,
        Recipient::Friend | Recipient::DeadFriend => FRIEND,
    }
}

fn folder_for(cmd: &BattleCommand) -> &'static str {
    match cmd.command_type {
        2 => "weaponskill",
        3 => "ability",
        4 => "magic",
        _ => "unknown",
    }
}

/// Status names from `statuseffectids.lua` keyed by id.
fn lua_status_ids() -> HashMap<u32, String> {
    let text = std::fs::read_to_string(script_root().join("statuseffectids.lua")).unwrap();
    let mut out = HashMap::new();
    for line in text.lines() {
        let line = line.split("--").next().unwrap_or("");
        if let Some((name, value)) = line.split_once('=') {
            let value = value.trim().trim_end_matches(',').trim();
            if let Ok(id) = value.parse::<u32>() {
                out.insert(id, name.trim().to_string());
            }
        }
    }
    out
}

#[derive(Default)]
struct Static {
    script: &'static str,
    notes: Vec<String>,
}

fn static_checks(
    cmd: &BattleCommand,
    catalog: &HashMap<u16, BattleCommand>,
    lua_ids: &HashMap<u32, String>,
    status_defs: &HashMap<u32, crate::gamedata::StatusEffectDef>,
) -> Static {
    let mut s = Static::default();
    let folder = folder_for(cmd);
    let own = script_root().join(format!("commands/{folder}/{}.lua", cmd.name));
    let def = script_root().join(format!("commands/{folder}/default.lua"));
    s.script = if own.exists() {
        "own"
    } else if def.exists() {
        "default"
    } else {
        s.notes.push("no Lua script".into());
        "none"
    };
    if cmd.status_id != 0 {
        if !lua_ids.contains_key(&cmd.status_id) {
            s.notes.push(format!(
                "status {} not in statuseffectids.lua",
                cmd.status_id
            ));
        }
        match status_defs.get(&cmd.status_id) {
            None => s.notes.push(format!(
                "status {} not in server_statuseffects",
                cmd.status_id
            )),
            Some(d) => {
                if !script_root()
                    .join(format!("effects/{}.lua", d.name))
                    .exists()
                {
                    s.notes.push(format!("no effects/{}.lua", d.name));
                }
            }
        }
    }
    for c in cmd.combo_next_command_id {
        if c != 0 && !catalog.contains_key(&(c as u16)) {
            s.notes.push(format!("combo id {c} missing"));
        }
    }
    match cmd.command_type {
        2 if cmd.tp_cost <= 0 || cmd.tp_cost > 3000 => {
            s.notes.push(format!("weaponskill tpCost {}", cmd.tp_cost))
        }
        4 if cmd.mp_cost <= 0 => s.notes.push(format!("spell mpCost {}", cmd.mp_cost)),
        _ => {}
    }
    if cmd.cast_time_ms > 10_000 {
        s.notes.push(format!("castTime {} ms", cmd.cast_time_ms));
    }
    if cmd.max_recast_time_seconds > 900 {
        s.notes
            .push(format!("recast {} s", cmd.max_recast_time_seconds));
    }
    if cmd.status_id != 0 && cmd.status_chance <= 0.0 {
        s.notes.push(
            "statusChance 0: status needs a combo/positional/trait hook (none in Rust)".into(),
        );
    }
    if cmd.combo_step != 0 {
        s.notes.push("combo bonus not implemented".into());
    }
    s
}

struct Scene {
    registry: Arc<ActorRegistry>,
    ticker: GameTicker,
    processor: crate::processor::PacketProcessor,
    rx: mpsc::Receiver<Vec<u8>>,
    _rx_friend: mpsc::Receiver<Vec<u8>>,
}

fn actor_at(id: u32, kind: ActorKind, x: f32, z: f32, alive: bool) -> StoredActor {
    StoredActor {
        actor_id: id,
        kind,
        position: Vector3::new(x, 0.0, z),
        grid: (0, 0),
        is_alive: alive,
    }
}

async fn scene(
    db: &Arc<crate::database::Database>,
    lua: &Arc<crate::lua::LuaEngine>,
    cmd: &BattleCommand,
    rcpt: Recipient,
) -> Scene {
    let world = Arc::new(WorldManager::new());
    let registry = Arc::new(ActorRegistry::new());
    let friend_dead = rcpt == Recipient::DeadFriend;

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
    zone.core
        .add_actor(actor_at(PLAYER, ActorKind::Player, 0.0, 0.0, true), &mut ob);
    zone.core.add_actor(
        actor_at(ENEMY, ActorKind::BattleNpc, 3.0, 0.0, true),
        &mut ob,
    );
    zone.core.add_actor(
        actor_at(ENEMY2, ActorKind::BattleNpc, 3.5, 0.5, true),
        &mut ob,
    );
    zone.core.add_actor(
        actor_at(FRIEND, ActorKind::Player, -2.0, 0.0, !friend_dead),
        &mut ob,
    );
    let _ = ob.drain();
    world.register_zone(zone).await;

    let level = i16::from(cmd.level.max(1));
    let class = if cmd.job == 0 { 3 } else { i16::from(cmd.job) };

    let mut player = Character::new(PLAYER);
    player.base.zone_id = ZONE;
    player.chara.hp = PLAYER_HP / 2;
    player.chara.max_hp = PLAYER_HP;
    player.chara.mp = 9999;
    player.chara.max_mp = 9999;
    player.chara.tp = 3000;
    player.chara.level = level;
    player.chara.class = class;
    player.base.current_main_state = crate::actor::MAIN_STATE_ACTIVE;
    // Facing the dummy, so cones and boxes in front of the caster cover it.
    player.base.rotation = crate::runtime::ticker::look_at_rotation(0.0, 0.0, 3.0, 0.0);
    player.chara.current_target = ENEMY;
    player.chara.hotbar.push(crate::gamedata::HotbarEntry {
        hotbar_slot: 0,
        command_id: u32::from(cmd.id),
        recast_time: 0,
    });
    // Already fighting: engaged on the dummy with a swing clock far in
    // the future, so auto-attacks never muddy the damage readout.
    player
        .ai_container
        .internal_engage(ENEMY, crate::runtime::clock::server_now_ms(), 100_000_000);
    registry
        .insert(ActorHandle::new(
            PLAYER,
            ActorKindTag::Player,
            ZONE,
            PLAYER_SESSION,
            player,
        ))
        .await;

    for (id, x, z) in [(ENEMY, 3.0, 0.0), (ENEMY2, 3.5, 0.5)] {
        let mut e = Character::new(id);
        e.base.zone_id = ZONE;
        e.base.position_x = x;
        e.base.position_z = z;
        e.chara.hp = ENEMY_HP;
        e.chara.max_hp = ENEMY_HP;
        e.chara.level = level;
        e.chara.respawn_disabled = true;
        registry
            .insert(ActorHandle::new(id, ActorKindTag::BattleNpc, ZONE, 0, e))
            .await;
    }

    let mut friend = Character::new(FRIEND);
    friend.base.zone_id = ZONE;
    friend.base.position_x = -2.0;
    friend.chara.max_hp = PLAYER_HP;
    friend.chara.hp = if friend_dead { 0 } else { PLAYER_HP / 2 };
    friend.chara.level = level;
    if friend_dead {
        friend.base.current_main_state = crate::actor::MAIN_STATE_DEAD;
    }
    registry
        .insert(ActorHandle::new(
            FRIEND,
            ActorKindTag::Player,
            ZONE,
            FRIEND_SESSION,
            friend,
        ))
        .await;

    let (tx, rx) = mpsc::channel::<Vec<u8>>(4096);
    world
        .register_client(PLAYER_SESSION, ClientHandle::new(PLAYER_SESSION, tx))
        .await;
    let (tx2, rx_friend) = mpsc::channel::<Vec<u8>>(4096);
    world
        .register_client(FRIEND_SESSION, ClientHandle::new(FRIEND_SESSION, tx2))
        .await;
    for id in [PLAYER_SESSION, FRIEND_SESSION] {
        world
            .upsert_session(crate::data::Session {
                id,
                current_zone_id: ZONE,
                ..crate::data::Session::default()
            })
            .await;
    }

    let ticker = GameTicker::with_lua(
        TickerConfig::default(),
        world.clone(),
        registry.clone(),
        db.clone(),
        Some(lua.clone()),
    );
    let processor = crate::processor::PacketProcessor {
        db: db.clone(),
        world: world.clone(),
        registry: registry.clone(),
        lua: Some(lua.clone()),
        cmd: None,
    };
    Scene {
        registry,
        ticker,
        processor,
        rx,
        _rx_friend: rx_friend,
    }
}

fn event_start_body(owner: u32, target: u32) -> Vec<u8> {
    let mut v = Vec::new();
    v.extend_from_slice(&PLAYER.to_le_bytes());
    v.extend_from_slice(&owner.to_le_bytes());
    v.extend_from_slice(&0x2680_0000u32.to_le_bytes());
    v.extend_from_slice(&0u32.to_le_bytes());
    v.push(0);
    let mut name_field = [0u8; 0x20];
    let name = b"commandDefault";
    name_field[..name.len()].copy_from_slice(name);
    v.extend_from_slice(&name_field);
    common::luaparam::write_lua_params(&mut v, &[LuaParam::Actor(target)]).unwrap();
    v
}

/// Error texts (32xxx) the hotbar gate sent back on the X01 error row.
fn error_texts(rx: &mut mpsc::Receiver<Vec<u8>>, own_text: u16) -> Vec<u16> {
    let mut out = Vec::new();
    while let Ok(bytes) = rx.try_recv() {
        let mut offset = 0;
        while offset < bytes.len() {
            let Ok(sub) = common::subpacket::SubPacket::parse(&bytes, &mut offset) else {
                break;
            };
            if sub.game_message.opcode == crate::packets::opcodes::OP_COMMAND_RESULT_X01
                && sub.data.len() >= 0x30
            {
                let anim = u32::from_le_bytes(sub.data[0x04..0x08].try_into().unwrap());
                let text = u16::from_le_bytes(sub.data[0x2E..0x30].try_into().unwrap());
                if anim == 0 && text != own_text && (32500..32700).contains(&text) {
                    out.push(text);
                }
            }
        }
    }
    out
}

#[derive(Default, Debug)]
struct Outcome {
    errors: Vec<u16>,
    damage_main: i32,
    damage_splash: i32,
    heal: i32,
    self_damage: i32,
    friend_damage: i32,
    status_on: Option<u32>,
    revived: bool,
    mp_spent: i32,
    tp_spent: i32,
    recast_set: bool,
}

async fn hp(reg: &ActorRegistry, id: u32) -> i32 {
    i32::from(reg.get(id).await.unwrap().character.read().await.chara.hp)
}

async fn press_once(sc: &mut Scene, cmd: &BattleCommand, rcpt: Recipient) -> Outcome {
    let mut o = Outcome::default();
    // Re-arm between attempts: recast clear, pools full, a clean state
    // stack (keeps the far-future engage).
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let mut c = h.character.write().await;
        for e in c.chara.hotbar.iter_mut() {
            e.recast_time = 0;
        }
        c.chara.mp = 9999;
        c.chara.tp = 3000;
    }
    let before: HashMap<u32, i32> = {
        let mut m = HashMap::new();
        for id in [PLAYER, ENEMY, ENEMY2, FRIEND] {
            m.insert(id, hp(&sc.registry, id).await);
        }
        m
    };
    let press_target = match rcpt {
        Recipient::Caster | Recipient::Enemy => ENEMY,
        Recipient::Friend | Recipient::DeadFriend => FRIEND,
    };
    let body = event_start_body(0xA0F0_0000 | u32::from(cmd.id), press_target);
    sc.processor
        .handle_event_start(PLAYER_SESSION, &body)
        .await
        .unwrap();
    let base = crate::runtime::clock::server_now_ms();
    sc.ticker
        .tick_once(base + u64::from(cmd.cast_time_ms) + 50)
        .await;
    sc.ticker
        .tick_once(base + u64::from(cmd.cast_time_ms) + 600)
        .await;
    o.errors = error_texts(&mut sc.rx, cmd.world_master_text_id);

    let after_player = hp(&sc.registry, PLAYER).await;
    let after_enemy = hp(&sc.registry, ENEMY).await;
    let after_enemy2 = hp(&sc.registry, ENEMY2).await;
    let after_friend = hp(&sc.registry, FRIEND).await;
    o.damage_main = before[&ENEMY] - after_enemy;
    o.damage_splash = before[&ENEMY2] - after_enemy2;
    let rid = recipient_id(rcpt);
    let r_before = before[&rid];
    let r_after = hp(&sc.registry, rid).await;
    if rcpt != Recipient::Enemy {
        o.heal = r_after - r_before;
    }
    o.self_damage = (before[&PLAYER] - after_player).max(0);
    o.friend_damage = (before[&FRIEND] - after_friend).max(0);
    {
        let h = sc
            .registry
            .get(status_recipient_id(cmd, rcpt))
            .await
            .unwrap();
        let c = h.character.read().await;
        if cmd.status_id != 0 && c.status_effects.has(cmd.status_id) {
            o.status_on = Some(cmd.status_id);
        }
    }
    {
        let h = sc.registry.get(rid).await.unwrap();
        let c = h.character.read().await;
        if rcpt == Recipient::DeadFriend {
            o.revived = c.base.current_main_state != crate::actor::MAIN_STATE_DEAD && c.is_alive();
        }
    }
    {
        let h = sc.registry.get(PLAYER).await.unwrap();
        let c = h.character.read().await;
        o.mp_spent = 9999 - i32::from(c.chara.mp);
        o.tp_spent = 3000 - i32::from(c.chara.tp);
        o.recast_set = c.chara.hotbar.first().is_some_and(|e| e.recast_time != 0);
    }
    o
}

/// Force the landed status past its end time and tick: it must drop.
async fn check_expiry(sc: &mut Scene, rid: u32, status_id: u32) -> bool {
    {
        let h = sc.registry.get(rid).await.unwrap();
        let mut c = h.character.write().await;
        if let Some(e) = c.status_effects.get_mut(status_id) {
            if e.is_stance() || e.end_time == crate::status::STANCE_END_TIME {
                return true;
            }
            e.end_time = 1;
        }
    }
    let base = crate::runtime::clock::server_now_ms();
    sc.ticker.tick_once(base + 5_000).await;
    let h = sc.registry.get(rid).await.unwrap();
    !h.character.read().await.status_effects.has(status_id)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Verdict {
    Pass,
    Fail,
}

struct Row {
    cmd: BattleCommand,
    stat: Static,
    verdict: Verdict,
    detail: String,
}

async fn audit_command(
    db: &Arc<crate::database::Database>,
    lua: &Arc<crate::lua::LuaEngine>,
    cmd: &BattleCommand,
) -> (Verdict, String) {
    let rcpt = recipient(cmd);
    let mut sc = scene(db, lua, cmd, rcpt).await;
    let wants_damage = matches!(cmd.action_type, 1 | 2);
    let wants_heal = cmd.action_type == 3;
    let wants_status = cmd.status_id != 0 && cmd.status_chance > 0.0;
    let wants_revive = rcpt == Recipient::DeadFriend;
    let is_aoe = cmd.aoe_type != 0;

    let mut saw_damage = false;
    let mut saw_splash = false;
    let mut saw_heal = false;
    let mut saw_status = false;
    let mut expired = None;
    let mut revived = false;
    let mut errors: Vec<u16> = Vec::new();
    let mut friendly_fire = false;
    let mut costs_ok = true;
    let mut recast_ok = true;
    let mut last = Outcome::default();
    // Misses / resists / sub-1.0 status chances are random: press up to
    // 12 times and take the best of them.
    for _ in 0..12 {
        let o = press_once(&mut sc, cmd, rcpt).await;
        errors.extend(o.errors.iter().copied());
        saw_damage |= o.damage_main > 0;
        saw_splash |= o.damage_splash > 0;
        saw_heal |= o.heal > 0;
        revived |= o.revived;
        friendly_fire |=
            (wants_damage || cmd.action_type == 0) && (o.self_damage > 0 || o.friend_damage > 0);
        if o.errors.is_empty() {
            if cmd.tp_cost > 0 && o.tp_spent < i32::from(cmd.tp_cost) {
                costs_ok = false;
            }
            if cmd.mp_cost > 0 && o.mp_spent <= 0 {
                costs_ok = false;
            }
            if cmd.max_recast_time_seconds > 0 && !o.recast_set {
                recast_ok = false;
            }
        }
        if let Some(sid) = o.status_on
            && !saw_status
        {
            saw_status = true;
            expired = Some(check_expiry(&mut sc, status_recipient_id(cmd, rcpt), sid).await);
        }
        last = o;
        let done = (!wants_damage || saw_damage)
            && (!wants_heal || saw_heal)
            && (!wants_status || saw_status)
            && (!wants_revive || revived)
            && (!is_aoe || !wants_damage || saw_splash);
        if done || !errors.is_empty() || revived {
            break;
        }
    }

    let mut problems = Vec::new();
    let mut good = Vec::new();
    if !errors.is_empty() {
        errors.dedup();
        problems.push(format!("rejected {errors:?}"));
    }
    if wants_damage {
        if saw_damage {
            good.push(format!("dmg {}", last.damage_main.max(0)));
        } else {
            problems.push("no damage".into());
        }
        if is_aoe {
            if saw_splash {
                good.push("aoe".into());
            } else {
                problems.push("aoe hit only the main target".into());
            }
        }
    }
    if wants_heal {
        if saw_heal {
            good.push(format!("heal {}", last.heal.max(0)));
        } else {
            problems.push(format!("no heal on {rcpt:?}"));
        }
    }
    if wants_status {
        if saw_status {
            match expired {
                Some(true) => good.push("status+expiry".into()),
                _ => problems.push("status never expires".into()),
            }
        } else {
            problems.push(format!(
                "status {} not applied to {}",
                cmd.status_id,
                status_recipient_id(cmd, rcpt)
            ));
        }
    }
    if wants_revive {
        if revived {
            good.push("revive".into());
        } else {
            problems.push("no revive".into());
        }
    }
    if friendly_fire {
        problems.push("hit the caster/friend".into());
    }
    if !costs_ok {
        problems.push("cost not deducted".into());
    }
    if !recast_ok {
        problems.push("recast not started".into());
    }
    if !wants_damage && !wants_heal && !wants_status && !wants_revive && errors.is_empty() {
        good.push("no-op (row has no effect)".into());
    }
    let verdict = if problems.is_empty() {
        Verdict::Pass
    } else {
        Verdict::Fail
    };
    let mut detail = good.join(", ");
    if !problems.is_empty() {
        if !detail.is_empty() {
            detail.push_str("; ");
        }
        detail.push_str(&problems.join(", "));
    }
    (verdict, detail)
}

/// Commands that still fail for reasons outside this harness's reach —
/// each needs work the Rust battle path doesn't have yet. Keep this list
/// honest: an id here that starts passing makes the test fail too, so it
/// gets removed.
const KNOWN_GAPS: &[(u16, &str)] = &[
    (
        23459,
        "voice_of_the_dragon: ring 15-22 y around the caster; the dummies stand at 3 y",
    ),
    (
        23464,
        "the_scorpions_sting: cone rotated 1.0 pi (behind the caster); the dummies are in front",
    ),
];

#[tokio::test]
async fn battle_command_audit() {
    let db = Arc::new(
        crate::database::Database::open(tempdb())
            .await
            .expect("seeded db"),
    );
    let lua = Arc::new(crate::lua::LuaEngine::new(script_root()));
    let (catalog, by_level) = db
        .load_global_battle_command_list()
        .await
        .expect("battle command catalog");
    let status_defs = db
        .load_global_status_effect_list()
        .await
        .expect("status effect catalog");
    lua.catalogs()
        .install_battle_commands_with_level_index(catalog.clone(), by_level);
    lua.catalogs().install_status_effects(status_defs.clone());
    let lua_ids = lua_status_ids();

    let mut ids: Vec<u16> = catalog.keys().copied().collect();
    ids.sort_by_key(|id| {
        let c = &catalog[id];
        (c.job, c.level, *id)
    });
    assert_eq!(ids.len(), 151, "server_battle_commands row count");

    let mut rows = Vec::new();
    for id in &ids {
        let cmd = catalog[id].clone();
        let stat = static_checks(&cmd, &catalog, &lua_ids, &status_defs);
        let (verdict, detail) = audit_command(&db, &lua, &cmd).await;
        rows.push(Row {
            cmd,
            stat,
            verdict,
            detail,
        });
    }

    println!(
        "\n{:<6} {:<22} {:>3} {:>3} {:<4} {:<7} {:<5} detail / static notes",
        "id", "name", "cls", "lvl", "type", "script", "res"
    );
    let mut per_class: HashMap<u8, (u32, u32)> = HashMap::new();
    for r in &rows {
        let kind = match r.cmd.command_type {
            2 => "WS",
            3 => "AB",
            4 => "SP",
            _ => "??",
        };
        let res = match r.verdict {
            Verdict::Pass => "PASS",
            Verdict::Fail => "FAIL",
        };
        let e = per_class.entry(r.cmd.job).or_default();
        if r.verdict == Verdict::Pass {
            e.0 += 1;
        } else {
            e.1 += 1;
        }
        let mut notes = r.detail.clone();
        if !r.stat.notes.is_empty() {
            notes.push_str(" | ");
            notes.push_str(&r.stat.notes.join("; "));
        }
        println!(
            "{:<6} {:<22} {:>3} {:>3} {:<4} {:<7} {:<5} {}",
            r.cmd.id, r.cmd.name, r.cmd.job, r.cmd.level, kind, r.stat.script, res, notes
        );
    }
    let mut classes: Vec<_> = per_class.into_iter().collect();
    classes.sort();
    println!("\nclass  pass  fail");
    for (c, (p, f)) in &classes {
        println!("{c:>5} {p:>5} {f:>5}");
    }

    let known: HashSet<u16> = KNOWN_GAPS.iter().map(|(id, _)| *id).collect();
    let unexpected_fail: Vec<_> = rows
        .iter()
        .filter(|r| r.verdict == Verdict::Fail && !known.contains(&r.cmd.id))
        .map(|r| format!("{} {} ({})", r.cmd.id, r.cmd.name, r.detail))
        .collect();
    let unexpected_pass: Vec<_> = rows
        .iter()
        .filter(|r| r.verdict == Verdict::Pass && known.contains(&r.cmd.id))
        .map(|r| format!("{} {}", r.cmd.id, r.cmd.name))
        .collect();
    assert!(
        unexpected_fail.is_empty() && unexpected_pass.is_empty(),
        "battle command audit drift:\n  failing: {unexpected_fail:#?}\n  now passing (drop from KNOWN_GAPS): {unexpected_pass:#?}",
    );
}
