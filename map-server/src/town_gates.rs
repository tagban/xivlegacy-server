// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! City gates you can walk through both ways (#356).
//!
//! Ul'dah's Gate of Nald is drawn twice by the 1.23b client:
//!
//! - The town layout (`wil_w0_twn01`, layout 421) has it as `isgrp_002836`
//!   with `opn0` / `open` / `clos` schedules. It stays shut, with
//!   collision, until a `DoorServer` actor binds to it open: the zone-175
//!   spawn row `uldah_gate_of_nald` does that through its unique `init`.
//!   That lets a player walk out of the city.
//! - The Central Thanalan layout (`wil_w0_fld01`) has its own copy of the
//!   gate model at the same spot, in an empty group with no name and no
//!   schedules, so no actor can bind to it. The client loads that layout
//!   as soon as a player nears the gate and draws its copy shut on the
//!   outside face, with collision there only: a player coming back from
//!   the field walks into it and can't get in.
//!
//! So the server opens the way in itself: a player who walks up to the
//! outer face of the gate from the field side is moved through it, a few
//! steps inside the city (`WarpToPosition`, no loading screen). Leaving
//! the city needs nothing: the town gate is open and the field copy only
//! blocks from outside.
//!
//! The gate's `open` schedule is also played again for a player who walks
//! up to it from either side, in case a zone flip at the seam reloaded
//! the town layout after the actor was bound. Once per approach.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// One always-open gate.
pub struct OpenGate {
    /// Zone of the `DoorServer` spawn row that binds the gate.
    pub zone_id: u32,
    pub unique_id: &'static str,
    /// Zones a player can be in while at the gate.
    pub zones: &'static [u32],
    /// Where the gate stands (x, z), and how close a player must come to
    /// have its `open` schedule played again.
    pub x: f32,
    pub z: f32,
    pub radius: f32,
    /// The passage: half its width along x around `x`.
    pub half_width: f32,
    /// Field side: a player with z below `outside_z` is outside the gate.
    pub outside_z: f32,
    /// Where the field copy stops a player (z from `outside_z` to here).
    pub face_z: f32,
    /// Where a player coming in is put: x stays, this y and z.
    pub inside_y: f32,
    pub inside_z: f32,
}

pub const GATES: &[OpenGate] = &[OpenGate {
    zone_id: 175,
    unique_id: "uldah_gate_of_nald",
    zones: &[175, 170],
    x: -52.5,
    z: -2.3,
    radius: 30.0,
    half_width: 5.0,
    outside_z: -5.0,
    // A player walking in stops at z -3.3 to -3.9.
    face_z: -2.8,
    inside_y: 192.0,
    inside_z: 1.5,
}];

/// The gate near (x, z) in `zone_id`, for playing its schedule.
pub fn gate_near(zone_id: u32, x: f32, z: f32) -> Option<usize> {
    GATES
        .iter()
        .position(|g| g.zones.contains(&zone_id) && (x - g.x).hypot(z - g.z) <= g.radius)
}

#[derive(Default, Clone, Copy)]
struct Track {
    /// Gate whose `open` schedule was played on this approach.
    opened: Option<usize>,
    /// Gate the player was last seen outside of, in its passage.
    outside: Option<usize>,
}

fn tracks() -> &'static Mutex<HashMap<u32, Track>> {
    static L: OnceLock<Mutex<HashMap<u32, Track>>> = OnceLock::new();
    L.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Whether the gate's `open` schedule should be played for `player` now:
/// true on the first position near a gate, false until they walk away.
pub fn arrive(player: u32, gate: Option<usize>) -> bool {
    let mut l = tracks().lock().unwrap_or_else(|e| e.into_inner());
    let t = l.entry(player).or_default();
    let first = gate.is_some() && t.opened != gate;
    t.opened = gate;
    first
}

/// Where to move a player standing at (x, z) in `zone_id` so they get
/// through a gate's field-side copy: `Some((y, z))` when they came up to
/// its outer face from the field.
pub fn passage(player: u32, zone_id: u32, x: f32, z: f32) -> Option<(f32, f32)> {
    let mut l = tracks().lock().unwrap_or_else(|e| e.into_inner());
    let t = l.entry(player).or_default();
    let i = GATES.iter().position(|g| {
        g.zones.contains(&zone_id) && (x - g.x).abs() <= g.half_width && z <= g.face_z && z > g.outside_z - 20.0
    });
    let Some(i) = i else {
        t.outside = None;
        return None;
    };
    let g = &GATES[i];
    if z < g.outside_z {
        t.outside = Some(i);
        return None;
    }
    // At the face: only someone who came from the field goes through.
    if t.outside.take() == Some(i) {
        Some((g.inside_y, g.inside_z))
    } else {
        None
    }
}

/// Forget a player's gate state (zone-in, logout).
pub fn reset(player: u32) {
    tracks()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&player);
}

/// Play the `open` schedule of the gate the player just walked up to.
pub async fn on_position(
    world: &WorldManager,
    registry: &ActorRegistry,
    player: u32,
    zone_id: u32,
    x: f32,
    z: f32,
) {
    let near = gate_near(zone_id, x, z);
    if !arrive(player, near) {
        return;
    }
    let Some(i) = near else { return };
    let gate = &GATES[i];
    let mut actor_id = None;
    for h in registry.actors_in_zone(gate.zone_id).await {
        if h.character.read().await.base.unique_id == gate.unique_id {
            actor_id = Some(h.actor_id);
            break;
        }
    }
    let Some(actor_id) = actor_id else { return };
    let Some(client) = world.client(player).await else {
        return;
    };
    let mut pkt = crate::packets::send::actor::build_play_bg_animation(actor_id, "open");
    pkt.set_target_id(player);
    client.send_bytes(pkt.to_bytes()).await;
    tracing::debug!(
        player,
        gate = gate.unique_id,
        actor = format!("0x{actor_id:08X}"),
        "town gate: open schedule played",
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opens_once_per_approach_from_either_side() {
        let p = 0x7E00_0001;
        assert_eq!(gate_near(175, -52.5, 6.0), Some(0));
        assert_eq!(gate_near(170, -50.0, -24.0), Some(0));
        assert_eq!(gate_near(175, -75.0, 81.0), None, "Momodi is far away");
        assert_eq!(gate_near(209, -52.5, 0.0), None);
        assert!(arrive(p, gate_near(175, -52.5, 6.0)));
        assert!(!arrive(p, gate_near(175, -52.5, 2.0)), "already open for them");
        assert!(!arrive(p, gate_near(175, -52.5, 80.0)));
        assert!(arrive(p, gate_near(170, -50.0, -24.0)), "back again");
        reset(p);
        assert!(arrive(p, gate_near(170, -50.0, -24.0)), "after a zone-in");
        reset(p);
    }

    #[test]
    fn coming_in_from_the_field_goes_through_the_gate() {
        let p = 0x7E00_0002;
        // Walking out: inside, at the face, outside. Nobody is moved.
        for z in [4.0, -1.0, -3.5, -6.0, -12.0] {
            assert_eq!(passage(p, 175, -52.5, z), None, "walking out at z {z}");
        }
        // Walking back in from the field (the seam is still 170 here, or
        // already 175): stopped at the outer face, then moved inside.
        assert_eq!(passage(p, 170, -52.0, -9.0), None);
        assert_eq!(passage(p, 175, -51.2, -3.7), Some((192.0, 1.5)));
        // Once: standing at the face again doesn't move them twice.
        assert_eq!(passage(p, 175, -51.2, -3.7), None);
        // Off to the side of the passage, or another zone: nothing.
        assert_eq!(passage(p, 175, -62.0, -9.0), None);
        assert_eq!(passage(p, 175, -62.0, -3.6), None);
        assert_eq!(passage(p, 209, -52.5, -9.0), None);
        assert_eq!(passage(p, 209, -52.5, -3.6), None);
        reset(p);
    }
}
