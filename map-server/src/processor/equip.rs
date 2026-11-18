// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `EquipCommand`: equipping and removing gear from the Gear window.
//!
//! Meteor runs this in `commands/EquipCommand.lua` on top of its live
//! `ReferencedItemPackage`. Most of what that script calls has no binding
//! here, so it's done natively against the database: equip or clear the
//! gear slot, switch class when a main hand of another class goes on,
//! re-link the client's equipment package, and redraw the gear graphics.

use common::luaparam::LuaParam;

use super::PacketProcessor;
use crate::actor::player::{
    SLOT_BODY, SLOT_EARS, SLOT_FEET, SLOT_FINGER_LEFT, SLOT_FINGER_RIGHT, SLOT_HANDS, SLOT_HEAD,
    SLOT_LEGS, SLOT_MAINHAND, SLOT_NECK, SLOT_OFFHAND, SLOT_PACK, SLOT_THROWINGWEAPON,
    SLOT_UNDERGARMENT, SLOT_UNDERSHIRT, SLOT_WAIST, SLOT_WRISTS, gear_slot_fits,
};
use crate::lua::command::LuaCommand;
use crate::packets::send as tx;
use crate::runtime::actor_registry::ActorHandle;

const WORLD_MASTER: u32 = 0x5FF8_0001;
/// "You equip <item>." / "You remove <item>." / "<item> cannot be removed."
const MSG_EQUIPPED: u32 = 30601;
const MSG_REMOVED: u32 = 30602;
const MSG_CANNOT_REMOVE: u32 = 30730;
const LOG_SYSTEM: u8 = 0x20;
/// The bag: 200 slots, code 0.
const NORMAL_CAPACITY: u16 = 200;
const NORMAL_CODE: u16 = 0;
/// The equipment package: 35 gear slots, code 0x00FE.
const EQUIPMENT_CAPACITY: u16 = 35;
const EQUIPMENT_CODE: u16 = 0x00FE;
/// Bare hands and feet (Meteor `GraphicChange(slot, 0, 1, 0, 0)`).
const BARE_GRAPHIC: u32 = 1 << 10;

/// Every gear slot that draws something.
const DRAWN_SLOTS: [u16; 16] = [
    SLOT_MAINHAND,
    SLOT_OFFHAND,
    SLOT_THROWINGWEAPON,
    SLOT_PACK,
    SLOT_HEAD,
    SLOT_BODY,
    SLOT_LEGS,
    SLOT_HANDS,
    SLOT_FEET,
    SLOT_WAIST,
    SLOT_NECK,
    SLOT_EARS,
    SLOT_WRISTS,
    SLOT_FINGER_RIGHT,
    SLOT_FINGER_LEFT,
    SLOT_UNDERSHIRT,
];

/// The class a main hand makes you (Meteor `ItemData.Is*Weapon`).
pub(crate) fn weapon_class(catalog_id: u32) -> Option<u8> {
    Some(match catalog_id / 10_000 {
        402 => 2,  // pugilist
        403 => 3,  // gladiator
        404 => 4,  // marauder
        407 => 7,  // archer
        408 => 8,  // lancer
        502 => 22, // thaumaturge
        503 => 23, // conjurer
        601 => 29, // carpenter
        602 => 30, // blacksmith
        603 => 31, // armorer
        604 => 32, // goldsmith
        605 => 33, // leatherworker
        606 => 34, // weaver
        607 => 35, // alchemist
        608 => 36, // culinarian
        701 => 39, // miner
        702 => 40, // botanist
        703 => 41, // fisher
        _ => return None,
    })
}

/// Appearance slots (0x00D6 indices) a gear slot draws into, with the
/// `characters_appearance` column that keeps each, if any.
fn graphic_slots(equip_slot: u16) -> &'static [(usize, Option<&'static str>)] {
    match equip_slot {
        SLOT_MAINHAND => &[(5, Some("mainhand"))],
        SLOT_OFFHAND => &[(6, Some("offhand"))],
        SLOT_THROWINGWEAPON => &[(9, None)],
        SLOT_PACK => &[(10, None)],
        SLOT_HEAD => &[(12, Some("head"))],
        SLOT_BODY => &[(13, Some("body"))],
        SLOT_LEGS => &[(14, Some("legs"))],
        SLOT_HANDS => &[(15, Some("hands"))],
        SLOT_FEET => &[(16, Some("feet"))],
        SLOT_WAIST => &[(17, Some("waist"))],
        SLOT_NECK => &[(18, Some("neck"))],
        SLOT_EARS => &[(19, Some("leftEar")), (20, Some("rightEar"))],
        SLOT_WRISTS => &[(21, None), (22, None)],
        SLOT_FINGER_RIGHT => &[(23, Some("rightFinger"))],
        SLOT_FINGER_LEFT => &[(24, Some("leftFinger"))],
        _ => &[],
    }
}

/// Pack item graphics into an appearance id (Meteor `Player.GraphicChange`).
fn pack_graphic((weapon, equipment, variant, color): (u32, u32, u32, u32)) -> u32 {
    let mixed = if weapon == 0 {
        ((variant & 0x1F) << 5) | color
    } else {
        variant
    };
    (weapon & 0x3FF) << 20 | (equipment & 0x3FF) << 10 | (mixed & 0x3FF)
}

impl PacketProcessor {
    /// `EquipCommand` from the Gear window. Params after the trigger name:
    /// the bag item (Type7, nil to remove), seven unused, the 1-based gear
    /// slot, and the item ids (Type9).
    pub(super) async fn apply_equip_command(
        &self,
        handle: &ActorHandle,
        command_actor_id: u32,
        event_name: String,
        params: &[LuaParam],
    ) {
        let player_id = handle.actor_id;
        // Changing gear or class ends Monster Mode first, so the change
        // lands on the player's own body.
        if crate::runtime::monster_mode::release(player_id, "gear")
            .await
            .is_some()
        {
            crate::runtime::monster_mode::refresh_client(&self.registry, &self.world, player_id)
                .await;
        }
        let item_ref = match params.first() {
            Some(LuaParam::Type7 {
                slot,
                inventory_type,
                ..
            }) => Some((*inventory_type as u16, *slot as u16)),
            _ => None,
        };
        let equip_slot = match params.get(8) {
            Some(LuaParam::Int32(v)) => (*v as i64) - 1,
            Some(LuaParam::UInt32(v)) => (*v as i64) - 1,
            Some(LuaParam::Short(v)) => (*v as i64) - 1,
            Some(LuaParam::Byte(v)) => (*v as i64) - 1,
            _ => -1,
        };
        if (0..EQUIPMENT_CAPACITY as i64).contains(&equip_slot) {
            let equip_slot = equip_slot as u16;
            match item_ref {
                Some((package, slot)) => {
                    self.equip_gear(player_id, equip_slot, package, slot).await
                }
                None => self.remove_gear(player_id, equip_slot).await,
            }
        } else {
            tracing::warn!(
                player = player_id,
                ?params,
                "EquipCommand: no gear slot in params"
            );
        }
        let end = LuaCommand::EndEvent {
            player_id,
            event_owner: command_actor_id,
            event_name,
        };
        Box::pin(self.apply_event_script_commands(handle, vec![end])).await;
    }

    async fn current_class(&self, player_id: u32) -> u8 {
        let Some(handle) = self.registry.get(player_id).await else {
            return 0;
        };
        let c = handle.character.read().await;
        if c.chara.current_job != 0 {
            c.chara.current_job as u8
        } else {
            c.chara.class.max(0) as u8
        }
    }

    pub(super) async fn equip_gear(
        &self,
        player_id: u32,
        equip_slot: u16,
        package: u16,
        slot: u16,
    ) {
        let Ok(Some((server_item_id, catalog_id))) = self
            .db
            .resolve_bag_slot_item_id(player_id, package, slot)
            .await
        else {
            tracing::debug!(
                player = player_id,
                package,
                slot,
                "EquipCommand: bag slot empty"
            );
            return;
        };
        // The client sends whatever slot the item was dropped on; gear that
        // doesn't go there is refused (a robe on the head draws white).
        if let Ok(Some(point)) = self.db.item_equip_point(catalog_id).await
            && gear_slot_fits(point, equip_slot) == Some(false)
        {
            tracing::warn!(
                player = player_id,
                item = catalog_id,
                point,
                equip_slot,
                "EquipCommand: item doesn't go in that gear slot"
            );
            return;
        }
        let mut class_id = self.current_class(player_id).await;
        let mut redraw: Vec<u16> = vec![equip_slot];
        let mut switched = false;
        // A main hand of another class switches to that class; a class with
        // no outfit of its own yet keeps the one being worn.
        if equip_slot == SLOT_MAINHAND
            && let Some(new_class) = weapon_class(catalog_id)
            && new_class != class_id
        {
            if let Err(e) = self
                .db
                .copy_class_equipment(player_id, class_id, new_class)
                .await
            {
                tracing::warn!(player = player_id, err = %e, "EquipCommand: copying gear to new class failed");
            }
            self.apply_prepare_class_change(player_id, new_class).await;
            self.apply_do_class_change(player_id, new_class).await;
            class_id = new_class;
            redraw = DRAWN_SLOTS.to_vec();
            switched = true;
        }
        if equip_slot == SLOT_UNDERSHIRT {
            redraw.push(SLOT_BODY);
        } else if equip_slot == SLOT_UNDERGARMENT {
            redraw.push(SLOT_LEGS);
        }
        let replaced = match self.db.equipped_item(player_id, class_id, equip_slot).await {
            Ok(Some((old, _, _))) => Some(old),
            _ => None,
        };
        self.store_gear(player_id, equip_slot, Some(server_item_id))
            .await;
        let quality = match self.db.equipped_item(player_id, class_id, equip_slot).await {
            Ok(Some((_, _, q))) => q.max(1),
            _ => 1,
        };
        self.gear_message(player_id, MSG_EQUIPPED, equip_slot, catalog_id, quality)
            .await;
        if switched {
            self.send_class_state(player_id).await;
        }
        let changed: Vec<u64> = std::iter::once(server_item_id).chain(replaced).collect();
        self.send_gear_update(player_id, class_id, &changed, None)
            .await;
        self.redraw_gear(player_id, class_id, &redraw).await;
    }

    /// After a class switch: HP, the class and its level for the HUD's
    /// class line and the nameplate (`stateAtQuicklyForAll`, the packet the
    /// stat recalc sends only when the pools moved).
    async fn send_class_state(&self, player_id: u32) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let (hp, hp_max, class, level) = {
            let c = handle.character.read().await;
            (
                c.chara.hp.max(0) as u16,
                c.chara.max_hp.max(0) as u16,
                c.chara.class.max(0) as u8,
                c.chara.level.max(1) as u16,
            )
        };
        for sub in
            tx::actor::build_player_state_at_quickly_for_all(player_id, hp, hp_max, class, level)
        {
            let bytes = sub.to_bytes();
            crate::runtime::dispatcher::send_to_self_if_player(
                &self.registry,
                &self.world,
                player_id,
                bytes.clone(),
            )
            .await;
            crate::runtime::dispatcher::broadcast_to_neighbours(
                &self.world,
                &self.registry,
                player_id,
                bytes,
            )
            .await;
        }
    }

    pub(super) async fn remove_gear(&self, player_id: u32, equip_slot: u16) {
        let class_id = self.current_class(player_id).await;
        let Ok(Some((server_item_id, catalog_id, quality))) =
            self.db.equipped_item(player_id, class_id, equip_slot).await
        else {
            return;
        };
        let quality = quality.max(1);
        if matches!(
            equip_slot,
            SLOT_MAINHAND | SLOT_UNDERSHIRT | SLOT_UNDERGARMENT
        ) {
            self.gear_message(
                player_id,
                MSG_CANNOT_REMOVE,
                equip_slot,
                catalog_id,
                quality,
            )
            .await;
            return;
        }
        self.store_gear(player_id, equip_slot, None).await;
        self.gear_message(player_id, MSG_REMOVED, equip_slot, catalog_id, quality)
            .await;
        self.send_gear_update(player_id, class_id, &[server_item_id], Some(equip_slot))
            .await;
        self.redraw_gear(player_id, class_id, &[equip_slot]).await;
    }

    /// Equip or clear through the inventory dispatcher: the DB row plus the
    /// stat recalculation.
    async fn store_gear(&self, player_id: u32, equip_slot: u16, server_item_id: Option<u64>) {
        let event = match server_item_id {
            Some(unique_item_id) => crate::inventory::InventoryEvent::DbEquip {
                owner_actor_id: player_id,
                equip_slot,
                unique_item_id,
            },
            None => crate::inventory::InventoryEvent::DbUnequip {
                owner_actor_id: player_id,
                equip_slot,
            },
        };
        match self.lua.as_ref() {
            Some(lua) => {
                crate::runtime::dispatcher::dispatch_inventory_event(
                    &event,
                    &self.registry,
                    &self.world,
                    &self.db,
                    lua.catalogs(),
                )
                .await
            }
            None => tracing::warn!(
                player = player_id,
                "EquipCommand: no Lua engine for the stat recalc"
            ),
        }
    }

    async fn gear_message(
        &self,
        player_id: u32,
        text_id: u32,
        equip_slot: u16,
        catalog_id: u32,
        quality: u8,
    ) {
        let params = [
            equip_slot as i64 + 1,
            catalog_id as i64,
            quality as i64,
            0,
            0,
            1,
        ];
        crate::runtime::quest_apply::apply_send_game_message(
            player_id,
            WORLD_MASTER,
            text_id,
            LOG_SYSTEM,
            &params,
            &self.registry,
            &self.world,
        )
        .await;
    }

    async fn send_to_player(&self, player_id: u32, subs: Vec<common::subpacket::SubPacket>) {
        let Some(handle) = self.registry.get(player_id).await else {
            return;
        };
        let Some(client) = self.world.client(handle.session_id).await else {
            return;
        };
        for mut sub in subs {
            sub.set_target_id(handle.session_id);
            client.send_bytes(sub.to_bytes()).await;
        }
    }

    /// Tell the client what changed, the way Meteor's `ReferencedItemPackage`
    /// `Set` / `Clear` do: the changed bag items again (their equipped
    /// marks), the whole equipment package re-linked, and a cleared gear
    /// slot unlinked. A lone link packet mid-session doesn't refresh the
    /// Gear window.
    async fn send_gear_update(
        &self,
        player_id: u32,
        class_id: u8,
        changed_items: &[u64],
        cleared_slot: Option<u16>,
    ) {
        let bag = self
            .db
            .get_item_package(player_id, NORMAL_CODE as u32)
            .await
            .unwrap_or_default();
        let links = crate::runtime::quest_apply::load_initial_equipment_pairs(
            &self.db, player_id, class_id,
        )
        .await;
        let mut subs = vec![
            tx::actor_inventory::build_inventory_begin_change(player_id, false),
            tx::actor_inventory::build_inventory_set_begin(player_id, NORMAL_CAPACITY, NORMAL_CODE),
        ];
        subs.extend(
            bag.iter()
                .filter(|item| changed_items.contains(&item.unique_id))
                .map(|item| tx::actor_inventory::build_inventory_list_x01(player_id, item)),
        );
        subs.push(tx::actor_inventory::build_inventory_set_end(player_id));
        subs.push(tx::actor_inventory::build_inventory_set_begin(
            player_id,
            EQUIPMENT_CAPACITY,
            EQUIPMENT_CODE,
        ));
        subs.extend(tx::actor_inventory::build_set_initial_equipment(
            player_id, &links,
        ));
        subs.push(tx::actor_inventory::build_inventory_set_end(player_id));
        if let Some(slot) = cleared_slot {
            subs.push(tx::actor_inventory::build_inventory_set_begin(
                player_id,
                EQUIPMENT_CAPACITY,
                EQUIPMENT_CODE,
            ));
            subs.push(tx::actor_inventory::build_inventory_remove_x01(
                player_id, slot,
            ));
            subs.push(tx::actor_inventory::build_inventory_set_end(player_id));
        }
        subs.push(tx::actor_inventory::build_inventory_end_change(player_id));
        self.send_to_player(player_id, subs).await;
    }

    /// The graphic a gear slot shows now: its item, or what shows through
    /// when it's empty (the undershirt under no body, bare hands and feet).
    async fn gear_graphic(&self, player_id: u32, class_id: u8, equip_slot: u16) -> u32 {
        let item_graphic = |slot: u16| async move {
            match self.db.equipped_item(player_id, class_id, slot).await {
                Ok(Some((_, catalog_id, _))) => self
                    .db
                    .item_graphics(catalog_id)
                    .await
                    .ok()
                    .flatten()
                    .map(pack_graphic),
                _ => None,
            }
        };
        if let Some(g) = item_graphic(equip_slot).await {
            return g;
        }
        match equip_slot {
            SLOT_BODY => item_graphic(SLOT_UNDERSHIRT).await.unwrap_or(0),
            SLOT_LEGS => item_graphic(SLOT_UNDERGARMENT).await.unwrap_or(0),
            SLOT_HANDS | SLOT_FEET => BARE_GRAPHIC,
            _ => 0,
        }
    }

    /// Redraw gear slots: appearance ids, `characters_appearance`, and the
    /// 0x00D6 appearance broadcast.
    async fn redraw_gear(&self, player_id: u32, class_id: u8, equip_slots: &[u16]) {
        let mut changes: Vec<(usize, Option<&'static str>, u32)> = Vec::new();
        for &equip_slot in equip_slots {
            let targets = match equip_slot {
                SLOT_UNDERSHIRT => graphic_slots(SLOT_BODY),
                SLOT_UNDERGARMENT => graphic_slots(SLOT_LEGS),
                s => graphic_slots(s),
            };
            if targets.is_empty() {
                continue;
            }
            let drawn = match equip_slot {
                SLOT_UNDERSHIRT => SLOT_BODY,
                SLOT_UNDERGARMENT => SLOT_LEGS,
                s => s,
            };
            let graphic = self.gear_graphic(player_id, class_id, drawn).await;
            for &(index, column) in targets {
                changes.push((index, column, graphic));
            }
        }
        if changes.is_empty() {
            return;
        }
        if let Some(handle) = self.registry.get(player_id).await {
            let mut c = handle.character.write().await;
            for &(index, _, graphic) in &changes {
                c.chara.appearance_ids[index] = graphic;
            }
        }
        for &(_, column, graphic) in &changes {
            if let Some(column) = column
                && let Err(e) = self
                    .db
                    .save_appearance_slot(player_id, column, graphic)
                    .await
            {
                tracing::warn!(player = player_id, column, err = %e, "EquipCommand: saving appearance failed");
            }
        }
        self.apply_send_appearance(player_id).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn weapons_pick_their_class() {
        assert_eq!(weapon_class(4030010), Some(3)); // Weathered Gladius
        assert_eq!(weapon_class(4020001), Some(2));
        assert_eq!(weapon_class(5030101), Some(23));
        assert_eq!(weapon_class(7030001), Some(41));
        assert_eq!(weapon_class(8031120), None); // a tabard
        assert_eq!(weapon_class(4100001), None); // a shield
    }

    #[test]
    fn graphics_pack_like_meteor() {
        // weapons keep the variant as is
        assert_eq!(pack_graphic((1, 2, 3, 4)), 1 << 20 | 2 << 10 | 3);
        // gear folds the color into the variant
        assert_eq!(pack_graphic((0, 2, 3, 4)), 2 << 10 | (3 << 5 | 4));
    }
}
