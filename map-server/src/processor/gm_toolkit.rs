// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! GM commands for setting up a character's classes, jobs and gear, with
//! the client kept up to date (no relog):
//!
//! - `!setclass <class> [name]`: switch class. In 1.0 the class is the main
//!   hand, so this equips one of the class's weapons: the one its gear set
//!   holds, else one in the bag, else a new one for the class's level.
//! - `!setlevel <class> <level> [name]`: any class to level 1-50.
//! - `!maxall [level] [name]`: every class to 50 (or `level`).
//! - `!setjob <job|none> [name]`: take up a job. Brings the class to 30
//!   when it's lower, gives the soul crystal, marks the job's first quest
//!   done, switches to the class, then to the job. `none` goes back to the
//!   class.
//! - `!gearset <class|job> [level] [name]`: give and equip a set for the
//!   class at that level (default: the class's own level), picked from the
//!   item tables: the best main hand (and off hand) of the class, and armor
//!   and accessories everyone can wear, preferring the class's stats.
//!
//! With no name, a command works on the player the GM has targeted, else on
//! the GM. Each needs the GM level `settings/commands.toml` gives it, and
//! aiming at someone else needs `target_others`.

use std::sync::{Arc, OnceLock};

use super::PacketProcessor;
use crate::actor::player::{
    SLOT_BODY, SLOT_EARS, SLOT_FEET, SLOT_FINGER_LEFT, SLOT_FINGER_RIGHT, SLOT_HANDS, SLOT_HEAD,
    SLOT_LEGS, SLOT_MAINHAND, SLOT_NECK, SLOT_OFFHAND, SLOT_WAIST, SLOT_WRISTS,
};
use crate::database::GearRow;
use crate::inventory::{PKG_KEYITEMS, PKG_NORMAL};
use crate::runtime::actor_registry::ActorHandle;
use crate::runtime::class_level::{
    CLASSES, apply_set_level, class_by_name, class_name, class_of_job, job_by_name,
};

pub(crate) const COMMANDS: &[&str] = &["setclass", "setlevel", "maxall", "setjob", "gearset"];

/// The level a job's first quest asks of its class.
const JOB_LEVEL: i16 = 30;

/// Each job's first quest ("Job 1"), the one that gives the soul crystal.
const JOB_FIRST_QUEST: &[(u8, u32)] = &[
    (17, 111201), // warrior
    (15, 111221), // monk
    (27, 111241), // white mage
    (26, 111261), // black mage
    (16, 111281), // paladin
    (18, 111301), // bard
    (19, 111321), // dragoon
];

/// Armor and accessories: where the item tables say it goes, and the gear
/// slot. Rings go on both hands.
const ARMOR_SLOTS: &[(u16, u16)] = &[
    (9, SLOT_HEAD),
    (11, SLOT_BODY),
    (13, SLOT_LEGS),
    (14, SLOT_HANDS),
    (15, SLOT_FEET),
    (16, SLOT_WAIST),
    (17, SLOT_NECK),
    (47, SLOT_EARS),
    (45, SLOT_WRISTS),
    (49, SLOT_FINGER_RIGHT),
    (49, SLOT_FINGER_LEFT),
];

/// `equipTribe` for gear every race and gender can wear.
const ANY_TRIBE: u16 = 29;
/// The shields' `mainSkill`.
const SHIELD_SKILL: u8 = 10;

/// Stat ids (`paramBonusType - 15001`, crate::actor::modifier) a class
/// wants on its gear.
fn class_stats(class_id: u8) -> &'static [i64] {
    match class_id {
        3 | 4 => &[3, 4, 18, 0, 39, 41], // STR VIT defense HP parry block
        2 | 8 => &[3, 5, 17, 15, 19],    // STR DEX attack accuracy crit
        7 => &[5, 3, 15, 17, 19],        // DEX STR accuracy attack crit
        22 => &[6, 8, 1, 23, 27],        // INT PIE MP attack magic, magic accuracy
        23 => &[7, 8, 1, 24, 27],        // MND PIE MP healing magic, magic accuracy
        29..=36 => &[29, 30, 31],        // craftsmanship, magic craftsmanship, control
        39..=41 => &[32, 33, 34],        // gathering, output, perception
        _ => &[],
    }
}

/// The main attributes and the crafting/gathering ones: on gear for another
/// kind of class, they count against an item.
const MAIN_STATS: &[i64] = &[3, 4, 5, 6, 7, 8, 29, 30, 31, 32, 33, 34];

/// How well an item suits the class: its class stats, less twice any main
/// stat meant for another kind of class.
fn gear_score(row: &GearRow, class_id: u8) -> i64 {
    let wanted = class_stats(class_id);
    row.bonuses
        .iter()
        .filter(|(t, _)| (15001..15101).contains(t))
        .map(|(t, v)| {
            let stat = t - 15001;
            if wanted.contains(&stat) {
                *v
            } else if MAIN_STATS.contains(&stat) {
                -2 * v
            } else {
                0
            }
        })
        .sum()
}

/// Gear `!gearset` never hands out: untranslated rows and gear limited to
/// certain jobs. (Armor also leaves out one race's or one gender's gear,
/// the job and crafting/gathering artifact sets, the GM's Judge's set and
/// costumes: see `pick_gearset`.)
fn wearable(row: &GearRow, level: i16) -> bool {
    row.level >= 1
        && row.level <= level
        && !row.name.is_empty()
        && !row.name.starts_with('[')
        && !row
            .bonuses
            .iter()
            .any(|(t, _)| (16000..17000).contains(t) || (1_016_000..1_017_000).contains(t))
}

/// The best of `rows` for the class: the highest level, then the class's
/// stats (a level weighs as much as 4 stat points), then the lowest id.
fn best<'a>(rows: impl Iterator<Item = &'a GearRow>, class_id: u8) -> Option<&'a GearRow> {
    rows.max_by_key(|r| {
        (
            r.level as i64 * 4 + gear_score(r, class_id),
            std::cmp::Reverse(r.catalog_id),
        )
    })
}

/// The class's main hand at `level`.
fn pick_main_hand(rows: &[GearRow], class_id: u8, level: i16) -> Option<&GearRow> {
    best(
        rows.iter().filter(|r| {
            r.main_skill == class_id && (36..=39).contains(&r.equip_point) && wearable(r, level)
        }),
        class_id,
    )
}

/// A set for the class at `level`: (gear slot, item), main hand first.
pub(crate) fn pick_gearset(rows: &[GearRow], class_id: u8, level: i16) -> Vec<(u16, &GearRow)> {
    let mut set = Vec::new();
    let Some(main) = pick_main_hand(rows, class_id, level) else {
        return set;
    };
    set.push((SLOT_MAINHAND, main));
    let off = match class_id {
        // the crafting and gathering off-hand tools
        29..=41 => best(
            rows.iter()
                .filter(|r| r.main_skill == class_id && r.equip_point == 40 && wearable(r, level)),
            class_id,
        ),
        // a gladiator's shield
        3 => best(
            rows.iter().filter(|r| {
                r.main_skill == SHIELD_SKILL
                    && r.equip_point == 2
                    && r.tribe == ANY_TRIBE
                    && wearable(r, level)
            }),
            class_id,
        ),
        _ => None,
    };
    if let Some(off) = off {
        set.push((SLOT_OFFHAND, off));
    }
    for &(point, slot) in ARMOR_SLOTS {
        let piece = best(
            rows.iter().filter(|r| {
                r.main_skill == 0
                    && r.equip_point == point
                    && r.tribe == ANY_TRIBE
                    && !matches!(r.compatibility, 2031..=2033 | 2119..=2128 | 2137..=2147)
                    && wearable(r, level)
                    && gear_score(r, class_id) >= 0
            }),
            class_id,
        );
        if let Some(piece) = piece {
            set.push((slot, piece));
        }
    }
    set
}

static GEAR_ROWS: OnceLock<Arc<Vec<GearRow>>> = OnceLock::new();

impl PacketProcessor {
    /// `!setclass`, `!setlevel`, `!maxall`, `!setjob`, `!gearset` typed in
    /// chat by `handle`, whose account has GM level `level`. `None` when
    /// the line is some other command.
    pub(super) async fn gm_toolkit_command(
        &self,
        handle: &ActorHandle,
        line: &str,
        level: u8,
    ) -> Option<Result<String, String>> {
        let mut words = line.split_whitespace();
        let cmd = words.next()?.to_ascii_lowercase();
        if !COMMANDS.contains(&cmd.as_str()) {
            return None;
        }
        let perms = crate::command_permissions::get();
        if level < perms.required(&cmd) {
            return Some(Err(format!("unknown command: !{cmd} (!help lists yours)")));
        }
        let args: Vec<&str> = words.collect();
        let invoker = handle
            .character
            .read()
            .await
            .base
            .display_name()
            .to_string();
        if let Err(e) = self
            .db
            .log_gm_command(Some(&invoker), &cmd, &args.join(" "))
            .await
        {
            tracing::warn!(error = %e, "logging a GM command");
        }
        let can_target_others = level >= perms.target_others;
        let result = match cmd.as_str() {
            "setclass" => self.gm_setclass(handle, &args, can_target_others).await,
            "setlevel" => self.gm_setlevel(handle, &args, can_target_others).await,
            "maxall" => self.gm_maxall(handle, &args, can_target_others).await,
            "setjob" => self.gm_setjob(handle, &args, can_target_others).await,
            _ => self.gm_gearset(handle, &args, can_target_others).await,
        };
        match &result {
            Ok(response) | Err(response) => tracing::info!(%response, "command result"),
        }
        Some(result)
    }

    /// Who a command is for: the name in `name_words`, else the player the
    /// GM has targeted, else the GM. (character id, name).
    async fn toolkit_target(
        &self,
        me: &ActorHandle,
        name_words: &[&str],
        can_target_others: bool,
    ) -> Result<(u32, String), String> {
        let id = if name_words.is_empty() {
            let target = me.character.read().await.chara.current_target;
            match self.registry.get(target).await {
                Some(h) if target != me.actor_id && h.is_player() => target,
                _ => me.actor_id,
            }
        } else {
            let name = name_words.join(" ");
            self.db
                .character_id_by_name(&name)
                .await
                .ok()
                .flatten()
                .ok_or_else(|| format!("unknown character: {name}"))?
        };
        if id != me.actor_id && !can_target_others {
            return Err("at your GM level this works only on yourself".into());
        }
        let name = match self.registry.get(id).await {
            Some(h) => h.character.read().await.base.display_name().to_string(),
            None => name_words.join(" "),
        };
        Ok((id, name))
    }

    async fn online(&self, id: u32, name: &str) -> Result<ActorHandle, String> {
        self.registry
            .get(id)
            .await
            .ok_or_else(|| format!("{name} is not online"))
    }

    async fn gear_rows(&self) -> Result<Arc<Vec<GearRow>>, String> {
        if let Some(rows) = GEAR_ROWS.get() {
            return Ok(rows.clone());
        }
        let rows = self
            .db
            .load_gear_rows()
            .await
            .map_err(|e| format!("reading the item tables failed: {e}"))?;
        Ok(GEAR_ROWS.get_or_init(|| Arc::new(rows)).clone())
    }

    /// (class, job, level of the class) the character is playing.
    async fn playing(handle: &ActorHandle) -> (u8, u8, i16) {
        let c = handle.character.read().await;
        let class = c.chara.class.max(0) as u8;
        let level = c
            .battle_save
            .skill_level
            .get(class as usize)
            .copied()
            .unwrap_or(1);
        (class, c.chara.current_job as u8, level)
    }

    async fn class_level(handle: &ActorHandle, class_id: u8) -> i16 {
        let c = handle.character.read().await;
        c.battle_save
            .skill_level
            .get(class_id as usize)
            .copied()
            .unwrap_or(0)
    }

    /// Put `item_id` in the gear slot: a copy in the bag not already used
    /// (`used`), else a new one. Returns false when there's no room.
    async fn equip_catalog_item(
        &self,
        id: u32,
        equip_slot: u16,
        item_id: u32,
        used: &mut Vec<u64>,
    ) -> bool {
        let mut pick = None;
        for attempt in 0..2 {
            let bag = self
                .db
                .get_item_package(id, PKG_NORMAL as u32)
                .await
                .unwrap_or_default();
            pick = bag
                .iter()
                .filter(|i| i.item_id == item_id && !used.contains(&i.unique_id))
                .max_by_key(|i| i.unique_id)
                .map(|i| (i.unique_id, i.slot));
            if pick.is_some() || attempt == 1 {
                break;
            }
            crate::runtime::quest_apply::apply_add_item_quality(
                id,
                PKG_NORMAL,
                item_id,
                1,
                1,
                &self.registry,
                Some(&self.world),
                &self.db,
            )
            .await;
        }
        let Some((unique_id, slot)) = pick else {
            return false;
        };
        used.push(unique_id);
        self.equip_gear(id, equip_slot, PKG_NORMAL, slot).await;
        true
    }

    /// Switch an online character to `class_id` by equipping one of its
    /// weapons; a character on the class's job goes back to the class.
    async fn switch_class(&self, handle: &ActorHandle, class_id: u8) -> Result<(), String> {
        let id = handle.actor_id;
        let (class, job, _) = Self::playing(handle).await;
        if class == class_id {
            if job != 0 {
                self.apply_change_job(id, 2).await;
            }
            return Ok(());
        }
        // the class's own weapon, then any of its weapons in the bag
        let rows = self.gear_rows().await?;
        let is_main = |item_id: u32| {
            rows.iter().any(|r| {
                r.catalog_id == item_id
                    && r.main_skill == class_id
                    && (36..=39).contains(&r.equip_point)
            })
        };
        let bag = self
            .db
            .get_item_package(id, PKG_NORMAL as u32)
            .await
            .unwrap_or_default();
        let own = match self.db.equipped_item(id, class_id, SLOT_MAINHAND).await {
            Ok(Some((unique_id, _, _))) => bag.iter().find(|i| i.unique_id == unique_id),
            _ => None,
        };
        let weapon = own.or_else(|| {
            bag.iter()
                .filter(|i| is_main(i.item_id))
                .max_by_key(|i| i.item_id)
        });
        match weapon {
            Some(item) => {
                self.equip_gear(id, SLOT_MAINHAND, PKG_NORMAL, item.slot)
                    .await
            }
            None => {
                let level = Self::class_level(handle, class_id).await.max(1);
                let Some(new) = pick_main_hand(&rows, class_id, level) else {
                    return Err(format!(
                        "no {} weapon in the item tables",
                        class_name(class_id)
                    ));
                };
                let new = new.catalog_id;
                if !self
                    .equip_catalog_item(id, SLOT_MAINHAND, new, &mut Vec::new())
                    .await
                {
                    return Err("no room in the bag for a weapon".into());
                }
            }
        }
        let (now, _, _) = Self::playing(handle).await;
        if now != class_id {
            return Err(format!(
                "the switch to {} didn't take",
                class_name(class_id)
            ));
        }
        Ok(())
    }

    async fn gm_setclass(
        &self,
        me: &ActorHandle,
        args: &[&str],
        others: bool,
    ) -> Result<String, String> {
        const USAGE: &str = "usage: !setclass <class> [name] (gla, pgl, mrd, arc, lnc, thm, cnj, crp, bsm, arm, gsm, ltw, wvr, alc, cul, min, btn, fsh)";
        let Some(word) = args.first() else {
            return Err(USAGE.into());
        };
        let Some(class_id) = class_by_name(word) else {
            if job_by_name(word).is_some() {
                return Err(format!("{word} is a job: use !setjob {word}"));
            }
            return Err(USAGE.into());
        };
        let (id, name) = self.toolkit_target(me, &args[1..], others).await?;
        let handle = self.online(id, &name).await?;
        self.switch_class(&handle, class_id).await?;
        let (_, _, level) = Self::playing(&handle).await;
        Ok(format!(
            "{name} is now a {} (level {level}).",
            class_name(class_id)
        ))
    }

    async fn gm_setlevel(
        &self,
        me: &ActorHandle,
        args: &[&str],
        others: bool,
    ) -> Result<String, String> {
        const USAGE: &str = "usage: !setlevel <class or job> <level 1-50> [name]";
        let (Some(word), Some(level)) = (args.first(), args.get(1)) else {
            return Err(USAGE.into());
        };
        let class_id = class_by_name(word)
            .or_else(|| job_by_name(word).and_then(class_of_job))
            .ok_or(USAGE)?;
        let level = level
            .parse::<i16>()
            .ok()
            .filter(|l| (1..=50).contains(l))
            .ok_or(USAGE)?;
        let (id, name) = self.toolkit_target(me, &args[2..], others).await?;
        let before = apply_set_level(
            id,
            class_id,
            level,
            &self.registry,
            &self.db,
            &self.world,
            self.lua.as_ref(),
        )
        .await
        .map_err(|e| format!("setlevel failed: {e}"))?;
        if let Some(handle) = self.registry.get(id).await {
            self.refresh_quest_offers(&handle).await;
        }
        Ok(format!(
            "{name}'s {} is now level {level} (was {}).",
            class_name(class_id),
            before.max(0)
        ))
    }

    async fn gm_maxall(
        &self,
        me: &ActorHandle,
        args: &[&str],
        others: bool,
    ) -> Result<String, String> {
        let (level, rest) = match args.first().and_then(|w| w.parse::<i16>().ok()) {
            Some(l) if (1..=50).contains(&l) => (l, &args[1..]),
            Some(_) => return Err("usage: !maxall [level 1-50] [name]".into()),
            None => (50, args),
        };
        let (id, name) = self.toolkit_target(me, rest, others).await?;
        for &(class_id, _, _) in CLASSES {
            apply_set_level(
                id,
                class_id,
                level,
                &self.registry,
                &self.db,
                &self.world,
                self.lua.as_ref(),
            )
            .await
            .map_err(|e| format!("maxall failed at {}: {e}", class_name(class_id)))?;
        }
        if let Some(handle) = self.registry.get(id).await {
            self.refresh_quest_offers(&handle).await;
        }
        Ok(format!(
            "{name}: all {} classes are now level {level}.",
            CLASSES.len()
        ))
    }

    async fn gm_setjob(
        &self,
        me: &ActorHandle,
        args: &[&str],
        others: bool,
    ) -> Result<String, String> {
        const USAGE: &str = "usage: !setjob <pld|war|mnk|drg|brd|whm|blm|none> [name]";
        let Some(word) = args.first() else {
            return Err(USAGE.into());
        };
        let (id, name) = self.toolkit_target(me, &args[1..], others).await?;
        let handle = self.online(id, &name).await?;
        if matches!(word.to_ascii_lowercase().as_str(), "none" | "off" | "class") {
            let (class, job, _) = Self::playing(&handle).await;
            if job == 0 {
                return Ok(format!("{name} has no job on."));
            }
            self.apply_change_job(id, 2).await;
            return Ok(format!("{name} is a {} again.", class_name(class)));
        }
        let job = job_by_name(word).ok_or(USAGE)?;
        let class_id = class_of_job(job).ok_or(USAGE)?;
        let Some((_, crystal)) = crate::actor::job_of_class(class_id) else {
            return Err(USAGE.into());
        };
        let mut done = Vec::new();
        if Self::class_level(&handle, class_id).await < JOB_LEVEL {
            apply_set_level(
                id,
                class_id,
                JOB_LEVEL,
                &self.registry,
                &self.db,
                &self.world,
                self.lua.as_ref(),
            )
            .await
            .map_err(|e| format!("setjob failed: {e}"))?;
            done.push(format!("{} to level {JOB_LEVEL}", class_name(class_id)));
        }
        let owned = self
            .db
            .owns_item_in_package(id, crystal, PKG_KEYITEMS)
            .await
            .unwrap_or(false);
        if !owned {
            crate::runtime::quest_apply::apply_add_item_quality(
                id,
                PKG_KEYITEMS,
                crystal,
                1,
                1,
                &self.registry,
                Some(&self.world),
                &self.db,
            )
            .await;
            done.push("soul crystal".into());
        }
        if let Some(&(_, quest)) = JOB_FIRST_QUEST.iter().find(|(j, _)| *j == job) {
            let finished = handle
                .character
                .read()
                .await
                .quest_journal
                .is_completed(quest);
            if !finished {
                crate::runtime::quest_apply::finish_complete_quest(
                    &handle,
                    id,
                    quest,
                    &self.registry,
                    &self.db,
                    &self.world,
                )
                .await;
                done.push(format!("quest {quest} done"));
            }
        }
        self.switch_class(&handle, class_id).await?;
        let (_, now, _) = Self::playing(&handle).await;
        if now != job {
            self.apply_change_job(id, 1).await;
        }
        let (_, now, level) = Self::playing(&handle).await;
        if now != job {
            return Err(format!("the change to {} didn't take", class_name(job)));
        }
        let extra = if done.is_empty() {
            String::new()
        } else {
            format!(" ({})", done.join(", "))
        };
        self.refresh_quest_offers(&handle).await;
        Ok(format!(
            "{name} is now a {} (level {level}){extra}.",
            class_name(job)
        ))
    }

    async fn gm_gearset(
        &self,
        me: &ActorHandle,
        args: &[&str],
        others: bool,
    ) -> Result<String, String> {
        const USAGE: &str = "usage: !gearset <class or job> [level 1-50] [name]";
        let Some(word) = args.first() else {
            return Err(USAGE.into());
        };
        let job = job_by_name(word);
        let class_id = class_by_name(word)
            .or_else(|| job.and_then(class_of_job))
            .ok_or(USAGE)?;
        let (level, rest) = match args.get(1).and_then(|w| w.parse::<i16>().ok()) {
            Some(l) if (1..=50).contains(&l) => (Some(l), &args[2..]),
            Some(_) => return Err(USAGE.into()),
            None => (None, &args[1..]),
        };
        let (id, name) = self.toolkit_target(me, rest, others).await?;
        let handle = self.online(id, &name).await?;
        let level = match level {
            Some(l) => l,
            None => Self::class_level(&handle, class_id).await.max(1),
        };
        let rows = self.gear_rows().await?;
        let set = pick_gearset(&rows, class_id, level);
        if set.is_empty() {
            return Err(format!(
                "no {} gear up to level {level} in the item tables",
                class_name(class_id)
            ));
        }
        // The weapon first: it makes the switch to the class.
        let mut used = Vec::new();
        let mut worn = Vec::new();
        let mut missed = Vec::new();
        for (slot, row) in &set {
            if self
                .equip_catalog_item(id, *slot, row.catalog_id, &mut used)
                .await
            {
                worn.push(row.name.as_str());
            } else {
                missed.push(row.name.as_str());
            }
            if *slot == SLOT_MAINHAND && Self::playing(&handle).await.0 != class_id {
                return Err(format!(
                    "couldn't switch {name} to {}",
                    class_name(class_id)
                ));
            }
        }
        if let Some(job) = job
            && Self::playing(&handle).await.1 != job
        {
            let crystal = crate::actor::job_of_class(class_id).map(|(_, c)| c);
            let owned = match crystal {
                Some(c) => self
                    .db
                    .owns_item_in_package(id, c, PKG_KEYITEMS)
                    .await
                    .unwrap_or(false),
                None => false,
            };
            if owned {
                self.apply_change_job(id, 1).await;
            }
        }
        let mut msg = format!(
            "{name}: level {level} {} gear on: {}.",
            class_name(job.unwrap_or(class_id)),
            worn.join(", ")
        );
        if !missed.is_empty() {
            msg.push_str(&format!(" No room in the bag for: {}.", missed.join(", ")));
        }
        Ok(msg)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(
        id: u32,
        name: &str,
        level: i16,
        skill: u8,
        point: u16,
        bonuses: &[(i64, i64)],
    ) -> GearRow {
        GearRow {
            catalog_id: id,
            name: name.into(),
            level,
            main_skill: skill,
            compatibility: 1001,
            exclusive: false,
            equip_point: point,
            tribe: ANY_TRIBE,
            bonuses: bonuses.to_vec(),
        }
    }

    #[test]
    fn picks_the_highest_level_weapon_of_the_class() {
        let rows = vec![
            row(4030010, "Weathered Gladius", 1, 3, 36, &[]),
            row(4030101, "Bronze Gladius", 12, 3, 36, &[]),
            row(4030201, "Iron Gladius", 30, 3, 36, &[]),
            row(4020101, "Bronze Baghnakhs", 12, 2, 37, &[]),
        ];
        let set = pick_gearset(&rows, 3, 20);
        assert_eq!(set[0].0, SLOT_MAINHAND);
        assert_eq!(set[0].1.catalog_id, 4030101);
        assert!(pick_gearset(&rows, 22, 50).is_empty());
    }

    #[test]
    fn armor_prefers_the_class_stats_and_skips_other_classes() {
        let rows = vec![
            row(4030010, "Weathered Gladius", 1, 3, 36, &[]),
            row(8030001, "Plain Doublet", 20, 0, 11, &[]),
            row(8030002, "Robe of Intelligence", 20, 0, 11, &[(15007, 5)]),
            row(8030003, "Doublet of Strength", 19, 0, 11, &[(15004, 5)]),
            row(8030004, "Iron Cuirass", 40, 0, 11, &[]),
        ];
        let set = pick_gearset(&rows, 3, 20);
        let body = set.iter().find(|(s, _)| *s == SLOT_BODY).unwrap().1;
        assert_eq!(body.catalog_id, 8030003);
        let set = pick_gearset(&rows, 22, 20);
        assert!(set.is_empty(), "no thaumaturge weapon, no set");
    }

    #[test]
    fn leaves_out_race_locked_artifact_and_job_gear() {
        let mut race = row(8011, "Hyur Hat", 10, 0, 9, &[]);
        race.tribe = 1;
        let mut af = row(8012, "Gallant Coronet", 10, 0, 9, &[]);
        af.compatibility = 2120;
        let job = row(8013, "Job Hat", 10, 0, 9, &[(16007, 1)]);
        let untranslated = row(8014, "[en]", 10, 0, 9, &[]);
        let ok = row(8015, "Felt Hat", 5, 0, 9, &[]);
        let rows = vec![
            row(4030010, "Weathered Gladius", 1, 3, 36, &[]),
            race,
            af,
            job,
            untranslated,
            ok,
        ];
        let set = pick_gearset(&rows, 3, 50);
        let head = set.iter().find(|(s, _)| *s == SLOT_HEAD).unwrap().1;
        assert_eq!(head.catalog_id, 8015);
    }

    #[test]
    fn rings_go_on_both_hands_and_tools_in_the_off_hand() {
        let rows = vec![
            row(6010001, "Weathered Saw", 1, 29, 39, &[]),
            row(6011001, "Bronze Claw Hammer", 10, 29, 40, &[]),
            row(8130001, "Brass Ring", 5, 0, 49, &[]),
        ];
        let set = pick_gearset(&rows, 29, 15);
        let slots: Vec<u16> = set.iter().map(|(s, _)| *s).collect();
        assert_eq!(
            slots,
            vec![
                SLOT_MAINHAND,
                SLOT_OFFHAND,
                SLOT_FINGER_RIGHT,
                SLOT_FINGER_LEFT
            ]
        );
    }

    #[test]
    fn every_job_has_its_first_quest() {
        for (job, _, _) in crate::runtime::class_level::JOBS {
            assert!(JOB_FIRST_QUEST.iter().any(|(j, _)| j == job));
        }
    }
}
