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

//! World-placement record for gathering nodes. Parallel to
//! [`crate::zone::SpawnLocation`] for BattleNpcs/ENPCs, but carries the
//! `harvest_node_id` + `harvest_type` fields the minigame needs to
//! resolve a physical node back to its template pool.

/// `!mine` — ore outcrops. Retail action id 20001.
pub const HARVEST_TYPE_MINE: u32 = 22002;
/// `!log` — tree stumps, bushes. Retail action id 20002.
pub const HARVEST_TYPE_LOG: u32 = 22003;
/// `!fish` — schools of fish, squid beds, coral. Retail action id 20003.
pub const HARVEST_TYPE_FISH: u32 = 22004;
/// `!quarry` — stone / dye / pigment deposits. Command 22006 in the
/// 1.23b command sheet (22005 is the unused "Herd"); retired in 1.23b.
pub const HARVEST_TYPE_QUARRY: u32 = 22006;
/// `!harvest` (botany) — grass, flowers, small animals. Command 22007;
/// retired in 1.23b.
pub const HARVEST_TYPE_HARVEST: u32 = 22007;
/// `!spearfish` — shallow-water spear fishing. Command 22008; retired
/// in 1.23b.
pub const HARVEST_TYPE_SPEARFISH: u32 = 22008;

/// Numeric ids garlemald stores internally for the six 1.x harvest
/// actions. Matches Meteor's `DummyCommand.lua` convention; the
/// `load_gather_node_spawns` loader rejects any other value so the
/// seed table can't wander into unknown territory.
pub fn is_valid_harvest_type(ty: u32) -> bool {
    matches!(
        ty,
        HARVEST_TYPE_MINE
            | HARVEST_TYPE_LOG
            | HARVEST_TYPE_FISH
            | HARVEST_TYPE_QUARRY
            | HARVEST_TYPE_HARVEST
            | HARVEST_TYPE_SPEARFISH
    )
}

#[derive(Debug, Clone, PartialEq)]
pub struct GatherNodeSpawn {
    pub id: u32,
    pub actor_class_id: u32,
    pub unique_id: String,
    pub zone_id: u32,
    pub private_area_name: String,
    pub private_area_level: i32,
    pub position: (f32, f32, f32),
    pub rotation: f32,
    /// FK into `gamedata_gather_nodes.id` — selects the template
    /// (grade/attempts/item pool) the DummyCommand minigame will run
    /// against this physical placement.
    pub harvest_node_id: u32,
    /// Which harvest command opens the minigame. See
    /// [`HARVEST_TYPE_MINE`] / [`HARVEST_TYPE_LOG`] / [`HARVEST_TYPE_FISH`].
    pub harvest_type: u32,
    /// `server_gather_node_quests`: the `(quest_id, sequence)` steps this
    /// point is for. Empty: an ordinary point everyone sees.
    pub quest_gates: Vec<(u32, u32)>,
}

/// Whether a quest-only point is open to a player holding `held`
/// `(quest_id, sequence)` steps: one of its gates names a quest the player
/// holds, at that sequence.
pub fn quest_gate_open(gates: &[(u32, u32)], held: &[(u32, u32)]) -> bool {
    gates.iter().any(|g| held.contains(g))
}

/// The `(quest_id, sequence)` of every quest in a journal.
pub fn held_quest_steps(journal: &crate::actor::quest::QuestJournal) -> Vec<(u32, u32)> {
    journal
        .slots
        .iter()
        .flatten()
        .map(|q| (q.quest_id(), q.get_sequence()))
        .collect()
}

/// Parse the loader's `GROUP_CONCAT` of `questId:sequence` pairs.
pub fn parse_quest_gates(s: &str) -> Vec<(u32, u32)> {
    s.split(',')
        .filter_map(|pair| {
            let (q, seq) = pair.trim().split_once(':')?;
            Some((q.parse().ok()?, seq.parse().ok()?))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quest_gate_opens_only_on_a_listed_step() {
        let gates = parse_quest_gates("110500:10,110500:15");
        assert_eq!(gates, vec![(110500, 10), (110500, 15)]);
        assert!(quest_gate_open(&gates, &[(110001, 0), (110500, 15)]));
        assert!(!quest_gate_open(&gates, &[(110500, 20)]), "step over");
        assert!(!quest_gate_open(&gates, &[]), "quest not held");
        assert!(parse_quest_gates("").is_empty());
        assert!(parse_quest_gates("junk,1:x").is_empty());
    }

    #[test]
    fn harvest_type_validation_accepts_all_six_commands() {
        assert!(is_valid_harvest_type(HARVEST_TYPE_MINE));
        assert!(is_valid_harvest_type(HARVEST_TYPE_LOG));
        assert!(is_valid_harvest_type(HARVEST_TYPE_FISH));
        assert!(is_valid_harvest_type(HARVEST_TYPE_QUARRY));
        assert!(is_valid_harvest_type(HARVEST_TYPE_HARVEST));
        assert!(is_valid_harvest_type(HARVEST_TYPE_SPEARFISH));
        assert!(!is_valid_harvest_type(0));
        assert!(!is_valid_harvest_type(22001));
        assert!(!is_valid_harvest_type(22005)); // Herd
        assert!(!is_valid_harvest_type(22009));
    }
}
