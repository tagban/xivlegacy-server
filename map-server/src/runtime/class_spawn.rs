// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! A monster built straight from its actor class, with no
//! `server_battlenpc_*` rows: the class and its look are in the game data,
//! the combat numbers come from the caller. The world-event spawners use
//! it (`!worldend`'s Final Days monsters, the Atomos camps of
//! `crate::atomos`). It mirrors the processor's
//! `apply_spawn_battle_npc_by_id`.

use crate::database::{BattleNpcSpawn, Database};
use crate::runtime::actor_registry::{ActorHandle, ActorKindTag, ActorRegistry};
use crate::world_manager::WorldManager;

/// What to build.
#[derive(Debug, Clone)]
pub(crate) struct ClassMonster<'a> {
    /// gamedata_actor_class id (its displayNameId gives the name).
    pub class_id: u32,
    /// Script name / log tag.
    pub tag: &'a str,
    pub level: u32,
    pub hp: u32,
    /// Hunts players on sight. False: never starts a fight.
    pub hostile: bool,
    /// Picks fights whatever the level gap. Off, the monster AI's level
    /// check applies (which, knowing no target's level, takes every
    /// target for level 1).
    pub any_level: bool,
    /// Weapons and spells leave it at 1 HP.
    pub cannot_fall: bool,
    /// `server_drop_lists` list its kill rolls (0: the one with its class id).
    pub drop_list_id: u32,
}

/// Builds `m` at actor id `id` in `zone` and adds it to the zone, where the
/// in-range streaming shows it to the players around. False when its class
/// is missing or has no class path (the 1.23b client crashes instantiating
/// an actor with an empty class name).
pub(crate) async fn spawn(
    db: &Database,
    world: &WorldManager,
    registry: &ActorRegistry,
    m: &ClassMonster<'_>,
    zone: u32,
    id: u32,
    at: (f32, f32, f32, f32),
) -> bool {
    let (x, y, z, rotation) = at;
    let class = match db.load_actor_class(m.class_id).await {
        Ok(Some(c)) => c,
        _ => {
            tracing::warn!(
                class = m.class_id,
                tag = m.tag,
                "class spawn: actor class missing"
            );
            return false;
        }
    };
    if class.class_path.is_empty() {
        tracing::warn!(
            class = m.class_id,
            tag = m.tag,
            "class spawn skipped — empty classPath (client-fatal instantiate)",
        );
        return false;
    }
    let spawn = BattleNpcSpawn {
        position_x: x,
        position_y: y,
        position_z: z,
        rotation,
        script_name: m.tag.to_string(),
        min_level: m.level,
        max_level: m.level,
        hp: m.hp,
        zone_id: zone,
        actor_class_id: m.class_id,
        combat_delay: 3000,
        aggro_type: u8::from(m.hostile),
        // sight, sound (and any level)
        detection: 0x01 | 0x04 | if m.any_level { 0x10 } else { 0 },
        drop_list_id: m.drop_list_id,
        ..Default::default()
    };
    let mut bnpc = crate::npc::battle_npc::BattleNpc::new(
        id & 0x7FFFF,
        &class,
        m.tag,
        zone,
        x,
        y,
        z,
        rotation,
        0,
        0,
        None,
    );
    if bnpc.actor_id() != id {
        tracing::warn!(id, tag = m.tag, "class spawn: actor id mismatch");
        return false;
    }
    {
        let chara = &mut bnpc.npc.character.chara;
        let hp = m.hp.min(i16::MAX as u32) as i16;
        chara.hp = hp;
        chara.max_hp = hp;
        chara.level = m.level as i16;
        if let Ok(Some(app)) = db.load_npc_appearance(m.class_id).await {
            let (model_id, slots) = app.pack();
            chara.model_id = model_id;
            chara.appearance_ids = slots;
        }
    }
    bnpc.apply_spawn_metadata(&spawn, 0, id, None);
    let mut character = bnpc.npc.character.clone();
    character.chara.respawn_disabled = true;
    // The kill path reads the drop list off the character (as
    // bnpc_spawn sets it); 0 means no drops.
    character.chara.drop_list_id = m.drop_list_id;
    if m.cannot_fall {
        character
            .chara
            .mods
            .set(crate::actor::Modifier::MinimumHpLock, 1.0);
    }

    let Some(zone_arc) = world.zone(zone).await else {
        return false;
    };
    {
        let mut zw = zone_arc.write().await;
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        let pos = common::Vector3::new(x, y, z);
        zw.core.add_actor(
            crate::zone::area::StoredActor {
                actor_id: id,
                kind: crate::zone::area::ActorKind::BattleNpc,
                position: pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
        zw.core.update_actor_position(id, pos, &mut ob);
    }
    registry
        .insert(ActorHandle::new(
            id,
            ActorKindTag::BattleNpc,
            zone,
            0,
            character,
        ))
        .await;
    // Players nearby get it from the regular in-range streaming; sending
    // the spawn bundle here as well adds the actor twice, which crashes
    // the client.
    true
}
