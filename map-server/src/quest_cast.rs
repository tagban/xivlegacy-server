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

//! Quest cast: seeded NPCs that stand in the world only for the players
//! whose quests need them (`server_spawn_location_quests`).
//!
//! A spawn listed there carries one gate per quest. Each gate is one of:
//!
//! - `quest`: open while the player holds the quest, at any step. Used for
//!   the casts of private areas that several Echoes share.
//! - `step`: open while the player holds the quest AND the quest's current
//!   step names this NPC's class (`quest:SetENpc` in its `onStateChange`).
//!   The quest scripts already say who is on stage at each step, so the
//!   cast comes and goes with them; nothing is copied into the data.
//!
//! A spawn is sent to a player when any of its gates is open. A spawn with
//! no gates is for everyone.
//!
//! The spawner tags each live actor with its gates ([`tag_actor`]); the
//! zone-in bundle and the instance stream drop the actors a player's
//! [`QuestView`] doesn't open ([`hidden`]).

use std::collections::{HashMap, HashSet};
use std::sync::{OnceLock, RwLock};

/// When a gate opens. See the module docs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Gate {
    /// While the player holds the quest.
    Quest,
    /// While the quest's current step names the NPC.
    Step,
}

impl Gate {
    pub fn parse(s: &str) -> Option<Self> {
        match s.trim().to_ascii_lowercase().as_str() {
            "quest" => Some(Self::Quest),
            "step" => Some(Self::Step),
            _ => None,
        }
    }
}

/// One `server_spawn_location_quests` row of a spawn.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SpawnQuestGate {
    pub quest_id: u32,
    pub gate: Gate,
}

/// Parse the spawn loader's `GROUP_CONCAT` of `questId:gate` pairs. A
/// pair without a gate (or an unknown one) is a `quest` gate, the table's
/// default; a pair without a quest id is skipped.
pub fn parse_gates(s: &str) -> Vec<SpawnQuestGate> {
    s.split(',')
        .filter_map(|pair| {
            let (quest, gate) = match pair.split_once(':') {
                Some((q, g)) => (q, Gate::parse(g).unwrap_or(Gate::Quest)),
                None => (pair, Gate::Quest),
            };
            Some(SpawnQuestGate {
                quest_id: quest.trim().parse().ok()?,
                gate,
            })
        })
        .collect()
}

/// What a player's journal says about the quest cast: the quests they
/// hold, and the NPC classes each one's current step names.
#[derive(Debug, Clone, Default)]
pub struct QuestView {
    held: HashSet<u32>,
    on_stage: HashSet<(u32, u32)>,
}

impl QuestView {
    pub fn of(journal: &crate::actor::quest::QuestJournal) -> Self {
        let mut view = Self::default();
        for quest in journal.slots.iter().flatten() {
            let quest_id = quest.quest_id();
            view.held.insert(quest_id);
            for class_id in quest.state.current.keys() {
                view.on_stage.insert((quest_id, *class_id));
            }
        }
        view
    }

    /// A view by hand: `held` quests, and `(quest_id, class_id)` pairs the
    /// quests' current steps name.
    #[cfg(test)]
    pub fn from_parts(held: &[u32], on_stage: &[(u32, u32)]) -> Self {
        Self {
            held: held.iter().copied().collect(),
            on_stage: on_stage.iter().copied().collect(),
        }
    }
}

/// Whether a spawn of `class_id` with these gates goes to a player with
/// this view.
pub fn gate_open(gates: &[SpawnQuestGate], class_id: u32, view: &QuestView) -> bool {
    gates.is_empty()
        || gates.iter().any(|g| {
            view.held.contains(&g.quest_id)
                && match g.gate {
                    Gate::Quest => true,
                    Gate::Step => view.on_stage.contains(&(g.quest_id, class_id)),
                }
        })
}

/// Live actors with gates: actor id -> (class id, gates).
type Tags = HashMap<u32, (u32, Vec<SpawnQuestGate>)>;

fn tags() -> &'static RwLock<Tags> {
    static TAGS: OnceLock<RwLock<Tags>> = OnceLock::new();
    TAGS.get_or_init(Default::default)
}

/// Remember the gates of spawned actor `actor_id` (of `class_id`). An
/// actor spawned with no gates is forgotten, in case its id was reused.
pub fn tag_actor(actor_id: u32, class_id: u32, gates: &[SpawnQuestGate]) {
    if let Ok(mut t) = tags().write() {
        if gates.is_empty() {
            t.remove(&actor_id);
        } else {
            t.insert(actor_id, (class_id, gates.to_vec()));
        }
    }
}

/// Whether actor `actor_id` is quest cast that a player with this view
/// must not be sent. Untagged actors never are.
pub fn hidden(actor_id: u32, view: &QuestView) -> bool {
    tags().read().is_ok_and(|t| {
        t.get(&actor_id)
            .is_some_and(|(class_id, gates)| !gate_open(gates, *class_id, view))
    })
}

/// Whether any live actor carries gates (the filters skip building a view
/// when none does).
pub fn any_tagged() -> bool {
    tags().read().is_ok_and(|t| !t.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    const COM0G6: u32 = 111_606;
    const GC105: u32 = 111_631;
    const LEWIN: u32 = 1_000_020;
    const CID: u32 = 1_001_572;

    #[test]
    fn parses_gates_with_the_quest_default() {
        assert_eq!(
            parse_gates("111606:step,110010:quest,110081"),
            vec![
                SpawnQuestGate {
                    quest_id: 111_606,
                    gate: Gate::Step
                },
                SpawnQuestGate {
                    quest_id: 110_010,
                    gate: Gate::Quest
                },
                SpawnQuestGate {
                    quest_id: 110_081,
                    gate: Gate::Quest
                },
            ]
        );
        assert_eq!(
            parse_gates("7:odd"),
            vec![SpawnQuestGate {
                quest_id: 7,
                gate: Gate::Quest
            }]
        );
        assert!(parse_gates("").is_empty());
        assert!(parse_gates("x:step").is_empty());
    }

    #[test]
    fn no_gates_is_everyone() {
        assert!(gate_open(&[], LEWIN, &QuestView::default()));
    }

    #[test]
    fn quest_gate_opens_while_the_quest_is_held() {
        let gates = parse_gates("110010:quest");
        assert!(!gate_open(&gates, 1, &QuestView::default()));
        assert!(gate_open(
            &gates,
            1,
            &QuestView::from_parts(&[110_010], &[])
        ));
        assert!(!gate_open(
            &gates,
            1,
            &QuestView::from_parts(&[110_081], &[])
        ));
    }

    #[test]
    fn step_gate_opens_only_while_the_step_names_the_npc() {
        let gates = parse_gates("111606:step");
        // no quest
        assert!(!gate_open(&gates, LEWIN, &QuestView::default()));
        // quest held, but this step doesn't name Lewin
        let off = QuestView::from_parts(&[COM0G6], &[(COM0G6, CID)]);
        assert!(!gate_open(&gates, LEWIN, &off));
        // the step names Lewin
        let on = QuestView::from_parts(&[COM0G6], &[(COM0G6, LEWIN)]);
        assert!(gate_open(&gates, LEWIN, &on));
        // another quest naming Lewin doesn't open this gate
        let other = QuestView::from_parts(&[GC105], &[(GC105, LEWIN)]);
        assert!(!gate_open(&gates, LEWIN, &other));
    }

    #[test]
    fn any_open_gate_is_enough() {
        // Cid at the Lotus Stand: com0g6's cast, also wanted by gc105.
        let gates = parse_gates("111606:step,111631:step");
        let gc105 = QuestView::from_parts(&[GC105], &[(GC105, CID)]);
        assert!(gate_open(&gates, CID, &gc105));
        let gc105_elsewhere = QuestView::from_parts(&[GC105], &[(GC105, LEWIN)]);
        assert!(!gate_open(&gates, CID, &gc105_elsewhere));
    }

    #[test]
    fn tagged_actors_hide_and_untagged_ones_do_not() {
        // ids far from any the spawner hands out, so tests don't collide
        let (lewin, plain) = (0x7F51_0001, 0x7F51_0002);
        tag_actor(lewin, LEWIN, &parse_gates("111606:step"));
        tag_actor(plain, 1_000_234, &[]);
        let nobody = QuestView::default();
        assert!(hidden(lewin, &nobody));
        assert!(!hidden(plain, &nobody));
        assert!(any_tagged());
        let on = QuestView::from_parts(&[COM0G6], &[(COM0G6, LEWIN)]);
        assert!(!hidden(lewin, &on));
        // respawned without gates: forgotten
        tag_actor(lewin, LEWIN, &[]);
        assert!(!hidden(lewin, &nobody));
    }
}
