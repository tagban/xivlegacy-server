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
//! Meteor never got past a stub for this (`ItemState`), so it's native:
//! potions restore a percentage of HP / MP up to a cap, food and medicine
//! put the Well Fed status on and their stat bonuses ride it (the stat
//! recalc applies them while it lasts, see `Character::apply_food_bonuses`).
//! Each item's recast group has its own timer.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use common::luaparam::LuaParam;

use super::PacketProcessor;
use crate::actor::FoodBuff;
use crate::lua::command::LuaCommand;
use crate::runtime::actor_registry::ActorHandle;

/// "<command> cannot be used now."
const MSG_CANNOT_USE: u16 = 32544;
/// `ItemCommand`'s command id (its static actor is `0xA0F00000 | id`).
const ITEM_COMMAND_ID: u16 = 0x520F;
/// The status food and medicine bonuses ride.
const WELL_FED: u32 = 223_999;
/// `paramBonusType` ranges on consumables: a percent stat buff, a percent
/// HP / MP / TP restore. The stat is `type - base` (`Modifier` ids).
const BUFF_BASE: u32 = 1_015_001;
const RESTORE_BASE: u32 = 1_016_001;
const MAX_TP: i32 = 3000;

/// What each remove-status item (`CmnRemoveStatusItem`) cures, by catalog
/// id. Blood Drops is the English name of the 1.0 Antidote (its French name
/// is "Antidote"; "This alchemically crafted restorative instantly cures
/// poison"). Gold Lung and Goldbile are the Aurum Vale's poisons.
const REMOVE_STATUS_ITEMS: &[(u32, &[u32])] = &[(
    3_020_406,
    &[
        223_011, // Poison
        crate::runtime::aurum_hazards::STATUS_GOLD_LUNG,
        crate::runtime::aurum_hazards::STATUS_GOLDBILE,
    ],
)];

/// The statuses a remove-status item cures, if it is one.
pub fn cures_of(catalog_id: u32) -> Option<&'static [u32]> {
    REMOVE_STATUS_ITEMS
        .iter()
        .find(|(id, _)| *id == catalog_id)
        .map(|(_, cures)| *cures)
}

/// When each (player, recast group) is ready again.
static RECASTS: Mutex<Option<HashMap<(u32, i32), Instant>>> = Mutex::new(None);

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
        if let Some(LuaParam::Type7 {
            slot,
            inventory_type,
            ..
        }) = params.first()
        {
            self.use_item(player_id, *inventory_type as u16, *slot as u16)
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

    async fn use_item(&self, player_id: u32, package: u16, slot: u16) {
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
        if let Some(cures) = cures_of(catalog_id) {
            return self
                .use_remove_status_item(player_id, package, catalog_id, &item, cures)
                .await;
        }
        let restores = item.category.ends_with("/PotionItem");
        let buffs =
            item.category.ends_with("/FoodItem") || item.category.ends_with("/EnchantMedicineItem");
        if !(restores || buffs) || item.effects.is_empty() {
            tracing::info!(player = player_id, catalog_id, category = %item.category, "ItemCommand: no effect for this item yet");
            return self.cannot_use(player_id, catalog_id).await;
        }
        if !take_recast(player_id, item.recast_group, item.recast_s) {
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
        if restores {
            self.restore_pools(player_id, &item.effects).await;
        } else {
            self.eat(player_id, &item.effects, item.duration_s).await;
        }
        tracing::info!(player = player_id, catalog_id, category = %item.category, "item used");
    }

    /// Antidote and the like: take off the statuses the item cures. It can't
    /// be used (and isn't spent) when you have none of them.
    pub(crate) async fn use_remove_status_item(
        &self,
        player_id: u32,
        package: u16,
        catalog_id: u32,
        item: &crate::database::UsableItem,
        cures: &[u32],
    ) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let has_any = {
            let c = handle.character.read().await;
            cures.iter().any(|id| c.status_effects.has(*id))
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
        let mut outbox = crate::status::StatusOutbox::new();
        {
            let mut c = handle.character.write().await;
            for &id in cures {
                c.status_effects.remove_status_effect(
                    id,
                    crate::status::DEFAULT_LOSS_TEXT_ID,
                    true,
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
        tracing::info!(player = player_id, catalog_id, "remove-status item used");
    }

    /// Restore `percent` of max HP / MP / TP, up to each effect's cap.
    async fn restore_pools(&self, player_id: u32, effects: &[(u32, i32, i32)]) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let (max_hp, max_mp) = {
            let c = handle.character.read().await;
            (c.chara.max_hp as i32, c.chara.max_mp as i32)
        };
        for &(kind, percent, cap) in effects {
            let Some(stat) = kind.checked_sub(RESTORE_BASE).filter(|s| *s < 3) else {
                continue;
            };
            let max = [max_hp, max_mp, MAX_TP][stat as usize];
            let mut amount = max * percent / 100;
            if cap > 0 {
                amount = amount.min(cap);
            }
            let r = &self.registry;
            match stat {
                0 => crate::runtime::dispatcher::apply_hp_delta(r, player_id, amount).await,
                1 => crate::runtime::dispatcher::apply_mp_delta(r, player_id, amount).await,
                _ => crate::runtime::dispatcher::apply_tp_delta(r, player_id, amount).await,
            };
        }
        crate::runtime::dispatcher::sync_pools_after_tick(&self.registry, &self.world, player_id)
            .await;
    }

    /// Food and medicine: (re)start Well Fed for `duration_s` with this
    /// item's bonuses; the status gain recalculates stats.
    async fn eat(&self, player_id: u32, effects: &[(u32, i32, i32)], duration_s: f32) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let bonuses = effects
            .iter()
            .filter_map(|&(kind, percent, cap)| Some((kind.checked_sub(BUFF_BASE)?, percent, cap)))
            .collect();
        let mut outbox = crate::status::StatusOutbox::new();
        {
            let mut c = handle.character.write().await;
            c.status_effects.remove_status_effect(
                WELL_FED,
                crate::status::DEFAULT_LOSS_TEXT_ID,
                false,
                &mut outbox,
            );
            c.food = Some(FoodBuff {
                status_id: WELL_FED,
                bonuses,
            });
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
        crate::runtime::quest_apply::apply_try_status(
            player_id,
            player_id,
            WELL_FED,
            duration_s.max(1.0) as u32,
            0.0,
            0,
            0,
            &self.registry,
            &self.db,
            &self.world,
            self.lua.as_ref(),
        )
        .await;
    }

    /// "<command> cannot be used now." A battle text: it names the command
    /// from a CommandResult, so it can't go out as a game message.
    async fn cannot_use(&self, player_id: u32, _catalog_id: u32) {
        let result = crate::packets::send::actor_battle::CommandResult {
            target_id: player_id,
            worldmaster_text_id: MSG_CANNOT_USE,
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
}
