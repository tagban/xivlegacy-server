// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Quest offers: quests a player can take but hasn't, shown on the NPC who
//! gives them.
//!
//! pmeteor keeps every available quest at `SEQ_ACCEPT` (65535). Its
//! `onStateChange(SEQ_ACCEPT)` names the giver (`quest:SetENpc(giver,
//! QFLAG_TALK)`), the marker goes up on that NPC, and talking to them runs
//! the quest's `onTalk` at `SEQ_ACCEPT`, which shows the offer and calls
//! `player:AcceptQuest(quest)` on a yes. Here the offers live on the
//! character (`Character::quest_offers`), rebuilt at zone-in, whenever
//! the journal changes and when the player's level changes.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use super::PacketProcessor;
use crate::actor::quest::QuestEnpc;
use crate::lua::command::LuaCommand;
use crate::runtime::actor_registry::ActorHandle;

/// pmeteor `SEQ_ACCEPT`: the sequence of a quest that's offered, not taken.
pub(crate) const SEQ_ACCEPT: u32 = 65535;

/// Each quest's offer markers, from its `onStateChange(SEQ_ACCEPT)`. The
/// arm only names the giver, so it's read once per quest and kept.
fn givers() -> &'static Mutex<HashMap<u32, Vec<QuestEnpc>>> {
    static GIVERS: OnceLock<Mutex<HashMap<u32, Vec<QuestEnpc>>>> = OnceLock::new();
    GIVERS.get_or_init(Default::default)
}

/// Whether a quest is offered at its giver. The default-talk carriers
/// (`Dft*`) and the opening tutorials (`Trl*`) never are. The main scenario
/// (`Man*`) is offered only where it follows another quest: the opening
/// quests replace themselves in-script, but from the level 8 quest on, each
/// nation's story is given by its giver once the quest before it is done.
fn is_offerable(script_name: &str, has_prerequisite: bool) -> bool {
    if script_name.starts_with("dft") || script_name.starts_with("trl") {
        return false;
    }
    !script_name.starts_with("man") || has_prerequisite
}

/// Quests that follow any one of several others, which the single
/// `prerequisite` column can't say: Fade to White follows whichever
/// nation's level 13 quest the player finished.
const ANY_OF_PREREQUISITES: &[(u32, &[u32])] = &[(110013, &[110004, 110008, 110012])];

/// The quests any one of which unlocks this one (empty: none needed).
fn prerequisites(quest_id: u32, prerequisite: u32) -> Vec<u32> {
    match ANY_OF_PREREQUISITES.iter().find(|(id, _)| *id == quest_id) {
        Some((_, any)) => any.to_vec(),
        None if prerequisite != 0 => vec![prerequisite],
        None => Vec::new(),
    }
}

/// Whether offers built at `built_at` are out of date for a player now at
/// `level`. Offers never built (before the zone-in builds them) aren't
/// rebuilt here.
fn offers_stale(built_at: Option<i16>, level: i16) -> bool {
    built_at.is_some_and(|built| built != level)
}

/// Grand Company quests by the company's standing. `com0x1`-`com0x6` and
/// the oath `com0x7` are the recruits' arc (their prerequisites chain from
/// the test quest); `com5*` and `gc*` are for sworn members. Anyone sworn
/// to another company is offered none of this one's, and the oath isn't
/// offered twice.
/// The class a guild quest belongs to (Thm200 -> thaumaturge), by script
/// prefix. Each guild offers its quests only to players on that class.
const CLASS_QUESTS: &[(&str, i16)] = &[
    ("pgl", 2),
    ("gla", 3),
    ("exc", 4),
    ("arc", 7),
    ("lnc", 8),
    ("thm", 22),
    ("cnj", 23),
    ("wdk", 29),
    ("bsm", 30),
    ("gld", 32),
    ("tan", 33),
    ("wvr", 34),
    ("alc", 35),
    ("cul", 36),
    ("min", 39),
    ("hrv", 40),
    ("fsh", 41),
];

fn class_gate(script_name: &str, class: i16) -> bool {
    match CLASS_QUESTS
        .iter()
        .find(|(prefix, _)| script_name.starts_with(prefix) && script_name.len() == 6)
    {
        Some((_, needed)) => *needed == class,
        None => true,
    }
}

/// Job quests (`war0j1`-`war0j6` ...): the job, its class and the second
/// class Job 1 asks for at level 15 (the client's own hint,
/// processEventStart_Hint: Marauder 30 and Gladiator 15 for the warrior).
const JOB_QUESTS: &[(&str, i16, u16, usize)] = &[
    ("war0j", 4, 17, 3),
    ("mnk0j", 2, 15, 8),
    ("whm0j", 23, 27, 3),
    ("blm0j", 22, 26, 2),
    ("pld0j", 3, 16, 23),
    ("brd0j", 7, 18, 23),
    ("drg0j", 8, 19, 2),
];

/// Job 1 is offered on the job's class, with the second class at 15 and
/// no job taken up; the later job quests only to the job itself.
fn job_gate(script_name: &str, class: i16, current_job: u16, skill_level: &[i16]) -> bool {
    let Some((prefix, base_class, job, second)) = JOB_QUESTS
        .iter()
        .find(|(prefix, ..)| script_name.starts_with(prefix) && script_name.len() == 6)
    else {
        return true;
    };
    if script_name == format!("{prefix}1") {
        current_job == 0
            && class == *base_class
            && skill_level.get(*second).copied().unwrap_or(0) >= 15
    } else {
        current_job == *job
    }
}

fn company_gate(script_name: &str, chara: &crate::actor::CharaState) -> bool {
    use crate::actor::gc;
    let (nation, kind) = if let Some(rest) = script_name.strip_prefix("com") {
        (
            rest.chars().nth(1),
            rest.get(0..1).unwrap_or("").to_string() + rest.get(2..3).unwrap_or(""),
        )
    } else if let Some(rest) = script_name.strip_prefix("gc") {
        (rest.chars().next(), "gc".to_string())
    } else {
        return true;
    };
    let company = match nation {
        Some('l') => gc::GC_MAELSTROM,
        Some('g') => gc::GC_TWIN_ADDER,
        Some('u') => gc::GC_IMMORTAL_FLAMES,
        _ => return true,
    };
    let rank_in = |g: u8| match g {
        gc::GC_MAELSTROM => chara.gc_rank_limsa,
        gc::GC_TWIN_ADDER => chara.gc_rank_gridania,
        gc::GC_IMMORTAL_FLAMES => chara.gc_rank_uldah,
        _ => 0,
    };
    let sworn_to =
        if gc::is_valid_gc(chara.gc_current) && gc::is_sworn_rank(rank_in(chara.gc_current)) {
            chara.gc_current
        } else {
            gc::GC_NONE
        };
    if sworn_to != gc::GC_NONE && sworn_to != company {
        return false;
    }
    let sworn_here = sworn_to == company;
    match kind.as_str() {
        "07" => !sworn_here,
        "gc" => sworn_here,
        k if k.starts_with('5') => sworn_here,
        _ => true,
    }
}

impl PacketProcessor {
    /// Rebuild the player's offers and put the markers up (or take stale
    /// ones down).
    pub(super) async fn refresh_quest_offers(&self, handle: &ActorHandle) {
        let Some(engine) = self.lua.as_ref() else {
            return;
        };
        let metas: Vec<crate::gamedata::QuestMeta> = match engine.catalogs().quests.read() {
            Ok(m) => m.values().cloned().collect(),
            Err(_) => return,
        };
        let eligible: Vec<u32> = {
            let c = handle.character.read().await;
            let level = c.chara.level.max(0) as u16;
            let journal = &c.quest_journal;
            metas
                .iter()
                .filter(|m| {
                    let name = m.class_name.to_lowercase();
                    let needs = prerequisites(m.id, m.prerequisite);
                    is_offerable(&name, !needs.is_empty())
                        && company_gate(&name, &c.chara)
                        && class_gate(&name, c.chara.class)
                        && job_gate(
                            &name,
                            c.chara.class,
                            c.chara.current_job,
                            &c.battle_save.skill_level,
                        )
                        && !journal.has(m.id)
                        && !journal.is_completed(m.id)
                        && level >= m.min_level
                        && (needs.is_empty() || needs.iter().any(|p| journal.is_completed(*p)))
                        && engine.resolver().quest(&name).exists()
                })
                .map(|m| m.id)
                .collect()
        };

        let mut offers: HashMap<u32, (u32, QuestEnpc)> = HashMap::new();
        for quest_id in eligible {
            for enpc in self.quest_givers(handle, quest_id).await {
                offers
                    .entry(enpc.actor_class_id)
                    .or_insert((quest_id, enpc));
            }
        }

        let (removed, claimed): (Vec<QuestEnpc>, Vec<u32>) = {
            let mut c = handle.character.write().await;
            let removed = c
                .quest_offers
                .iter()
                .filter(|(class, _)| !offers.contains_key(class))
                .map(|(_, (_, enpc))| *enpc)
                .collect();
            let claimed = c
                .quest_journal
                .slots
                .iter()
                .flatten()
                .flat_map(|q| q.state.current.keys().copied())
                .collect();
            c.quest_offers = offers.clone();
            c.quest_offers_level = Some(c.chara.level);
            (removed, claimed)
        };
        // An NPC a taken quest now uses keeps that quest's marker.
        for enpc in removed {
            if !claimed.contains(&enpc.actor_class_id) {
                self.broadcast_quest_enpc_clear(handle.actor_id, enpc).await;
            }
        }
        for (class, (_, enpc)) in &offers {
            if !claimed.contains(class) {
                self.broadcast_quest_enpc_update(handle.actor_id, *enpc)
                    .await;
            }
        }
        tracing::debug!(
            player = handle.actor_id,
            offers = offers.len(),
            "quest offers refreshed"
        );
    }

    /// Rebuild the offers if the player's level moved since they were
    /// built. Level-ups happen on paths that can't reach the processor (a
    /// kill's EXP in the battle runtime, `!giveexp`), so the processor
    /// checks on the player's next position update instead.
    pub(super) async fn refresh_quest_offers_if_level_changed(&self, handle: &ActorHandle) {
        let stale = {
            let c = handle.character.read().await;
            offers_stale(c.quest_offers_level, c.chara.level)
        };
        if stale {
            self.refresh_quest_offers(handle).await;
        }
    }

    pub(super) async fn refresh_quest_offers_for(&self, player_id: u32) {
        if let Some(handle) = self.registry.get(player_id).await {
            self.refresh_quest_offers(&handle).await;
        }
    }

    /// The givers `onStateChange(SEQ_ACCEPT)` names for a quest (cached).
    async fn quest_givers(&self, handle: &ActorHandle, quest_id: u32) -> Vec<QuestEnpc> {
        if let Some(found) = givers().lock().ok().and_then(|g| g.get(&quest_id).cloned()) {
            return found;
        }
        let Some(engine) = self.lua.as_ref() else {
            return Vec::new();
        };
        let Some(script_name) = engine.catalogs().quest_script_name(quest_id) else {
            return Vec::new();
        };
        let script_path = engine.resolver().quest(&script_name);
        let snapshot = {
            let c = handle.character.read().await;
            super::build_player_snapshot_from_character(&c)
        };
        let quest_handle = offer_handle(snapshot.actor_id, quest_id);
        let engine_clone = engine.clone();
        let result = tokio::task::spawn_blocking(move || {
            engine_clone.call_quest_hook(
                &script_path,
                "onStateChange",
                snapshot,
                quest_handle,
                vec![crate::lua::QuestHookArg::Int(SEQ_ACCEPT as i64)],
            )
        })
        .await;
        let found: Vec<QuestEnpc> = match result {
            Ok(r) => r
                .commands
                .into_iter()
                .filter_map(|cmd| match cmd {
                    LuaCommand::QuestSetEnpc {
                        actor_class_id,
                        quest_flag_type,
                        is_talk_enabled,
                        is_push_enabled,
                        is_emote_enabled,
                        is_spawned,
                        ..
                    } if quest_flag_type != 0 => Some(QuestEnpc::new(
                        actor_class_id,
                        quest_flag_type,
                        is_spawned,
                        is_talk_enabled,
                        is_emote_enabled,
                        is_push_enabled,
                    )),
                    _ => None,
                })
                .collect(),
            Err(e) => {
                tracing::warn!(quest = quest_id, error = %e, "quest offer: SEQ_ACCEPT hook panicked");
                Vec::new()
            }
        };
        if let Ok(mut g) = givers().lock() {
            g.insert(quest_id, found.clone());
        }
        found
    }

    /// The quest offered by an NPC of this class, unless a taken quest has
    /// claimed the NPC (that quest's talk wins).
    pub(super) async fn offered_quest_at(
        &self,
        handle: &ActorHandle,
        npc_class_id: u32,
    ) -> Option<u32> {
        let c = handle.character.read().await;
        let claimed = c
            .quest_journal
            .slots
            .iter()
            .flatten()
            .any(|q| q.state.current.contains_key(&npc_class_id));
        if claimed {
            return None;
        }
        c.quest_offers
            .get(&npc_class_id)
            .map(|(quest_id, _)| *quest_id)
    }
}

/// A quest handle for a quest that isn't in the journal: `SEQ_ACCEPT`, no
/// flags or counters.
pub(crate) fn offer_handle(player_id: u32, quest_id: u32) -> crate::lua::LuaQuestHandle {
    crate::lua::LuaQuestHandle {
        player_id,
        quest_id,
        has_quest: false,
        sequence: SEQ_ACCEPT,
        flags: 0,
        counters: [0; 4],
        npc_ls_from: 0,
        npc_ls_msg_step: 0,
        queue: crate::lua::command::CommandQueue::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn story_quests_are_offered_only_after_a_prerequisite() {
        assert!(!is_offerable("man0l1", false));
        assert!(is_offerable("man1u0", true));
        assert!(!is_offerable("dftsea", false));
        assert!(!is_offerable("dftsea", true));
        assert!(!is_offerable("trl0l1", false));
        assert!(is_offerable("etc1l1", false));
        assert!(is_offerable("wld0l1", false));
    }

    #[test]
    fn offers_rebuild_after_a_level_change() {
        assert!(!offers_stale(None, 8));
        assert!(!offers_stale(Some(8), 8));
        assert!(offers_stale(Some(7), 8));
    }

    #[test]
    fn guild_quests_need_their_class() {
        assert!(class_gate("thm200", 22));
        assert!(!class_gate("thm200", 23));
        assert!(!class_gate("exc306", 2));
        assert!(class_gate("hrv200", 40));
        assert!(class_gate("man200", 2));
        assert!(class_gate("etc1l1", 22));
    }

    #[test]
    fn fade_to_white_follows_any_nations_level_13_quest() {
        assert_eq!(prerequisites(110013, 0), vec![110004, 110008, 110012]);
        assert_eq!(prerequisites(110011, 110010), vec![110010]);
        assert!(prerequisites(110001, 0).is_empty());
    }

    fn standing(gc: u8, limsa: u8, gridania: u8, uldah: u8) -> crate::actor::CharaState {
        crate::actor::CharaState {
            gc_current: gc,
            gc_rank_limsa: limsa,
            gc_rank_gridania: gridania,
            gc_rank_uldah: uldah,
            ..Default::default()
        }
    }

    #[test]
    fn company_quests_follow_the_players_standing() {
        // No company yet: the test quests and the recruit arc, not the
        // members' quests.
        let none = standing(0, 127, 127, 127);
        assert!(company_gate("com0l1", &none));
        assert!(company_gate("com0g2", &none));
        assert!(company_gate("com0u7", &none));
        assert!(company_gate("com0l5", &none));
        assert!(!company_gate("com5g0", &none));
        assert!(!company_gate("gcu101", &none));
        // A recruit (127) of one company may still try the others.
        let recruit = standing(1, 127, 127, 127);
        assert!(company_gate("com0g1", &recruit));
        assert!(company_gate("com0l7", &recruit));
        // Sworn to the Maelstrom as a Corporal (17).
        let sworn = standing(1, 17, 127, 127);
        assert!(company_gate("com5l0", &sworn));
        assert!(company_gate("gcl101", &sworn));
        assert!(!company_gate("com0l7", &sworn));
        assert!(!company_gate("com0g1", &sworn));
        assert!(!company_gate("gcu101", &sworn));
        // Other quests are untouched.
        assert!(company_gate("man300", &sworn));
    }
}

#[cfg(test)]
mod job_gate_tests {
    use super::job_gate;

    #[test]
    fn job_one_needs_the_class_and_a_second_class_at_15() {
        let mut levels = vec![0i16; 64];
        levels[4] = 30;
        assert!(!job_gate("war0j1", 4, 0, &levels), "no gladiator 15");
        levels[3] = 15;
        assert!(job_gate("war0j1", 4, 0, &levels));
        assert!(!job_gate("war0j1", 3, 0, &levels), "on another class");
        assert!(!job_gate("war0j1", 4, 17, &levels), "already the warrior");
    }

    #[test]
    fn later_job_quests_need_the_job() {
        let levels = vec![50i16; 64];
        assert!(job_gate("war0j2", 4, 17, &levels));
        assert!(!job_gate("war0j2", 4, 0, &levels));
        assert!(!job_gate("mnk0j3", 2, 17, &levels));
        assert!(job_gate("gla306", 3, 0, &levels), "other quests pass");
    }
}
