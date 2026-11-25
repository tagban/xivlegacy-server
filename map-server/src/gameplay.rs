// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Host-chosen gameplay settings: `[progression]`, `[storage]`, `[economy]`
//! and `[drops]` in `settings/map.toml`.
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

/// `[economy]` as written in the settings file.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct EconomySection {
    pub shop_price_percent: i64,
    pub chocobo_price_percent: i64,
    pub gil_drop_percent: i64,
}

impl Default for EconomySection {
    fn default() -> Self {
        Self {
            shop_price_percent: SHOP_PRICE.retail,
            chocobo_price_percent: CHOCOBO_PRICE.retail,
            gil_drop_percent: GIL_DROP.retail,
        }
    }
}

/// `[drops]` as written in the settings file.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct DropsSection {
    pub drop_rate_percent: i64,
    pub rare_drop_percent: i64,
}

impl Default for DropsSection {
    fn default() -> Self {
        Self {
            drop_rate_percent: DROP_RATE.retail,
            rare_drop_percent: RARE_DROP.retail,
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

/// NPC shop prices in gil (not seals or guild marks). The window shows the
/// client's own retail price; the purchase message and the charge use this.
pub const SHOP_PRICE: Bounded<i64> = Bounded {
    name: "economy.shop_price_percent",
    retail: 100,
    safe: 50..=300,
    hard: 0..=1000,
    risky: "the shop window still shows retail prices, so a price far from \
            them surprises players at the till",
    breaks: "past 10x a stack of the dearest goods (99 x 514,800 gil) \
             passes the 32-bit gil limit",
};

/// Chocobo gil costs (the rental fee, retail 800 gil).
pub const CHOCOBO_PRICE: Bounded<i64> = Bounded {
    name: "economy.chocobo_price_percent",
    retail: 100,
    safe: 0..=500,
    hard: 0..=10_000,
    risky: "above 5x a rental costs more than new players earn in an hour",
    breaks: "past 100x the fee means nothing but a locked menu",
};

/// Gil from monsters, leves and treasure chests.
pub const GIL_DROP: Bounded<i64> = Bounded {
    name: "economy.gil_drop_percent",
    retail: 100,
    safe: 0..=1000,
    hard: 0..=10_000,
    risky: "above 10x gil stops mattering and shop goods are free in effect",
    breaks: "past 100x a few leves pass the 32-bit gil limit",
};

/// The chance of each monster item drop. The final chance is capped at 100%.
pub const DROP_RATE: Bounded<i64> = Bounded {
    name: "drops.drop_rate_percent",
    retail: 100,
    safe: 0..=500,
    hard: 0..=10_000,
    risky: "above 5x common materials flood bags and the market",
    breaks: "past 100x even a 1-in-10,000 drop is certain, so higher means nothing",
};

/// An extra multiplier for rare-tier drops and the HQ chance of every drop.
pub const RARE_DROP: Bounded<i64> = Bounded {
    name: "drops.rare_drop_percent",
    retail: 100,
    safe: 0..=500,
    hard: 0..=10_000,
    risky: "above 5x rare items stop being rare",
    breaks: "past 100x even a 1-in-10,000 rare drop is certain, so higher means nothing",
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
    /// Percent, 0..=1000.
    pub shop_price_percent: u32,
    /// Percent, 0..=10000.
    pub chocobo_price_percent: u32,
    /// Percent, 0..=10000.
    pub gil_drop_percent: u32,
    /// Percent, 0..=10000.
    pub drop_rate_percent: u32,
    /// Percent, 0..=10000.
    pub rare_drop_percent: u32,
}

impl Gameplay {
    /// Retail 1.23b.
    pub const RETAIL: Self = Self {
        level_cap: 50,
        exp_rate_percent: 100,
        crafting_gathering_exp_rate_percent: 100,
        bag_slots: 200,
        shop_price_percent: 100,
        chocobo_price_percent: 100,
        gil_drop_percent: 100,
        drop_rate_percent: 100,
        rare_drop_percent: 100,
    };

    /// The settings file's values checked against their limits (logged).
    pub fn from_config(cfg: &crate::config::Config) -> Self {
        let (p, s, e, d) = (&cfg.progression, &cfg.storage, &cfg.economy, &cfg.drops);
        // `apply` clamps into the hard range, so the casts can't truncate.
        Self {
            level_cap: LEVEL_CAP.apply(p.level_cap) as i16,
            exp_rate_percent: EXP_RATE.apply(p.exp_rate_percent) as u32,
            crafting_gathering_exp_rate_percent: CRAFT_GATHER_EXP_RATE
                .apply(p.crafting_gathering_exp_rate_percent)
                as u32,
            bag_slots: BAG_SLOTS.apply(s.bag_slots) as u16,
            shop_price_percent: SHOP_PRICE.apply(e.shop_price_percent) as u32,
            chocobo_price_percent: CHOCOBO_PRICE.apply(e.chocobo_price_percent) as u32,
            gil_drop_percent: GIL_DROP.apply(e.gil_drop_percent) as u32,
            drop_rate_percent: DROP_RATE.apply(d.drop_rate_percent) as u32,
            rare_drop_percent: RARE_DROP.apply(d.rare_drop_percent) as u32,
        }
    }

    /// What a gil shop charges for goods whose retail price is `retail`
    /// (all units) and which an NPC buys back for `sell_back` (all units).
    /// Never below the buy-back price, so buying to sell back can't make
    /// gil; never above retail on that account either.
    pub fn shop_buy_price(&self, retail: i64, sell_back: i64) -> i64 {
        let floor = sell_back.clamp(0, retail.max(0));
        percent_of(retail, self.shop_price_percent).max(floor)
    }

    /// A chocobo gil cost whose retail price is `retail`.
    pub fn chocobo_price(&self, retail: i64) -> i64 {
        percent_of(retail, self.chocobo_price_percent)
    }

    /// Gil from a monster, leve or chest whose retail amount is `retail`.
    pub fn gil_reward(&self, retail: i64) -> i64 {
        percent_of(retail, self.gil_drop_percent)
    }

    /// The chance, per 10000, of a drop entry whose listed chance is
    /// `per_10000`: `drop_rate_percent`, and for a rare entry
    /// `rare_drop_percent` on top, capped at 10000 (certain).
    pub fn drop_chance(&self, per_10000: u32, rare: bool) -> u32 {
        let mut c = u64::from(per_10000) * u64::from(self.drop_rate_percent) / 100;
        if rare {
            c = c * u64::from(self.rare_drop_percent) / 100;
        }
        c.min(10_000) as u32
    }

    /// The HQ chance, per 10000, of a dropped item listed at `per_10000`:
    /// `rare_drop_percent`, capped at 10000.
    pub fn hq_chance(&self, per_10000: u32) -> u32 {
        (u64::from(per_10000) * u64::from(self.rare_drop_percent) / 100).min(10_000) as u32
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
        shop_price_percent = g.shop_price_percent,
        chocobo_price_percent = g.chocobo_price_percent,
        gil_drop_percent = g.gil_drop_percent,
        drop_rate_percent = g.drop_rate_percent,
        rare_drop_percent = g.rare_drop_percent,
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

/// `value` x `percent` / 100, rounded to the nearest whole number.
pub fn percent_of(value: i64, percent: u32) -> i64 {
    (value.saturating_mul(i64::from(percent)) + 50).div_euclid(100)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_retail() {
        let g = Gameplay::from_config(&crate::config::Config::default());
        assert_eq!(g, Gameplay::RETAIL);
    }

    #[test]
    fn shipped_settings_file_is_retail() {
        let raw = include_str!("../../settings/default/map.toml");
        let cfg: crate::config::Config = toml::from_str(raw).expect("map.toml parses");
        let g = Gameplay::from_config(&cfg);
        assert_eq!(g, Gameplay::RETAIL);
    }

    #[test]
    fn out_of_range_values_are_clamped() {
        let cfg = crate::config::Config {
            progression: ProgressionSection {
                level_cap: 99,
                exp_rate_percent: -50,
                crafting_gathering_exp_rate_percent: 1_000_000,
            },
            storage: StorageSection { bag_slots: 500 },
            economy: EconomySection {
                shop_price_percent: 5000,
                chocobo_price_percent: -1,
                gil_drop_percent: 20_000,
            },
            drops: DropsSection {
                drop_rate_percent: 99_999,
                rare_drop_percent: -3,
            },
            ..Default::default()
        };
        let g = Gameplay::from_config(&cfg);
        assert_eq!(g.level_cap, 50);
        assert_eq!(g.exp_rate_percent, 0);
        assert_eq!(g.crafting_gathering_exp_rate_percent, 10_000);
        assert_eq!(g.bag_slots, 200);
        assert_eq!(g.shop_price_percent, 1000);
        assert_eq!(g.chocobo_price_percent, 0);
        assert_eq!(g.gil_drop_percent, 10_000);
        assert_eq!(g.drop_rate_percent, 10_000);
        assert_eq!(g.rare_drop_percent, 0);
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

    #[test]
    fn shop_prices_scale_but_never_below_the_buy_back_price() {
        let half = Gameplay {
            shop_price_percent: 50,
            ..Gameplay::RETAIL
        };
        assert_eq!(Gameplay::RETAIL.shop_buy_price(2700, 270), 2700);
        assert_eq!(half.shop_buy_price(2700, 270), 1350);
        let double = Gameplay {
            shop_price_percent: 200,
            ..Gameplay::RETAIL
        };
        assert_eq!(double.shop_buy_price(2700, 270), 5400);
        // free shops still charge what the NPC pays back
        let free = Gameplay {
            shop_price_percent: 0,
            ..Gameplay::RETAIL
        };
        assert_eq!(free.shop_buy_price(2700, 270), 270);
        // odd data: a buy-back above the price never raises it past retail
        assert_eq!(free.shop_buy_price(100, 500), 100);
        // hard maximum, dearest goods, a full stack: no overflow
        let max = Gameplay {
            shop_price_percent: 1000,
            ..Gameplay::RETAIL
        };
        assert!(max.shop_buy_price(99 * 514_800, 0) < i64::from(i32::MAX));
    }

    #[test]
    fn chocobo_and_gil_scale() {
        let g = Gameplay {
            chocobo_price_percent: 50,
            gil_drop_percent: 300,
            ..Gameplay::RETAIL
        };
        assert_eq!(g.chocobo_price(800), 400);
        assert_eq!(Gameplay::RETAIL.chocobo_price(800), 800);
        assert_eq!(g.gil_reward(140), 420);
        assert_eq!(Gameplay::RETAIL.gil_reward(140), 140);
    }

    #[test]
    fn drop_chances_scale_and_cap_at_certain() {
        let g = Gameplay {
            drop_rate_percent: 200,
            rare_drop_percent: 300,
            ..Gameplay::RETAIL
        };
        assert_eq!(Gameplay::RETAIL.drop_chance(1000, false), 1000);
        assert_eq!(g.drop_chance(1000, false), 2000);
        // rare: both multipliers
        assert_eq!(g.drop_chance(100, true), 600);
        // common entries don't get the rare boost
        assert_eq!(g.drop_chance(100, false), 200);
        // capped at 100%
        assert_eq!(g.drop_chance(8000, false), 10_000);
        assert_eq!(g.drop_chance(4000, true), 10_000);
        // HQ: the rare multiplier only
        assert_eq!(g.hq_chance(100), 300);
        assert_eq!(g.hq_chance(5000), 10_000);
    }
}
