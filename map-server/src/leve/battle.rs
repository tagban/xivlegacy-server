// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Battle leves (the regional guildleves in `gamedata_guildleves`, ids
//! 1001+ and 10801+).
//!
//! Meteor never got these past a scripted demo (its director faked the
//! kill counter on a timer), so this is native:
//!
//! * the levemete offers a camp's leves ([`offers`]); taking one puts it
//!   in a free `work.guildleveId[slot]` ([`add`]);
//! * starting it at the camp ([`start`]) spawns a guildleve director actor
//!   (the client's leve tracker reads its `guildleveWork`) and the leve's
//!   targets at monster spawn points near the camp;
//! * kills of those targets advance the objectives ([`on_death`]); when
//!   all are met the leve completes and pays gil;
//! * [`tick`] ends leves whose time ran out or whose owner left, and
//!   takes the director down a little after the leve ended.
//!
//! The leve's targets are `mob1..4` (display-name ids) with `aimNum1..4`
//! of each to defeat. A target with no count (a Detect leve's decoys)
//! spawns a couple of extras that don't count. Gathering leves count each
//! defeated target as one item.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use common::luaparam::LuaParam;
use common::subpacket::SubPacket;

use crate::database::Database;
use crate::gamedata::{GuildleveGamedata, GuildleveRegionalEntry};
use crate::lua::LuaEngine;
use crate::packets::send::actor::ActorPropertyPacketBuilder;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

const WORLD_MASTER: u32 = 0x5FF8_0001;
const LOG_SYSTEM: u8 = 0x20;
/// "You have started the leve..."
const TEXT_STARTED: u16 = 50036;
/// The leve name + difficulty banner.
const TEXT_BEGIN: u16 = 50022;
/// "Time limit: N minutes."
const TEXT_TIME_LIMIT: u16 = 50026;
/// "<leve> complete!"
const TEXT_COMPLETE: u16 = 50023;
/// "You have abandoned <leve>."
const TEXT_ABANDON: u16 = 50147;
const MUSIC_VICTORY: u16 = 81;
/// The `init` values a guildleve director script returns after its class
/// path: director kind 0x4E25, the leve id, then the aetheryte-location
/// slot and an unused marker (Meteor's scripts all pass 6, 0, 0, 0).
const DIRECTOR_KIND: i32 = 0x4E25;
/// Regional guildleve slots (`work.guildleveId[16]`).
const SLOTS: u16 = 16;
/// How many of one target are up at a time; more respawn as they fall.
const MAX_UP: usize = 8;
/// Extras of a target that doesn't count (decoys).
const EXTRAS: usize = 2;
/// Targets stand at least this far from the camp.
const MIN_CAMP_DISTANCE: f32 = 30.0;
/// Party members this close to the leader (yalms) join the leve they
/// start at the camp.
const PARTY_JOIN_RANGE: f32 = 50.0;
/// The director stays this long after the leve ended, so the tracker can
/// show the result.
const LINGER_MS: u64 = 15_000;
/// A levemete's leve set changes every 36 hours, as in 1.0.
const ROTATION_SECS: u64 = 36 * 3600;
/// Leve sets show 8 cards.
const CARDS: usize = 8;
/// "My Very First Adventure" and the other class tutorials: they run their
/// own scripted director.
const TUTORIALS: [u32; 6] = [10801, 10802, 11601, 11602, 12401, 12402];

/// Survive leves (a timed hold-out) need mechanics this doesn't have yet,
/// so they aren't offered.
fn plate_supported(plate_id: u32) -> bool {
    plate_id != PLATE_SURVIVE
}

/// Necrologos leves (PrivateGLBattleOrbNormal): gather the torn pages of the
/// Necrologos, each summoning a beast that must be put down, then destroy
/// the tome. Objectives 1-3 are pages (`item1..3`, `aimNum1..3`); the fourth
/// line is the tome (`item4`), cleared when every page is in.
const PLATE_NECROLOGOS: u32 = 20023;
const PLATE_SURVIVE: u32 = 20027;
const PLATE_GATHER: u32 = 20025;
/// Chase leves ("Pursue and defeat the target enemies") run their
/// objectives as stages: the first group, then a bigger one further out
/// (the sheet's counts grow stage by stage, often of the same monster).
const PLATE_CHASE: u32 = 20022;
/// How far (yalms) a Chase leve's next group is from the last one.
const STAGE_STEP: f32 = 40.0;

/// An objective whose item is carried by monsters of the area: a Necrologos
/// page, or a Gather leve's item when the sheet names no monster for it.
fn carried_by_local_beasts(gd: &GuildleveGamedata, i: usize) -> bool {
    match gd.plate_id {
        PLATE_NECROLOGOS => is_page(gd, i),
        PLATE_GATHER => gd.aim_num[i] > 0 && gd.items[i] != 0 && target_of(gd, i) == 0,
        _ => false,
    }
}

/// A Necrologos leve's page objectives: those with a count and a page item.
fn is_page(gd: &GuildleveGamedata, i: usize) -> bool {
    i < 3 && gd.aim_num[i] > 0 && gd.items[i] != 0
}

/// A battle leve this runtime can run: has at least one target to defeat,
/// and every target it counts has a monster to spawn.
pub fn is_supported(gd: &GuildleveGamedata) -> bool {
    if gd.plate_id == PLATE_NECROLOGOS {
        // a page's beast is the leve's own mob when it names one, else a
        // monster of the area
        return gd.class_type == 1
            && (0..3).any(|i| is_page(gd, i))
            && (0..3).all(|i| !is_page(gd, i) || gd.mobs[i] == 0 || !gd.mob_missing[i]);
    }
    let counted = |i: usize| gd.aim_num[i] > 0 && target_of(gd, i) != 0;
    gd.class_type == 1
        && !TUTORIALS.contains(&gd.id)
        && plate_supported(gd.plate_id)
        && (0..4).any(|i| counted(i) || carried_by_local_beasts(gd, i))
        && (0..4).all(|i| !counted(i) || !target_missing(gd, i))
}

/// Objective `i`'s target has no monster class (its own mob, or the
/// first one it falls back to).
fn target_missing(gd: &GuildleveGamedata, i: usize) -> bool {
    if gd.mobs[i] != 0 {
        gd.mob_missing[i]
    } else {
        gd.mob_missing[0]
    }
}

/// The regional leves a camp's levemete hands out (`10801..`). The rows
/// below are faction leves (`1001..1120`, Operation/Wanted: they need
/// faction credit and come from the faction menus) and the ones above are
/// Grand Company leves (`20901..`, from the company's leve officers).
pub fn is_regional(gl_id: u32) -> bool {
    (10_801..20_000).contains(&gl_id)
}

/// The display-name id objective `i` counts: its own mob, or for a single
/// objective whose mob slot is empty, the first one.
fn target_of(gd: &GuildleveGamedata, i: usize) -> u32 {
    if gd.mobs[i] != 0 {
        gd.mobs[i]
    } else if i == 0 {
        0
    } else {
        gd.mobs[0]
    }
}

/// The director script (and client class) for a leve's plate.
fn director_class(gd: &GuildleveGamedata) -> &'static str {
    crate::director::guildleve::guildleve_script_for_plate(gd.id, gd.plate_id)
        .map(|p| p.trim_start_matches("Guildleve/"))
        .unwrap_or("PrivateGLBattleSweepNormal")
}

/// The Grand Company a GC leve belongs to (1 Maelstrom, 2 Twin Adder,
/// 3 Immortal Flames), from its authority: 40065 leves start at Limsa
/// Lominsa's camps, 40066 at Gridania's, 40067 at Ul'dah's.
pub fn company_of(gd: &GuildleveGamedata) -> Option<u8> {
    match gd.authority {
        40065 => Some(1),
        40066 => Some(2),
        40067 => Some(3),
        _ => None,
    }
}

/// The leves a Grand Company officer of company `gc` offers: that
/// company's GC leves (ids 20901 and up) that can run, lowest level first.
pub fn company_offers(catalog: &HashMap<u32, GuildleveGamedata>, gc: u8) -> Vec<u32> {
    let mut leves: Vec<&GuildleveGamedata> = catalog
        .values()
        .filter(|g| g.id >= 20_901 && company_of(g) == Some(gc) && is_supported(g))
        .collect();
    leves.sort_by_key(|g| (g.level, g.id));
    leves.into_iter().map(|g| g.id).collect()
}

/// Up to 8 leves for a camp's leve set: the camp's regional battle leves
/// at its base level (the lowest one it has; in 1.23b each camp's regional
/// leves share one level, and the star menu raises it), rotated every 36
/// hours when it has more than 8.
pub fn offers(
    catalog: &HashMap<u32, GuildleveGamedata>,
    aetheryte: u32,
    now_secs: u64,
) -> Vec<u32> {
    // Unused leve rows are copies of each other (same data, new id; the
    // client titles them "x"); real leves are unique.
    let key = |g: &GuildleveGamedata| {
        (
            g.class_type,
            g.location,
            g.level,
            g.aetheryte,
            g.plate_id,
            g.border_id,
            g.time_limit,
            g.favor_count,
            g.aim_num,
            g.mobs,
        )
    };
    let mut copies: HashMap<_, usize> = HashMap::new();
    for g in catalog.values().filter(|g| g.aetheryte == aetheryte) {
        *copies.entry(key(g)).or_default() += 1;
    }
    let mine: Vec<&GuildleveGamedata> = catalog
        .values()
        .filter(|g| g.aetheryte == aetheryte && g.level > 0 && is_regional(g.id) && is_supported(g))
        .filter(|g| copies.get(&key(g)) == Some(&1))
        .collect();
    let Some(base) = mine.iter().map(|g| g.level).min() else {
        return Vec::new();
    };
    let mut ids: Vec<u32> = mine
        .iter()
        .filter(|g| g.level == base)
        .map(|g| g.id)
        .collect();
    ids.sort_unstable();
    if ids.len() <= CARDS {
        return ids;
    }
    let start = ((now_secs / ROTATION_SECS) as usize * CARDS) % ids.len();
    (0..CARDS).map(|k| ids[(start + k) % ids.len()]).collect()
}

#[derive(Debug, Clone, PartialEq)]
enum Phase {
    Running {
        deadline_ms: u64,
    },
    /// Ended; the director goes away at `remove_at_ms`.
    Ended {
        remove_at_ms: u64,
    },
}

#[derive(Debug, Clone)]
struct Leve {
    /// Who runs it: the player who started it, or the party member it
    /// passed to when they left.
    owner: u32,
    /// Who holds the leve card (the starter); it leaves their slots when
    /// the leve ends.
    holder: u32,
    /// Party members on the leve with the owner: they see the tracker and
    /// share the reward.
    members: Vec<u32>,
    guildleve_id: u32,
    difficulty: u8,
    zone_id: u32,
    director_id: u32,
    monster_level: u32,
    aim: [i8; 4],
    now: [i8; 4],
    /// Display-name id each objective counts.
    targets: [u32; 4],
    /// Monster class spawned for each objective.
    classes: [u32; 4],
    /// Live spawned actors and the objective they count for.
    spawned: HashMap<u32, Option<usize>>,
    /// Ground spots the targets use.
    spots: Vec<(f32, f32, f32)>,
    next_spot: usize,
    reward_gil: i32,
    phase: Phase,
    /// Director class (`/Director/Guildleve/<class>`), for spawning it
    /// again for a member who comes back.
    class: &'static str,
    /// `guildleveWork.startTime` and the target marker, for the same.
    start_secs: u32,
    marker: (f32, f32, f32),
    /// A Necrologos leve: objective 4 is the tome, done when the pages are.
    necrologos: bool,
    /// Objectives run one at a time (Chase).
    staged: bool,
    /// The camp and every monster spawn point of the zone, for placing a
    /// staged leve's next group.
    camp: (f32, f32, f32),
    points: Vec<(f32, f32, f32)>,
    /// Members who dropped off (left the zone, logged out); they rejoin
    /// when they are back in the zone and still in the party.
    dropped: Vec<u32>,
    /// When each dropped member was first seen back.
    back_since: HashMap<u32, u64>,
}

static ACTIVE: Mutex<Vec<Leve>> = Mutex::new(Vec::new());
static NEXT_DIRECTOR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0x6_0000);

fn with_active<R>(f: impl FnOnce(&mut Vec<Leve>) -> R) -> R {
    f(&mut ACTIVE.lock().unwrap())
}

impl Leve {
    /// The owner, then the members.
    fn participants(&self) -> Vec<u32> {
        std::iter::once(self.owner)
            .chain(self.members.iter().copied())
            .collect()
    }

    fn has(&self, player_id: u32) -> bool {
        self.owner == player_id || self.members.contains(&player_id)
    }
}

/// The leve `player_id` is running, their own or their party's: (leve id,
/// difficulty).
pub fn current(player_id: u32) -> Option<(u32, u8)> {
    with_active(|a| {
        a.iter()
            .find(|l| l.has(player_id) && matches!(l.phase, Phase::Running { .. }))
            .map(|l| (l.guildleve_id, l.difficulty))
    })
}

/// Send each of `players` the same packets.
async fn send_all(
    registry: &ActorRegistry,
    world: &WorldManager,
    players: &[u32],
    subs: Vec<SubPacket>,
) {
    for &p in players {
        send(registry, world, p, subs.clone()).await;
    }
}

/// Is `player_id` online, in `zone_id`, with a live connection?
async fn in_zone(
    registry: &ActorRegistry,
    world: &WorldManager,
    player_id: u32,
    zone_id: u32,
) -> bool {
    match registry.get(player_id).await {
        Some(h) => h.zone_id == zone_id && world.client(h.session_id).await.is_some(),
        None => false,
    }
}

/// The party members who join a leve `leader` starts: online, in the same
/// zone, within [`PARTY_JOIN_RANGE`] of the leader and not on a leve of
/// their own.
async fn party_joiners(
    leader: u32,
    zone_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
) -> Vec<u32> {
    let Some(lh) = registry.get(leader).await else {
        return Vec::new();
    };
    let at = {
        let c = lh.character.read().await;
        (c.base.position_x, c.base.position_z)
    };
    let mut out = Vec::new();
    for m in crate::parties::others(leader) {
        let Some(h) = registry.get(m).await else {
            continue;
        };
        if !h.is_player() || !in_zone(registry, world, m, zone_id).await || current(m).is_some() {
            continue;
        }
        let near = {
            let c = h.character.read().await;
            ((c.base.position_x - at.0).powi(2) + (c.base.position_z - at.1).powi(2)).sqrt()
                <= PARTY_JOIN_RANGE
        };
        if near {
            out.push(m);
        }
    }
    out
}

async fn send(
    registry: &ActorRegistry,
    world: &WorldManager,
    player_id: u32,
    subs: Vec<SubPacket>,
) {
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    let Some(client) = world.client(handle.session_id).await else {
        return;
    };
    for mut sub in subs {
        sub.set_target_id(handle.session_id);
        client.send_bytes(sub.to_bytes()).await;
    }
}

async fn message(
    registry: &ActorRegistry,
    world: &WorldManager,
    player_id: u32,
    text_id: u16,
    params: &[LuaParam],
) {
    let sub = if params.is_empty() {
        crate::packets::send::build_game_message_actor1(
            WORLD_MASTER,
            player_id,
            WORLD_MASTER,
            text_id,
            LOG_SYSTEM,
        )
    } else {
        crate::packets::send::build_game_message_actor1_with_params(
            WORLD_MASTER,
            player_id,
            WORLD_MASTER,
            text_id,
            LOG_SYSTEM,
            params,
        )
    };
    send(registry, world, player_id, vec![sub]).await;
}

async fn music(registry: &ActorRegistry, world: &WorldManager, player_id: u32, id: u16) {
    let sub = crate::packets::send::misc::build_set_music(player_id, id, 0);
    send(registry, world, player_id, vec![sub]).await;
}

async fn say(registry: &ActorRegistry, world: &WorldManager, player_id: u32, text: &str) {
    crate::runtime::quest_apply::apply_send_message(
        player_id, LOG_SYSTEM, "", text, registry, world,
    )
    .await;
}

fn gamedata(lua: Option<&Arc<LuaEngine>>, gl_id: u32) -> Option<GuildleveGamedata> {
    lua?.catalogs()
        .guildleves
        .read()
        .ok()
        .and_then(|m| m.get(&gl_id).cloned())
}

/// Put `gl_id` in a free regional leve slot. False when the player already
/// holds it or every slot is taken.
pub async fn add(
    player_id: u32,
    gl_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
) -> bool {
    let Some(handle) = registry.get(player_id).await else {
        return false;
    };
    let slot = {
        let mut c = handle.character.write().await;
        let held = &mut c.chara.guildleves_regional;
        if held.iter().any(|e| u32::from(e.guildleve_id) == gl_id) {
            None
        } else {
            let slot =
                (0..SLOTS).find(|s| !held.iter().any(|e| e.slot == *s && e.guildleve_id != 0));
            if let Some(slot) = slot {
                held.retain(|e| e.slot != slot);
                held.push(GuildleveRegionalEntry {
                    slot,
                    guildleve_id: gl_id as u16,
                    abandoned: false,
                    completed: false,
                });
            }
            slot
        }
    };
    let Some(slot) = slot else {
        return false;
    };
    if let Err(e) = db.save_guildleve(player_id, gl_id, i32::from(slot)).await {
        tracing::warn!(player = player_id, gl_id, error = %e, "guildleve: save failed");
    }
    send_slot(registry, world, player_id, slot, gl_id as u16).await;
    tracing::info!(player = player_id, gl_id, slot, "guildleve taken");
    true
}

async fn send_slot(
    registry: &ActorRegistry,
    world: &WorldManager,
    player_id: u32,
    slot: u16,
    id: u16,
) {
    let mut b = ActorPropertyPacketBuilder::new(player_id, "work/guildleve");
    b.add_short(&format!("work.guildleveId[{slot}]"), id);
    send(registry, world, player_id, b.done()).await;
}

/// Take `gl_id` out of the player's leve slots.
async fn remove(
    player_id: u32,
    gl_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
) {
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    let slot = {
        let mut c = handle.character.write().await;
        let held = &mut c.chara.guildleves_regional;
        let slot = held
            .iter()
            .find(|e| u32::from(e.guildleve_id) == gl_id)
            .map(|e| e.slot);
        held.retain(|e| u32::from(e.guildleve_id) != gl_id);
        slot
    };
    if let Err(e) = db.remove_guildleve(player_id, gl_id).await {
        tracing::warn!(player = player_id, gl_id, error = %e, "guildleve: remove failed");
    }
    if let Some(slot) = slot {
        send_slot(registry, world, player_id, slot, 0).await;
    }
}

fn director_packets(
    leve: &Leve,
    target: &str,
    add: impl FnOnce(&mut ActorPropertyPacketBuilder),
) -> Vec<SubPacket> {
    let mut b = ActorPropertyPacketBuilder::new(leve.director_id, target);
    add(&mut b);
    let _ = leve;
    b.done()
}

/// Gil for completing a leve. The 1.23b data carries no reward amounts, so
/// this is an approximation scaled by level and difficulty.
pub fn reward_gil(level: u16, difficulty: u8) -> i32 {
    let base = 100 + 40 * i32::from(level.max(1));
    base * (4 + i32::from(difficulty.clamp(1, 5))) / 5
}

/// Start the leve `gl_id` the player holds, at `difficulty` (1..=5 stars).
#[allow(clippy::too_many_arguments)]
pub async fn start(
    player_id: u32,
    gl_id: u32,
    difficulty: u8,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
    now_ms: u64,
) {
    let Some(gd) = gamedata(lua, gl_id) else {
        tracing::warn!(player = player_id, gl_id, "guildleve: no gamedata");
        return;
    };
    if current(player_id).is_some() {
        say(
            registry,
            world,
            player_id,
            "You are already on a levequest.",
        )
        .await;
        return;
    }
    if !is_supported(&gd) {
        say(
            registry,
            world,
            player_id,
            "This levequest isn't available yet.",
        )
        .await;
        return;
    }
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    let zone_id = handle.zone_id;
    let held = {
        let c = handle.character.read().await;
        c.chara
            .guildleves_regional
            .iter()
            .any(|e| u32::from(e.guildleve_id) == gl_id)
    };
    if !held {
        tracing::warn!(
            player = player_id,
            gl_id,
            "guildleve: start without holding it"
        );
        return;
    }
    let difficulty = difficulty.clamp(1, 5);

    // Ground spots: the monster spawn point nearest the camp (but not on
    // top of it), then the spawn points around that one.
    let camp = match db.aetheryte_spot(gd.aetheryte).await {
        Ok(Some((z, x, y, zz))) if z == zone_id => (x, y, zz),
        _ => {
            let c = handle.character.read().await;
            (c.base.position_x, c.base.position_y, c.base.position_z)
        }
    };
    let points = db.battlenpc_spawn_points(zone_id).await.unwrap_or_default();
    let dist =
        |a: (f32, f32, f32), b: (f32, f32, f32)| ((a.0 - b.0).powi(2) + (a.2 - b.2).powi(2)).sqrt();
    let center = points
        .iter()
        .copied()
        .filter(|p| dist(*p, camp) >= MIN_CAMP_DISTANCE)
        .min_by(|a, b| dist(*a, camp).total_cmp(&dist(*b, camp)))
        .unwrap_or((camp.0 + MIN_CAMP_DISTANCE, camp.1, camp.2));
    let mut spots: Vec<(f32, f32, f32)> = points.clone();
    spots.sort_by(|a, b| dist(*a, center).total_cmp(&dist(*b, center)));
    spots.truncate(24);
    if spots.is_empty() {
        spots.push(center);
    }

    let necrologos = gd.plate_id == PLATE_NECROLOGOS;
    let mut classes = [0u32; 4];
    let mut targets = [0u32; 4];
    if necrologos || (0..4).any(|i| carried_by_local_beasts(&gd, i)) {
        // each page's beast: the leve's own mob, or a monster of the area
        // around the leve spot near its level (a different one per page)
        let monsters = db.zone_monsters(zone_id).await.unwrap_or_default();
        let local = pick_beasts(&monsters, center, u32::from(gd.level), 3);
        for i in (0..4)
            .filter(|&i| carried_by_local_beasts(&gd, i) || (!necrologos && gd.aim_num[i] > 0))
        {
            targets[i] = if necrologos {
                gd.mobs[i]
            } else {
                target_of(&gd, i)
            };
            classes[i] = if targets[i] != 0 {
                db.monster_class_for_name(targets[i])
                    .await
                    .ok()
                    .flatten()
                    .unwrap_or(0)
            } else {
                local.get(i % local.len().max(1)).copied().unwrap_or(0)
            };
        }
    } else {
        for i in 0..4 {
            if gd.aim_num[i] <= 0 {
                continue;
            }
            targets[i] = target_of(&gd, i);
            classes[i] = db
                .monster_class_for_name(targets[i])
                .await
                .ok()
                .flatten()
                .unwrap_or(0);
        }
    }
    let director_id = (6 << 28)
        | (zone_id << 19)
        | (NEXT_DIRECTOR.fetch_add(1, std::sync::atomic::Ordering::Relaxed) & 0x7_FFFF);
    let time_limit_ms = u64::from(gd.time_limit.max(1)) * 60_000;
    let members = party_joiners(player_id, zone_id, registry, world).await;
    let start_secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as u32)
        .unwrap_or_default();
    let mut leve = Leve {
        owner: player_id,
        holder: player_id,
        members,
        guildleve_id: gl_id,
        difficulty,
        zone_id,
        director_id,
        // the client's difficulty menu: each star past the first is enemy level +3
        monster_level: u32::from(gd.level.max(1)) + 3 * u32::from(difficulty - 1),
        aim: if necrologos {
            // the pages, then the tome (one, destroyed when they're in)
            std::array::from_fn(|i| match i {
                3 => 1,
                _ if is_page(&gd, i) => gd.aim_num[i],
                _ => 0,
            })
        } else {
            gd.aim_num.map(|a| a.max(0))
        },
        now: [0; 4],
        targets,
        classes,
        spawned: HashMap::new(),
        spots,
        next_spot: 0,
        reward_gil: reward_gil(gd.level, difficulty),
        phase: Phase::Running {
            deadline_ms: now_ms + time_limit_ms,
        },
        class: director_class(&gd),
        start_secs,
        marker: center,
        necrologos,
        staged: gd.plate_id == PLATE_CHASE,
        camp,
        points: points.clone(),
        dropped: Vec::new(),
        back_since: HashMap::new(),
    };
    for i in 0..4 {
        if leve.aim[i] > 0 && classes[i] == 0 && !(necrologos && i == 3) {
            tracing::warn!(
                gl_id,
                target = targets[i],
                "guildleve: no monster class for target; objective dropped"
            );
            leve.aim[i] = 0;
        }
    }
    if leve
        .aim
        .iter()
        .zip(leve.classes)
        .all(|(a, c)| *a == 0 || c == 0)
    {
        say(
            registry,
            world,
            player_id,
            "This levequest's targets couldn't be found.",
        )
        .await;
        return;
    }

    // Director actor first: the tracker and the start texts point at it.
    let Some(spawn) = director_spawn(&leve, world).await else {
        return;
    };
    // Everyone on it gets the director, the start texts and the tracker:
    // the leader and the party members who came along.
    let everyone = leve.participants();
    send_all(registry, world, &everyone, spawn).await;
    let anim =
        crate::director::guildleve::guildleve_start_animation(gd.border_id, gd.plate_id, false);
    let tune = crate::director::guildleve::GuildleveLocationMusic::pick(u32::from(gd.location));
    for &p in &everyone {
        message(
            registry,
            world,
            p,
            TEXT_STARTED,
            &[LuaParam::Int32(gl_id as i32), LuaParam::Actor(player_id)],
        )
        .await;
        let anim_sub = crate::packets::send::actor::build_play_animation_on_actor(p, anim);
        send(registry, world, p, vec![anim_sub]).await;
        if let Some(m) = tune {
            music(registry, world, p, m).await;
        }
        message(
            registry,
            world,
            p,
            TEXT_BEGIN,
            &[
                LuaParam::Int32(gl_id as i32),
                LuaParam::Int32(i32::from(difficulty)),
            ],
        )
        .await;
        message(
            registry,
            world,
            p,
            TEXT_TIME_LIMIT,
            &[LuaParam::Int32(gd.time_limit as i32)],
        )
        .await;
    }

    send_all(registry, world, &everyone, tracker_state(&leve)).await;

    // Targets: up to MAX_UP of each objective, plus decoys for mobs that
    // don't count.
    let mut wave: Vec<(u32, Option<usize>)> = Vec::new();
    let first_stage = stage(&leve.aim, &leve.now);
    for i in 0..4 {
        if leve.classes[i] == 0 || (leve.staged && first_stage != Some(i)) {
            continue;
        }
        for _ in 0..(leve.aim[i] as usize).min(MAX_UP) {
            wave.push((leve.classes[i], Some(i)));
        }
    }
    for (j, &mob) in gd.mobs.iter().enumerate() {
        if mob == 0 || leve.targets.contains(&mob) || gd.mobs[..j].contains(&mob) {
            continue;
        }
        if let Ok(Some(class_id)) = db.monster_class_for_name(mob).await {
            for _ in 0..EXTRAS {
                wave.push((class_id, None));
            }
        }
    }
    for (class_id, objective) in wave {
        if let Some(actor_id) = spawn_one(&mut leve, class_id, registry, world, db, lua).await {
            leve.spawned.insert(actor_id, objective);
        }
    }
    tracing::info!(
        player = player_id,
        gl_id,
        difficulty,
        zone_id,
        director = format!("0x{director_id:08X}"),
        party = ?leve.members,
        targets = leve.spawned.len(),
        actors = ?leve
            .spawned
            .keys()
            .map(|a| format!("0x{a:08X}"))
            .collect::<Vec<_>>(),
        center = ?center,
        "battle leve started"
    );
    with_active(|a| a.push(leve));
}

/// The guildleve director actor's spawn packets.
async fn director_spawn(leve: &Leve, world: &WorldManager) -> Option<Vec<SubPacket>> {
    let (zone_name, zone_actor) = {
        let z = world.zone(leve.zone_id).await?;
        let z = z.read().await;
        (z.core.zone_name.clone(), z.core.actor_id)
    };
    let class_path = format!("/Director/Guildleve/{}", leve.class);
    Some(crate::world_manager::build_director_spawn_subpackets_with(
        leve.director_id,
        zone_actor,
        &class_path,
        leve.class,
        &zone_name,
        &[
            LuaParam::Int32(DIRECTOR_KIND),
            LuaParam::Int32(leve.guildleve_id as i32),
            LuaParam::Int32(6),
            LuaParam::Int32(0),
            LuaParam::Int32(0),
            LuaParam::Int32(0),
        ],
    ))
}

/// The tracker's state: start time (the client counts the timer down from
/// it), objectives with what's done so far, and the target marker.
fn tracker_state(leve: &Leve) -> Vec<SubPacket> {
    let mut subs = director_packets(leve, "guildleveWork/start", |b| {
        b.add_int("guildleveWork.startTime", leve.start_secs);
    });
    subs.extend(director_packets(leve, "guildleveWork/infoVariable", |b| {
        for i in 0..4 {
            if leve.aim[i] != 0 {
                b.add_byte(&format!("guildleveWork.aimNum[{i}]"), leve.aim[i] as u8);
                b.add_byte(
                    &format!("guildleveWork.uiState[{i}]"),
                    ui_state(leve.staged, &leve.aim, &leve.now, i),
                );
                if leve.now[i] != 0 {
                    b.add_byte(&format!("guildleveWork.aimNumNow[{i}]"), leve.now[i] as u8);
                }
            }
        }
    }));
    // Hunt and Detect trackers have a fifth line (an item or a count of
    // targets found) read from `work.searchNumber` / `work.detectNumber`;
    // the client hides it at -1. Nothing here fills it, so hide it rather
    // than show an empty "[en] 0".
    if let Some(field) = extra_line_field(leve.class) {
        subs.extend(director_packets(leve, "work/info", |b| {
            b.add_byte(field, (-1i8) as u8);
        }));
    }
    if let Some((done, max)) = round_line(leve.class, &leve.aim, &leve.now) {
        subs.extend(director_packets(leve, "work/info", |b| {
            b.add_byte("work.roundNumber", done);
            b.add_byte("work.roundNumberMax", max);
        }));
    }
    subs.extend(director_packets(leve, "guildleveWork/marker", |b| {
        b.add_float("guildleveWork.markerX[0]", leve.marker.0);
        b.add_float("guildleveWork.markerY[0]", leve.marker.1);
        b.add_float("guildleveWork.markerZ[0]", leve.marker.2);
    }));
    subs
}

/// Up to `n` different monster classes for a Necrologos leve's pages: the
/// area's monsters whose level range is closest to the leve's, nearest the
/// leve spot first. `monsters` is (class, min level, max level, spawn spot).
fn pick_beasts(
    monsters: &[crate::database::ZoneMonster],
    center: (f32, f32, f32),
    level: u32,
    n: usize,
) -> Vec<u32> {
    let gap = |lo: u32, hi: u32| {
        if level < lo {
            lo - level
        } else {
            level.saturating_sub(hi)
        }
    };
    let mut best: HashMap<u32, (u32, f32)> = HashMap::new();
    for &(class, lo, hi, (x, _, z)) in monsters {
        let score = (
            gap(lo, hi),
            ((x - center.0).powi(2) + (z - center.2).powi(2)).sqrt(),
        );
        best.entry(class)
            .and_modify(|b| {
                if score.0 < b.0 || (score.0 == b.0 && score.1 < b.1) {
                    *b = score;
                }
            })
            .or_insert(score);
    }
    let mut ranked: Vec<(u32, (u32, f32))> = best.into_iter().collect();
    ranked.sort_by(|a, b| {
        a.1.0
            .cmp(&b.1.0)
            .then(a.1.1.total_cmp(&b.1.1))
            .then(a.0.cmp(&b.0))
    });
    ranked.into_iter().take(n).map(|(c, _)| c).collect()
}

/// The Round tracker's fifth line (PrivateGLBattleRoundNormal), always
/// shown as `work.roundNumber/roundNumberMax`, "on" while the first is
/// lower. The leve sheet has no round count, so the leve is one round:
/// 0/1 while any objective is open, 1/1 once all are met.
fn round_line(class: &str, aim: &[i8; 4], now: &[i8; 4]) -> Option<(u8, u8)> {
    if class != "PrivateGLBattleRoundNormal" {
        return None;
    }
    let met = (0..4).all(|i| now[i] >= aim[i]);
    Some((met as u8, 1))
}

/// The `work` field behind a director class's fifth tracker line, for the
/// classes that hide it at -1 (PrivateGLBattleHuntNormal and
/// PrivateGLBattleDetectNormal in the 1.23b client scripts).
fn extra_line_field(class: &str) -> Option<&'static str> {
    match class {
        "PrivateGLBattleHuntNormal" => Some("work.searchNumber"),
        "PrivateGLBattleDetectNormal" => Some("work.detectNumber"),
        _ => None,
    }
}

/// A dropped member back in the zone this long (ms) rejoins: long enough
/// for their client to finish loading the zone.
const REJOIN_AFTER_MS: u64 = 5_000;

/// Members who dropped off a running leve and are back in its zone, in
/// the same party as the one running it: after [`REJOIN_AFTER_MS`] they
/// get the director and the tracker again and are on the leve.
async fn rejoin_dropped(leve: &Leve, now_ms: u64, registry: &ActorRegistry, world: &WorldManager) {
    if leve.dropped.is_empty() {
        return;
    }
    let party = crate::parties::members_of(leve.owner);
    let mut back = Vec::new();
    let mut away = Vec::new();
    for &d in &leve.dropped {
        if party.contains(&d) && in_zone(registry, world, d, leve.zone_id).await {
            back.push(d);
        } else {
            away.push(d);
        }
    }
    let director_id = leve.director_id;
    let ready: Vec<u32> = with_active(|a| {
        let Some(l) = a.iter_mut().find(|l| l.director_id == director_id) else {
            return Vec::new();
        };
        for d in &away {
            l.back_since.remove(d);
        }
        let mut ready = Vec::new();
        for &d in &back {
            let since = *l.back_since.entry(d).or_insert(now_ms);
            if now_ms >= since + REJOIN_AFTER_MS {
                ready.push(d);
            }
        }
        for d in &ready {
            l.back_since.remove(d);
            l.dropped.retain(|x| x != d);
            if !l.has(*d) {
                l.members.push(*d);
            }
        }
        ready
    });
    if ready.is_empty() {
        return;
    }
    let Some(spawn) = director_spawn(leve, world).await else {
        return;
    };
    for &d in &ready {
        send(registry, world, d, spawn.clone()).await;
        send(registry, world, d, tracker_state(leve)).await;
        message(
            registry,
            world,
            d,
            TEXT_BEGIN,
            &[
                LuaParam::Int32(leve.guildleve_id as i32),
                LuaParam::Int32(i32::from(leve.difficulty)),
            ],
        )
        .await;
        tracing::info!(
            player = d,
            gl_id = leve.guildleve_id,
            "back on the party's battle leve"
        );
    }
}

/// Spawn one leve monster at the leve's next ground spot.
async fn spawn_one(
    leve: &mut Leve,
    class_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
) -> Option<u32> {
    let class = db.load_actor_class(class_id).await.ok().flatten()?;
    let genus = crate::processor::gm_spawn::genus_for(db, class_id, &class.class_path).await;
    let (x, y, z) = leve.spots[leve.next_spot % leve.spots.len()];
    leve.next_spot += 1;
    // spread out a little around the spot
    let k = leve.next_spot as f32;
    let (x, z) = (x + 2.0 * (k * 2.4).sin(), z + 2.0 * (k * 2.4).cos());
    let rotation = (k * 1.7) % std::f32::consts::TAU;
    let (bnpc_ids, group_id, pool_id) = db
        .gm_spawn_insert(
            class_id,
            class_id.to_string(),
            genus,
            leve.zone_id,
            leve.monster_level,
            vec![(x, y, z, rotation)],
        )
        .await
        .ok()?;
    let mut spawned = None;
    for bnpc_id in &bnpc_ids {
        let actor_id = (4 << 28) | (leve.zone_id << 19) | crate::processor::gm_spawn::next_number();
        if crate::runtime::bnpc_spawn::spawn_battle_npc(
            *bnpc_id,
            leve.zone_id,
            actor_id,
            Some(None),
            db,
            world,
            registry,
            lua,
        )
        .await
        {
            spawned = Some(actor_id);
        }
    }
    if let Err(e) = db.gm_spawn_delete(bnpc_ids, group_id, pool_id).await {
        tracing::warn!(error = %e, "guildleve: removing the temporary spawn rows failed");
    }
    spawned
}

/// A battle NPC died: count it for the leve that spawned it.
pub async fn on_death(
    victim_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: Option<&Database>,
    lua: Option<&Arc<LuaEngine>>,
    now_ms: u64,
) {
    // update under the lock, act after it
    let hit = with_active(|a| {
        let leve = a.iter_mut().find(|l| {
            matches!(l.phase, Phase::Running { .. }) && l.spawned.contains_key(&victim_id)
        })?;
        let objective = leve.spawned.remove(&victim_id)?;
        let i = objective?;
        if leve.now[i] >= leve.aim[i] {
            return None;
        }
        leve.now[i] += 1;
        let up = leve.spawned.values().filter(|o| **o == Some(i)).count() as i8;
        let respawn = leve.now[i] + up < leve.aim[i];
        if leve.necrologos && (0..3).all(|k| leve.now[k] >= leve.aim[k]) {
            // every page is in: the tome is destroyed
            leve.now[3] = leve.aim[3];
        }
        let done = (0..4).all(|k| leve.now[k] >= leve.aim[k]);
        Some((leve.clone(), i, respawn, done))
    });
    let Some((leve, i, respawn, done)) = hit else {
        return;
    };
    let subs = director_packets(&leve, "guildleveWork/infoVariable", |b| {
        b.add_byte(&format!("guildleveWork.aimNumNow[{i}]"), leve.now[i] as u8);
        if leve.necrologos && done {
            b.add_byte("guildleveWork.aimNumNow[3]", leve.now[3] as u8);
        }
    });
    send_all(registry, world, &leve.participants(), subs).await;
    tracing::info!(
        player = leve.owner,
        gl_id = leve.guildleve_id,
        objective = i,
        now = leve.now[i],
        aim = leve.aim[i],
        "battle leve kill"
    );
    if done {
        if let Some(db) = db {
            complete(leve.owner, registry, world, db, now_ms).await;
        }
        return;
    }
    if leve.staged && leve.now[i] >= leve.aim[i] {
        if let Some(db) = db {
            next_stage(leve, registry, world, db, lua).await;
        }
        return;
    }
    if respawn && let Some(db) = db {
        let mut leve = leve;
        let class_id = leve.classes[i];
        if let Some(actor_id) = spawn_one(&mut leve, class_id, registry, world, db, lua).await {
            tracing::info!(
                gl_id = leve.guildleve_id,
                objective = i,
                actor = format!("0x{actor_id:08X}"),
                "battle leve target respawned"
            );
            with_active(|a| {
                if let Some(l) = a.iter_mut().find(|l| l.director_id == leve.director_id) {
                    l.spawned.insert(actor_id, Some(i));
                    l.next_spot = leve.next_spot;
                }
            });
        }
    }
}

/// A staged leve's group is down: the next group appears further out, the
/// marker moves to it and the tracker lights its line.
async fn next_stage(
    mut leve: Leve,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
) {
    let Some(next) = stage(&leve.aim, &leve.now) else {
        return;
    };
    let center = next_stage_center(&leve.points, leve.camp, leve.marker);
    let mut spots = leve.points.clone();
    let d = |a: &(f32, f32, f32)| (a.0 - center.0).powi(2) + (a.2 - center.2).powi(2);
    spots.sort_by(|a, b| d(a).total_cmp(&d(b)));
    spots.truncate(24);
    if spots.is_empty() {
        spots.push(center);
    }
    leve.spots = spots;
    leve.next_spot = 0;
    leve.marker = center;
    let mut new = Vec::new();
    if leve.classes[next] != 0 {
        for _ in 0..(leve.aim[next] as usize).min(MAX_UP) {
            let class_id = leve.classes[next];
            if let Some(actor_id) = spawn_one(&mut leve, class_id, registry, world, db, lua).await {
                new.push(actor_id);
            }
        }
    }
    let director_id = leve.director_id;
    let still_running = with_active(|a| {
        let Some(l) = a
            .iter_mut()
            .find(|l| l.director_id == director_id && matches!(l.phase, Phase::Running { .. }))
        else {
            return false;
        };
        l.spots = leve.spots.clone();
        l.next_spot = leve.next_spot;
        l.marker = leve.marker;
        for a in &new {
            l.spawned.insert(*a, Some(next));
        }
        true
    });
    if !still_running {
        for a in new {
            crate::runtime::quest_apply::apply_despawn_actor(leve.zone_id, a, registry, world)
                .await;
        }
        return;
    }
    send_all(registry, world, &leve.participants(), tracker_state(&leve)).await;
    tracing::info!(
        gl_id = leve.guildleve_id,
        stage = next,
        center = ?center,
        actors = ?new.iter().map(|a| format!("0x{a:08X}")).collect::<Vec<_>>(),
        "battle leve next stage"
    );
}

/// The objective a staged leve is on: the first one not yet met.
fn stage(aim: &[i8; 4], now: &[i8; 4]) -> Option<usize> {
    (0..4).find(|&i| aim[i] > 0 && now[i] < aim[i])
}

/// `guildleveWork.uiState` of objective `i`: shown (1) for a leve that runs
/// its objectives at once; for a staged one, cleared (2) once met, shown
/// while it's the current stage and hidden (0) before that.
fn ui_state(staged: bool, aim: &[i8; 4], now: &[i8; 4], i: usize) -> u8 {
    if !staged {
        return 1;
    }
    if now[i] >= aim[i] {
        2
    } else if stage(aim, now) == Some(i) {
        1
    } else {
        0
    }
}

/// Where a staged leve's next group waits: the spawn point nearest the last
/// group that is at least [`STAGE_STEP`] from it and no closer to the camp,
/// so the chase leads away from camp; any point [`STAGE_STEP`] away when
/// none is; the last spot when there are none.
fn next_stage_center(
    points: &[(f32, f32, f32)],
    camp: (f32, f32, f32),
    from: (f32, f32, f32),
) -> (f32, f32, f32) {
    let d =
        |a: (f32, f32, f32), b: (f32, f32, f32)| ((a.0 - b.0).powi(2) + (a.2 - b.2).powi(2)).sqrt();
    let nearest = |ok: &dyn Fn(&(f32, f32, f32)) -> bool| {
        points
            .iter()
            .copied()
            .filter(|p| d(*p, from) >= STAGE_STEP && ok(p))
            .min_by(|a, b| d(*a, from).total_cmp(&d(*b, from)))
    };
    nearest(&|p| d(*p, camp) >= d(from, camp))
        .or_else(|| nearest(&|_| true))
        .unwrap_or(from)
}

/// End the running leve `player_id` owns; returns it with its phase set to
/// Ended.
fn finish(player_id: u32, now_ms: u64) -> Option<Leve> {
    with_active(|a| {
        let leve = a
            .iter_mut()
            .find(|l| l.owner == player_id && matches!(l.phase, Phase::Running { .. }))?;
        leve.phase = Phase::Ended {
            remove_at_ms: now_ms + LINGER_MS,
        };
        let out = leve.clone();
        leve.spawned.clear();
        Some(out)
    })
}

async fn wrap_up(leve: &Leve, registry: &ActorRegistry, world: &WorldManager, db: &Database) {
    for &actor_id in leve.spawned.keys() {
        crate::runtime::quest_apply::apply_despawn_actor(leve.zone_id, actor_id, registry, world)
            .await;
    }
    let subs = {
        let mut s = director_packets(leve, "guildleveWork/signal", |b| {
            b.add_byte("guildleveWork.signal", (-1i8) as u8);
        });
        s.extend(director_packets(leve, "guildleveWork/start", |b| {
            b.add_int("guildleveWork.startTime", 0);
        }));
        s
    };
    send_all(registry, world, &leve.participants(), subs).await;
    remove(leve.holder, leve.guildleve_id, registry, world, db).await;
}

/// Everyone on the leve who is still in its zone: they hear the result
/// and share the reward.
async fn present(leve: &Leve, registry: &ActorRegistry, world: &WorldManager) -> Vec<u32> {
    let mut out = Vec::new();
    for p in leve.participants() {
        if in_zone(registry, world, p, leve.zone_id).await {
            out.push(p);
        }
    }
    out
}

async fn complete(
    player_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    now_ms: u64,
) {
    let Some(leve) = finish(player_id, now_ms) else {
        return;
    };
    let paid = present(&leve, registry, world).await;
    for &p in &paid {
        music(registry, world, p, MUSIC_VICTORY).await;
        message(
            registry,
            world,
            p,
            TEXT_COMPLETE,
            &[LuaParam::Int32(leve.guildleve_id as i32)],
        )
        .await;
    }
    wrap_up(&leve, registry, world, db).await;
    for &p in &paid {
        crate::runtime::quest_apply::apply_add_gil(p, leve.reward_gil, registry, Some(world), db)
            .await;
        say(
            registry,
            world,
            p,
            &format!(
                "You receive {} gil for completing the levequest.",
                leve.reward_gil
            ),
        )
        .await;
    }
    tracing::info!(
        player = player_id,
        gl_id = leve.guildleve_id,
        gil = leve.reward_gil,
        paid = ?paid,
        "battle leve complete"
    );
}

/// Give up the running leve. The one running it ends it for everyone; a
/// party member on it just leaves it.
pub async fn abandon(
    player_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    now_ms: u64,
) {
    let left = with_active(|a| {
        let l = a
            .iter_mut()
            .find(|l| l.members.contains(&player_id) && matches!(l.phase, Phase::Running { .. }))?;
        l.members.retain(|&m| m != player_id);
        Some((l.guildleve_id, l.director_id))
    });
    if let Some((gl_id, director_id)) = left {
        message(
            registry,
            world,
            player_id,
            TEXT_ABANDON,
            &[LuaParam::Int32(gl_id as i32)],
        )
        .await;
        let sub = crate::packets::send::actor::build_remove_actor(director_id);
        send(registry, world, player_id, vec![sub]).await;
        tracing::info!(player = player_id, gl_id, "left the party's battle leve");
        return;
    }
    let Some(leve) = finish(player_id, now_ms) else {
        return;
    };
    for p in present(&leve, registry, world).await {
        message(
            registry,
            world,
            p,
            TEXT_ABANDON,
            &[LuaParam::Int32(leve.guildleve_id as i32)],
        )
        .await;
    }
    wrap_up(&leve, registry, world, db).await;
    tracing::info!(
        player = player_id,
        gl_id = leve.guildleve_id,
        "battle leve abandoned"
    );
}

/// Time limits, players who left, and taking ended leves' directors down.
/// A member who leaves the zone (or logs out) drops off the leve; when the
/// one running it leaves, it passes to a member still there, and fails
/// when nobody is.
pub async fn tick(now_ms: u64, registry: &ActorRegistry, world: &WorldManager, db: &Database) {
    // once a second is plenty
    static LAST: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let last = LAST.load(std::sync::atomic::Ordering::Relaxed);
    if now_ms < last + 1000 {
        return;
    }
    LAST.store(now_ms, std::sync::atomic::Ordering::Relaxed);
    let snapshot: Vec<Leve> = with_active(|a| a.clone());
    if snapshot.is_empty() {
        return;
    }
    for leve in snapshot {
        let here = present(&leve, registry, world).await;
        let director_id = leve.director_id;
        match leve.phase {
            Phase::Running { deadline_ms } => {
                if here.len() != leve.participants().len() && !here.is_empty() {
                    // drop who left; a new owner if the owner did
                    let owner = if here.contains(&leve.owner) {
                        leve.owner
                    } else {
                        here[0]
                    };
                    let gone: Vec<u32> = leve
                        .participants()
                        .into_iter()
                        .filter(|p| !here.contains(p))
                        .collect();
                    with_active(|a| {
                        if let Some(l) = a.iter_mut().find(|l| l.director_id == director_id) {
                            l.owner = owner;
                            l.members = here.iter().copied().filter(|&p| p != owner).collect();
                            for g in &gone {
                                if !l.dropped.contains(g) {
                                    l.dropped.push(*g);
                                }
                            }
                        }
                    });
                    if owner != leve.owner {
                        tracing::info!(
                            gl_id = leve.guildleve_id,
                            from = leve.owner,
                            to = owner,
                            "battle leve passed to a party member"
                        );
                    }
                }
                if !here.is_empty() && now_ms < deadline_ms {
                    rejoin_dropped(&leve, now_ms, registry, world).await;
                }
                if here.is_empty() || now_ms >= deadline_ms {
                    let owner = here.first().copied().unwrap_or(leve.owner);
                    if let Some(ended) = finish(owner, now_ms) {
                        wrap_up(&ended, registry, world, db).await;
                        for &p in &here {
                            say(registry, world, p, "Time is up. The levequest has failed.").await;
                        }
                        tracing::info!(
                            player = owner,
                            gl_id = ended.guildleve_id,
                            left = here.is_empty(),
                            "battle leve failed"
                        );
                    }
                }
            }
            Phase::Ended { remove_at_ms } if now_ms >= remove_at_ms || here.is_empty() => {
                with_active(|a| a.retain(|l| l.director_id != director_id));
                let bgm = match world.zone(leve.zone_id).await {
                    Some(z) => z.read().await.core.bgm_day,
                    None => 0,
                };
                for &p in &here {
                    let sub = crate::packets::send::actor::build_remove_actor(director_id);
                    send(registry, world, p, vec![sub]).await;
                    if bgm != 0 {
                        music(registry, world, p, bgm).await;
                    }
                }
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn leve(
        id: u32,
        aetheryte: u32,
        level: u16,
        plate: u32,
        aim: [i8; 4],
        mobs: [u32; 4],
    ) -> GuildleveGamedata {
        GuildleveGamedata {
            id,
            class_type: 1,
            location: 1,
            level,
            aetheryte,
            plate_id: plate,
            time_limit: 30,
            aim_num: aim,
            mobs,
            ..Default::default()
        }
    }

    #[test]
    fn a_gc_officer_offers_its_own_companys_leves() {
        let gc = |id, authority, level, mob| GuildleveGamedata {
            authority,
            ..leve(id, 1280004, level, 20036, [2, 0, 0, 0], [mob, 0, 0, 0])
        };
        let mut cat = HashMap::new();
        for g in [
            gc(20903, 40065, 40, 3200103),
            gc(21422, 40065, 30, 3200103),
            gc(20901, 40065, 40, 4000625),
            gc(22523, 40066, 40, 3200103),
            gc(10821, 40065, 1, 3200103),
        ] {
            cat.insert(g.id, g);
        }
        cat.get_mut(&20901).unwrap().mob_missing[0] = true;
        assert_eq!(company_offers(&cat, 1), vec![21422, 20903]);
        assert_eq!(company_offers(&cat, 2), vec![22523]);
        assert!(company_offers(&cat, 3).is_empty());
    }

    #[test]
    fn offers_the_camps_base_level_and_rotates() {
        let mut cat = HashMap::new();
        for k in 0..10 {
            let id = 10821 + k;
            cat.insert(
                id,
                leve(id, 1280002, 1, 20021, [5, 0, 0, 0], [3205701 + k, 0, 0, 0]),
            );
        }
        // unused copies of one row
        for id in [10840, 10841] {
            cat.insert(
                id,
                leve(id, 1280002, 1, 20021, [3, 0, 0, 0], [3204101, 0, 0, 0]),
            );
        }
        // other levels, other camps, tutorials and unsupported plates
        cat.insert(
            1119,
            leve(1119, 1280002, 50, 20059, [1, 0, 0, 0], [3109003, 0, 0, 0]),
        );
        cat.insert(
            10801,
            leve(10801, 1280002, 1, 20021, [3, 0, 0, 0], [3204001, 0, 0, 0]),
        );
        cat.insert(
            10846,
            leve(10846, 1280002, 1, 20023, [3, 0, 0, 0], [0, 0, 0, 0]),
        );
        cat.insert(
            10881,
            leve(10881, 1280003, 10, 20021, [3, 0, 0, 0], [3205602, 0, 0, 0]),
        );
        let first = offers(&cat, 1280002, 0);
        assert_eq!(first, (10821..10829).collect::<Vec<_>>());
        let later = offers(&cat, 1280002, ROTATION_SECS);
        assert_eq!(later.len(), 8);
        assert_ne!(later, first, "the set rotates");
        assert!(later.iter().all(|id| (10821..10831).contains(id)));
        assert_eq!(offers(&cat, 1280003, 0), vec![10881]);
        assert!(offers(&cat, 1280099, 0).is_empty());
    }

    #[test]
    fn levemete_offers_regional_leves_only() {
        let mut cat = HashMap::new();
        cat.insert(
            11641,
            leve(11641, 1280033, 10, 20021, [5, 0, 0, 0], [3200101, 0, 0, 0]),
        );
        // a faction leve and a Grand Company leve at the same camp and level
        cat.insert(
            1101,
            leve(1101, 1280033, 10, 20021, [1, 0, 0, 0], [3200102, 0, 0, 0]),
        );
        cat.insert(
            20901,
            leve(20901, 1280033, 10, 20049, [3, 0, 0, 0], [3200103, 0, 0, 0]),
        );
        assert_eq!(offers(&cat, 1280033, 0), vec![11641]);
    }

    #[test]
    fn a_target_with_no_monster_is_not_offered() {
        // Securing Horizon's Edge: footpads and raiders have no monster class
        let mut footpads = leve(
            11661,
            1280034,
            20,
            20021,
            [5, 5, 0, 0],
            [3280101, 3280105, 0, 0],
        );
        footpads.mob_missing = [true, true, false, false];
        assert!(!is_supported(&footpads));
        // one counted target missing is enough
        footpads.mob_missing = [false, true, false, false];
        assert!(!is_supported(&footpads));
        // a Detect leve's decoy without a monster doesn't matter
        let mut imps = leve(
            11668,
            1280034,
            20,
            20028,
            [2, 0, 0, 0],
            [3202603, 3280114, 0, 3209901],
        );
        imps.mob_missing = [false, true, false, false];
        assert!(is_supported(&imps));
        // an objective with no mob of its own counts the first one
        let mut fallback = leve(1, 1280034, 20, 20021, [2, 3, 0, 0], [3280101, 0, 0, 0]);
        fallback.mob_missing = [true, false, false, false];
        assert!(!is_supported(&fallback));
    }

    #[test]
    fn needs_a_target_to_be_supported() {
        assert!(!is_supported(&leve(
            10863,
            1280005,
            20,
            20025,
            [3, 0, 0, 0],
            [0, 0, 0, 0]
        )));
        assert!(is_supported(&leve(
            10866,
            1280005,
            20,
            20028,
            [4, 0, 0, 0],
            [3202603, 3206004, 0, 0]
        )));
    }

    #[test]
    fn necrologos_leves_are_supported_by_their_pages() {
        // Necrologos: Lords of Skyey Realms: three charred pages, then the tome
        let mut orb = leve(10846, 1280007, 30, 20023, [3, 0, 0, 0], [0; 4]);
        orb.items = [12000003, 0, 0, 12000004];
        assert!(is_supported(&orb));
        assert!(is_page(&orb, 0) && !is_page(&orb, 1) && !is_page(&orb, 3));
        // no page, nothing to do
        orb.items = [0, 0, 0, 12000004];
        assert!(!is_supported(&orb));
        // a page whose named beast has no monster
        orb.items = [12000003, 0, 0, 12000004];
        orb.mobs = [3280101, 0, 0, 0];
        orb.mob_missing = [true, false, false, false];
        assert!(!is_supported(&orb));
        // Survive is still out
        assert!(!is_supported(&leve(
            10907,
            1280004,
            40,
            20027,
            [1, 0, 0, 0],
            [3203101, 0, 0, 0]
        )));
    }

    #[test]
    fn a_gather_leve_with_no_monster_uses_local_beasts() {
        // To Catch a Thief: three items, no monster named
        let mut thief = leve(10863, 1280005, 20, 20025, [3, 0, 0, 0], [0; 4]);
        thief.items = [12000058, 0, 0, 0];
        assert!(carried_by_local_beasts(&thief, 0));
        assert!(is_supported(&thief));
        // a Gather leve that names its monster keeps it
        let mut claws = leve(
            10883,
            1280003,
            10,
            20025,
            [2, 2, 0, 0],
            [3200101, 3204102, 0, 0],
        );
        claws.items = [12000043, 12000044, 0, 0];
        assert!(!carried_by_local_beasts(&claws, 0));
        assert!(is_supported(&claws));
        // a Sweep leve with nothing to defeat stays out
        assert!(!is_supported(&leve(
            11004,
            1280050,
            100,
            20021,
            [3, 0, 0, 0],
            [0; 4]
        )));
    }

    #[test]
    fn necrologos_beasts_are_local_and_near_the_leve_level() {
        let at = |x: f32| (x, 0.0, 0.0);
        let monsters = [
            (2201, 1, 5, at(10.0)),    // too weak
            (2230, 28, 32, at(400.0)), // right level, far
            (2231, 29, 31, at(50.0)),  // right level, near
            (2231, 29, 31, at(900.0)),
            (2240, 33, 36, at(20.0)), // a little strong
        ];
        let picked = pick_beasts(&monsters, at(0.0), 30, 3);
        assert_eq!(picked, vec![2231, 2230, 2240]);
        assert!(pick_beasts(&[], at(0.0), 30, 3).is_empty());
    }

    #[test]
    fn chase_stages_run_in_order() {
        // Sating the Simians: 2, then 4, then 6 galagos
        let aim = [2, 4, 6, 0];
        assert_eq!(stage(&aim, &[0, 0, 0, 0]), Some(0));
        assert_eq!(stage(&aim, &[2, 0, 0, 0]), Some(1));
        assert_eq!(stage(&aim, &[2, 4, 5, 0]), Some(2));
        assert_eq!(stage(&aim, &[2, 4, 6, 0]), None);
        // the tracker: cleared, current, hidden
        let now = [2, 1, 0, 0];
        assert_eq!(ui_state(true, &aim, &now, 0), 2);
        assert_eq!(ui_state(true, &aim, &now, 1), 1);
        assert_eq!(ui_state(true, &aim, &now, 2), 0);
        // a leve that isn't staged shows every line
        assert_eq!(ui_state(false, &aim, &now, 2), 1);
    }

    #[test]
    fn the_next_chase_group_is_further_from_camp() {
        let camp = (0.0, 0.0, 0.0);
        let from = (50.0, 0.0, 0.0);
        let points = [
            (60.0, 0.0, 0.0),  // too close to the last group
            (10.0, 0.0, 0.0),  // back towards camp
            (95.0, 0.0, 10.0), // away from camp, 40+ out
            (200.0, 0.0, 0.0),
        ];
        assert_eq!(next_stage_center(&points, camp, from), (95.0, 0.0, 10.0));
        // nothing further out: any point far enough
        assert_eq!(
            next_stage_center(&[(10.0, 0.0, 0.0), (55.0, 0.0, 0.0)], camp, from),
            (10.0, 0.0, 0.0)
        );
        assert_eq!(next_stage_center(&[], camp, from), from);
    }

    #[test]
    fn hunt_and_detect_trackers_hide_their_fifth_line() {
        assert_eq!(
            extra_line_field("PrivateGLBattleHuntNormal"),
            Some("work.searchNumber")
        );
        assert_eq!(
            extra_line_field("PrivateGLBattleDetectNormal"),
            Some("work.detectNumber")
        );
        assert_eq!(extra_line_field("PrivateGLBattleSweepNormal"), None);
    }

    #[test]
    fn round_tracker_counts_one_round() {
        let aim = [2, 0, 0, 0];
        assert_eq!(
            round_line("PrivateGLBattleRoundNormal", &aim, &[1, 0, 0, 0]),
            Some((0, 1))
        );
        assert_eq!(
            round_line("PrivateGLBattleRoundNormal", &aim, &[2, 0, 0, 0]),
            Some((1, 1))
        );
        assert_eq!(
            round_line("PrivateGLBattleSweepNormal", &aim, &[2, 0, 0, 0]),
            None
        );
    }

    #[test]
    fn reward_grows_with_level_and_difficulty() {
        assert!(reward_gil(1, 1) < reward_gil(1, 5));
        assert!(reward_gil(1, 3) < reward_gil(20, 3));
        assert_eq!(reward_gil(1, 1), 140);
    }
}
