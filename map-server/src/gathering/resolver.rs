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

//! [`GatherResolver`] — the read-only gathering catalog.
//!
//! Mirrors the shape of [`crate::crafting::RecipeResolver`]:
//!   * owns the `GatherNode`/`GatherNodeItem` maps once,
//!   * is wrapped in an `Arc` inside [`crate::lua::catalogs::Catalogs`] so
//!     every Lua VM shares one copy,
//!   * exposes a single "build aim slots" pivot that converts a node id
//!     + its items into the 11-slot table the DummyCommand minigame
//!       feeds through `callClientFunction`.

use std::collections::HashMap;

use super::node::{AIM_SLOTS, AimSlot, GatherNode, GatherNodeItem};

#[derive(Debug, Default)]
pub struct GatherResolver {
    nodes: HashMap<u32, GatherNode>,
    items: HashMap<u32, GatherNodeItem>,
    /// Fish catalog id -> the bait and lure catalog ids it takes
    /// (`gamedata_fishing_tackle`). A fish with no entry takes any tackle.
    tackle: HashMap<u32, Vec<u32>>,
}

impl GatherResolver {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn from_parts(
        nodes: impl IntoIterator<Item = GatherNode>,
        items: impl IntoIterator<Item = GatherNodeItem>,
    ) -> Self {
        Self {
            nodes: nodes.into_iter().map(|n| (n.id, n)).collect(),
            items: items.into_iter().map(|i| (i.id, i)).collect(),
            tackle: HashMap::new(),
        }
    }

    /// Add `(fish, tackle)` pairs: which bait or lure each fish takes.
    pub fn with_tackle(mut self, pairs: impl IntoIterator<Item = (u32, u32)>) -> Self {
        for (fish, tackle) in pairs {
            let list = self.tackle.entry(fish).or_default();
            if !list.contains(&tackle) {
                list.push(tackle);
            }
        }
        self
    }

    /// The bait and lures a fish takes, in catalog order; empty when none
    /// were recorded (the fish takes anything).
    pub fn fish_tackle(&self, fish_catalog_id: u32) -> &[u32] {
        self.tackle
            .get(&fish_catalog_id)
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }

    /// Does this fish bite on this bait or lure? A fish with no recorded
    /// tackle bites on anything.
    pub fn fish_bites_on(&self, fish_catalog_id: u32, tackle_catalog_id: u32) -> bool {
        let list = self.fish_tackle(fish_catalog_id);
        list.is_empty() || list.contains(&tackle_catalog_id)
    }

    pub fn insert_node(&mut self, node: GatherNode) {
        self.nodes.insert(node.id, node);
    }

    pub fn insert_item(&mut self, item: GatherNodeItem) {
        self.items.insert(item.id, item);
    }

    pub fn get_node(&self, id: u32) -> Option<&GatherNode> {
        self.nodes.get(&id)
    }

    pub fn get_item(&self, id: u32) -> Option<&GatherNodeItem> {
        self.items.get(&id)
    }

    pub fn num_nodes(&self) -> usize {
        self.nodes.len()
    }

    pub fn num_items(&self) -> usize {
        self.items.len()
    }

    pub fn iter_nodes(&self) -> impl Iterator<Item = &GatherNode> {
        self.nodes.values()
    }

    pub fn iter_items(&self) -> impl Iterator<Item = &GatherNodeItem> {
        self.items.values()
    }

    /// Build the [`AimSlot`]; 11 positions matching the retail aim gauge.
    /// Each of the node's item keys is resolved to its item row and
    /// placed at its aim slot; the remaining slots default to `empty`.
    ///
    /// Returns `None` if the node id isn't in the catalog. Unknown item
    /// keys inside a known node are silently skipped (they leave their
    /// target slot empty).
    pub fn build_aim_slots(&self, node_id: u32) -> Option<[AimSlot; AIM_SLOTS]> {
        let node = self.nodes.get(&node_id)?;
        let mut slots = [AimSlot::empty(); AIM_SLOTS];
        // Two items of one pool can share an aim (the 1.x data puts every
        // Quarry/Harvest/Spearfish item at 50). Items whose aim is free
        // take it first; the rest take the nearest free slot, so every
        // item stays reachable.
        let items: Vec<&GatherNodeItem> = node
            .active_item_keys()
            .filter_map(|key| self.items.get(&key))
            .collect();
        let mut moved = Vec::new();
        for item in items {
            let want = item.aim_slot() - 1;
            if want < AIM_SLOTS && slots[want].empty {
                slots[want] = AimSlot::from_item(item);
            } else {
                moved.push(item);
            }
        }
        for item in moved {
            if let Some(idx) = nearest_free_slot(&slots, item.aim_slot() - 1) {
                slots[idx] = AimSlot::from_item(item);
            }
        }
        Some(slots)
    }
}

/// The free slot nearest `want` (lower first on a tie), if any is left.
fn nearest_free_slot(slots: &[AimSlot; AIM_SLOTS], want: usize) -> Option<usize> {
    let want = want.min(AIM_SLOTS - 1);
    (0..AIM_SLOTS).find_map(|d| {
        [want.checked_sub(d), Some(want + d)]
            .into_iter()
            .flatten()
            .find(|&i| i < AIM_SLOTS && slots[i].empty)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fish_bite_only_on_recorded_tackle() {
        let r = GatherResolver::new().with_tackle([(10, 1), (10, 2), (10, 1), (11, 3)]);
        assert_eq!(r.fish_tackle(10), &[1, 2], "pairs dedupe, order kept");
        assert!(r.fish_bites_on(10, 2));
        assert!(!r.fish_bites_on(10, 3));
        assert!(r.fish_bites_on(11, 3));
        // No record: the fish takes anything.
        assert!(r.fish_tackle(12).is_empty());
        assert!(r.fish_bites_on(12, 99));
    }

    fn mk_node(id: u32, keys: &[u32]) -> GatherNode {
        let mut item_keys = [0u32; 11];
        for (i, k) in keys.iter().enumerate().take(11) {
            item_keys[i] = *k;
        }
        GatherNode {
            id,
            grade: 1,
            attempts: 2,
            item_keys,
        }
    }

    fn mk_item(id: u32, aim: u8) -> GatherNodeItem {
        GatherNodeItem {
            id,
            item_catalog_id: 10000000 + id,
            remainder: 80,
            aim,
            sweetspot: 30,
            max_yield: 3,
        }
    }

    #[test]
    fn resolver_round_trips_node_and_item() {
        let r = GatherResolver::from_parts(
            [mk_node(1001, &[1, 2, 3])],
            [mk_item(1, 0), mk_item(2, 50), mk_item(3, 100)],
        );
        assert_eq!(r.num_nodes(), 1);
        assert_eq!(r.num_items(), 3);
        assert!(r.get_node(1001).is_some());
        assert!(r.get_node(9999).is_none());
        assert_eq!(r.get_item(2).unwrap().aim, 50);
    }

    /// Items sharing an aim each get their own slot (the nearest free
    /// one), so none of them is overwritten and lost.
    #[test]
    fn build_aim_slots_spreads_items_that_share_an_aim() {
        let r = GatherResolver::from_parts(
            [mk_node(2063, &[1, 2, 3, 4])],
            [
                mk_item(1, 50),
                mk_item(2, 50),
                mk_item(3, 50),
                mk_item(4, 60),
            ],
        );
        let slots = r.build_aim_slots(2063).unwrap();
        let keys: Vec<u32> = slots
            .iter()
            .filter(|s| !s.empty)
            .map(|s| s.item_key)
            .collect();
        assert_eq!(keys.len(), 4, "every item keeps a slot: {keys:?}");
        assert_eq!(slots[5].item_key, 1, "the first item keeps its own aim");
        assert_eq!(slots[6].item_key, 4, "an item alone on its aim keeps it");
        assert_eq!(slots[4].item_key, 2, "the next takes the nearest free slot");
        assert_eq!(slots[3].item_key, 3);
    }

    #[test]
    fn build_aim_slots_pivots_into_eleven_slots() {
        let r = GatherResolver::from_parts(
            [mk_node(1001, &[1, 2, 3])],
            [mk_item(1, 0), mk_item(2, 50), mk_item(3, 100)],
        );
        let slots = r.build_aim_slots(1001).unwrap();
        assert!(!slots[0].empty);
        assert_eq!(slots[0].item_key, 1);
        assert!(slots[1].empty);
        assert!(!slots[5].empty);
        assert_eq!(slots[5].item_key, 2);
        assert!(!slots[10].empty);
        assert_eq!(slots[10].item_key, 3);
        assert_eq!(slots.iter().filter(|s| !s.empty).count(), 3);
    }

    #[test]
    fn build_aim_slots_returns_none_for_unknown_node() {
        let r = GatherResolver::from_parts([mk_node(1001, &[1])], [mk_item(1, 0)]);
        assert!(r.build_aim_slots(9999).is_none());
    }

    #[test]
    fn build_aim_slots_skips_unknown_item_keys() {
        // Node references key 99 but only key 1 is in the items map.
        let r = GatherResolver::from_parts([mk_node(1001, &[1, 99])], [mk_item(1, 0)]);
        let slots = r.build_aim_slots(1001).unwrap();
        assert_eq!(slots.iter().filter(|s| !s.empty).count(), 1);
        assert_eq!(slots[0].item_key, 1);
    }

    #[test]
    fn build_aim_slots_keeps_both_items_on_a_colliding_slot() {
        // Two items both landing on slot 1: the second moves to slot 2
        // instead of overwriting the first.
        let r =
            GatherResolver::from_parts([mk_node(1001, &[1, 2])], [mk_item(1, 0), mk_item(2, 5)]);
        let slots = r.build_aim_slots(1001).unwrap();
        let filled: usize = slots.iter().filter(|s| !s.empty).count();
        assert_eq!(filled, 2, "both items stay reachable");
        assert_eq!(slots[0].item_key, 1);
        assert_eq!(slots[1].item_key, 2);
    }
}
