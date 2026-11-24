// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Host-chosen gameplay settings: `[progression]` and `[storage]` in
//! `settings/map.toml`.
//!
//! Every default is the 1.23b retail value. Each setting has a
//! [`Bounded`] spec with its safe and hard range; [`install`] checks the
//! configured values once at start-up (logging anything non-retail, risky or
//! clamped) and publishes them for the code that reads them through
//! [`current`]. The table in `settings/README.md` documents the same limits.

use std::sync::RwLock;

use common::bounded::Bounded;
use serde::Deserialize;

/// `[progression]` as written in the settings file. Numbers are `i64` so any
/// integer parses: a value out of range is clamped with an error in the log
/// rather than refusing to start.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ProgressionSection {
    pub level_cap: i64,
    pub exp_rate_percent: i64,
    pub crafting_gathering_exp_rate_percent: i64,
}

impl Default for ProgressionSection {
    fn default() -> Self {
        Self {
            level_cap: LEVEL_CAP.retail,
            exp_rate_percent: EXP_RATE.retail,
            crafting_gathering_exp_rate_percent: CRAFT_GATHER_EXP_RATE.retail,
        }
    }
}

/// `[storage]` as written in the settings file.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct StorageSection {
    pub bag_slots: i64,
}

impl Default for StorageSection {
    fn default() -> Self {
        Self {
            bag_slots: BAG_SLOTS.retail,
        }
    }
}

/// The highest level a class reaches by earning EXP.
pub const LEVEL_CAP: Bounded<i64> = Bounded {
    name: "progression.level_cap",
    retail: 50,
    safe: 1..=50,
    hard: 1..=50,
    risky: "",
    breaks: "the client's EXP bar and the server's level, stat and ability \
             tables end at level 50",
};

/// EXP multiplier for battle classes (and any class but the crafters and
/// gatherers): kills, quests, leves, GM grants.
pub const EXP_RATE: Bounded<i64> = Bounded {
    name: "progression.exp_rate_percent",
    retail: 100,
    safe: 0..=1000,
    hard: 0..=10_000,
    risky: "above 10x, one kill or quest levels a character several times",
    breaks: "past 100x a single quest reward covers the whole 1-50 curve \
             (1,781,150 EXP), so higher means nothing",
};

/// EXP multiplier for the crafters (29-36) and gatherers (39-41).
pub const CRAFT_GATHER_EXP_RATE: Bounded<i64> = Bounded {
    name: "progression.crafting_gathering_exp_rate_percent",
    retail: 100,
    safe: 0..=1000,
    hard: 0..=10_000,
    risky: "above 10x, one synthesis or gathering levels a class several times",
    breaks: "past 100x a single synthesis covers the whole 1-50 curve, \
             so higher means nothing",
};

/// How many slots of the normal bag (package 0) take new items.
pub const BAG_SLOTS: Bounded<i64> = Bounded {
    name: "storage.bag_slots",
    retail: 200,
    safe: 50..=200,
    hard: 1..=200,
    risky: "below 50 the bag fills fast and quest rewards, purchases and \
            gathered items that don't fit are lost",
    breaks: "the 1.23b client crashes at every login with an item at bag \
             slot 200 or above",
};

/// The gameplay settings in force.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Gameplay {
    /// 1..=50.
    pub level_cap: i16,
    /// Percent, 0..=10000.
    pub exp_rate_percent: u32,
    /// Percent, 0..=10000.
    pub crafting_gathering_exp_rate_percent: u32,
    /// 1..=200.
    pub bag_slots: u16,
}

impl Gameplay {
    /// Retail 1.23b.
    pub const RETAIL: Self = Self {
        level_cap: 50,
        exp_rate_percent: 100,
        crafting_gathering_exp_rate_percent: 100,
        bag_slots: 200,
    };

    /// The settings file's values checked against their limits (logged).
    pub fn from_sections(p: &ProgressionSection, s: &StorageSection) -> Self {
        // `apply` clamps into the hard range, so the casts can't truncate.
        Self {
            level_cap: LEVEL_CAP.apply(p.level_cap) as i16,
            exp_rate_percent: EXP_RATE.apply(p.exp_rate_percent) as u32,
            crafting_gathering_exp_rate_percent: CRAFT_GATHER_EXP_RATE
                .apply(p.crafting_gathering_exp_rate_percent)
                as u32,
            bag_slots: BAG_SLOTS.apply(s.bag_slots) as u16,
        }
    }

    /// The EXP rate for `class_id`.
    pub fn exp_rate_for(&self, class_id: u8) -> u32 {
        if is_crafter_or_gatherer(class_id) {
            self.crafting_gathering_exp_rate_percent
        } else {
            self.exp_rate_percent
        }
    }
}

impl Default for Gameplay {
    fn default() -> Self {
        Self::RETAIL
    }
}

static CURRENT: RwLock<Gameplay> = RwLock::new(Gameplay::RETAIL);

/// The gameplay settings in force (retail until [`install`]).
pub fn current() -> Gameplay {
    *CURRENT.read().unwrap_or_else(|e| e.into_inner())
}

/// Put `g` in force and log a one-line summary.
pub fn install(g: Gameplay) {
    *CURRENT.write().unwrap_or_else(|e| e.into_inner()) = g;
    tracing::info!(
        level_cap = g.level_cap,
        exp_rate_percent = g.exp_rate_percent,
        crafting_gathering_exp_rate_percent = g.crafting_gathering_exp_rate_percent,
        bag_slots = g.bag_slots,
        "gameplay settings",
    );
}

/// Crafters (carpenter..culinarian, 29-36) and gatherers (miner, botanist,
/// fisher, 39-41).
pub fn is_crafter_or_gatherer(class_id: u8) -> bool {
    matches!(class_id, 29..=36 | 39..=41)
}

/// `exp` scaled by `percent`, rounded up (a gain never rounds away to
/// nothing at a positive rate, like the retail bonus folds). Losses and
/// zero pass through unscaled.
pub fn scale_exp(exp: i32, percent: u32) -> i32 {
    if exp <= 0 {
        return exp;
    }
    let scaled = (i64::from(exp) * i64::from(percent) + 99) / 100;
    scaled.min(i64::from(i32::MAX)) as i32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_retail() {
        let g = Gameplay::from_sections(&ProgressionSection::default(), &StorageSection::default());
        assert_eq!(g, Gameplay::RETAIL);
    }

    #[test]
    fn shipped_settings_file_is_retail() {
        let raw = include_str!("../../settings/default/map.toml");
        let cfg: crate::config::Config = toml::from_str(raw).expect("map.toml parses");
        let g = Gameplay::from_sections(&cfg.progression, &cfg.storage);
        assert_eq!(g, Gameplay::RETAIL);
    }

    #[test]
    fn out_of_range_values_are_clamped() {
        let g = Gameplay::from_sections(
            &ProgressionSection {
                level_cap: 99,
                exp_rate_percent: -50,
                crafting_gathering_exp_rate_percent: 1_000_000,
            },
            &StorageSection { bag_slots: 500 },
        );
        assert_eq!(g.level_cap, 50);
        assert_eq!(g.exp_rate_percent, 0);
        assert_eq!(g.crafting_gathering_exp_rate_percent, 10_000);
        assert_eq!(g.bag_slots, 200);
    }

    #[test]
    fn exp_at_200_percent_doubles_a_grant() {
        assert_eq!(scale_exp(750, 200), 1500);
        assert_eq!(scale_exp(750, 100), 750);
        assert_eq!(scale_exp(750, 0), 0);
        // rounds up: 1 EXP at 150% is 2, not 1
        assert_eq!(scale_exp(1, 150), 2);
        // losses aren't boosted
        assert_eq!(scale_exp(-40, 200), -40);
        // no overflow at the hard maximum
        assert_eq!(scale_exp(i32::MAX, 10_000), i32::MAX);
    }

    #[test]
    fn crafters_and_gatherers_get_their_own_rate() {
        let g = Gameplay {
            exp_rate_percent: 300,
            crafting_gathering_exp_rate_percent: 150,
            ..Gameplay::RETAIL
        };
        assert_eq!(g.exp_rate_for(2), 300); // pugilist
        assert_eq!(g.exp_rate_for(22), 300); // thaumaturge
        assert_eq!(g.exp_rate_for(29), 150); // carpenter
        assert_eq!(g.exp_rate_for(36), 150); // culinarian
        assert_eq!(g.exp_rate_for(39), 150); // miner
        assert_eq!(g.exp_rate_for(41), 150); // fisher
    }
}
