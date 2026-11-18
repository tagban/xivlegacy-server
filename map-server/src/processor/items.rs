// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `ItemCommand`: using an item from the Use Item window.
//!
//! Meteor never got past a stub for this (`ItemState`), so it's native.
//! What an item does comes from its category (the client's item classes,
//! `client/script/.../Item/Normal/*Item`) and the item sheet columns:
//!
//! - `PotionItem`: restore a percentage of HP / MP / TP up to a cap.
//! - `FoodItem`: Well Fed with the item's stat bonuses (percent with a cap,
//!   or flat `15xxx` types) and its EXP bonus.
//! - `EnchantMedicineItem`: the same on Medicated; Bloodwall / Manawall have
//!   no sheet data and use their own statuses with estimated numbers.
//! - `CmnBadStatusItem`: thrown at an enemy, puts the ailment(s) on it.
//! - `CmnRemoveStatusItem`: cures the ailment(s) on you or an ally.
//! - `CmnGoodStatusItem`: unguents (Protect / Shell), the company-issue
//!   manuals (EXP bonus for crafting or gathering), Sanction, Lunar Curtain,
//!   and the fireworks / confetti / prisms, whose use is the show itself.
//! - `RaiseItem`: revives a KO'd ally (Expectorant: 60% chance).
//!
//! The client decides who an item may target (`canUseForRelation`); the
//! server checks the target it sends again. Each recast group has its own
//! timer.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use common::luaparam::LuaParam;

use super::PacketProcessor;
use crate::actor::modifier::Modifier;
use crate::actor::{Character, FoodBuff};
use crate::lua::command::LuaCommand;
use crate::runtime::actor_registry::ActorHandle;

/// Game-message log type for the item texts (see `use_text`).
const ITEM_TEXT_LOG: u8 = 0x1D;
/// "<command> cannot be used now."
const MSG_CANNOT_USE: u16 = 32544;
/// worldMaster texts for using an item: "<you> use <item> on <target>.",
/// "<you> use <item>.", "<you> attempt to use <item> on <target>, but
/// fail.", "<you> eat <item>.", "<you> drink <item>."
const MSG_USE_ON: u16 = 25201;
const MSG_USE: u16 = 25205;
const MSG_USE_FAILED: u16 = 25204;
const MSG_EAT: u16 = 25212;
const MSG_DRINK: u16 = 25217;
/// "<target> recovers N HP / MP", "<target> gains N TP" (battle texts).
const MSG_RECOVER: [u16; 3] = [30451, 30452, 30453];
/// `ItemCommand`'s command id (its static actor is `0xA0F00000 | id`).
const ITEM_COMMAND_ID: u16 = 0x520F;

/// The status food bonuses ride ("Well Fed").
pub const WELL_FED: u32 = 223_999;
/// The status medicine bonuses ride ("Medicated").
pub const MEDICATED: u32 = 223_998;
const PROTECT: u32 = 223_129;
const SHELL: u32 = 223_130;
/// "Craftsmen's Prime" / "Gatherers' Prime": more EXP for the Disciples of
/// the Hand / Land (the company-issue manuals).
pub const CRAFTERS_PRIME: u32 = 223_198;
pub const GATHERERS_PRIME: u32 = 223_199;
/// "Defense & Evasion bonus" / "Magic Defense & Magic Evasion bonus".
pub const BLOODWALL: u32 = 223_265;
pub const MANAWALL: u32 = 223_266;
/// "Lunar Veil": Dalamud-fed magic is halved.
const LUNAR_CURTAIN: u32 = 223_273;
/// "Enjoys the bonus of upgraded equipment."
const SANCTION: u32 = 223_992;

const PETRIFICATION: u32 = 223_004;
const PARALYSIS: u32 = 223_005;
const SILENCE: u32 = 223_006;
const BLIND: u32 = 223_007;
const MUTE: u32 = 223_008;
const POISON: u32 = 223_011;
const SLEEP: u32 = 228_001;

/// Statuses that carry an item's stat bonuses. Their magnitude is the
/// catalog id of the item, so a relog can rebuild the bonuses.
pub const BUFF_STATUSES: [u32; 4] = [WELL_FED, MEDICATED, BLOODWALL, MANAWALL];

/// `paramBonusType` ranges on consumables: a flat stat, a percent stat
/// buff, a percent HP / MP / TP restore. The stat is `type - base`
/// (`Modifier` ids).
const FLAT_BASE: u32 = 15_001;
const BUFF_BASE: u32 = 1_015_001;
const RESTORE_BASE: u32 = 1_016_001;
const MAX_TP: i32 = 3000;
/// The EXP bonus percent type (`Modifier::Exp`).
const EXP_TYPE: u32 = BUFF_BASE + Modifier::Exp as u32;

/// Ailments a `CmnBadStatusItem` puts on its target, from the item help
/// text ("Smothering Potion ... (Effects: Poison & Silence)").
const AILMENT_ITEMS: &[(u32, &[u32])] = &[
    (3_020_301, &[BLIND]),             // Blinding Potion
    (3_020_302, &[SILENCE]),           // Silencing Potion
    (3_020_303, &[SLEEP]),             // Sleeping Potion
    (3_020_304, &[PARALYSIS]),         // Paralyzing Potion
    (3_020_306, &[POISON]),            // Poisoning Potion
    (3_020_307, &[POISON, SILENCE]),   // Smothering Potion
    (3_020_308, &[POISON, PARALYSIS]), // Disabling Potion
];

/// What each remove-status item (`CmnRemoveStatusItem`) cures, by catalog
/// id, from the item help text. Blood Drops is the English name of the 1.0
/// Antidote (its French name is "Antidote"); Gold Lung and Goldbile are the
/// Aurum Vale's poisons. Lung / Heart Drops cure what the Smothering /
/// Disabling Potions cause.
const REMOVE_STATUS_ITEMS: &[(u32, &[u32])] = &[
    (3_020_401, &[BLIND]),         // Eye Drops
    (3_020_402, &[SILENCE, MUTE]), // Throat Drops
    (3_020_403, &[SLEEP]),         // Dawn Drops
    (3_020_404, &[PARALYSIS]),     // Spine Drops
    (
        3_020_406, // Blood Drops
        &[
            POISON,
            crate::runtime::aurum_hazards::STATUS_GOLD_LUNG,
            crate::runtime::aurum_hazards::STATUS_GOLDBILE,
        ],
    ),
    (3_020_407, &[POISON, SILENCE, MUTE]), // Lung Drops
    (3_020_408, &[POISON, PARALYSIS]),     // Heart Drops
    (3_020_409, &[PETRIFICATION]),         // Gold Needle
];

/// Percent bonuses: (modifier, percent, cap).
type Pct = &'static [(Modifier, i32, i32)];
/// Flat bonuses: (modifier, amount).
type Flat = &'static [(Modifier, i32)];

/// Bloodwall / Manawall potions: the item sheet has no numbers for them, so
/// these are our own, modeled on the stat potions (weak / hi / mega:
/// smaller percent, higher cap): (catalog id, status, percent, flat).
const WALL_POTIONS: &[(u32, u32, Pct, Flat)] = &[
    (
        3_020_530,
        BLOODWALL,
        &[(Modifier::Defense, 26, 45), (Modifier::Evasion, 24, 40)],
        &[],
    ),
    (
        3_020_531,
        BLOODWALL,
        &[(Modifier::Defense, 22, 90), (Modifier::Evasion, 20, 60)],
        &[],
    ),
    (
        3_020_532,
        BLOODWALL,
        &[(Modifier::Defense, 18, 125), (Modifier::Evasion, 16, 80)],
        &[],
    ),
    (
        3_020_533,
        MANAWALL,
        &[(Modifier::MagicEvasion, 24, 40)],
        &ELEMENT_WALL[0],
    ),
    (
        3_020_534,
        MANAWALL,
        &[(Modifier::MagicEvasion, 20, 60)],
        &ELEMENT_WALL[1],
    ),
    (
        3_020_535,
        MANAWALL,
        &[(Modifier::MagicEvasion, 16, 80)],
        &ELEMENT_WALL[2],
    ),
];
/// Manawall's magic defense: each elemental resistance, by tier (the
/// Bloodwall Defense caps, since resistances mitigate spells the way
/// Defense mitigates hits).
const ELEMENT_WALL: [[(Modifier, i32); 6]; 3] = [elements(45), elements(90), elements(125)];
const fn elements(v: i32) -> [(Modifier, i32); 6] {
    [
        (Modifier::FireResistance, v),
        (Modifier::IceResistance, v),
        (Modifier::WindResistance, v),
        (Modifier::EarthResistance, v),
        (Modifier::LightningResistance, v),
        (Modifier::WaterResistance, v),
    ]
}

/// What using an item does.
#[derive(Debug, Clone, PartialEq)]
pub enum ItemUse {
    /// HP / MP / TP restore (`PotionItem`).
    Restore,
    /// Stat bonuses on this status (food, medicine).
    Buff(u32),
    /// Ailments on an enemy.
    Ailment(&'static [u32]),
    /// Cures on you or an ally.
    Cure(&'static [u32]),
    /// Revive a KO'd ally with this chance.
    Raise(f64),
    /// A status with this magnitude on you or an ally (unguents, Sanction,
    /// Lunar Curtain).
    Status(u32, f64),
    /// An EXP bonus status for crafting / gathering (the manuals).
    Manual(u32),
    /// Fireworks, confetti, prisms: nothing beyond being used.
    Show,
}

/// The statuses a remove-status item cures, if it is one.
pub fn cures_of(catalog_id: u32) -> Option<&'static [u32]> {
    REMOVE_STATUS_ITEMS
        .iter()
        .find(|(id, _)| *id == catalog_id)
        .map(|(_, cures)| *cures)
}

fn ailments_of(catalog_id: u32) -> Option<&'static [u32]> {
    AILMENT_ITEMS
        .iter()
        .find(|(id, _)| *id == catalog_id)
        .map(|(_, a)| *a)
}

/// What `catalog_id` does when used, or `None` if it does nothing (items the
/// 1.23b client names "[en]" or leaves without effect data).
pub fn item_use(catalog_id: u32, item: &crate::database::UsableItem) -> Option<ItemUse> {
    let kind = item.category.rsplit('/').next().unwrap_or("");
    let has_effects = !item.effects.is_empty();
    match kind {
        "PotionItem" if has_effects => Some(ItemUse::Restore),
        "FoodItem" if has_effects => Some(ItemUse::Buff(WELL_FED)),
        "EnchantMedicineItem" => {
            if let Some((_, status, _, _)) = WALL_POTIONS.iter().find(|w| w.0 == catalog_id) {
                Some(ItemUse::Buff(*status))
            } else if has_effects {
                Some(ItemUse::Buff(MEDICATED))
            } else {
                None
            }
        }
        "CmnBadStatusItem" => ailments_of(catalog_id).map(ItemUse::Ailment),
        "CmnRemoveStatusItem" => cures_of(catalog_id).map(ItemUse::Cure),
        "RaiseItem" => Some(ItemUse::Raise(if item.magnitude > 0.0 {
            item.magnitude.min(1.0)
        } else {
            1.0
        })),
        "CmnGoodStatusItem" => match catalog_id {
            3_020_501 => Some(ItemUse::Status(PROTECT, item.magnitude)),
            3_020_502 => Some(ItemUse::Status(SHELL, item.magnitude)),
            3_020_504 | 3_020_509 => Some(ItemUse::Manual(CRAFTERS_PRIME)),
            3_020_505 | 3_020_510 => Some(ItemUse::Manual(GATHERERS_PRIME)),
            3_020_506 => Some(ItemUse::Status(SANCTION, 0.0)),
            3_020_538 => Some(ItemUse::Status(LUNAR_CURTAIN, item.magnitude)),
            3_020_507 | 3_020_508 | 3_020_601..=3_020_616 => Some(ItemUse::Show),
            _ => None,
        },
        _ => None,
    }
}

/// The stat bonuses an item puts on `status` (food and medicine).
pub fn buff_for(catalog_id: u32, status: u32, item: &crate::database::UsableItem) -> FoodBuff {
    if let Some((_, _, pct, flat)) = WALL_POTIONS.iter().find(|w| w.0 == catalog_id) {
        return FoodBuff {
            status_id: status,
            bonuses: pct.iter().map(|(m, p, c)| (*m as u32, *p, *c)).collect(),
            flat: flat.iter().map(|(m, v)| (*m as u32, *v)).collect(),
        };
    }
    let mut buff = FoodBuff {
        status_id: status,
        ..Default::default()
    };
    for &(kind, value, cap) in &item.effects {
        if let Some(m) = kind.checked_sub(BUFF_BASE).filter(|m| *m < 1000) {
            buff.bonuses.push((m, value, cap));
        } else if let Some(m) = kind.checked_sub(FLAT_BASE).filter(|m| *m < 1000) {
            buff.flat.push((m, value));
        }
    }
    buff
}

/// The EXP percent of a manual and its bonus cap (`1015063: 50`, cap 9000).
fn manual_bonus(item: &crate::database::UsableItem) -> (f64, f64) {
    item.effects
        .iter()
        .find(|e| e.0 == EXP_TYPE)
        .map(|&(_, pct, cap)| (pct as f64, cap as f64))
        .unwrap_or((0.0, 0.0))
}

/// `gain` EXP plus the item bonuses: food's EXP percent (`Modifier::Exp`)
/// on every class, and a company-issue manual's bonus on crafting (29-36)
/// or gathering (39-41) classes. A manual's status holds its bonus
/// percent (`extra`) and the bonus EXP it has left (`magnitude`).
pub fn item_exp_bonus(c: &mut Character, class_id: u8, gain: i32) -> i32 {
    if gain <= 0 {
        return gain;
    }
    let pct = c.chara.mods.get(Modifier::Exp).max(0.0);
    let mut total = gain.saturating_add((gain as f64 * pct / 100.0).ceil() as i32);
    let manual = match class_id {
        29..=36 => CRAFTERS_PRIME,
        39..=41 => GATHERERS_PRIME,
        _ => return total,
    };
    if let Some(e) = c.status_effects.get_mut(manual) {
        let left = e.magnitude.max(0.0);
        let extra = (gain as f64 * e.extra / 100.0).ceil().min(left);
        e.magnitude = left - extra;
        total = total.saturating_add(extra as i32);
    }
    total
}

/// When each (player, recast group) is ready again.
static RECASTS: Mutex<Option<HashMap<(u32, i32), Instant>>> = Mutex::new(None);

/// Every recast group ready again for `player_id` (GM `!resetrecast`).
pub(crate) fn reset_recasts(player_id: u32) {
    if let Some(recasts) = RECASTS.lock().unwrap().as_mut() {
        recasts.retain(|(p, _), _| *p != player_id);
    }
}

fn take_recast(player_id: u32, group: i32, recast_s: f32) -> bool {
    let mut guard = RECASTS.lock().unwrap();
    let recasts = guard.get_or_insert_with(HashMap::new);
    let now = Instant::now();
    if recasts.get(&(player_id, group)).is_some_and(|t| *t > now) {
        return false;
    }
    recasts.insert(
        (player_id, group),
        now + Duration::from_secs_f32(recast_s.max(0.0)),
    );
    true
}

/// Who an item lands on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Target {
    /// The user, or another player.
    Ally,
    /// A KO'd player other than the user.
    DeadAlly,
    /// A living non-player.
    Enemy,
    /// The user only.
    User,
}

impl ItemUse {
    fn target(&self) -> Target {
        match self {
            ItemUse::Ailment(_) => Target::Enemy,
            ItemUse::Raise(_) => Target::DeadAlly,
            ItemUse::Cure(_) | ItemUse::Status(..) | ItemUse::Show => Target::Ally,
            ItemUse::Restore | ItemUse::Buff(_) | ItemUse::Manual(_) => Target::User,
        }
    }
}

impl PacketProcessor {
    /// Params after the trigger name: the bag item (Type7), nil, the
    /// quantity, nil, the target actor, four nils and the item ids (Type9).
    pub(super) async fn apply_item_command(
        &self,
        handle: &ActorHandle,
        command_actor_id: u32,
        event_name: String,
        params: &[LuaParam],
    ) {
        let player_id = handle.actor_id;
        let target = params
            .iter()
            .find_map(|p| match p {
                LuaParam::Actor(id) if *id != 0 && *id != 0xC000_0000 => Some(*id),
                _ => None,
            })
            .unwrap_or(player_id);
        if let Some(LuaParam::Type7 {
            slot,
            inventory_type,
            ..
        }) = params.first()
        {
            self.use_item(player_id, *inventory_type as u16, *slot as u16, target)
                .await;
        } else {
            tracing::warn!(player = player_id, ?params, "ItemCommand: no bag item");
        }
        let end = LuaCommand::EndEvent {
            player_id,
            event_owner: command_actor_id,
            event_name,
        };
        Box::pin(self.apply_event_script_commands(handle, vec![end])).await;
    }

    pub(crate) async fn use_item(&self, player_id: u32, package: u16, slot: u16, target: u32) {
        let Ok(Some((_, catalog_id))) = self
            .db
            .resolve_bag_slot_item_id(player_id, package, slot)
            .await
        else {
            return;
        };
        let item = match self.db.usable_item(catalog_id).await {
            Ok(Some(item)) if item.usable => item,
            _ => return self.cannot_use(player_id, catalog_id).await,
        };
        self.use_catalog_item(player_id, package, catalog_id, &item, target)
            .await;
    }

    /// Use `item` (catalog id `catalog_id`, from bag `package`) on `target`.
    pub(crate) async fn use_catalog_item(
        &self,
        player_id: u32,
        package: u16,
        catalog_id: u32,
        item: &crate::database::UsableItem,
        target: u32,
    ) {
        let Some(what) = item_use(catalog_id, item) else {
            tracing::info!(player = player_id, catalog_id, category = %item.category, "ItemCommand: no effect for this item");
            return self.cannot_use(player_id, catalog_id).await;
        };
        let Some(target) = self.item_target(player_id, target, &what).await else {
            tracing::info!(
                player = player_id,
                catalog_id,
                target,
                ?what,
                "ItemCommand: no valid target"
            );
            return self.cannot_use(player_id, catalog_id).await;
        };
        if !take_recast(player_id, item.recast_group, item.recast_s) {
            tracing::info!(
                player = player_id,
                catalog_id,
                group = item.recast_group,
                "ItemCommand: recast not ready"
            );
            return self.cannot_use(player_id, catalog_id).await;
        }
        crate::runtime::quest_apply::apply_remove_item(
            player_id,
            package,
            catalog_id,
            1,
            &self.registry,
            Some(&self.world),
            &self.db,
        )
        .await;
        let duration = item.duration_s.max(1.0) as u32;
        let use_text = if target == player_id {
            MSG_USE
        } else {
            MSG_USE_ON
        };
        match &what {
            ItemUse::Restore => {
                self.use_text(player_id, target, catalog_id, MSG_DRINK)
                    .await;
                self.restore_pools(player_id, &item.effects).await;
            }
            ItemUse::Buff(status) => {
                let text = if *status == WELL_FED {
                    MSG_EAT
                } else {
                    MSG_DRINK
                };
                self.use_text(player_id, target, catalog_id, text).await;
                let buff = buff_for(catalog_id, *status, item);
                self.give_buff(player_id, buff, catalog_id, duration).await;
            }
            ItemUse::Ailment(statuses) => {
                self.use_text(player_id, target, catalog_id, use_text).await;
                for &status in *statuses {
                    self.try_status(player_id, target, status, duration, 0.0)
                        .await;
                }
                if let Some(h) = self.registry.get(target).await {
                    h.character.write().await.hate.update_hate(player_id, 1);
                }
            }
            ItemUse::Cure(cures) => {
                self.use_text(player_id, target, catalog_id, use_text).await;
                self.remove_statuses(target, cures, true).await;
                if let Some(h) = self.registry.get(target).await {
                    let c = h.character.read().await;
                    let left: Vec<u32> = cures
                        .iter()
                        .copied()
                        .filter(|s| c.status_effects.has(*s))
                        .collect();
                    tracing::info!(player = player_id, catalog_id, target, ?left, "item cure");
                }
            }
            ItemUse::Raise(chance) => {
                if rand::random::<f64>() < *chance {
                    self.use_text(player_id, target, catalog_id, use_text).await;
                    if let Some(h) = self.registry.get(target).await
                        && let Some(zone) = self.world.zone(h.zone_id).await
                    {
                        crate::runtime::dispatcher::apply_revive(
                            target,
                            &self.registry,
                            &self.world,
                            &zone,
                        )
                        .await;
                    }
                } else {
                    self.use_text(player_id, target, catalog_id, MSG_USE_FAILED)
                        .await;
                }
            }
            ItemUse::Status(status, magnitude) => {
                self.use_text(player_id, target, catalog_id, use_text).await;
                self.remove_statuses(target, &[*status], false).await;
                self.try_status(player_id, target, *status, duration, *magnitude)
                    .await;
            }
            ItemUse::Manual(status) => {
                self.use_text(player_id, target, catalog_id, MSG_USE).await;
                let (pct, cap) = manual_bonus(item);
                self.remove_statuses(player_id, &[*status], false).await;
                self.try_status(player_id, player_id, *status, duration, cap)
                    .await;
                if let Some(h) = self.registry.get(player_id).await
                    && let Some(e) = h.character.write().await.status_effects.get_mut(*status)
                {
                    e.extra = pct;
                }
            }
            ItemUse::Show => {
                self.use_text(player_id, target, catalog_id, use_text).await;
            }
        }
        tracing::info!(player = player_id, catalog_id, target, category = %item.category, ?what, "item used");
    }

    /// The actor an item lands on: the user, or the requested target if the
    /// item may land on it. `None` if there is no valid one.
    async fn item_target(&self, player_id: u32, requested: u32, what: &ItemUse) -> Option<u32> {
        let kind = what.target();
        let id = match kind {
            Target::User => player_id,
            _ => requested,
        };
        let handle = self.registry.get(id).await?;
        let c = handle.character.read().await;
        let dead = c.base.current_main_state == crate::actor::MAIN_STATE_DEAD;
        let ok = match kind {
            Target::User => !dead,
            Target::Ally => handle.is_player() && !dead,
            Target::DeadAlly => handle.is_player() && dead && id != player_id,
            Target::Enemy => !handle.is_player() && !dead && c.chara.max_hp > 0,
        };
        // A cure with nothing to cure isn't used up.
        let has_cure = match what {
            ItemUse::Cure(cures) => cures.iter().any(|s| c.status_effects.has(*s)),
            _ => true,
        };
        (ok && has_cure).then_some(id)
    }

    async fn try_status(
        &self,
        source: u32,
        target: u32,
        status: u32,
        duration: u32,
        magnitude: f64,
    ) {
        crate::runtime::quest_apply::apply_try_status(
            source,
            target,
            status,
            duration,
            magnitude,
            0,
            0,
            &self.registry,
            &self.db,
            &self.world,
            self.lua.as_ref(),
        )
        .await;
    }

    /// Take `statuses` off `target`; `announce` logs the loss (a cure),
    /// otherwise it's quiet (a fresh use restarting the same status).
    async fn remove_statuses(&self, target: u32, statuses: &[u32], announce: bool) {
        let Some(handle) = self.registry.get(target).await else {
            return;
        };
        let mut outbox = crate::status::StatusOutbox::new();
        {
            let mut c = handle.character.write().await;
            for &id in statuses {
                c.status_effects.remove_status_effect(
                    id,
                    crate::status::DEFAULT_LOSS_TEXT_ID,
                    announce,
                    &mut outbox,
                );
            }
        }
        if let Some(lua) = self.lua.as_ref() {
            for event in outbox.drain() {
                crate::runtime::dispatcher::dispatch_status_event(
                    &event,
                    &self.registry,
                    &self.world,
                    &self.db,
                    lua.catalogs(),
                )
                .await;
            }
        }
    }

    /// Antidote and the like used on yourself: take off the statuses the
    /// item cures. It can't be used (and isn't spent) when you have none.
    #[cfg(test)]
    pub(crate) async fn use_remove_status_item(
        &self,
        player_id: u32,
        package: u16,
        catalog_id: u32,
        item: &crate::database::UsableItem,
        cures: &[u32],
    ) {
        let has_any = match self.registry.get(player_id).await {
            Some(h) => {
                let c = h.character.read().await;
                cures.iter().any(|id| c.status_effects.has(*id))
            }
            None => return,
        };
        if !has_any || !take_recast(player_id, item.recast_group, item.recast_s) {
            return self.cannot_use(player_id, catalog_id).await;
        }
        crate::runtime::quest_apply::apply_remove_item(
            player_id,
            package,
            catalog_id,
            1,
            &self.registry,
            Some(&self.world),
            &self.db,
        )
        .await;
        self.remove_statuses(player_id, cures, true).await;
        tracing::info!(player = player_id, catalog_id, "remove-status item used");
    }

    /// Restore `percent` of max HP / MP / TP, up to each effect's cap, and
    /// log "You recover N HP." for each.
    async fn restore_pools(&self, player_id: u32, effects: &[(u32, i32, i32)]) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        for &(kind, percent, cap) in effects {
            let Some(stat) = kind.checked_sub(RESTORE_BASE).filter(|s| *s < 3) else {
                continue;
            };
            let (now, max) = {
                let c = handle.character.read().await;
                match stat {
                    0 => (c.chara.hp as i32, c.chara.max_hp as i32),
                    1 => (c.chara.mp as i32, c.chara.max_mp as i32),
                    _ => (c.chara.tp as i32, MAX_TP),
                }
            };
            let mut amount = max * percent / 100;
            if cap > 0 {
                amount = amount.min(cap);
            }
            let gained = amount.min((max - now).max(0));
            tracing::info!(player = player_id, stat, now, max, gained, "item restore");
            let r = &self.registry;
            match stat {
                0 => crate::runtime::dispatcher::apply_hp_delta(r, player_id, amount).await,
                1 => crate::runtime::dispatcher::apply_mp_delta(r, player_id, amount).await,
                _ => crate::runtime::dispatcher::apply_tp_delta(r, player_id, amount).await,
            };
            self.battle_text(
                player_id,
                player_id,
                MSG_RECOVER[stat as usize],
                gained.max(0) as u32,
            )
            .await;
        }
        crate::runtime::dispatcher::sync_pools_after_tick(&self.registry, &self.world, player_id)
            .await;
    }

    /// Food and medicine: (re)start the buff status for `duration_s` with
    /// this item's bonuses; the status gain recalculates stats. The status
    /// magnitude is the item, so a relog can rebuild the bonuses.
    async fn give_buff(&self, player_id: u32, buff: FoodBuff, catalog_id: u32, duration_s: u32) {
        let status = buff.status_id;
        let mods: Vec<u32> = buff
            .bonuses
            .iter()
            .map(|b| b.0)
            .chain(buff.flat.iter().map(|f| f.0))
            .collect();
        let read_mods = |c: &Character| -> Vec<(u32, f64)> {
            mods.iter().map(|&m| (m, c.chara.mods.get_raw(m))).collect()
        };
        self.remove_statuses(player_id, &[status], false).await;
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let before = {
            let mut c = handle.character.write().await;
            c.food.retain(|f| f.status_id != status);
            c.food.push(buff);
            read_mods(&c)
        };
        self.try_status(player_id, player_id, status, duration_s, catalog_id as f64)
            .await;
        let after = read_mods(&*handle.character.read().await);
        tracing::info!(
            player = player_id,
            catalog_id,
            status,
            ?before,
            ?after,
            "item buff stats"
        );
    }

    /// At login: rebuild the stat bonuses of restored food / medicine
    /// statuses from the item each one names.
    pub(crate) async fn restore_item_buffs(&self, character: &mut Character) {
        for status in BUFF_STATUSES {
            let Some(catalog_id) = character
                .status_effects
                .get(status)
                .map(|e| e.magnitude as u32)
                .filter(|id| *id > 1_000_000)
            else {
                continue;
            };
            if character.food.iter().any(|f| f.status_id == status) {
                continue;
            }
            if let Ok(Some(item)) = self.db.usable_item(catalog_id).await {
                character.food.push(buff_for(catalog_id, status, &item));
            }
        }
    }

    /// "You use <item> (on <target>)." — a worldMaster game message.
    ///
    /// Client-checked layout (1.23b): the item texts read the item from
    /// the second Int32 param and its quality (0 = normal, 1-3 = +1..+3)
    /// from the third (an Actor-typed param before them blanks the name),
    /// and the target of "... on <target>" from a fourth, Actor param. Log type
    /// 0x1D shows the line as your own action ("You drink a potion.");
    /// 0x20 prefixes it with your name like a chat line. The message actor
    /// must be a real actor: the worldMaster id crashes the client.
    async fn use_text(&self, player_id: u32, target: u32, catalog_id: u32, text_id: u16) {
        let mut params = vec![
            LuaParam::Int32(player_id as i32),
            LuaParam::Int32(catalog_id as i32),
            LuaParam::Int32(0),
        ];
        // "... on <target>": the target as an Actor param after the quality.
        if matches!(text_id, MSG_USE_ON | MSG_USE_FAILED) {
            params.push(LuaParam::Actor(target));
        }
        let bytes = crate::packets::send::misc::build_game_message_actor1_with_params(
            player_id,
            player_id,
            crate::packets::send::misc::WORLD_MASTER_ACTOR_ID,
            text_id,
            ITEM_TEXT_LOG,
            &params,
        )
        .to_bytes();
        crate::runtime::dispatcher::send_to_self_if_player(
            &self.registry,
            &self.world,
            player_id,
            bytes,
        )
        .await;
    }

    /// A battle text on `target` with `amount`, from the item command.
    async fn battle_text(&self, player_id: u32, target: u32, text_id: u16, amount: u32) {
        let result = crate::packets::send::actor_battle::CommandResult {
            target_id: target,
            worldmaster_text_id: text_id,
            amount,
            hit_num: 1,
            ..Default::default()
        };
        let bytes = crate::packets::send::actor_battle::build_command_result_x01(
            player_id,
            0,
            ITEM_COMMAND_ID,
            &result,
        )
        .to_bytes();
        crate::runtime::dispatcher::send_to_self_if_player(
            &self.registry,
            &self.world,
            player_id,
            bytes,
        )
        .await;
    }

    /// "<command> cannot be used now." A battle text: it names the command
    /// from a CommandResult, so it can't go out as a game message.
    async fn cannot_use(&self, player_id: u32, _catalog_id: u32) {
        self.battle_text(player_id, player_id, MSG_CANNOT_USE, 0)
            .await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::UsableItem;

    fn item(category: &str, effects: Vec<(u32, i32, i32)>) -> UsableItem {
        UsableItem {
            category: format!("Normal/{category}"),
            usable: true,
            effects,
            ..Default::default()
        }
    }

    #[test]
    fn each_kind_maps_to_its_use() {
        let potion = item("PotionItem", vec![(1_016_001, 40, 100)]);
        assert_eq!(item_use(3_020_001, &potion), Some(ItemUse::Restore));
        let food = item("FoodItem", vec![(EXP_TYPE, 3, 0)]);
        assert_eq!(item_use(3_011_001, &food), Some(ItemUse::Buff(WELL_FED)));
        let med = item("EnchantMedicineItem", vec![(1_015_004, 22, 20)]);
        assert_eq!(item_use(3_020_512, &med), Some(ItemUse::Buff(MEDICATED)));
        let wall = item("EnchantMedicineItem", vec![]);
        assert_eq!(item_use(3_020_530, &wall), Some(ItemUse::Buff(BLOODWALL)));
        assert_eq!(item_use(3_020_535, &wall), Some(ItemUse::Buff(MANAWALL)));
        let bad = item("CmnBadStatusItem", vec![]);
        assert_eq!(
            item_use(3_020_307, &bad),
            Some(ItemUse::Ailment(&[POISON, SILENCE]))
        );
        // Venom Potion has no data in 1.23b.
        assert_eq!(item_use(3_020_309, &bad), None);
        let cure = item("CmnRemoveStatusItem", vec![]);
        assert_eq!(
            item_use(3_020_409, &cure),
            Some(ItemUse::Cure(&[PETRIFICATION]))
        );
        let mut raise = item("RaiseItem", vec![]);
        raise.magnitude = 0.6;
        assert_eq!(item_use(3_020_411, &raise), Some(ItemUse::Raise(0.6)));
        let mut good = item("CmnGoodStatusItem", vec![]);
        good.magnitude = 45.0;
        assert_eq!(
            item_use(3_020_502, &good),
            Some(ItemUse::Status(SHELL, 45.0))
        );
        assert_eq!(item_use(3_020_613, &good), Some(ItemUse::Show));
        assert_eq!(item_use(3_020_503, &good), None);
        // Unreleased potions with no effect data.
        assert_eq!(item_use(3_020_104, &item("PotionItem", vec![])), None);
    }

    #[test]
    fn buffs_split_percent_and_flat_bonuses() {
        // Dodo Omelette: HP +13% (max 45), VIT +2, EXP +3%.
        let omelette = item(
            "FoodItem",
            vec![(1_015_001, 13, 45), (15_005, 2, 0), (EXP_TYPE, 3, 0)],
        );
        let b = buff_for(3_010_004, WELL_FED, &omelette);
        assert_eq!(b.bonuses, vec![(Modifier::Hp as u32, 13, 45), (62, 3, 0)]);
        assert_eq!(b.flat, vec![(Modifier::Vitality as u32, 2)]);
        // Maddening Potion: Enmity +100 (flat 15052).
        let maddening = item("EnchantMedicineItem", vec![(15_052, 100, 0)]);
        let b = buff_for(3_020_305, MEDICATED, &maddening);
        assert_eq!(b.flat, vec![(Modifier::Enmity as u32, 100)]);
        let b = buff_for(3_020_533, MANAWALL, &item("EnchantMedicineItem", vec![]));
        assert_eq!(b.flat.len(), 6);
    }

    #[test]
    fn manuals_pay_their_bonus_until_the_pool_runs_out() {
        let mut c = Character::new(1);
        let mut outbox = crate::status::StatusOutbox::new();
        let mut e = crate::status::StatusEffect::new(1, CRAFTERS_PRIME, 100.0, 0, 10_800, 0, 0);
        e.extra = 50.0;
        c.status_effects
            .add_status_effect(e, 1, 0, 30328, &mut outbox);
        // Weaver (32): +50%, but only 100 bonus left.
        assert_eq!(item_exp_bonus(&mut c, 32, 120), 180);
        assert_eq!(item_exp_bonus(&mut c, 32, 120), 160);
        assert_eq!(item_exp_bonus(&mut c, 32, 120), 120);
        // A battle class gets nothing from the manual.
        c.status_effects.get_mut(CRAFTERS_PRIME).unwrap().magnitude = 1000.0;
        assert_eq!(item_exp_bonus(&mut c, 2, 120), 120);
        // Food's EXP +3% applies everywhere.
        c.chara.mods.set(Modifier::Exp, 3.0);
        assert_eq!(item_exp_bonus(&mut c, 2, 100), 103);
    }
}
