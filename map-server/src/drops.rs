// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Monster drops: the `server_drop_lists` table, loaded once at start-up,
//! and the roll when a monster falls.
//!
//! A monster uses its group's `dropListId`, or, when that is 0, the list
//! whose id is its actor class id. Each row rolls on its own: its chance
//! (per 10000) times the host's `[drops] drop_rate_percent`, and for a rare
//! row `rare_drop_percent` too, capped at certain. A dropped item rolls HQ
//! at its `hqChance` times `rare_drop_percent`. Gil rows (item 1000001) pay
//! their amount at `[economy] gil_drop_percent`. See `crate::gameplay`.

use std::collections::HashMap;
use std::sync::{OnceLock, RwLock};

use crate::gameplay::Gameplay;

/// Gil's item id.
pub const GIL: u32 = 1_000_001;
/// Quality of an HQ (+1) item.
pub const QUALITY_HQ: u8 = 2;
/// `rarity` of a rare row.
pub const RARITY_RARE: u8 = 2;

/// One row of a drop list.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DropEntry {
    pub item_id: u32,
    pub quantity_min: u32,
    pub quantity_max: u32,
    /// Per 10000.
    pub chance: u32,
    /// 0 common, 1 uncommon, 2 rare.
    pub rarity: u8,
    /// Per 10000.
    pub hq_chance: u32,
}

/// One thing a kill gives.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Drop {
    Item {
        item_id: u32,
        quantity: i32,
        quality: u8,
    },
    Gil(i32),
}

/// Roll `entries` once. `roll(n)` returns a number in `0..n` (random in play).
pub fn roll(entries: &[DropEntry], g: &Gameplay, mut roll: impl FnMut(u32) -> u32) -> Vec<Drop> {
    let mut out = Vec::new();
    for e in entries {
        let lo = e.quantity_min.max(1);
        let hi = e.quantity_max.max(lo);
        if e.item_id == GIL {
            // gil rows: listed chance only; the amount takes the gil rate
            if roll(10_000) >= e.chance.min(10_000) {
                continue;
            }
            let amount = lo + roll(hi - lo + 1);
            let gil = g
                .gil_reward(i64::from(amount))
                .clamp(0, i64::from(i32::MAX)) as i32;
            if gil > 0 {
                out.push(Drop::Gil(gil));
            }
            continue;
        }
        if roll(10_000) >= g.drop_chance(e.chance, e.rarity >= RARITY_RARE) {
            continue;
        }
        let quantity = (lo + roll(hi - lo + 1)).min(i32::MAX as u32) as i32;
        let quality = if roll(10_000) < g.hq_chance(e.hq_chance) {
            QUALITY_HQ
        } else {
            1
        };
        out.push(Drop::Item {
            item_id: e.item_id,
            quantity,
            quality,
        });
    }
    out
}

/// The list a monster uses: its group's, else the one named by its class.
pub fn list_id(group_drop_list_id: u32, actor_class_id: u32) -> u32 {
    if group_drop_list_id != 0 {
        group_drop_list_id
    } else {
        actor_class_id
    }
}

fn lists() -> &'static RwLock<HashMap<u32, Vec<DropEntry>>> {
    static L: OnceLock<RwLock<HashMap<u32, Vec<DropEntry>>>> = OnceLock::new();
    L.get_or_init(Default::default)
}

/// Put the loaded drop lists in force.
pub fn install(map: HashMap<u32, Vec<DropEntry>>) {
    *lists().write().unwrap_or_else(|e| e.into_inner()) = map;
}

/// A drop list's rows (empty for an unknown list).
pub fn list(id: u32) -> Vec<DropEntry> {
    lists()
        .read()
        .unwrap_or_else(|e| e.into_inner())
        .get(&id)
        .cloned()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    const ORE: DropEntry = DropEntry {
        item_id: 10_001_006,
        quantity_min: 1,
        quantity_max: 1,
        chance: 1000,
        rarity: 0,
        hq_chance: 100,
    };
    const GEM: DropEntry = DropEntry {
        item_id: 10_009_999,
        quantity_min: 1,
        quantity_max: 1,
        chance: 200,
        rarity: RARITY_RARE,
        hq_chance: 0,
    };

    /// A fixed sequence of rolls.
    fn rolls(seq: &[u32]) -> impl FnMut(u32) -> u32 + '_ {
        let mut i = 0;
        move |n| {
            let v = seq[i % seq.len()] % n;
            i += 1;
            v
        }
    }

    #[test]
    fn a_roll_under_the_chance_drops() {
        // ORE: chance roll 999 < 1000 drops; quantity roll; HQ roll 5000 misses
        let got = roll(&[ORE], &Gameplay::RETAIL, rolls(&[999, 0, 5000]));
        assert_eq!(
            got,
            vec![Drop::Item {
                item_id: ORE.item_id,
                quantity: 1,
                quality: 1
            }]
        );
        // 1000 is not under 1000
        assert!(roll(&[ORE], &Gameplay::RETAIL, rolls(&[1000])).is_empty());
    }

    #[test]
    fn drop_rate_doubles_the_chance() {
        let g = Gameplay {
            drop_rate_percent: 200,
            ..Gameplay::RETAIL
        };
        // 1500 misses at retail (1000), hits at 200% (2000)
        assert!(roll(&[ORE], &Gameplay::RETAIL, rolls(&[1500])).is_empty());
        assert_eq!(roll(&[ORE], &g, rolls(&[1500, 0, 9999])).len(), 1);
    }

    #[test]
    fn chance_is_capped_at_certain() {
        let g = Gameplay {
            drop_rate_percent: 10_000,
            ..Gameplay::RETAIL
        };
        // the highest roll still drops
        assert_eq!(roll(&[ORE], &g, rolls(&[9999, 0, 9999])).len(), 1);
    }

    #[test]
    fn rare_boost_touches_rare_rows_and_hq_only() {
        let g = Gameplay {
            rare_drop_percent: 500,
            ..Gameplay::RETAIL
        };
        // GEM 200 -> 1000 at 500%: a roll of 900 now drops
        assert!(roll(&[GEM], &Gameplay::RETAIL, rolls(&[900])).is_empty());
        assert_eq!(roll(&[GEM], &g, rolls(&[900, 0, 9999])).len(), 1);
        // ORE (common) keeps 1000: a roll of 1200 misses either way
        assert!(roll(&[ORE], &g, rolls(&[1200])).is_empty());
        // ORE's HQ chance 100 -> 500: an HQ roll of 300 makes it HQ
        assert_eq!(
            roll(&[ORE], &g, rolls(&[0, 0, 300])),
            vec![Drop::Item {
                item_id: ORE.item_id,
                quantity: 1,
                quality: QUALITY_HQ
            }]
        );
    }

    #[test]
    fn quantity_is_within_the_range() {
        let shards = DropEntry {
            item_id: 1_000_006,
            quantity_min: 1,
            quantity_max: 6,
            chance: 10_000,
            rarity: 0,
            hq_chance: 0,
        };
        for q in 0..6 {
            match roll(&[shards], &Gameplay::RETAIL, rolls(&[0, q, 0]))[0] {
                Drop::Item { quantity, .. } => assert_eq!(quantity, q as i32 + 1),
                other => panic!("{other:?}"),
            }
        }
    }

    #[test]
    fn gil_rows_pay_at_the_gil_rate() {
        let gil = DropEntry {
            item_id: GIL,
            quantity_min: 10,
            quantity_max: 20,
            chance: 10_000,
            rarity: 0,
            hq_chance: 0,
        };
        assert_eq!(
            roll(&[gil], &Gameplay::RETAIL, rolls(&[0, 5])),
            vec![Drop::Gil(15)]
        );
        let g = Gameplay {
            gil_drop_percent: 300,
            drop_rate_percent: 0,
            ..Gameplay::RETAIL
        };
        // the drop rate doesn't touch gil rows; the gil rate does
        assert_eq!(roll(&[gil], &g, rolls(&[0, 5])), vec![Drop::Gil(45)]);
    }

    #[test]
    fn a_group_list_wins_over_the_class_list() {
        assert_eq!(list_id(17, 2_101_111), 17);
        assert_eq!(list_id(0, 2_101_111), 2_101_111);
    }
}
