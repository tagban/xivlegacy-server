// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Dungeon boss chests. When a boss of a dungeon copy
//! (`dungeon_fight::BOSS_ROOMS`) falls, a treasure chest appears in its
//! room. The first player to open it rolls the chest's loot: each item
//! goes to a random player of the copy, and quest items go to every
//! player of the copy who is on the quest and doesn't hold one yet
//! (the client's `RaidDungeonTreasureBox:processOpenDzemaelEpicQuestType`).
//!
//! The 1.23b client names no chest actor class for dungeons
//! (`RaidDungeonTreasureBox` and `InstanceRaidTreasureBox` have no
//! `gamedata_actor_class` row), so the chest is the guildleve bonus
//! chest (`GuildleveBonusTreasureBox`, class 1200161), which has the
//! chest model and a talk event. Its `onEventStarted`
//! (`scripts/lua/base/chara/npc/object/GuildleveBonusTreasureBox.lua`)
//! calls `player:OpenDungeonChest(npc)`.
//!
//! The loot tables are mostly empty: the client's chest script reads
//! drop sheets that only ever lived on the retail server, and no
//! archived source lists what the 1.0 dungeon chests held.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};

use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::runtime::dungeon_fight::BossRoom;
use crate::world_manager::WorldManager;

/// `GuildleveBonusTreasureBox`: the chest model with a talk event.
pub const CHEST_CLASS_ID: u32 = 1_200_161;

/// The chest's name over its head.
pub const CHEST_NAME: &str = "Treasure Chest";

/// `gamedata_actor_class.propertyFlags` of the talkable objects.
pub const CHEST_PROPERTY_FLAGS: u32 = 19;

/// One item a chest can give.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ChestItem {
    pub item_id: u32,
    pub quantity: i32,
    /// Given only to players on this quest who don't hold the item yet
    /// (one each); `None` = one roll for a random player of the copy.
    pub quest_id: Option<u32>,
}

/// Enchiridion, for "A Relic Reborn" (Etc106): the one item the 1.23b
/// client's chest script names (`processOpenDzemaelEpicQuestType`,
/// quest 110868, item 10011244).
pub const ENCHIRIDION: ChestItem = ChestItem {
    item_id: 10_011_244,
    quantity: 1,
    quest_id: Some(110_868),
};

/// What the chest after a boss holds, by the boss's
/// `BossRoom::bnpc_id`. Bosses not listed have an empty chest for now.
pub fn loot_for(boss_bnpc_id: u32) -> &'static [ChestItem] {
    match boss_bnpc_id {
        // Batraal, the Dzemael Darkhold's last boss.
        2000 => &[ENCHIRIDION],
        _ => &[],
    }
}

/// The chest's unique id in a copy (one per boss).
pub fn unique_id(boss_bnpc_id: u32) -> String {
    format!("dungeon_chest_{boss_bnpc_id}")
}

/// The chest's actor id in a copy: the content `SpawnActor` formula
/// (the unique id's hash plus the copy's slot).
pub fn actor_id(zone_id: u32, slot: u32, boss_bnpc_id: u32) -> u32 {
    let suffix = common::utils::murmur_hash2(&unique_id(boss_bnpc_id), 0) & 0xFFF;
    let actor_number = crate::content_instance::spawn_actor_number(slot, 0x60000 | suffix);
    (4u32 << 28) | (zone_id << 19) | ((actor_number + 5) & 0x7FFFF)
}

#[derive(Debug, Clone)]
struct Chest {
    zone_id: u32,
    instance_id: u32,
    boss_bnpc_id: u32,
    opened: bool,
}

fn chests() -> &'static Mutex<HashMap<u32, Chest>> {
    static C: OnceLock<Mutex<HashMap<u32, Chest>>> = OnceLock::new();
    C.get_or_init(Default::default)
}

/// Forget a finished copy's chests.
pub fn release_instance(instance_id: u32) {
    chests()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .retain(|_, c| c.instance_id != instance_id);
}

/// A boss of a copy fell: put its chest in the middle of its room.
/// Players in range get it through the normal actor streaming.
pub async fn spawn(
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    room: &BossRoom,
    instance_id: u32,
    slot: u32,
) {
    let zone_id = room.zone_id;
    let actor_id = actor_id(zone_id, slot, room.bnpc_id);
    if registry.get(actor_id).await.is_some() {
        tracing::warn!(
            zone = zone_id,
            boss = room.name,
            actor_id = format!("0x{actor_id:08X}"),
            "dungeon chest: actor id already taken, no chest",
        );
        return;
    }
    let mut class = match db.load_actor_class(CHEST_CLASS_ID).await {
        Ok(Some(c)) => c,
        other => {
            tracing::warn!(?other, "dungeon chest: chest actor class missing");
            return;
        }
    };
    // The class row has property flags 0, which the client won't let a
    // player target; talkable objects (task boards, item storage) use 19.
    class.property_flags = CHEST_PROPERTY_FLAGS;
    let (x, y, z) = room.centre;
    let mut npc = crate::npc::npc::Npc::new(
        actor_id & 0x7FFFF,
        &class,
        unique_id(room.bnpc_id),
        zone_id,
        x,
        y,
        z,
        0.0,
        0,
        0,
        // The class's name id shows as a blank "[en]" in the client.
        Some(CHEST_NAME.to_string()),
    );
    if let Ok(Some(app)) = db.load_npc_appearance(CHEST_CLASS_ID).await {
        let (model_id, slots) = app.pack();
        npc.character.chara.model_id = model_id;
        npc.character.chara.appearance_ids = slots;
    }
    npc.generate_actor_name(actor_id & 0x7FFFF);
    let Some(zone_arc) = world.zone(zone_id).await else {
        return;
    };
    {
        let mut zone = zone_arc.write().await;
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        let pos = common::Vector3::new(x, y, z);
        zone.core.add_actor(
            crate::zone::area::StoredActor {
                actor_id,
                kind: crate::zone::area::ActorKind::Npc,
                position: pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
        zone.core.set_instance(actor_id, instance_id);
        zone.core.update_actor_position(actor_id, pos, &mut ob);
    }
    registry
        .insert(crate::runtime::actor_registry::ActorHandle::new(
            actor_id,
            crate::runtime::actor_registry::ActorKindTag::Npc,
            zone_id,
            0,
            npc.character.clone(),
        ))
        .await;
    // The copy's teardown despawns what the owner's content recorded.
    for mut snap in world.all_sessions().await {
        if let Some(active) = snap.active_content_script.as_mut()
            && active.parent_zone_id == zone_id
            && active.instance_id == instance_id
            && !active.party_member
        {
            if !active.spawned_actor_ids.contains(&actor_id) {
                active.spawned_actor_ids.push(actor_id);
                world.upsert_session(snap).await;
            }
            break;
        }
    }
    chests().lock().unwrap_or_else(|e| e.into_inner()).insert(
        actor_id,
        Chest {
            zone_id,
            instance_id,
            boss_bnpc_id: room.bnpc_id,
            opened: false,
        },
    );
    tracing::info!(
        zone = zone_id,
        instance = instance_id,
        boss = room.name,
        actor_id = format!("0x{actor_id:08X}"),
        "dungeon chest appeared",
    );
}

/// Who gets what from one chest: `(player, item)` pairs. `on_quest`
/// lists, per quest item, the players who are on its quest and don't
/// hold it; `pick` chooses an index below its argument (random in play).
pub fn share_loot(
    loot: &[ChestItem],
    players: &[u32],
    on_quest: impl Fn(&ChestItem) -> Vec<u32>,
    mut pick: impl FnMut(usize) -> usize,
) -> Vec<(u32, ChestItem)> {
    let mut out = Vec::new();
    for item in loot {
        if item.quest_id.is_some() {
            for p in on_quest(item) {
                out.push((p, *item));
            }
        } else if !players.is_empty() {
            out.push((players[pick(players.len()) % players.len()], *item));
        }
    }
    out
}

/// `player:OpenDungeonChest(npc)`: open the chest, hand out its loot to
/// the copy's players, and take the chest away.
pub async fn open(
    player_id: u32,
    chest_actor_id: u32,
    registry: &ActorRegistry,
    db: &Database,
    world: &WorldManager,
    lua: Option<&Arc<LuaEngine>>,
) {
    let chest = {
        let mut map = chests().lock().unwrap_or_else(|e| e.into_inner());
        match map.get_mut(&chest_actor_id) {
            Some(c) if !c.opened => {
                c.opened = true;
                c.clone()
            }
            _ => return,
        }
    };
    let players =
        crate::runtime::dungeon_fight::players_in_copy(world, chest.zone_id, chest.instance_id)
            .await;
    let opener = match registry.get(player_id).await {
        Some(h) => h.character.read().await.base.display_name().to_string(),
        None => String::new(),
    };
    let loot = loot_for(chest.boss_bnpc_id);
    // Quest items: who is on the quest and doesn't hold the item yet.
    let mut eligible: HashMap<u32, Vec<u32>> = HashMap::new();
    for item in loot {
        let Some(quest) = item.quest_id else {
            continue;
        };
        let mut list = Vec::new();
        for &p in &players {
            let on_quest = match registry.get(p).await {
                Some(h) => h
                    .character
                    .read()
                    .await
                    .quest_journal
                    .slots
                    .iter()
                    .flatten()
                    .any(|q| q.quest_id() == quest),
                None => false,
            };
            let holds = db
                .item_count(p, crate::inventory::PKG_NORMAL, item.item_id)
                .await
                .unwrap_or(0)
                > 0;
            if on_quest && !holds {
                list.push(p);
            }
        }
        eligible.insert(item.item_id, list);
    }
    let shares = share_loot(
        loot,
        &players,
        |i| eligible.get(&i.item_id).cloned().unwrap_or_default(),
        |n| rand::random_range(0..n),
    );
    let mut lines = vec![format!("{opener} opens the treasure chest.")];
    for (p, item) in &shares {
        crate::runtime::quest_apply::apply_add_item(
            *p,
            crate::inventory::PKG_NORMAL,
            item.item_id,
            item.quantity,
            registry,
            Some(world),
            db,
        )
        .await;
        let who = match registry.get(*p).await {
            Some(h) => h.character.read().await.base.display_name().to_string(),
            None => continue,
        };
        let name = lua
            .and_then(|l| {
                l.catalogs()
                    .items
                    .read()
                    .ok()
                    .and_then(|m| m.get(&item.item_id).map(|d| d.name.clone()))
            })
            .unwrap_or_else(|| format!("item {}", item.item_id));
        lines.push(format!("{who} obtains {name}."));
    }
    if shares.is_empty() {
        lines.push("The treasure chest is empty.".to_string());
    }
    for &p in &players {
        for line in &lines {
            crate::runtime::quest_apply::apply_send_message(p, 0x20, "", line, registry, world)
                .await;
        }
    }
    tracing::info!(
        zone = chest.zone_id,
        instance = chest.instance_id,
        boss_bnpc = chest.boss_bnpc_id,
        opener = player_id,
        ?shares,
        "dungeon chest opened",
    );
    crate::runtime::quest_apply::apply_despawn_actor(
        chest.zone_id,
        chest_actor_id,
        registry,
        world,
    )
    .await;
    chests()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&chest_actor_id);
}

#[cfg(test)]
mod tests {
    use super::*;

    const GIL_BAG: ChestItem = ChestItem {
        item_id: 1,
        quantity: 1,
        quest_id: None,
    };

    #[test]
    fn plain_items_go_to_the_picked_player() {
        let got = share_loot(&[GIL_BAG], &[10, 20, 30], |_| vec![], |_| 2);
        assert_eq!(got, vec![(30, GIL_BAG)]);
    }

    #[test]
    fn quest_items_go_to_everyone_on_the_quest() {
        let got = share_loot(&[ENCHIRIDION], &[10, 20, 30], |_| vec![10, 30], |_| 0);
        assert_eq!(got, vec![(10, ENCHIRIDION), (30, ENCHIRIDION)]);
    }

    #[test]
    fn an_empty_copy_gets_nothing() {
        assert!(share_loot(&[GIL_BAG], &[], |_| vec![], |_| 0).is_empty());
    }

    #[test]
    fn batraal_holds_the_enchiridion_and_others_are_empty() {
        assert_eq!(loot_for(2000), &[ENCHIRIDION]);
        assert!(loot_for(2300).is_empty());
    }

    #[test]
    fn chest_ids_differ_per_boss_and_copy() {
        let a = actor_id(231, 0, 2000);
        assert_ne!(a, actor_id(231, 0, 2001));
        assert_ne!(a, actor_id(231, 1, 2000));
    }
}
