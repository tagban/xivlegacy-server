// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Setting a class's level outright (the GM `!setlevel` / `!maxall`
//! commands), as opposed to earning it through `AddExp`. The level and an
//! empty EXP bar are saved; for a character in the world the client is told
//! (the class's level, and the nameplate level when it's the class being
//! played), the commands the new levels unlock are put on the hotbar the way
//! a level up does it, and the stats are worked out again.

use std::sync::Arc;

use crate::battle::save::MAX_LEVEL;
use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The 1.23b classes: (class id, short name, full name).
pub const CLASSES: &[(u8, &str, &str)] = &[
    (2, "pgl", "pugilist"),
    (3, "gla", "gladiator"),
    (4, "mrd", "marauder"),
    (7, "arc", "archer"),
    (8, "lnc", "lancer"),
    (22, "thm", "thaumaturge"),
    (23, "cnj", "conjurer"),
    (29, "crp", "carpenter"),
    (30, "bsm", "blacksmith"),
    (31, "arm", "armorer"),
    (32, "gsm", "goldsmith"),
    (33, "ltw", "leatherworker"),
    (34, "wvr", "weaver"),
    (35, "alc", "alchemist"),
    (36, "cul", "culinarian"),
    (39, "min", "miner"),
    (40, "btn", "botanist"),
    (41, "fsh", "fisher"),
];

/// The 1.23b jobs: (job id, short name, full name).
pub const JOBS: &[(u8, &str, &str)] = &[
    (15, "mnk", "monk"),
    (16, "pld", "paladin"),
    (17, "war", "warrior"),
    (18, "brd", "bard"),
    (19, "drg", "dragoon"),
    (26, "blm", "blackmage"),
    (27, "whm", "whitemage"),
];

fn lookup(table: &[(u8, &str, &str)], word: &str) -> Option<u8> {
    let w: String = word
        .to_ascii_lowercase()
        .chars()
        .filter(|c| !matches!(c, ' ' | '_' | '-'))
        .collect();
    if let Ok(id) = w.parse::<u8>() {
        return table.iter().find(|(i, _, _)| *i == id).map(|(i, _, _)| *i);
    }
    table
        .iter()
        .find(|(_, short, full)| *short == w || *full == w)
        .map(|(id, _, _)| *id)
}

/// A class by id, short name ("gla") or name ("gladiator").
pub fn class_by_name(word: &str) -> Option<u8> {
    lookup(CLASSES, word)
}

/// A job by id, short name ("pld") or name ("paladin", "whitemage").
pub fn job_by_name(word: &str) -> Option<u8> {
    lookup(JOBS, word)
}

/// The full name of a class or job id, for messages.
pub fn class_name(id: u8) -> &'static str {
    CLASSES
        .iter()
        .chain(JOBS)
        .find(|(i, _, _)| *i == id)
        .map(|(_, _, full)| *full)
        .unwrap_or("unknown class")
}

/// The class a job grows out of.
pub fn class_of_job(job: u8) -> Option<u8> {
    crate::actor::job::JOBS
        .iter()
        .find(|(_, j, _)| *j == job)
        .map(|(class, _, _)| *class)
}

/// Set `class_id`'s level to `level` (1-50) with no EXP toward the next.
/// Works on a character who isn't in the world too (the database only).
/// Returns the level the class had before.
pub async fn apply_set_level(
    chara_id: u32,
    class_id: u8,
    level: i16,
    registry: &ActorRegistry,
    db: &Database,
    world: &WorldManager,
    lua: Option<&Arc<LuaEngine>>,
) -> anyhow::Result<i16> {
    let level = level.clamp(1, MAX_LEVEL);
    let slot = class_id as usize;
    let Some(handle) = registry.get(chara_id).await else {
        let before = db
            .load_class_levels_and_exp(chara_id)
            .await
            .ok()
            .and_then(|row| row.skill_level.get(slot).copied())
            .unwrap_or(0);
        db.set_level(chara_id, class_id, level).await?;
        db.set_exp(chara_id, class_id, 0).await?;
        return Ok(before);
    };
    let (before, active) = {
        let mut c = handle.character.write().await;
        if slot >= c.battle_save.skill_level.len() {
            anyhow::bail!("no class {class_id}");
        }
        let before = c.battle_save.skill_level[slot];
        c.battle_save.skill_level[slot] = level;
        c.battle_save.skill_point[slot] = 0;
        let active = c.chara.class as i32 == class_id as i32;
        if active {
            c.chara.level = level;
        }
        (before, active)
    };
    db.set_level(chara_id, class_id, level).await?;
    db.set_exp(chara_id, class_id, 0).await?;
    if active {
        db.save_player_current_class(chara_id, class_id, level)
            .await?;
    }
    // The commands each new level unlocks, as a level up equips them.
    if let Some(lua) = lua {
        for at in (before.max(1) + 1)..=level {
            crate::runtime::quest_apply::equip_abilities_at_level(
                chara_id,
                class_id,
                at,
                registry,
                db,
                Some(world),
                lua,
            )
            .await;
        }
    }

    // The class's level (and the nameplate's, for the class being played)
    // for everyone around; its EXP bar for the player.
    let class_slot = class_id.saturating_sub(1);
    let mut all = crate::packets::send::actor::ActorPropertyPacketBuilder::new(
        chara_id,
        "charaWork/stateForAll",
    );
    all.add_short(
        &format!("charaWork.battleSave.skillLevel[{class_slot}]"),
        level as u16,
    );
    if active {
        all.add_short("charaWork.parameterSave.state_mainSkillLevel", level as u16);
    }
    for sub in all.done() {
        let bytes = sub.to_bytes();
        crate::runtime::dispatcher::send_to_self_if_player(
            registry,
            world,
            chara_id,
            bytes.clone(),
        )
        .await;
        crate::runtime::dispatcher::broadcast_to_neighbours(world, registry, chara_id, bytes).await;
    }
    let mut own = crate::packets::send::actor::ActorPropertyPacketBuilder::new(
        chara_id,
        "charaWork/battleStateForSelf",
    );
    own.add_int(&format!("charaWork.battleSave.skillPoint[{class_slot}]"), 0);
    for sub in own.done() {
        crate::runtime::dispatcher::send_to_self_if_player(
            registry,
            world,
            chara_id,
            sub.to_bytes(),
        )
        .await;
    }
    if active && let Some(lua) = lua {
        crate::runtime::dispatcher::recalc_stats_now(registry, world, lua.catalogs(), db, chara_id)
            .await;
    }
    Ok(before)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classes_and_jobs_by_name() {
        assert_eq!(class_by_name("gla"), Some(3));
        assert_eq!(class_by_name("Gladiator"), Some(3));
        assert_eq!(class_by_name("23"), Some(23));
        assert_eq!(class_by_name("pld"), None);
        assert_eq!(class_by_name("99"), None);
        assert_eq!(job_by_name("pld"), Some(16));
        assert_eq!(job_by_name("white-mage"), Some(27));
        assert_eq!(job_by_name("BLM"), Some(26));
        assert_eq!(class_of_job(27), Some(23));
        assert_eq!(class_name(41), "fisher");
        assert_eq!(class_name(19), "dragoon");
    }

    #[test]
    fn every_job_has_a_class_in_the_table() {
        for (job, _, _) in JOBS {
            let class = class_of_job(*job).expect("job without a class");
            assert!(CLASSES.iter().any(|(c, _, _)| *c == class));
        }
    }
}
