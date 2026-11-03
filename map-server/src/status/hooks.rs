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

//! Status effects' combat hooks: `onPreAction`, `onHit`, `onDamageTaken`,
//! `onCommandStart` and the rest, run for the effects whose flags ask for
//! them (pmeteor `StatusEffectContainer.CallLuaFunctionByFlag`).
//!
//! The hooks run against snapshots ([`HookSide`]) so the caller never holds
//! two actors' locks at once: the owner's share of the result is applied
//! with [`apply_owner`] and the other actor's with [`apply_other`],
//! whenever the caller holds that actor.

use std::path::Path;

use crate::actor::Character;
use crate::battle::command::{BattleCommand, CommandResult};
use crate::battle::effects::HitEffect;

use super::script::{
    EffectView, HookAction, HookActor, HookActorChange, HookCall, HookReplace, HookRow,
    HookRowKind, HookSkill, run_hook,
};
use super::{DEFAULT_LOSS_TEXT_ID, StatusEffectFlags, StatusOutbox};

#[derive(Debug, Clone)]
pub struct HookEffect {
    pub id: u32,
    pub name: String,
    pub flags: StatusEffectFlags,
    pub view: EffectView,
}

/// An actor and its effects, as the hooks see them.
#[derive(Debug, Clone, Default)]
pub struct HookSide {
    pub actor: HookActor,
    pub effects: Vec<HookEffect>,
}

impl HookSide {
    pub fn of(c: &Character) -> Self {
        Self {
            actor: HookActor {
                actor_id: c.base.actor_id,
                mods: c.chara.mods.clone(),
                level: c.chara.level,
                hp: i32::from(c.chara.hp),
                max_hp: i32::from(c.chara.max_hp),
                mp: i32::from(c.chara.mp),
                max_mp: i32::from(c.chara.max_mp),
                tp: i32::from(c.chara.tp),
                status_ids: c.status_effects.iter().map(|e| e.id).collect(),
            },
            effects: c
                .status_effects
                .iter()
                .map(|e| HookEffect {
                    id: e.id,
                    name: e.name.clone(),
                    flags: e.flags,
                    view: e.view(),
                })
                .collect(),
        }
    }

    pub fn has(&self, flag: StatusEffectFlags) -> bool {
        self.effects.iter().any(|e| e.flags.intersects(flag))
    }
}

/// What one effect's hook asks of its owner.
#[derive(Debug, Clone, PartialEq)]
pub struct EffectResult {
    pub effect_id: u32,
    pub owner: HookActorChange,
    pub effect: EffectView,
    pub remove_self: bool,
    pub replace: Option<HookReplace>,
}

/// Every effect's hook at one point of an action.
#[derive(Debug, Clone, Default)]
pub struct HookRun {
    pub owner: Vec<EffectResult>,
    /// All the hooks' changes to the other actor, together.
    pub other: HookActorChange,
    pub rows: Vec<HookRow>,
}

fn merge(into: &mut HookActorChange, c: HookActorChange) {
    into.hp += c.hp;
    into.mp += c.mp;
    into.tp += c.tp;
    for (k, d) in c.mod_deltas {
        match into.mod_deltas.iter_mut().find(|(t, _)| *t == k) {
            Some(t) => t.1 += d,
            None => into.mod_deltas.push((k, d)),
        }
    }
    into.removed.extend(c.removed);
}

/// Run `hook` for each of `owner`'s effects flagged with `flag`, in
/// order, threading the skill and action through so one effect sees what
/// the one before it changed.
#[allow(clippy::too_many_arguments)]
pub fn run(
    script_root: &Path,
    hook: &str,
    flag: StatusEffectFlags,
    owner: &HookSide,
    other: Option<&HookActor>,
    owner_acts: bool,
    skill: &mut HookSkill,
    action: &mut Option<HookAction>,
) -> HookRun {
    let mut out = HookRun::default();
    for e in owner.effects.iter().filter(|e| e.flags.intersects(flag)) {
        let call = HookCall {
            hook,
            effect_name: &e.name,
            effect: e.view,
            owner: &owner.actor,
            other,
            owner_acts,
            skill: *skill,
            action: *action,
        };
        match run_hook(script_root, &call) {
            Ok(Some(o)) => {
                tracing::debug!(
                    owner = owner.actor.actor_id,
                    effect = %e.name,
                    hook,
                    hp = o.owner.hp,
                    mp = o.owner.mp,
                    other_hp = o.other.hp,
                    mods = ?o.owner.mod_deltas,
                    removed = o.remove_self,
                    replace = ?o.replace.map(|r| r.status_id),
                    rows = o.rows.len(),
                    "status hook ran"
                );
                *skill = o.skill;
                if o.action.is_some() {
                    *action = o.action;
                }
                merge(&mut out.other, o.other);
                out.rows.extend(o.rows);
                out.owner.push(EffectResult {
                    effect_id: e.id,
                    owner: o.owner,
                    effect: o.effect,
                    remove_self: o.remove_self,
                    replace: o.replace,
                });
            }
            Ok(None) => {}
            Err(err) => {
                tracing::debug!(effect = %e.name, hook, error = %err, "status hook failed");
            }
        }
    }
    out
}

fn apply_pools(c: &mut Character, ch: &HookActorChange) {
    if ch.hp != 0 && c.is_alive() {
        c.add_hp(ch.hp);
    }
    if ch.mp != 0 {
        c.add_mp(ch.mp);
    }
    if ch.tp != 0 {
        c.add_tp(ch.tp);
    }
}

fn remove(c: &mut Character, ids: &[u32], outbox: &mut StatusOutbox) {
    for &id in ids {
        if c.status_effects.has(id) {
            c.status_effects
                .remove_status_effect(id, DEFAULT_LOSS_TEXT_ID, true, outbox);
        }
    }
}

/// Apply one effect's hook result to its owner. Modifier changes are kept
/// with the effect so they come off when it goes. Returns the replacement
/// the hook asked for (Power Surge stepping up a tier), for the caller to
/// build from the status catalog.
pub fn apply_owner(
    c: &mut Character,
    r: &EffectResult,
    outbox: &mut StatusOutbox,
) -> Option<(u32, HookReplace)> {
    if !r.owner.mod_deltas.is_empty() {
        c.add_status_mods(r.effect_id, &r.owner.mod_deltas);
    }
    apply_pools(c, &r.owner);
    if let Some(e) = c.status_effects.get_mut(r.effect_id) {
        e.extra = r.effect.extra;
        e.tier = r.effect.tier;
        e.magnitude = r.effect.magnitude;
    }
    remove(c, &r.owner.removed, outbox);
    if r.remove_self {
        let text = c
            .status_effects
            .get(r.effect_id)
            .map_or(DEFAULT_LOSS_TEXT_ID, |e| e.status_loss_text_id);
        c.status_effects
            .remove_status_effect(r.effect_id, text, true, outbox);
        return None;
    }
    r.replace.map(|rep| (r.effect_id, rep))
}

/// Apply the hooks' changes to the actor on the other side.
pub fn apply_other(c: &mut Character, ch: &HookActorChange, outbox: &mut StatusOutbox) {
    for &(k, d) in &ch.mod_deltas {
        c.chara.mods.add_raw(k, d);
    }
    apply_pools(c, ch);
    remove(c, &ch.removed, outbox);
}

impl HookSkill {
    pub fn from_command(c: &BattleCommand) -> Self {
        Self {
            id: u32::from(c.id),
            command_type: c.command_type.bits(),
            action_type: c.action_type as u8,
            num_hits: c.num_hits,
            enmity_modifier: f64::from(c.enmity_modifier),
            accuracy_modifier: f64::from(c.accuracy_modifier),
            bonus_crit_rate: f64::from(c.bonus_crit_rate),
            mp_cost: f64::from(c.mp_cost),
            tp_cost: f64::from(c.tp_cost),
            cast_time_ms: f64::from(c.cast_time_ms),
            recast_time_ms: f64::from(c.recast_time_ms),
            range: f64::from(c.range),
            is_ranged: c.is_ranged,
        }
    }

    /// The auto-attack, for hooks that check `skill.GetCommandType()`.
    pub fn auto_attack() -> Self {
        Self {
            command_type: crate::battle::command::CommandType::AUTO_ATTACK.bits(),
            action_type: crate::battle::effects::ActionType::Physical as u8,
            num_hits: 1,
            enmity_modifier: 1.0,
            ..Default::default()
        }
    }

    /// Put what the hooks changed back on the command.
    pub fn apply_to(&self, c: &mut BattleCommand) {
        c.num_hits = self.num_hits;
        c.enmity_modifier = self.enmity_modifier as f32;
        c.accuracy_modifier = self.accuracy_modifier as f32;
        c.bonus_crit_rate = self.bonus_crit_rate as f32;
        c.mp_cost = self.mp_cost.round().clamp(0.0, f64::from(i16::MAX)) as i16;
        c.tp_cost = self.tp_cost.round().clamp(0.0, f64::from(i16::MAX)) as i16;
        c.cast_time_ms = self.cast_time_ms.max(0.0) as u32;
        let recast = self.recast_time_ms.max(0.0) as u32;
        if recast != c.recast_time_ms {
            c.recast_time_ms = recast;
            c.max_recast_time_seconds = recast.div_ceil(1000);
        }
        c.range = self.range as f32;
    }
}

impl HookAction {
    pub fn from_result(r: &CommandResult, hit_direction: u8) -> Self {
        Self {
            amount: f64::from(r.amount),
            amount_mitigated: f64::from(r.amount_mitigated),
            enmity: f64::from(r.enmity),
            hit_rate: r.hit_rate,
            crit_rate: r.crit_rate,
            block_rate: r.block_rate,
            parry_rate: r.parry_rate,
            resist_rate: r.resist_rate,
            param: hit_direction,
            world_master_text_id: r.world_master_text_id,
        }
    }

    /// Put what the hooks changed back on the result row. The hit
    /// direction is the hooks' to read only.
    pub fn apply_to(&self, r: &mut CommandResult) {
        r.amount = self.amount.floor().clamp(0.0, f64::from(u16::MAX)) as u16;
        r.amount_mitigated = self
            .amount_mitigated
            .floor()
            .clamp(0.0, f64::from(u16::MAX)) as u16;
        r.enmity = self.enmity.floor().clamp(0.0, f64::from(u16::MAX)) as u16;
        r.hit_rate = self.hit_rate;
        r.crit_rate = self.crit_rate;
        r.block_rate = self.block_rate;
        r.parry_rate = self.parry_rate;
        r.resist_rate = self.resist_rate;
        r.world_master_text_id = self.world_master_text_id;
    }
}

impl HookRow {
    /// The battle-log row (pmeteor `CommandResultContainer.AddHPAction`
    /// and friends). `fallback_target` stands in for a hook that passed 0.
    pub fn to_result(self, fallback_target: u32) -> CommandResult {
        let effect = match self.kind {
            HookRowKind::Hp => HitEffect::MAGIC_EFFECT_TYPE | HitEffect::HEAL,
            HookRowKind::Mp => HitEffect::MAGIC_EFFECT_TYPE | HitEffect::MP,
            HookRowKind::HpAbsorb => {
                HitEffect::SELF_HEAL_TYPE | HitEffect::SELF_HEAL | HitEffect::SELF_HEAL_HP
            }
            HookRowKind::MpAbsorb => {
                HitEffect::SELF_HEAL_TYPE | HitEffect::SELF_HEAL | HitEffect::SELF_HEAL_MP
            }
            HookRowKind::Hit => HitEffect::HIT_EFFECT_TYPE | HitEffect::RECOIL_LV2,
        };
        CommandResult {
            target_actor_id: if self.target_actor_id != 0 {
                self.target_actor_id
            } else {
                fallback_target
            },
            amount: self.amount,
            world_master_text_id: self.text_id,
            effect_id: effect.bits(),
            hit_num: 1,
            ..Default::default()
        }
    }
}

/// Which side of the defender the attacker stands on (pmeteor
/// `Character.GetHitDirection`): the `HitDirection` bits Front 1, Right 2,
/// Rear 4, Left 8.
pub fn hit_direction(
    defender: common::Vector3,
    defender_rotation: f32,
    attacker: common::Vector3,
) -> u8 {
    use std::f64::consts::PI;
    let angle = f64::from(common::Vector3::angle_between(defender, attacker));
    let mut a = (angle + f64::from(defender_rotation) - 0.25 * PI) % (2.0 * PI);
    if a < 0.0 {
        a += 2.0 * PI;
    }
    match (a / (0.5 * PI)) as u32 {
        0 => 2,
        1 => 1,
        2 => 8,
        _ => 4,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::actor::modifier::Modifier;

    #[test]
    fn hook_results_land_on_the_owner_and_come_off_with_the_effect() {
        let mut c = Character::new(1);
        c.chara.max_hp = 1000;
        c.chara.hp = 500;
        let mut outbox = StatusOutbox::new();
        let r = EffectResult {
            effect_id: 7,
            owner: HookActorChange {
                mod_deltas: vec![(Modifier::Attack.as_u32(), 20.0)],
                hp: 40,
                ..Default::default()
            },
            effect: EffectView::default(),
            remove_self: false,
            replace: None,
        };
        apply_owner(&mut c, &r, &mut outbox);
        apply_owner(&mut c, &r, &mut outbox);
        assert_eq!(c.chara.hp, 580);
        assert_eq!(c.chara.mods.get(Modifier::Attack), 40.0);
        c.remove_status_mods(7);
        assert_eq!(c.chara.mods.get(Modifier::Attack), 0.0);
    }

    #[test]
    fn hit_direction_reads_the_defenders_facing() {
        let d = common::Vector3::new(0.0, 0.0, 0.0);
        // Off the axes: `angle_xz` reads straight up or down the z axis
        // as 0, as pmeteor's does.
        let dirs: Vec<u8> = [(1.0, 0.1), (0.1, 1.0), (-1.0, -0.1), (-0.1, -1.0)]
            .iter()
            .map(|&(x, z)| hit_direction(d, 0.0, common::Vector3::new(x, 0.0, z)))
            .collect();
        let mut sorted = dirs.clone();
        sorted.sort_unstable();
        assert_eq!(sorted, vec![1, 2, 4, 8], "{dirs:?}");
        // Turning the defender around swaps front and rear.
        let front = dirs[0];
        let turned = hit_direction(d, std::f32::consts::PI, common::Vector3::new(1.0, 0.0, 0.1));
        assert_eq!(
            turned,
            match front {
                1 => 4,
                4 => 1,
                2 => 8,
                _ => 2,
            }
        );
    }
}
