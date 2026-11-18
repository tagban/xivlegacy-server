// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Doors and barriers of dungeon copies (`/Chara/Npc/MapObj/DoorServer`).
//!
//! A dungeon's doors and barriers are background objects baked into the
//! zone's layout. The server binds an actor to one (`SetActorBGProperties`
//! with the layout and instance ids the door's unique script `init`
//! returns) and moves it by naming one of the object's schedules
//! (`PlayBGAnimation`, 0x00D9). Toto-Rak's layout (`fst_f0_dun03`) names
//! them: doors have `open` / `clos`, barriers `hide` / `show`, and each
//! schedule switches the object's collision too, so a closed door or a
//! raised barrier blocks the client's own movement.
//!
//! The client's `DoorServer:initForEvent(layout, instance, isOpen)` runs
//! the `open` (class 5900015, a door) or `hide` (5900016, a barrier)
//! schedule when `isOpen` is true; otherwise the object keeps its layout
//! default (closed / shown). The bind params carry the copy's current
//! state, so a player zoning in sees the door the way the copy has it.
//!
//! State is per copy: every copy spawns its own door actors
//! (`contentArea:SpawnMapObjects()`), registered here by unique id.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

/// `DoorServer` actor class of a door (runs `open` / `clos`).
pub const DOOR_CLASS: u32 = 5_900_015;
/// `DoorServer` actor class of a barrier (runs `hide` / `show`).
pub const BARRIER_CLASS: u32 = 5_900_016;

/// The schedule that puts a `DoorServer` object in the given state.
pub fn schedule_name(actor_class_id: u32, open: bool) -> &'static str {
    match (actor_class_id == BARRIER_CLASS, open) {
        (true, true) => "hide",
        (true, false) => "show",
        (false, true) => "open",
        (false, false) => "clos",
    }
}

/// Map-object classes a content copy spawns for itself: the doors and
/// barriers the server opens and closes.
pub fn is_copy_gate_class(actor_class_id: u32) -> bool {
    actor_class_id == DOOR_CLASS || actor_class_id == BARRIER_CLASS
}

#[derive(Debug, Clone)]
struct Gate {
    instance_id: u32,
    unique_id: String,
    actor_class_id: u32,
    open: bool,
}

#[derive(Default)]
struct Registry {
    by_actor: HashMap<u32, Gate>,
}

fn registry() -> &'static Mutex<Registry> {
    static R: OnceLock<Mutex<Registry>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(Registry::default()))
}

fn lock() -> std::sync::MutexGuard<'static, Registry> {
    registry().lock().unwrap_or_else(|e| e.into_inner())
}

/// Record a copy's door or barrier actor. Gates start open, like the
/// scripts' `init` has them.
pub fn register(instance_id: u32, actor_id: u32, unique_id: &str, actor_class_id: u32) {
    lock().by_actor.insert(
        actor_id,
        Gate {
            instance_id,
            unique_id: unique_id.to_string(),
            actor_class_id,
            open: true,
        },
    );
}

/// Whether a registered gate is open; `None` for anything else.
pub fn is_open(actor_id: u32) -> Option<bool> {
    lock().by_actor.get(&actor_id).map(|g| g.open)
}

/// A copy's gate actor by unique id, with its class.
pub fn find(instance_id: u32, unique_id: &str) -> Option<(u32, u32)> {
    lock()
        .by_actor
        .iter()
        .find(|(_, g)| g.instance_id == instance_id && g.unique_id == unique_id)
        .map(|(id, g)| (*id, g.actor_class_id))
}

/// Unique ids of a copy's gates, sorted.
pub fn unique_ids(instance_id: u32) -> Vec<String> {
    let mut ids: Vec<String> = lock()
        .by_actor
        .values()
        .filter(|g| g.instance_id == instance_id)
        .map(|g| g.unique_id.clone())
        .collect();
    ids.sort();
    ids
}

/// Set a gate's state. Returns the schedule to play when it changed.
pub fn set_open(actor_id: u32, open: bool) -> Option<&'static str> {
    let mut r = lock();
    let g = r.by_actor.get_mut(&actor_id)?;
    if g.open == open {
        return None;
    }
    g.open = open;
    Some(schedule_name(g.actor_class_id, open))
}

/// Forget a finished copy's gates.
pub fn release_instance(instance_id: u32) {
    lock().by_actor.retain(|_, g| g.instance_id != instance_id);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn doors_and_barriers_use_their_own_schedules() {
        assert_eq!(schedule_name(DOOR_CLASS, true), "open");
        assert_eq!(schedule_name(DOOR_CLASS, false), "clos");
        assert_eq!(schedule_name(BARRIER_CLASS, true), "hide");
        assert_eq!(schedule_name(BARRIER_CLASS, false), "show");
    }

    #[test]
    fn gate_state_is_per_copy_and_reports_changes_once() {
        register(9_101, 0x4F00_0001, "door_a", DOOR_CLASS);
        register(9_102, 0x4F00_0002, "door_a", DOOR_CLASS);
        assert_eq!(find(9_102, "door_a"), Some((0x4F00_0002, DOOR_CLASS)));
        assert_eq!(set_open(0x4F00_0001, false), Some("clos"));
        assert_eq!(set_open(0x4F00_0001, false), None);
        assert_eq!(is_open(0x4F00_0001), Some(false));
        assert_eq!(is_open(0x4F00_0002), Some(true));
        release_instance(9_101);
        release_instance(9_102);
        assert_eq!(is_open(0x4F00_0001), None);
    }
}
