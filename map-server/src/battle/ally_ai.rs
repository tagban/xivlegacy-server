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

//! NPC helper (ally) roles and kits (#334).
//!
//! An ally's role comes from its spawn: the client's actor class
//! (`FighterAllyOpeningHealer`), its pool job and its script name. Its kit
//! comes from the role, the job and the level, out of the real
//! `server_battle_commands` rows, so a level gate on a row gates the ally
//! the same way it gates a player:
//!
//! * **Tank** (pugilist, gladiator, marauder, lancer): an enmity move
//!   (Flash, Provoke, Taunt) it uses on any foe that is on the player or
//!   another non-tank, plus the job's weaponskills.
//! * **Healer** (the opening healers and any conjurer): the best cure for
//!   its level (Cure, then Cura at 30), Protect (6) and Stoneskin (26) on
//!   whoever is missing them, and Raise (18) for a fallen player or ally.
//! * **Damage** (archer, thaumaturge): the job's weaponskills or attack
//!   spells.
//! * **Escortee** (an escort duty's charge): fights with its job's moves
//!   but never pulls foes onto itself; losing it fails the duty.
//!
//! The ticker's ally support pass (`runtime::ticker`) uses the kit; the
//! controller's TP-move and spell picks use the job moves.

use std::collections::HashMap;

use crate::battle::command::BattleCommand;
use crate::battle::effects::ActionType;
use crate::battle::target_find::ValidTarget;

/// Pool `currentJob` / command `classJob` ids.
pub const PGL: u32 = 2;
pub const GLA: u32 = 3;
pub const MRD: u32 = 4;
pub const ARC: u32 = 7;
pub const LNC: u32 = 8;
pub const THM: u32 = 22;
pub const CNJ: u32 = 23;

/// Provoke (MRD 14): the enmity move every tank falls back on.
pub const PROVOKE_ID: u16 = 27180;
/// Flash (GLA 14).
pub const FLASH_ID: u16 = 27145;
/// Taunt (PGL 42).
pub const TAUNT_ID: u16 = 27102;
/// Cure (CNJ 2): every healer has it, whatever its level.
pub const CURE_ID: u16 = 27346;
/// Cura (CNJ 30): twice Cure's potency.
pub const CURA_ID: u16 = 27347;
/// Raise (CNJ 18).
pub const RAISE_ID: u16 = 27349;
/// Protect (CNJ 6).
pub const PROTECT_ID: u16 = 27351;
/// Stoneskin (CNJ 26).
pub const STONESKIN_ID: u16 = 27350;

/// Each tank job's own enmity moves, best first. A tank below all of them
/// uses Provoke: in 1.0 any class could set another class's actions, and
/// Provoke is the one every front-liner reached for.
const ENMITY_MOVES: &[(u32, &[u16])] = &[
    (GLA, &[FLASH_ID]),
    (MRD, &[PROVOKE_ID]),
    (PGL, &[TAUNT_ID]),
    (LNC, &[]),
];
/// Single-target heals, strongest first.
const HEALS: &[u16] = &[CURA_ID, CURE_ID];
/// Buffs a healer keeps up on the player and the other allies.
const BUFFS: &[u16] = &[PROTECT_ID, STONESKIN_ID];

/// Escort charges whose script name doesn't start with `escort_`.
const ESCORTEE_SCRIPTS: &[&str] = &["sisipu"];

/// What an ally does in a fight.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AllyRole {
    /// Attacks with its job's moves.
    #[default]
    Damage,
    /// Holds foes off the player with enmity moves.
    Tank,
    /// Heals, buffs and raises.
    Healer,
    /// An escort duty's charge: fights, never draws foes onto itself.
    Escortee,
}

/// Does a player-side battle NPC heal? The client marks the opening
/// fights' healers with the `FighterAllyOpeningHealer` actor class
/// (Papalymo is a THM but cures in the Gridania opening); any other
/// conjurer ally (job 23) heals too.
pub fn ally_is_healer(class_path: &str, current_job: u32) -> bool {
    class_path.ends_with("Healer") || current_job == CNJ
}

/// An ally's role from its actor class path, pool job and script name.
pub fn ally_role(class_path: &str, current_job: u32, script_name: &str) -> AllyRole {
    if script_name.starts_with("escort_") || ESCORTEE_SCRIPTS.contains(&script_name) {
        AllyRole::Escortee
    } else if ally_is_healer(class_path, current_job) {
        AllyRole::Healer
    } else if matches!(current_job, PGL | GLA | MRD | LNC) {
        AllyRole::Tank
    } else {
        AllyRole::Damage
    }
}

/// The moves an ally's role, job and level give it.
#[derive(Debug, Clone, Default)]
pub struct AllyKit {
    pub role: AllyRole,
    /// A tank's enmity move.
    pub enmity: Option<BattleCommand>,
    /// A healer's single-target heal.
    pub heal: Option<BattleCommand>,
    /// A healer's buffs, in the order it puts them up.
    pub buffs: Vec<BattleCommand>,
    /// A healer's Raise.
    pub raise: Option<BattleCommand>,
    /// The job's weaponskills at this level (TP moves).
    pub skills: Vec<BattleCommand>,
    /// The job's attack spells at this level (for a caster).
    pub spells: Vec<BattleCommand>,
}

fn within_level(
    catalog: &HashMap<u16, BattleCommand>,
    id: u16,
    level: i16,
) -> Option<BattleCommand> {
    catalog
        .get(&id)
        .filter(|c| i16::from(c.level) <= level)
        .cloned()
}

/// Build an ally's kit out of the battle-command catalog.
pub fn ally_kit(
    role: AllyRole,
    job: u32,
    level: i16,
    catalog: &HashMap<u16, BattleCommand>,
) -> AllyKit {
    let mut kit = AllyKit {
        role,
        ..AllyKit::default()
    };
    match role {
        AllyRole::Tank => {
            let own = ENMITY_MOVES
                .iter()
                .find(|(j, _)| *j == job)
                .map_or(&[][..], |(_, ids)| *ids);
            kit.enmity = own
                .iter()
                .find_map(|id| within_level(catalog, *id, level))
                .or_else(|| catalog.get(&PROVOKE_ID).cloned());
        }
        AllyRole::Healer => {
            kit.heal = HEALS
                .iter()
                .find_map(|id| within_level(catalog, *id, level))
                .or_else(|| catalog.get(&CURE_ID).cloned());
            kit.buffs = BUFFS
                .iter()
                .filter_map(|id| within_level(catalog, *id, level))
                .collect();
            kit.raise = within_level(catalog, RAISE_ID, level);
        }
        AllyRole::Damage | AllyRole::Escortee => {}
    }
    let job_rows = |pick: &dyn Fn(&BattleCommand) -> bool| {
        let mut v: Vec<BattleCommand> = catalog
            .values()
            .filter(|c| {
                u32::from(c.job) == job
                    && i16::from(c.level) <= level
                    && c.main_target.intersects(ValidTarget::ENEMY)
                    && pick(c)
            })
            .cloned()
            .collect();
        v.sort_by_key(|c| c.id);
        v
    };
    kit.skills = job_rows(&|c| c.action_type == ActionType::Physical && c.tp_cost > 0);
    if matches!(job, THM | CNJ) {
        kit.spells = job_rows(&|c| c.action_type == ActionType::Magic && c.cast_time_ms > 0);
    }
    kit
}

/// Who a tank ally pulls off: among the foes in reach that are on someone
/// other than a tank, the nearest. `foes` is `(actor id, distance, is the
/// foe's top enmity on a tank)`.
pub fn pick_enmity_target(foes: &[(u32, f32, bool)], range: f32) -> Option<u32> {
    foes.iter()
        .filter(|(_, d, on_tank)| !*on_tank && *d <= range)
        .min_by(|a, b| a.1.total_cmp(&b.1).then(a.0.cmp(&b.0)))
        .map(|(id, _, _)| *id)
}

/// Which buff a healer puts up next, and on whom: the first of its buffs
/// someone in reach is missing. `missing(buff, actor)` says whether the
/// actor lacks it; `targets` are `(actor id, distance)`.
pub fn pick_buff(
    buffs: &[BattleCommand],
    targets: &[(u32, f32)],
    missing: impl Fn(&BattleCommand, u32) -> bool,
) -> Option<(usize, u32)> {
    buffs.iter().enumerate().find_map(|(i, b)| {
        targets
            .iter()
            .filter(|(_, d)| *d <= b.range.max(1.0))
            .find(|(id, _)| missing(b, *id))
            .map(|(id, _)| (i, *id))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cmd(id: u16, name: &str, job: u8, level: u8, action: ActionType) -> BattleCommand {
        let mut c = BattleCommand::new(id, name);
        c.job = job;
        c.level = level;
        c.action_type = action;
        c.range = 20.0;
        c.main_target = if matches!(action, ActionType::Physical | ActionType::Magic) {
            ValidTarget::ENEMY
        } else {
            ValidTarget::SELF
        };
        if action == ActionType::Physical {
            c.tp_cost = 1000;
        }
        if action == ActionType::Magic {
            c.cast_time_ms = 2000;
        }
        c
    }

    fn catalog() -> HashMap<u16, BattleCommand> {
        let mut provoke = cmd(PROVOKE_ID, "provoke", 4, 14, ActionType::Status);
        provoke.main_target = ValidTarget::ENEMY;
        let mut flash = cmd(FLASH_ID, "flash", 3, 14, ActionType::Status);
        flash.main_target = ValidTarget::ENEMY;
        [
            provoke,
            flash,
            cmd(TAUNT_ID, "taunt", 2, 42, ActionType::Status),
            cmd(CURE_ID, "cure", 23, 2, ActionType::Heal),
            cmd(CURA_ID, "cura", 23, 30, ActionType::Heal),
            cmd(RAISE_ID, "raise", 23, 18, ActionType::Status),
            cmd(PROTECT_ID, "protect", 23, 6, ActionType::Status),
            cmd(STONESKIN_ID, "stoneskin", 23, 26, ActionType::Status),
            cmd(27110, "pummel", 2, 1, ActionType::Physical),
            cmd(27111, "concussive_blow", 2, 10, ActionType::Physical),
            cmd(27150, "fast_blade", 3, 1, ActionType::Physical),
            cmd(27313, "thunder", 22, 1, ActionType::Magic),
            cmd(27308, "blizzard", 22, 4, ActionType::Magic),
        ]
        .into_iter()
        .map(|c| (c.id, c))
        .collect()
    }

    #[test]
    fn roles_follow_class_job_and_script() {
        let healer = "/Chara/Npc/Monster/Fighter/FighterAllyOpeningHealer";
        let attacker = "/Chara/Npc/Monster/Fighter/FighterAllyOpeningAttacker";
        assert_eq!(ally_role(healer, THM, "papalymo"), AllyRole::Healer);
        assert_eq!(ally_role(healer, CNJ, "yshtola"), AllyRole::Healer);
        assert_eq!(ally_role(attacker, PGL, "yda"), AllyRole::Tank);
        assert_eq!(ally_role(attacker, GLA, "x"), AllyRole::Tank);
        assert_eq!(ally_role(attacker, MRD, "x"), AllyRole::Tank);
        assert_eq!(ally_role(attacker, LNC, "x"), AllyRole::Tank);
        assert_eq!(ally_role(attacker, ARC, "x"), AllyRole::Damage);
        assert_eq!(ally_role(attacker, THM, "x"), AllyRole::Damage);
        assert_eq!(ally_role(attacker, PGL, "escort_powle"), AllyRole::Escortee);
        assert_eq!(ally_role(attacker, PGL, "sisipu"), AllyRole::Escortee);
        assert!(ally_is_healer(healer, 22), "Papalymo: THM, healer class");
        assert!(ally_is_healer("/Chara/Npc/Monster/Fighter/Fighter", 23));
        assert!(!ally_is_healer("/Chara/Npc/Monster/Fighter/Fighter", 22));
    }

    #[test]
    fn tank_enmity_move_by_job_and_level() {
        let cat = catalog();
        let id = |job, level| {
            ally_kit(AllyRole::Tank, job, level, &cat)
                .enmity
                .map(|c| c.id)
        };
        assert_eq!(id(GLA, 20), Some(FLASH_ID), "GLA 14+: Flash");
        assert_eq!(id(GLA, 5), Some(PROVOKE_ID), "below Flash: Provoke");
        assert_eq!(id(MRD, 16), Some(PROVOKE_ID));
        assert_eq!(id(PGL, 1), Some(PROVOKE_ID), "PGL below Taunt");
        assert_eq!(id(PGL, 42), Some(TAUNT_ID));
        assert_eq!(id(LNC, 30), Some(PROVOKE_ID));
        assert!(ally_kit(AllyRole::Healer, CNJ, 50, &cat).enmity.is_none());
    }

    #[test]
    fn healer_kit_grows_with_level() {
        let cat = catalog();
        let ids = |level| {
            let k = ally_kit(AllyRole::Healer, CNJ, level, &cat);
            (
                k.heal.map(|c| c.id),
                k.buffs.iter().map(|c| c.id).collect::<Vec<_>>(),
                k.raise.map(|c| c.id),
            )
        };
        assert_eq!(ids(1), (Some(CURE_ID), vec![], None), "Cure even at 1");
        assert_eq!(ids(16), (Some(CURE_ID), vec![PROTECT_ID], None));
        assert_eq!(ids(22), (Some(CURE_ID), vec![PROTECT_ID], Some(RAISE_ID)));
        assert_eq!(
            ids(30),
            (
                Some(CURA_ID),
                vec![PROTECT_ID, STONESKIN_ID],
                Some(RAISE_ID)
            )
        );
    }

    #[test]
    fn job_moves_follow_job_and_level() {
        let cat = catalog();
        let skills = |job, level| {
            ally_kit(AllyRole::Tank, job, level, &cat)
                .skills
                .iter()
                .map(|c| c.id)
                .collect::<Vec<_>>()
        };
        assert_eq!(skills(PGL, 1), vec![27110]);
        assert_eq!(skills(PGL, 16), vec![27110, 27111]);
        assert_eq!(skills(GLA, 1), vec![27150]);
        let thm = ally_kit(AllyRole::Damage, THM, 4, &cat);
        assert!(thm.skills.is_empty());
        assert_eq!(
            thm.spells.iter().map(|c| c.id).collect::<Vec<_>>(),
            vec![27308, 27313]
        );
    }

    #[test]
    fn tank_pulls_the_nearest_foe_not_on_a_tank() {
        assert_eq!(
            pick_enmity_target(&[(1, 3.0, true), (2, 8.0, false), (3, 5.0, false)], 15.0),
            Some(3)
        );
        assert_eq!(pick_enmity_target(&[(1, 3.0, true)], 15.0), None);
        assert_eq!(pick_enmity_target(&[(2, 30.0, false)], 15.0), None);
    }

    #[test]
    fn buffs_go_on_whoever_lacks_them_first() {
        let cat = catalog();
        let buffs = vec![cat[&PROTECT_ID].clone(), cat[&STONESKIN_ID].clone()];
        let targets = [(1, 2.0), (2, 4.0)];
        // Nobody has anything: Protect on the first.
        assert_eq!(pick_buff(&buffs, &targets, |_, _| true), Some((0, 1)));
        // 1 has Protect: Protect on 2.
        assert_eq!(
            pick_buff(&buffs, &targets, |b, id| !(b.id == PROTECT_ID && id == 1)),
            Some((0, 2))
        );
        // Everyone has Protect: Stoneskin.
        assert_eq!(
            pick_buff(&buffs, &targets, |b, _| b.id == STONESKIN_ID),
            Some((1, 1))
        );
        assert_eq!(pick_buff(&buffs, &targets, |_, _| false), None);
    }
}
