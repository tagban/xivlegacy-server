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

//! Anima, the 1.x teleport currency (Gamer Escape, "Anima (1.x)"):
//!
//! - A character recovers 1 anima every 4 hours of real time, logged in or
//!   not, up to 100.
//! - Teleporting to another region costs 6, within the current region 4.
//! - Teleporting to a city's aetheryte plaza (or a favored destination)
//!   costs half: 3 from another region, 2 from the same one.
//! - An aetheryte crystal to one of its own aetherial gates (and a gate back
//!   to its crystal) costs 1.
//! - Return, and accepting another player's teleport, are free.
//!
//! Favored destinations are not built in this server; when they are, they
//! take the plaza's half price ([`teleport_cost`]'s `half` case).
//!
//! The amount is kept with the unix time it was last brought up to date
//! (`characters_anima`, migration 018); [`regen`] works out what has come
//! back since, so no timer runs. Scripts read it with `player:GetAnima()`
//! and spend it with `player:SpendAnima(n)` (TeleportCommand.lua,
//! AetheryteParent.lua, AetheryteChild.lua).
//!
//! `[anima]` in settings/map.toml ([`Rules`]) sets the cap (`max_stored`,
//! 200 shipped) and the time per anima (`regen_minutes`, 240 as in 1.x),
//! and `enabled = false` makes teleports free with the menu showing full.

use crate::database::Database;
use crate::runtime::actor_registry::ActorRegistry;

/// The most anima a character could store in 1.x.
pub const RETAIL_MAX: u8 = 100;
/// Seconds of real time per anima regained in 1.x (4 hours).
pub const RETAIL_REGEN_SECS: i64 = 4 * 60 * 60;

/// How anima works on this server: `[anima]` in settings/map.toml
/// (crate::config::AnimaSection), set once at start-up by [`configure`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rules {
    /// Off: teleports and gate hops cost nothing and everyone holds `max`.
    pub enabled: bool,
    /// The most anima a character can store, 100..=255 (sent and stored
    /// as a byte).
    pub max: u8,
    /// Seconds per anima regained, at least 60.
    pub regen_secs: i64,
}

impl Rules {
    /// From the settings, held to sane values: `max_stored` to 100..=255,
    /// `regen_minutes` to at least 1.
    pub fn from_settings(enabled: bool, max_stored: i64, regen_minutes: i64) -> Self {
        Self {
            enabled,
            max: max_stored.clamp(i64::from(RETAIL_MAX), i64::from(u8::MAX)) as u8,
            regen_secs: regen_minutes.clamp(1, i64::MAX / 60) * 60,
        }
    }
}

impl Default for Rules {
    fn default() -> Self {
        let a = crate::config::AnimaSection::default();
        Self::from_settings(a.enabled, a.max_stored, a.regen_minutes)
    }
}

static RULES: std::sync::OnceLock<Rules> = std::sync::OnceLock::new();

/// Set the rules from settings/map.toml (once, at start-up).
pub fn configure(section: &crate::config::AnimaSection) {
    let rules = Rules::from_settings(section.enabled, section.max_stored, section.regen_minutes);
    if i64::from(rules.max) != section.max_stored
        || rules.regen_secs != section.regen_minutes.saturating_mul(60)
    {
        tracing::warn!(
            max_stored = section.max_stored,
            regen_minutes = section.regen_minutes,
            used_max = rules.max,
            used_regen_secs = rules.regen_secs,
            "[anima] held to max_stored 100..=255, regen_minutes >= 1"
        );
    }
    tracing::info!(
        enabled = rules.enabled,
        max_stored = rules.max,
        regen_secs = rules.regen_secs,
        "anima"
    );
    let _ = RULES.set(rules);
}

/// The rules in force ([`Rules::default`] before [`configure`]).
pub fn rules() -> Rules {
    RULES.get().copied().unwrap_or_default()
}

/// The most anima a character can store now.
pub fn max() -> u8 {
    rules().max
}

/// The anima a character holds now, from what is stored: [`regen`] with
/// the rules in force, or the full `max` with anima off.
pub fn held(anima: u8, stamp: i64, now: i64) -> (u8, i64) {
    let r = rules();
    if !r.enabled {
        return (r.max, now);
    }
    regen(anima, stamp, now, r.max, r.regen_secs)
}
/// Teleport costs.
pub const COST_OTHER_REGION: u8 = 6;
pub const COST_SAME_REGION: u8 = 4;
/// An aetheryte crystal to one of its own gates, or a gate to its crystal.
pub const COST_GATE_HOP: u8 = 1;

/// The city aetheryte plazas: Limsa Lominsa, Gridania, Ul'dah (the CAPs in
/// scripts/lua/aetheryte.lua's `aetheryteTeleportPositions`, zones 230,
/// 206 and 175).
pub const CITY_PLAZAS: [u32; 3] = [1_280_001, 1_280_061, 1_280_031];

/// Now, in unix seconds.
pub fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Bring `(anima, stamp)` up to `now`: one anima per whole `period`
/// seconds since `stamp`, up to `max`. The stamp moves forward by the whole
/// periods counted, so a part-finished period carries on; at or above `max`
/// it is `now` (nothing builds up while full). An amount above `max` (the
/// cap was lowered) is kept, not cut, and regains nothing until spent below
/// it. A stamp in the future (a clock set back) counts as no time passed.
/// Only the stamp is stored, so a changed `period` applies to the time
/// since it at once.
pub fn regen(anima: u8, stamp: i64, now: i64, max: u8, period: i64) -> (u8, i64) {
    if anima >= max {
        return (anima, now);
    }
    let period = period.max(1);
    let periods = (now - stamp).max(0) / period;
    let total = i64::from(anima) + periods;
    if total >= i64::from(max) {
        (max, now)
    } else {
        (total as u8, stamp + periods * period)
    }
}

/// The teleport menu's region (1 La Noscea, 2 Coerthas, 3 the Black
/// Shroud, 4 Thanalan, 5 Mor Dhona; TeleportCommand.lua's
/// `teleportMenuToAetheryte` order) for a zone, or 0 for one in none of
/// them (the sea, the inn room, the GM cottage, the gaol).
///
/// From `regionId` in common/sql/data/server_zones.sql: 101 La Noscea,
/// 102 Coerthas, 103 the Black Shroud, 104 Thanalan, 105 Mor Dhona; the
/// city interiors go with their city (202 Limsa Lominsa's markets and
/// Maelstrom Command, 204 Gridania's, 205 Ul'dah's), the battle instances
/// with theirs (106 Central Shroud, 107 Ul'dah) and 109 Rivenroad
/// (roc1Field*) with Coerthas.
pub fn zone_region(zone_id: u32) -> u8 {
    ZONE_REGIONS
        .iter()
        .find(|(_, zones)| zones.contains(&zone_id))
        .map_or(0, |(region, _)| *region)
}

/// The zones of each teleport menu region (see [`zone_region`]).
const ZONE_REGIONS: [(u8, &[u32]); 5] = [
    // regionId 101, 202
    (
        1,
        &[
            128, 129, 130, 131, 132, 133, 134, 135, 137, 138, 140, 141, 204, 205, 230, 232, 235,
            236, 237, 248, 260, 261, 269, 270,
        ],
    ),
    // regionId 102, 109
    (
        2,
        &[
            143, 144, 145, 146, 147, 148, 231, 239, 245, 250, 252, 253, 256, 257, 267, 268,
        ],
    ),
    // regionId 103, 106, 204
    (
        3,
        &[
            150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 164, 165, 166, 167,
            168, 206, 207, 208, 234, 238, 247, 258, 259,
        ],
    ),
    // regionId 104, 107, 205
    (
        4,
        &[
            170, 171, 172, 173, 174, 175, 176, 178, 179, 180, 181, 182, 184, 185, 186, 187, 188,
            209, 210, 211, 233, 240, 246, 249, 254, 255, 262, 263, 265,
        ],
    ),
    // regionId 105
    (5, &[190, 251, 264, 266]),
];

/// The teleport menu's region of an aetheryte (its actor class id), from
/// the blocks in scripts/lua/aetheryte.lua: 1280001-1280030 La Noscea,
/// 1280031-1280060 Thanalan, 1280061-1280090 the Black Shroud,
/// 1280091-1280120 Coerthas, 1280121-1280125 Mor Dhona. 0 for anything
/// else.
pub fn aetheryte_region(aetheryte_id: u32) -> u8 {
    match aetheryte_id {
        1_280_001..=1_280_030 => 1,
        1_280_031..=1_280_060 => 4,
        1_280_061..=1_280_090 => 3,
        1_280_091..=1_280_120 => 2,
        1_280_121..=1_280_125 => 5,
        _ => 0,
    }
}

/// What teleporting to `dest_aetheryte` costs from a zone in region
/// `from_region` (see [`zone_region`]; 0 counts as another region).
pub fn teleport_cost(from_region: u8, dest_aetheryte: u32) -> u8 {
    let same = from_region != 0 && from_region == aetheryte_region(dest_aetheryte);
    let full = if same {
        COST_SAME_REGION
    } else {
        COST_OTHER_REGION
    };
    if CITY_PLAZAS.contains(&dest_aetheryte) {
        full / 2
    } else {
        full
    }
}

/// `anima` less `cost`, or `None` when there is not enough.
pub fn spend_from(anima: u8, cost: u8) -> Option<u8> {
    anima.checked_sub(cost)
}

/// Spend `cost` anima of the player's (`player:SpendAnima`) and store it.
/// The amount left, or `None` when they hold less (nothing changes then).
pub async fn spend(
    player_id: u32,
    cost: u8,
    registry: &ActorRegistry,
    db: &Database,
) -> Option<u8> {
    if !rules().enabled {
        // Anima off: nothing to spend or store.
        return Some(max());
    }
    let handle = registry.get(player_id).await?;
    let now = now();
    let (left, stamp) = {
        let mut c = handle.character.write().await;
        let (have, stamp) = held(c.chara.anima, c.chara.anima_stamp, now);
        let Some(left) = spend_from(have, cost) else {
            // Keep the regained anima even when the spend fails.
            c.chara.anima = have;
            c.chara.anima_stamp = stamp;
            tracing::info!(player = player_id, cost, have, "anima: not enough");
            return None;
        };
        c.chara.anima = left;
        c.chara.anima_stamp = stamp;
        (left, stamp)
    };
    if let Err(e) = db.save_anima(player_id, left, stamp).await {
        tracing::warn!(player = player_id, error = %e, "anima: save failed");
    }
    tracing::info!(player = player_id, cost, left, "anima spent");
    Some(left)
}

#[cfg(test)]
mod tests {
    use super::*;

    const T: i64 = 1_800_000_000;
    const MAX: u8 = RETAIL_MAX;
    const P: i64 = RETAIL_REGEN_SECS;

    #[test]
    fn regen_counts_whole_periods_and_keeps_the_part() {
        // 2 periods and 1 hour in: +2, the hour carries over.
        let (a, s) = regen(50, T, T + 2 * P + 3600, MAX, P);
        assert_eq!(a, 52);
        assert_eq!(s, T + 2 * P);
        // The next anima comes 3 hours later, not 4.
        assert_eq!(regen(a, s, T + 3 * P - 1, MAX, P).0, 52);
        assert_eq!(regen(a, s, T + 3 * P, MAX, P).0, 53);
    }

    #[test]
    fn regen_nothing_before_a_full_period() {
        assert_eq!(regen(10, T, T + P - 1, MAX, P), (10, T));
        assert_eq!(regen(10, T, T, MAX, P), (10, T));
    }

    #[test]
    fn regen_stops_at_max_and_the_stamp_tracks_now() {
        assert_eq!(regen(99, T, T + 10 * P + 5, MAX, P), (MAX, T + 10 * P + 5));
        assert_eq!(regen(MAX, T, T + 7, MAX, P), (MAX, T + 7));
        // Empty for 400 hours fills right up.
        assert_eq!(regen(0, T, T + 100 * P, MAX, P), (MAX, T + 100 * P));
    }

    #[test]
    fn a_raised_cap_regenerates_past_retail() {
        // qol anima_max 200: a character full at 100 keeps going.
        assert_eq!(regen(100, T, T + 3 * P, 200, P), (103, T + 3 * P));
        assert_eq!(regen(150, T, T + 60 * P, 200, P), (200, T + 60 * P));
        assert_eq!(regen(200, T, T + 7, 200, P), (200, T + 7));
    }

    #[test]
    fn settings_are_held_to_sane_values() {
        let r = Rules::from_settings(true, 200, 240);
        assert_eq!((r.max, r.regen_secs), (200, RETAIL_REGEN_SECS));
        assert_eq!(Rules::from_settings(true, 50, 240).max, 100);
        assert_eq!(Rules::from_settings(true, 1000, 240).max, 255);
        assert_eq!(Rules::from_settings(true, 200, 0).regen_secs, 60);
        assert_eq!(Rules::from_settings(true, 200, -5).regen_secs, 60);
        assert!(Rules::from_settings(true, 200, i64::MAX).regen_secs > 0);
    }

    #[test]
    fn shipped_settings() {
        let c: crate::config::Config =
            toml::from_str(include_str!("../../../settings/default/map.toml")).unwrap();
        let a = c.anima;
        assert_eq!(
            Rules::from_settings(a.enabled, a.max_stored, a.regen_minutes),
            Rules {
                enabled: true,
                max: 200,
                regen_secs: RETAIL_REGEN_SECS
            }
        );
        assert_eq!(Rules::default(), Rules::from_settings(true, 200, 240));
    }

    #[test]
    fn a_changed_period_applies_to_the_time_since_the_stamp() {
        // Stored at 50, 6 hours ago: 1 back at 4 h a period, 6 at 1 h.
        assert_eq!(regen(50, T, T + 6 * 3600, 200, P).0, 51);
        assert_eq!(regen(50, T, T + 6 * 3600, 200, 3600), (56, T + 6 * 3600));
    }

    #[test]
    fn a_lowered_cap_keeps_what_is_held() {
        // The module switched off with 150 held: kept, nothing regained,
        // and the clock runs again once it is spent below 100.
        assert_eq!(regen(150, 0, T, MAX, P), (150, T));
        let left = spend_from(150, 60).unwrap();
        assert_eq!(regen(left, T, T + P, MAX, P).0, 91);
    }

    #[test]
    fn regen_ignores_a_stamp_in_the_future() {
        assert_eq!(regen(40, T + 1000, T, MAX, P), (40, T + 1000));
    }

    #[test]
    fn spending_full_anima_starts_the_clock_at_the_spend() {
        // Full at T: the stamp is T, so the first anima back is at T + 4 h.
        let (have, stamp) = regen(MAX, 0, T, MAX, P);
        let left = spend_from(have, 6).unwrap();
        assert_eq!((left, stamp), (94, T));
        assert_eq!(regen(left, stamp, T + P, MAX, P).0, 95);
    }

    #[test]
    fn spend_refuses_when_short() {
        assert_eq!(spend_from(5, 6), None);
        assert_eq!(spend_from(6, 6), Some(0));
        assert_eq!(spend_from(1, COST_GATE_HOP), Some(0));
    }

    #[test]
    fn zone_regions() {
        assert_eq!(zone_region(230), 1); // Limsa Lominsa
        assert_eq!(zone_region(128), 1); // Lower La Noscea
        assert_eq!(zone_region(134), 1); // Limsa's Market Wards
        assert_eq!(zone_region(143), 2); // Coerthas Central Highlands
        assert_eq!(zone_region(206), 3); // Gridania
        assert_eq!(zone_region(150), 3); // Central Shroud
        assert_eq!(zone_region(175), 4); // Ul'dah
        assert_eq!(zone_region(170), 4); // Central Thanalan
        assert_eq!(zone_region(190), 5); // Mor Dhona
        assert_eq!(zone_region(244), 0); // inn room
        assert_eq!(zone_region(200), 0); // the ferry
    }

    #[test]
    fn every_aetheryte_zone_is_in_its_aetherytes_region() {
        // (aetheryte, zone) pairs from aetheryteTeleportPositions.
        for (id, zone) in [
            (1_280_001, 230),
            (1_280_002, 128),
            (1_280_006, 135),
            (1_280_018, 131),
            (1_280_020, 132),
            (1_280_031, 175),
            (1_280_032, 170),
            (1_280_054, 178),
            (1_280_061, 206),
            (1_280_062, 150),
            (1_280_083, 158),
            (1_280_092, 143),
            (1_280_096, 148),
            (1_280_121, 190),
            (1_280_125, 190),
        ] {
            assert_eq!(
                aetheryte_region(id),
                zone_region(zone),
                "aetheryte {id} in zone {zone}"
            );
        }
    }

    #[test]
    fn teleport_costs() {
        // Lower La Noscea (region 1).
        let from = zone_region(128);
        assert_eq!(teleport_cost(from, 1_280_003), 4); // Camp Skull Valley, same region
        assert_eq!(teleport_cost(from, 1_280_001), 2); // Limsa's plaza, same region: half
        assert_eq!(teleport_cost(from, 1_280_061), 3); // Gridania's plaza, other region: half
        assert_eq!(teleport_cost(from, 1_280_031), 3); // Ul'dah's plaza
        assert_eq!(teleport_cost(from, 1_280_092), 6); // Camp Dragonhead, other region
        assert_eq!(teleport_cost(from, 1_280_121), 6); // Camp Brittlebark
        // Ul'dah to Ul'dah's own plaza and a Thanalan camp.
        assert_eq!(teleport_cost(zone_region(175), 1_280_031), 2);
        assert_eq!(teleport_cost(zone_region(175), 1_280_033), 4);
        // From nowhere (the inn room) everything is another region.
        assert_eq!(teleport_cost(0, 1_280_002), 6);
        assert_eq!(teleport_cost(0, 1_280_001), 3);
    }
}
