// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Spawning a battle NPC from its `server_battlenpc_*` rows, shared by
//! content scripts, GM `!spawn` and battle leves.

use std::sync::Arc;

use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The battle-NPC spawn behind `PacketProcessor::apply_spawn_battle_npc_by_id`.
/// `gm` is set for spawns that never respawn and stream in normally (GM
/// `!spawn`, leve targets); `Some(path)` swaps the class path for this spawn.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn spawn_battle_npc(
    bnpc_id: u32,
    parent_zone_id: u32,
    expected_actor_id: u32,
    gm: Option<Option<String>>,
    db: &Database,
    world: &WorldManager,
    registry: &ActorRegistry,
    lua: Option<&Arc<LuaEngine>>,
) -> bool {
    spawn_battle_npc_as(
        bnpc_id,
        parent_zone_id,
        expected_actor_id,
        gm,
        None,
        None,
        0,
        db,
        world,
        registry,
        lua,
    )
    .await
}

/// [`spawn_battle_npc`] wearing another class's look (`appearance_class_id`,
/// from `gamedata_actor_appearance`) and/or a custom name: an escort's Path
/// companion is the player's own companion, not a fixed pool class.
/// `instance_id` is the content copy the spawn belongs to (0 = none): it
/// tags the actor in the zone core and picks the owning session.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn spawn_battle_npc_as(
    bnpc_id: u32,
    parent_zone_id: u32,
    expected_actor_id: u32,
    gm: Option<Option<String>>,
    appearance_class_id: Option<u32>,
    display_name: Option<String>,
    instance_id: u32,
    db: &Database,
    world: &WorldManager,
    registry: &ActorRegistry,
    lua: Option<&Arc<LuaEngine>>,
) -> bool {
    // 1. Load the joined spawn DTO from the database.
    let spawn = match db.load_battle_npc_spawn(bnpc_id).await {
        Ok(Some(row)) => row,
        Ok(None) => {
            tracing::warn!(
                bnpc_id,
                parent_zone = parent_zone_id,
                "SpawnBattleNpcById: bnpc_id not in server_battlenpc_spawn_locations",
            );
            return false;
        }
        Err(e) => {
            tracing::warn!(
                bnpc_id,
                error = %e,
                "SpawnBattleNpcById: db query failed",
            );
            return false;
        }
    };

    // 2. Resolve the ActorClass row keyed by spawn.actor_class_id.
    //    The class carries class_path / display_name_id / event
    //    conditions — required for AddActor + ActorInstantiate.
    let mut actor_class = match db.load_actor_class(spawn.actor_class_id).await {
        Ok(Some(c)) => c,
        Ok(None) => {
            tracing::warn!(
                bnpc_id,
                actor_class_id = spawn.actor_class_id,
                "SpawnBattleNpcById: actor_class not in gamedata_actor_class",
            );
            return false;
        }
        Err(e) => {
            tracing::warn!(
                bnpc_id,
                error = %e,
                "SpawnBattleNpcById: actor_class load failed",
            );
            return false;
        }
    };

    if let Some(Some(path)) = &gm {
        actor_class.class_path = path.clone();
    }

    // 3. Compute actor_number from expected_actor_id (must round-trip
    //    through the same `(4 << 28) | (zone << 19) | actor_number`
    //    formula the Lua binding used).
    let actor_number = expected_actor_id & 0x7FFFF;

    // 4. Build the BattleNpc. Pre-fill HP from the group row so the
    //    `0x0134 SetActorState` packet has the right value (combat
    //    AI math is a follow-up pass).
    let mut bnpc = crate::npc::battle_npc::BattleNpc::new(
        actor_number,
        &actor_class,
        spawn.script_name.clone(),
        parent_zone_id,
        spawn.position_x,
        spawn.position_y,
        spawn.position_z,
        spawn.rotation,
        spawn.actor_state,
        spawn.animation_id,
        display_name,
    );
    // Give every script-spawned BattleNpc real HP. The seed `hp` column is
    // 0 for many groups (incl. the SEQ_005 tutorial wolves/Yda/Papalymo),
    // and garlemald's spawn path — unlike pmeteor's CalculateBaseStats() —
    // never derives HP from genus/level, so those actors would spawn at
    // hp=0 → `is_dead()` → rendered downed and unable to fight. When the
    // seed gives no HP, fall back to a level-scaled default so the actor is
    // alive. (Garlemald-Server #28; pmeteor parity TODO: full stat derive.)
    let resolved_hp: u32 = if spawn.hp > 0 {
        spawn.hp
    } else {
        // `saturating_mul` guards against a malformed seed row with an
        // absurd `min_level` overflowing u32 (panic in debug / wrap in
        // release); the result is clamped to i16 below regardless.
        spawn.min_level.max(1).saturating_mul(100).max(100)
    };
    bnpc.npc.character.chara.hp = resolved_hp.min(i16::MAX as u32) as i16;
    bnpc.npc.character.chara.max_hp = resolved_hp.min(i16::MAX as u32) as i16;
    if spawn.mp > 0 {
        bnpc.npc.character.chara.mp = spawn.mp.min(i16::MAX as u32) as i16;
        bnpc.npc.character.chara.max_mp = spawn.mp.min(i16::MAX as u32) as i16;
    }
    bnpc.npc.character.chara.level = spawn.min_level.clamp(1, i16::MAX as u32) as i16;

    // Stamp the visual model + equipment from `gamedata_actor_appearance`,
    // exactly as the populace `apply_spawn_actor` path does. Without this
    // the BattleNpc keeps the constructor defaults (model_id = 0, all 28
    // appearance slots = 0), so the zone-in 0x00D6 SetActorAppearance ships
    // an empty model: creature mobs (wolves) have no mesh to draw and are
    // invisible, and humanoid allies (Yda/Papalymo) fall back to an empty
    // skeleton that renders as a knocked-out/downed pose. (Garlemald #28.)
    let look_class_id = appearance_class_id.unwrap_or(spawn.actor_class_id);
    if let Ok(Some(app)) = db.load_npc_appearance(look_class_id).await {
        let (model_id, slots) = app.pack();
        bnpc.npc.character.chara.model_id = model_id;
        bnpc.npc.character.chara.appearance_ids = slots;
    }

    let actor_id = bnpc.actor_id();
    if actor_id != expected_actor_id {
        tracing::warn!(
            bnpc_id,
            expected = format!("0x{:08X}", expected_actor_id),
            actual = format!("0x{:08X}", actor_id),
            "SpawnBattleNpcById: actor_id mismatch — Lua side computed differently",
        );
        // Bail rather than spawn at the wrong id; the script's
        // subsequent calls would target a phantom actor.
        return false;
    }

    // 4b. Phase C1 — apply combat metadata from the joined DTO
    //     (detection / neutral / kindred / pool / genus / drop-list /
    //     respawn) and attach the AI Controller so the ticker drives
    //     aggro and engagement. See `BattleNpc::apply_spawn_metadata`
    //     for the full per-field mapping + the Meteor parity notes.
    //
    //     #28 S2.4 — pool-job casters (currentJob 22 THM / 23 CNJ)
    //     get their loop spell pre-resolved out of the boot-time
    //     battle-command catalog. The seed pools carry no spellListId,
    //     so the tutorial caster (Papalymo) uses THM lvl-1 `thunder`
    //     27313 (range 20, cast 2000 ms, recast 6 s) — report C §5.
    const CASTER_DEFAULT_SPELL_ID: u16 = 27313;
    let caster_spell = if matches!(spawn.current_job, 22 | 23) {
        lua.as_ref()
            .and_then(|l| {
                l.catalogs()
                    .battle_commands
                    .read()
                    .ok()
                    .and_then(|m| m.get(&CASTER_DEFAULT_SPELL_ID).cloned())
            })
            .map(|gd| gd.to_battle_command())
    } else {
        None
    };
    if matches!(spawn.current_job, 22 | 23) && caster_spell.is_none() {
        tracing::warn!(
            bnpc_id,
            spell_id = CASTER_DEFAULT_SPELL_ID,
            "SpawnBattleNpcById: caster pool job but spell not in catalog — \
             caster will stand back without casting",
        );
    }
    bnpc.apply_spawn_metadata(&spawn, bnpc_id, actor_id, caster_spell);

    // 5. Insert the spatial projection into the parent zone's grid.
    let Some(zone_arc) = world.zone(parent_zone_id).await else {
        tracing::warn!(
            bnpc_id,
            parent_zone = parent_zone_id,
            "SpawnBattleNpcById: parent zone not loaded",
        );
        return false;
    };
    {
        let mut zone = zone_arc.write().await;
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        let spawn_pos = common::Vector3::new(spawn.position_x, spawn.position_y, spawn.position_z);
        zone.core.add_actor(
            crate::zone::area::StoredActor {
                actor_id,
                kind: crate::zone::area::ActorKind::BattleNpc,
                position: spawn_pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
        zone.core.set_instance(actor_id, instance_id);
        // Project into the correct spatial-grid cell. `add_actor` stores
        // grid (0,0); `actors_around` / `broadcast_around_actor` read the
        // grid cell, not the raw position — so without this the NPC sits in
        // cell (0,0) and the post-warp content reveal's spawn_bundle_fanout
        // finds no nearby player and the NPC never renders (until its first
        // MoveActorToPosition happens to fix the cell). (Garlemald-Server #46.)
        zone.core
            .update_actor_position(actor_id, spawn_pos, &mut ob);
    }

    // 6. Register the live Character in the ActorRegistry.
    let mut character = bnpc.npc.character.clone();
    // #28 S0.5 — content-spawned NPCs are one-shots: opt them out of
    // the ticker's default 30 s BNpc respawn. A tutorial wolf
    // respawning at full HP mid-fight would keep the all-wolves-dead
    // gate from ever firing (seed `respawnTime` is 0 for all five
    // anyway). Detection: the spawn fires from a content script's
    // onCreate, which runs after `active_content_script` is set on
    // the owning session for this parent zone.
    let content_spawn = gm.is_some() || {
        let mut found = false;
        for mut snap in world.all_sessions().await {
            // A copy's spawn belongs to that copy's owner; an untagged one
            // (quest content before instancing) to the zone's first.
            if let Some(active) = snap.active_content_script.as_mut()
                && active.parent_zone_id == parent_zone_id
                && (instance_id == 0 || active.instance_id == instance_id)
                && !active.party_member
            {
                // #28 S1.3 — record the spawn on the owning content so
                // the ContentFinished teardown despawns actors the
                // script never AddMember'd into the director roster.
                if !active.spawned_actor_ids.contains(&actor_id) {
                    active.spawned_actor_ids.push(actor_id);
                    world.upsert_session(snap).await;
                }
                found = true;
                break;
            }
        }
        found
    };
    character.chara.respawn_disabled = content_spawn;
    character.chara.bnpc_id = bnpc_id;
    // Phase C1/C2b — tag ally-allegiance BNpcs as `Ally` in the
    // registry. C# Meteor instantiates `Ally` as a separate
    // subclass of `BattleNpc` (`Map Server/Actors/Chara/Npc/Ally.cs`);
    // garlemald folds it into the same struct + Controller kind,
    // but downstream classifiers (the content-area `GetAllies`
    // partition, future ally-only logic) need the tag to read
    // intent without locking the Character to peek at the
    // controller.
    let kind_tag = if spawn.allegiance == 1 {
        crate::runtime::actor_registry::ActorKindTag::Ally
    } else {
        crate::runtime::actor_registry::ActorKindTag::BattleNpc
    };
    registry
        .insert(crate::runtime::actor_registry::ActorHandle::new(
            actor_id,
            kind_tag,
            parent_zone_id,
            /* session */ 0,
            character,
        ))
        .await;

    // 7. SKIP the immediate spawn_bundle_fanout for content-area
    //    spawns. The 5 NPCs (yda/papalymo/3 mobs) spawn during
    //    SimpleContent30010.lua's onCreate, which fires BEFORE
    //    the player warps. Broadcasting AddActor + 9 follow-up
    //    state packets per NPC into the player's CURRENT zone
    //    view (50 packets total) leaks the content-area NPCs
    //    into the public Gridania area where the player still
    //    is.
    //
    //    Pmeteor's reference capture
    //    (`captures/pmeteor-quest/20260426-160210-gridania-manual3/`,
    //    line 31753..31928 = the SEQ_005 warp window) shows
    //    ZERO actor-spawn packets pre-kick: pmeteor's
    //    `contentArea:SpawnActor` only adds the actor to the
    //    content-area's data structure, deferring wire emission
    //    until the player warps in. Garlemald previously fanned
    //    out 6 spawn bursts pre-kick (5 NPCs + a director) on
    //    top of the kick — the pre-kick burst diff vs pmeteor
    //    is the ONE remaining structural delta after fixing the
    //    duplicate-kick + content-trio + KickEvent-field bugs.
    //
    //    Hypothesis under test: those leaked spawns are why the
    //    post-warp kick (`OUT 0x012F` at the right bytes)
    //    silently no-ops in the client and never echoes
    //    `IN 0x012D EventStart`. Skip the broadcast — keep the
    //    actor in the registry (so AI / engagement / combat
    //    work) but stop polluting the client's content-area
    //    state machine.
    //
    //    Trade-off: until a deferred-emit-on-zone-in path is
    //    wired, the client won't render the NPCs visually
    //    post-warp. Acceptable for the kick-test; the cinematic
    //    body fires from `delegateEvent processTtrBtl001` which
    //    is purely client-side rendering.
    // GM spawns reach nearby players through the normal in-range
    // streaming (send_instance_update); a second AddActor here would
    // duplicate the actor and crash the client.
    if gm.is_some() {
        return true;
    }
    let _ = zone_arc; // keep handle so registry insert works
    let _ = spawn.script_name.clone(); // suppress unused warning
    // crate::runtime::dispatcher::spawn_bundle_fanout(
    //     &self.world,
    //     &self.registry,
    //     &zone_arc,
    //     parent_zone_id,
    //     actor_id,
    // )
    // .await;

    tracing::info!(
        bnpc_id,
        parent_zone = parent_zone_id,
        actor_id = format!("0x{:08X}", actor_id),
        actor_class_id = spawn.actor_class_id,
        allegiance = spawn.allegiance,
        "SpawnBattleNpcById applied — wire fan-out SKIPPED to keep \
         content-area NPCs out of the player's pre-warp view",
    );
    true
}
