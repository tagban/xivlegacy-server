// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The Atomos event of patch 1.23b ([dev1485]): Atomos opens over five
//! aetheryte camps, Dragonhead, Emerald Moss, Crimson Bark, Black Brush and
//! Horizon, and lets voidsent out into the camp. Design and sources:
//! `docs/atomos.md`.
//!
//! - The event is the seasonal event `atomos` (`settings/events.toml`,
//!   `!event atomos on|off|auto`). While it runs the server sends special
//!   event work 9 = 20 (`crate::seasonal`), under which the client's
//!   Teleport menu shows the five camps as free, and `IsTeleportFree`
//!   (aetheryte.lua) charges them nothing.
//! - At 06:00 and 12:00 Eorzean time Atomos opens over each camp. It can't
//!   be brought down there (it never attacks and weapons leave it at 1 HP);
//!   the fight is its voidsent: deepvoid scamps, souls and warriors, a new
//!   wave each time the last one is slain, up to `[atomos] waves`.
//! - It closes `[atomos] open_minutes` Eorzean minutes after it opened (a
//!   little over three Eorzean hours, as in 1.0), when its last wave is
//!   slain, or when the event stops; its voidsent go with it.
//! - `!atomos` shows the camps; `!atomos open|close [camp|all]` opens or
//!   closes one now (`crate::command_processor`).

use std::sync::OnceLock;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use common::bounded::Bounded;
use serde::Deserialize;

use crate::database::Database;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The seasonal event (`settings/events.toml`) that runs the camps.
pub const EVENT: &str = "atomos";

/// Atomos (actor class 2111001, display name "Atomos"). Its class path is
/// the 1.23b client's `/Chara/Npc/Monster/Animaobj/AnimaobjStandard`.
pub const ATOMOS_CLASS: u32 = 2_111_001;

/// The voidsent the camps of [dev1485] saw (Gamer Escape's monster pages
/// list these three at all five): deepvoid scamp, soul and warrior.
pub const VOIDSENT: [(u32, &str); 3] = [
    (2_102_612, "atomos_deepvoid_scamp"),
    (2_104_328, "atomos_deepvoid_soul"),
    (2_101_910, "atomos_deepvoid_warrior"),
];

/// `server_drop_lists` list the voidsent roll: Over-aspected Crystals. Clear
/// of every actor class id (a class id is its own default list).
pub const VOIDSENT_DROP_LIST: u32 = 99_000_001;

/// Eorzean hours Atomos opens over these camps.
pub const OPEN_HOURS: [u32; 2] = [6, 12];

/// Real seconds in an Eorzean minute (an Eorzean hour is 175 s).
const SECONDS_PER_EORZEA_MINUTE: f64 = 175.0 / 60.0;
const SECONDS_PER_EORZEA_HOUR: u64 = 175;

/// Atomos's own numbers (it can't fall, so only what the client shows).
const ATOMOS_LEVEL: u32 = 60;
const ATOMOS_HP: u32 = 30_000;

/// Yalms from the aetheryte to Atomos, and from Atomos to its voidsent.
const ATOMOS_DISTANCE: f32 = 20.0;
const VOIDSENT_RING: f32 = 6.0;
/// A spot for Atomos must be within this many yalms of the aetheryte's
/// height (else the next direction is tried).
const MAX_STEP: f32 = 4.0;

/// One of the five camps: its aetheryte (actor class) and where that
/// stands (server_spawn_locations).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Camp {
    pub aetheryte: u32,
    /// For `!atomos open <key>`.
    pub key: &'static str,
    pub name: &'static str,
    pub zone: u32,
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

pub const CAMPS: [Camp; 5] = [
    Camp {
        aetheryte: 1_280_092,
        key: "dragonhead",
        name: "Camp Dragonhead",
        zone: 143,
        x: 216.0,
        y: 303.0,
        z: -258.0,
    },
    Camp {
        aetheryte: 1_280_064,
        key: "emeraldmoss",
        name: "Camp Emerald Moss",
        zone: 152,
        x: -1052.0,
        y: 20.6,
        z: -1760.0,
    },
    Camp {
        aetheryte: 1_280_065,
        key: "crimsonbark",
        name: "Camp Crimson Bark",
        zone: 153,
        x: -1566.04,
        y: -11.89,
        z: -550.51,
    },
    Camp {
        aetheryte: 1_280_032,
        key: "blackbrush",
        name: "Camp Black Brush",
        zone: 170,
        x: 33.0,
        y: 201.0,
        z: -482.0,
    },
    Camp {
        aetheryte: 1_280_034,
        key: "horizon",
        name: "Camp Horizon",
        zone: 172,
        x: -1315.0,
        y: 57.0,
        z: -147.0,
    },
];

/// The camp `key` names (its key, or part of its name, any case).
pub fn camp_by_key(key: &str) -> Option<usize> {
    let k: String = key
        .to_ascii_lowercase()
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect();
    if k.is_empty() {
        return None;
    }
    CAMPS.iter().position(|c| {
        let name: String = c
            .name
            .to_ascii_lowercase()
            .chars()
            .filter(|c| c.is_ascii_alphanumeric())
            .collect();
        c.key == k || name == k || c.key.starts_with(&k)
    })
}

/// The camp in `zone`, if one is there.
pub fn camp_in_zone(zone: u32) -> Option<usize> {
    CAMPS.iter().position(|c| c.zone == zone)
}

// --- settings ---------------------------------------------------------------

/// Voidsent level. Gamer Escape lists them at 60.
pub const VOIDSENT_LEVEL: Bounded<i64> = Bounded {
    name: "atomos.voidsent_level",
    retail: 60,
    safe: 40..=70,
    hard: 1..=99,
    risky: "far from 60 the voidsent are trivial or out of reach for a level-50 party",
    breaks: "levels past 99 don't fit the client's level display",
};

/// Voidsent hit points.
pub const VOIDSENT_HP: Bounded<i64> = Bounded {
    name: "atomos.voidsent_hp",
    retail: 5000,
    safe: 1000..=15_000,
    hard: 1..=32_767,
    risky: "far from 5000 a wave falls in a blow or takes a party minutes each",
    breaks: "a monster's HP is held in 16 bits",
};

/// Voidsent in each wave.
pub const VOIDSENT_PER_WAVE: Bounded<i64> = Bounded {
    name: "atomos.voidsent_per_wave",
    retail: 6,
    safe: 3..=9,
    hard: 1..=12,
    risky: "more than 9 at once overwhelms a full party at the camp",
    breaks: "past 12 they no longer fit the ring around Atomos",
};

/// Waves before Atomos closes.
pub const WAVES: Bounded<i64> = Bounded {
    name: "atomos.waves",
    retail: 3,
    safe: 1..=6,
    hard: 1..=20,
    risky: "more than 6 waves keeps a camp under attack the whole time it is open",
    breaks: "past 20 waves the camp never runs out of voidsent while open",
};

/// Eorzean minutes Atomos stays open. 1.0 players saw it go "a little
/// over three Eorzean hours" after it appeared.
pub const OPEN_MINUTES: Bounded<i64> = Bounded {
    name: "atomos.open_minutes",
    retail: 190,
    safe: 60..=360,
    hard: 10..=360,
    risky: "under an Eorzean hour few players reach the camp in time",
    breaks: "past 360 it would still be open at the next opening, six Eorzean hours on",
};

/// `[atomos]` in settings/map.toml.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct AtomosSection {
    pub voidsent_level: i64,
    pub voidsent_hp: i64,
    pub voidsent_per_wave: i64,
    pub waves: i64,
    pub open_minutes: i64,
}

impl Default for AtomosSection {
    fn default() -> Self {
        Self {
            voidsent_level: VOIDSENT_LEVEL.retail,
            voidsent_hp: VOIDSENT_HP.retail,
            voidsent_per_wave: VOIDSENT_PER_WAVE.retail,
            waves: WAVES.retail,
            open_minutes: OPEN_MINUTES.retail,
        }
    }
}

/// The numbers in force.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rules {
    pub voidsent_level: u32,
    pub voidsent_hp: u32,
    pub voidsent_per_wave: usize,
    pub waves: u32,
    pub open_minutes: u32,
}

impl Rules {
    pub fn from_settings(s: &AtomosSection) -> Self {
        Self {
            voidsent_level: VOIDSENT_LEVEL.apply(s.voidsent_level) as u32,
            voidsent_hp: VOIDSENT_HP.apply(s.voidsent_hp) as u32,
            voidsent_per_wave: VOIDSENT_PER_WAVE.apply(s.voidsent_per_wave) as usize,
            waves: WAVES.apply(s.waves) as u32,
            open_minutes: OPEN_MINUTES.apply(s.open_minutes) as u32,
        }
    }

    /// How long a camp stays open, in real time.
    pub fn open_for(&self) -> Duration {
        Duration::from_secs_f64(f64::from(self.open_minutes) * SECONDS_PER_EORZEA_MINUTE)
    }
}

impl Default for Rules {
    fn default() -> Self {
        Self::from_settings(&AtomosSection::default())
    }
}

static RULES: OnceLock<Rules> = OnceLock::new();

/// Read `[atomos]` once, at start-up.
pub fn configure(section: &AtomosSection) {
    let r = Rules::from_settings(section);
    tracing::info!(
        voidsent_level = r.voidsent_level,
        voidsent_hp = r.voidsent_hp,
        voidsent_per_wave = r.voidsent_per_wave,
        waves = r.waves,
        open_minutes = r.open_minutes,
        "atomos"
    );
    let _ = RULES.set(r);
}

pub fn rules() -> Rules {
    RULES.get().copied().unwrap_or_default()
}

// --- the schedule -----------------------------------------------------------

/// The opening slot at `unix_seconds`: Eorzean day * 24 + hour while the
/// Eorzean hour is one Atomos opens at, else None.
pub fn opening_slot(unix_seconds: u64) -> Option<u64> {
    let hours = unix_seconds / SECONDS_PER_EORZEA_HOUR;
    OPEN_HOURS.contains(&((hours % 24) as u32)).then_some(hours)
}

/// Real seconds from `unix_seconds` to the next opening hour.
pub fn seconds_to_next_opening(unix_seconds: u64) -> u64 {
    let hours = unix_seconds / SECONDS_PER_EORZEA_HOUR;
    let mut h = hours + 1;
    while !OPEN_HOURS.contains(&((h % 24) as u32)) {
        h += 1;
    }
    h * SECONDS_PER_EORZEA_HOUR - unix_seconds
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// An open camp.
#[derive(Debug, Clone)]
pub struct Open {
    pub atomos: Option<u32>,
    /// Where Atomos hangs; its voidsent ring it.
    pub at: (f32, f32, f32),
    /// The current wave's voidsent.
    pub voidsent: Vec<u32>,
    /// Waves released so far.
    pub waves: u32,
    pub closes_at: Instant,
    /// Opened by `!atomos open`: stays open when the event isn't running.
    pub forced: bool,
}

#[derive(Debug, Clone, Default)]
pub struct CampState {
    pub open: Option<Open>,
    /// The opening slot this camp last opened for, so a camp closed early
    /// doesn't open again inside the same hour.
    pub last_slot: Option<u64>,
}

/// Why a camp closes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Close {
    /// Its time ran out.
    Time,
    /// Its last wave was slain.
    Cleared,
    /// The event stopped.
    EventOver,
    /// A GM closed it.
    Gm,
}

/// What the tick should do at one camp.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Step {
    Nothing,
    Open,
    NextWave,
    Close(Close),
}

/// What camp `st` needs now. `wave_down`: every voidsent of its current
/// wave is dead or gone.
pub fn step(
    st: &CampState,
    event_running: bool,
    slot: Option<u64>,
    now: Instant,
    wave_down: bool,
    rules: &Rules,
) -> Step {
    match &st.open {
        None => match slot {
            Some(s) if event_running && st.last_slot != Some(s) => Step::Open,
            _ => Step::Nothing,
        },
        Some(o) => {
            if !event_running && !o.forced {
                Step::Close(Close::EventOver)
            } else if now >= o.closes_at {
                Step::Close(Close::Time)
            } else if wave_down && o.waves >= rules.waves {
                Step::Close(Close::Cleared)
            } else if wave_down {
                Step::NextWave
            } else {
                Step::Nothing
            }
        }
    }
}

/// Spots in a ring of `n` around (x, z), `r` yalms out, each facing the
/// middle: (x, z, rotation).
pub fn ring(x: f32, z: f32, r: f32, n: usize) -> Vec<(f32, f32, f32)> {
    (0..n)
        .map(|k| {
            let a = std::f32::consts::TAU * k as f32 / n.max(1) as f32;
            let (px, pz) = (x + r * a.sin(), z + r * a.cos());
            (px, pz, (x - px).atan2(z - pz))
        })
        .collect()
}

/// Of `floors` (heights under a spot), the one nearest `near`.
fn nearest(floors: &[f32], near: f32) -> Option<f32> {
    floors
        .iter()
        .copied()
        .min_by(|a, b| (a - near).abs().total_cmp(&(b - near).abs()))
}

/// Where Atomos hangs at `camp`: the first of eight directions,
/// [`ATOMOS_DISTANCE`] out from the aetheryte, whose ground is within
/// [`MAX_STEP`] of the aetheryte's height (`ground` gives the floors under
/// a spot, None when unknown). Unknown ground keeps the aetheryte's height
/// on the first direction.
pub fn atomos_spot(
    camp: &Camp,
    mut ground: impl FnMut(f32, f32) -> Option<Vec<f32>>,
) -> (f32, f32, f32) {
    let mut first = None;
    for k in 0..8 {
        let a = std::f32::consts::TAU * k as f32 / 8.0;
        let (x, z) = (
            camp.x + ATOMOS_DISTANCE * a.sin(),
            camp.z + ATOMOS_DISTANCE * a.cos(),
        );
        match ground(x, z) {
            None => return first.unwrap_or((x, camp.y, z)),
            Some(f) => {
                if let Some(y) = nearest(&f, camp.y) {
                    if (y - camp.y).abs() <= MAX_STEP {
                        return (x, y, z);
                    }
                    first.get_or_insert((x, y, z));
                }
            }
        }
    }
    first.unwrap_or((camp.x + ATOMOS_DISTANCE, camp.y, camp.z))
}

// --- the running event --------------------------------------------------------

#[derive(Debug, Default)]
struct State {
    camps: [CampState; 5],
}

fn state() -> &'static tokio::sync::Mutex<State> {
    static S: OnceLock<tokio::sync::Mutex<State>> = OnceLock::new();
    S.get_or_init(Default::default)
}

/// Whether the Atomos event runs today.
pub fn running() -> bool {
    crate::seasonal::is_active(EVENT)
}

async fn dead_or_gone(registry: &ActorRegistry, ids: &[u32]) -> bool {
    for id in ids {
        if let Some(h) = registry.get(*id).await
            && h.character.read().await.base.current_main_state != crate::actor::MAIN_STATE_DEAD
        {
            return false;
        }
    }
    true
}

/// Every 10 s (the game ticker) and after `!event`: open, refill and close
/// the camps.
pub async fn tick(world: &WorldManager, registry: &ActorRegistry, db: &Database) {
    let running = running();
    let slot = opening_slot(unix_now());
    let rules = rules();
    let mut st = state().lock().await;
    for (i, camp) in CAMPS.iter().enumerate() {
        if running && st.camps[i].open.is_none() {
            // start reading the camp's ground before it is needed
            if let Some(z) = world.zone(camp.zone).await {
                let name = z.read().await.core.zone_name.clone();
                let _ = crate::terrain::floors(&name, camp.x, camp.z);
            }
        }
        let wave_down = match &st.camps[i].open {
            Some(o) => dead_or_gone(registry, &o.voidsent).await,
            None => false,
        };
        match step(
            &st.camps[i],
            running,
            slot,
            Instant::now(),
            wave_down,
            &rules,
        ) {
            Step::Nothing => {}
            Step::Open => {
                st.camps[i].last_slot = slot;
                if world.zone(camp.zone).await.is_some() {
                    let open = open_camp(world, registry, db, i, false, &rules).await;
                    st.camps[i].open = Some(open);
                }
            }
            Step::NextWave => {
                if let Some(o) = st.camps[i].open.as_mut() {
                    release_wave(world, registry, db, i, o, &rules).await;
                }
            }
            Step::Close(why) => {
                if let Some(o) = st.camps[i].open.take() {
                    close_camp(world, registry, db, i, o, why).await;
                }
            }
        }
    }
}

/// `!atomos open`: open camp `i` now (an error line when it is open
/// already or its zone isn't loaded).
pub async fn open_now(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    i: usize,
) -> Result<String, String> {
    let mut st = state().lock().await;
    if st.camps[i].open.is_some() {
        return Err(format!("{} is open already", CAMPS[i].name));
    }
    if world.zone(CAMPS[i].zone).await.is_none() {
        return Err(format!("{}'s zone isn't loaded", CAMPS[i].name));
    }
    let rules = rules();
    let open = open_camp(world, registry, db, i, true, &rules).await;
    let n = open.voidsent.len();
    let atomos = open.atomos.is_some();
    st.camps[i].open = Some(open);
    Ok(format!(
        "{} open: {}{n} voidsent (wave 1 of {}), closes in {} Eorzean minutes",
        CAMPS[i].name,
        if atomos {
            "Atomos and "
        } else {
            "no Atomos (no class path), "
        },
        rules.waves,
        rules.open_minutes
    ))
}

/// `!atomos close`: close camp `i` now. False when it isn't open.
pub async fn close_now(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    i: usize,
) -> bool {
    let mut st = state().lock().await;
    let Some(o) = st.camps[i].open.take() else {
        return false;
    };
    close_camp(world, registry, db, i, o, Close::Gm).await;
    true
}

/// One line per camp for `!atomos`.
pub async fn describe(registry: &ActorRegistry) -> String {
    let st = state().lock().await;
    let now = Instant::now();
    let mut lines = Vec::new();
    for (i, camp) in CAMPS.iter().enumerate() {
        let line = match &st.camps[i].open {
            None => format!("{} ({}): closed", camp.name, camp.key),
            Some(o) => {
                let mut alive = 0;
                for id in &o.voidsent {
                    if !dead_or_gone(registry, std::slice::from_ref(id)).await {
                        alive += 1;
                    }
                }
                let left = o.closes_at.saturating_duration_since(now).as_secs_f64()
                    / SECONDS_PER_EORZEA_MINUTE;
                format!(
                    "{} ({}): open, wave {} with {alive} voidsent standing, {:.0} Eorzean minutes left{}",
                    camp.name,
                    camp.key,
                    o.waves,
                    left,
                    if o.forced { " (opened by a GM)" } else { "" }
                )
            }
        };
        lines.push(line);
    }
    let unix = unix_now();
    let next = seconds_to_next_opening(unix);
    format!(
        "Atomos event {} (special event work {}). Next opening (06:00/12:00 ET) in {}m{:02}s. {}",
        if running() { "running" } else { "not running" },
        crate::seasonal::special_event_work(),
        next / 60,
        next % 60,
        lines.join("; ")
    )
}

async fn zone_ground(world: &WorldManager, zone: u32) -> Option<String> {
    let z = world.zone(zone).await?;
    let name = z.read().await.core.zone_name.clone();
    Some(name)
}

fn ground_at(zone_name: &Option<String>, x: f32, z: f32) -> Option<Vec<f32>> {
    let name = zone_name.as_ref()?;
    match crate::terrain::floors(name, x, z) {
        crate::terrain::Floors::Known(f) => Some(f),
        crate::terrain::Floors::Unknown => None,
    }
}

fn next_id(zone: u32) -> u32 {
    (4 << 28) | (zone << 19) | crate::processor::gm_spawn::next_number()
}

async fn open_camp(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    i: usize,
    forced: bool,
    rules: &Rules,
) -> Open {
    let camp = &CAMPS[i];
    let ground = zone_ground(world, camp.zone).await;
    let (ax, ay, az) = atomos_spot(camp, |x, z| ground_at(&ground, x, z));
    // Atomos faces the camp
    let facing = (camp.x - ax).atan2(camp.z - az);
    let atomos = crate::runtime::class_spawn::ClassMonster {
        class_id: ATOMOS_CLASS,
        tag: "atomos",
        level: ATOMOS_LEVEL,
        hp: ATOMOS_HP,
        hostile: false,
        any_level: false,
        cannot_fall: true,
        drop_list_id: 0,
    };
    let id = next_id(camp.zone);
    let atomos_id = crate::runtime::class_spawn::spawn(
        db,
        world,
        registry,
        &atomos,
        camp.zone,
        id,
        (ax, ay, az, facing),
    )
    .await
    .then_some(id);
    let mut open = Open {
        atomos: atomos_id,
        at: (ax, ay, az),
        voidsent: Vec::new(),
        waves: 0,
        closes_at: Instant::now() + rules.open_for(),
        forced,
    };
    release_wave(world, registry, db, i, &mut open, rules).await;
    tracing::info!(
        camp = camp.name,
        zone = camp.zone,
        x = ax,
        y = ay,
        z = az,
        atomos = atomos_id.is_some(),
        voidsent = open.voidsent.len(),
        forced,
        "atomos: camp open"
    );
    tell_zone(
        world,
        registry,
        db,
        camp.zone,
        format!(
            "Atomos has appeared over {}! Voidsent pour into the camp.",
            camp.name
        ),
    )
    .await;
    open
}

async fn release_wave(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    i: usize,
    open: &mut Open,
    rules: &Rules,
) {
    let camp = &CAMPS[i];
    let ground = zone_ground(world, camp.zone).await;
    let (ax, ay, az) = open.at;
    // the last wave's corpses fade on their own; forget them
    open.voidsent.clear();
    for (k, (x, z, rot)) in ring(ax, az, VOIDSENT_RING, rules.voidsent_per_wave)
        .into_iter()
        .enumerate()
    {
        let (class_id, tag) = VOIDSENT[k % VOIDSENT.len()];
        let y = ground_at(&ground, x, z)
            .and_then(|f| nearest(&f, ay))
            .filter(|y| (y - ay).abs() <= MAX_STEP * 2.0)
            .unwrap_or(ay);
        let m = crate::runtime::class_spawn::ClassMonster {
            class_id,
            tag,
            level: rules.voidsent_level,
            hp: rules.voidsent_hp,
            hostile: true,
            // the AI's level check takes every target for level 1, so a
            // level-60 monster without this never picks a fight; townsfolk
            // are never its quarry either way
            any_level: true,
            cannot_fall: false,
            drop_list_id: VOIDSENT_DROP_LIST,
        };
        let id = next_id(camp.zone);
        // face away from Atomos, into the camp
        let out = rot + std::f32::consts::PI;
        if crate::runtime::class_spawn::spawn(
            db,
            world,
            registry,
            &m,
            camp.zone,
            id,
            (x, y, z, out),
        )
        .await
        {
            open.voidsent.push(id);
        }
    }
    open.waves += 1;
    if open.waves > 1 {
        tell_zone(
            world,
            registry,
            db,
            camp.zone,
            format!(
                "More voidsent spill from Atomos over {} (wave {} of {}).",
                camp.name, open.waves, rules.waves
            ),
        )
        .await;
    }
    tracing::info!(
        camp = camp.name,
        wave = open.waves,
        voidsent = open.voidsent.len(),
        "atomos: wave released"
    );
}

async fn close_camp(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    i: usize,
    open: Open,
    why: Close,
) {
    let camp = &CAMPS[i];
    for id in open.atomos.iter().chain(open.voidsent.iter()) {
        // gone already when it died and its corpse faded
        crate::runtime::quest_apply::apply_despawn_actor(camp.zone, *id, registry, world).await;
    }
    tracing::info!(
        camp = camp.name,
        ?why,
        waves = open.waves,
        "atomos: camp closed"
    );
    let text = match why {
        Close::Cleared => format!(
            "The last of the voidsent falls. Atomos withdraws from {}.",
            camp.name
        ),
        _ => format!("Atomos closes and fades from the sky over {}.", camp.name),
    };
    tell_zone(world, registry, db, camp.zone, text).await;
}

/// A system line to every player in `zone`.
async fn tell_zone(
    world: &WorldManager,
    registry: &ActorRegistry,
    db: &Database,
    zone: u32,
    message: String,
) {
    use crate::social::{ChatKind, SocialEvent, SocialOutbox, dispatch_social_event};
    let mut ob = SocialOutbox::new();
    for s in world.all_sessions().await {
        if s.current_zone_id != zone || s.current_private_area_name.is_some() {
            continue;
        }
        if let Some(h) = registry.by_session(s.id).await {
            ob.push(SocialEvent::ChatSystemToPlayer {
                target_actor_id: h.actor_id,
                kind: ChatKind::System,
                message: message.clone(),
            });
        }
    }
    for e in ob.drain() {
        dispatch_social_event(&e, registry, world, db).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn open(forced: bool, waves: u32, closes_in: i64) -> CampState {
        let now = Instant::now();
        let closes_at = if closes_in >= 0 {
            now + Duration::from_secs(closes_in as u64)
        } else {
            now - Duration::from_secs((-closes_in) as u64)
        };
        CampState {
            open: Some(Open {
                atomos: Some(1),
                at: (0.0, 0.0, 0.0),
                voidsent: vec![2, 3],
                waves,
                closes_at,
                forced,
            }),
            last_slot: Some(10),
        }
    }

    #[test]
    fn opens_at_six_and_noon_eorzean_time() {
        let h = SECONDS_PER_EORZEA_HOUR;
        let day = 24 * h;
        assert_eq!(opening_slot(5 * h), None);
        assert_eq!(opening_slot(6 * h), Some(6));
        assert_eq!(opening_slot(7 * h - 1), Some(6));
        assert_eq!(opening_slot(7 * h), None);
        assert_eq!(opening_slot(12 * h + 30), Some(12));
        assert_eq!(opening_slot(18 * h), None);
        assert_eq!(opening_slot(0), None);
        assert_eq!(opening_slot(day + 6 * h), Some(30));
        assert_eq!(seconds_to_next_opening(0), 6 * h);
        assert_eq!(seconds_to_next_opening(6 * h), 6 * h);
        assert_eq!(seconds_to_next_opening(12 * h + 5), 18 * h - 5);
    }

    #[test]
    fn a_camp_opens_once_per_slot_and_only_while_the_event_runs() {
        let r = Rules::default();
        let now = Instant::now();
        let closed = CampState::default();
        assert_eq!(step(&closed, true, Some(6), now, false, &r), Step::Open);
        assert_eq!(step(&closed, false, Some(6), now, false, &r), Step::Nothing);
        assert_eq!(step(&closed, true, None, now, false, &r), Step::Nothing);
        let again = CampState {
            open: None,
            last_slot: Some(6),
        };
        assert_eq!(step(&again, true, Some(6), now, false, &r), Step::Nothing);
        assert_eq!(step(&again, true, Some(12), now, false, &r), Step::Open);
    }

    #[test]
    fn waves_follow_each_other_until_the_last_then_it_closes() {
        let r = Rules::default();
        let now = Instant::now();
        assert_eq!(
            step(&open(false, 1, 600), true, None, now, false, &r),
            Step::Nothing
        );
        assert_eq!(
            step(&open(false, 1, 600), true, None, now, true, &r),
            Step::NextWave
        );
        assert_eq!(
            step(&open(false, r.waves, 600), true, None, now, true, &r),
            Step::Close(Close::Cleared)
        );
        assert_eq!(
            step(&open(false, 1, -1), true, None, now, false, &r),
            Step::Close(Close::Time)
        );
    }

    #[test]
    fn the_event_stopping_closes_all_but_gm_opened_camps() {
        let r = Rules::default();
        let now = Instant::now();
        assert_eq!(
            step(&open(false, 1, 600), false, None, now, false, &r),
            Step::Close(Close::EventOver)
        );
        assert_eq!(
            step(&open(true, 1, 600), false, None, now, false, &r),
            Step::Nothing
        );
        assert_eq!(
            step(&open(true, 1, -1), false, None, now, false, &r),
            Step::Close(Close::Time)
        );
    }

    #[test]
    fn open_time_is_eorzean_minutes() {
        let r = Rules::default();
        assert_eq!(r.open_minutes, 190);
        // 190 Eorzean minutes = 3 h 10 m Eorzean = 554 real seconds
        assert_eq!(r.open_for().as_secs(), 554);
    }

    #[test]
    fn settings_hold_to_their_limits() {
        let r = Rules::from_settings(&AtomosSection {
            voidsent_level: 500,
            voidsent_hp: 0,
            voidsent_per_wave: 40,
            waves: 0,
            open_minutes: 5000,
        });
        assert_eq!(r.voidsent_level, 99);
        assert_eq!(r.voidsent_hp, 1);
        assert_eq!(r.voidsent_per_wave, 12);
        assert_eq!(r.waves, 1);
        assert_eq!(r.open_minutes, 360);
        assert_eq!(Rules::default().voidsent_level, 60);
    }

    #[test]
    fn camps_are_the_five_of_dev1485() {
        let ids: Vec<u32> = CAMPS.iter().map(|c| c.aetheryte).collect();
        assert_eq!(ids, [1_280_092, 1_280_064, 1_280_065, 1_280_032, 1_280_034]);
        assert_eq!(camp_by_key("Dragonhead"), Some(0));
        assert_eq!(camp_by_key("emerald moss"), Some(1));
        assert_eq!(camp_by_key("Camp Crimson Bark"), Some(2));
        assert_eq!(camp_by_key("black"), Some(3));
        assert_eq!(camp_by_key("horizon"), Some(4));
        assert_eq!(camp_by_key("bluefog"), None);
        assert_eq!(camp_in_zone(170), Some(3));
        assert_eq!(camp_in_zone(175), None);
    }

    #[test]
    fn atomos_hangs_over_level_ground_near_the_camp() {
        let camp = CAMPS[0];
        // the first direction drops away, the second is level
        let mut asked = 0;
        let (x, y, z) = atomos_spot(&camp, |_, _| {
            asked += 1;
            Some(if asked == 1 {
                vec![camp.y - 30.0]
            } else {
                vec![camp.y - 30.0, camp.y + 1.0]
            })
        });
        assert_eq!(y, camp.y + 1.0);
        let d = ((x - camp.x).powi(2) + (z - camp.z).powi(2)).sqrt();
        assert!((d - ATOMOS_DISTANCE).abs() < 0.01);
        // ground not known yet: the aetheryte's height, first direction
        let (x, y, z) = atomos_spot(&camp, |_, _| None);
        assert_eq!((x, y), (camp.x, camp.y));
        assert!((z - (camp.z + ATOMOS_DISTANCE)).abs() < 0.01);
    }

    #[test]
    fn voidsent_ring_atomos_facing_in() {
        let spots = ring(0.0, 0.0, 6.0, 4);
        assert_eq!(spots.len(), 4);
        for (x, z, rot) in spots {
            assert!(((x * x + z * z).sqrt() - 6.0).abs() < 1e-4);
            // facing the middle
            let (fx, fz) = (rot.sin(), rot.cos());
            assert!(fx * -x + fz * -z > 5.9);
        }
    }
}
