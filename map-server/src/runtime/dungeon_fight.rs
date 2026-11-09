// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Opening and closing a dungeon copy's doors and barriers
//! (`crate::dungeon_gates`) for the players inside it.

use crate::world_manager::WorldManager;

/// Player actor ids standing in one copy of `zone_id`.
pub async fn players_in_copy(world: &WorldManager, zone_id: u32, instance_id: u32) -> Vec<u32> {
    let Some(zone) = world.zone(zone_id).await else {
        return Vec::new();
    };
    let sessions = world.all_sessions().await;
    let z = zone.read().await;
    sessions
        .iter()
        .filter(|s| s.current_zone_id == zone_id && z.core.instance_of(s.id) == instance_id)
        .map(|s| s.id)
        .collect()
}

/// Open or close one gate of a copy by its unique id and show it to the
/// copy's players. Returns false when the copy has no such gate.
pub async fn set_gate(
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
    unique_id: &str,
    open: bool,
) -> bool {
    let Some((actor_id, _class)) = crate::dungeon_gates::find(instance_id, unique_id) else {
        return false;
    };
    if let Some(schedule) = crate::dungeon_gates::set_open(actor_id, open) {
        send_schedule(world, zone_id, instance_id, actor_id, schedule).await;
        tracing::info!(
            zone = zone_id,
            instance = instance_id,
            gate = unique_id,
            schedule,
            "dungeon gate {}",
            if open { "opened" } else { "closed" },
        );
    }
    true
}

async fn send_schedule(
    world: &WorldManager,
    zone_id: u32,
    instance_id: u32,
    actor_id: u32,
    schedule: &str,
) {
    for player in players_in_copy(world, zone_id, instance_id).await {
        let Some(client) = world.client(player).await else {
            continue;
        };
        let mut pkt = crate::packets::send::actor::build_play_bg_animation(actor_id, schedule);
        pkt.set_target_id(player);
        client.send_bytes(pkt.to_bytes()).await;
    }
}

/// Unique ids of every gate of a copy.
pub fn gates_of(instance_id: u32) -> Vec<String> {
    crate::dungeon_gates::unique_ids(instance_id)
}
