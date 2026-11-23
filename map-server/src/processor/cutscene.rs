// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! GM `!cutscene <name>`: play any of the client's cutscenes
//! (`client/cut/<name>`) where you stand, and `!cutscene stop` to close one.
//!
//! No client patch: the 1.23b client's raid director class
//! (`InstanceRaidBaseClass`) has `cutSceneEvent(name, ...)`, which fades
//! out, runs `executeCutScene(name, nil, true)` (`worldMaster:createCutScene`,
//! then `startCutScene`) and fades back in where you are, with no warp. So
//! this spawns a director of that class for the typer alone, kicks its
//! `noticeEvent`, and `directors/CutScenePlayer.lua` calls `cutSceneEvent`
//! with the name from the event's start.

use std::collections::HashMap;
use std::sync::Mutex;

use common::luaparam::LuaParam;

use super::PacketProcessor;
use crate::runtime::actor_registry::ActorHandle;

/// The client class the director is spawned as: any `InstanceRaid`
/// director carries the base class's `cutSceneEvent`.
pub(crate) const CLIENT_CLASS: &str = "/Director/InstanceRaid/InstanceRaidLesserIfrit";
/// The server script (`directors/CutScenePlayer.lua`) that answers its
/// `noticeEvent`.
pub(crate) const SERVER_SCRIPT: &str = "CutScenePlayer";

/// How long the director has on the client before it's kicked.
const KICK_DELAY: std::time::Duration = std::time::Duration::from_millis(1500);

/// The scene each live cutscene director plays, by director actor id.
static PENDING: Mutex<Option<HashMap<u32, String>>> = Mutex::new(None);
/// Each player's last cutscene director (actor id, zone id), so the next
/// `!cutscene` or `!cutscene stop` can take it off the client.
static OWNED: Mutex<Option<HashMap<u32, (u32, u32)>>> = Mutex::new(None);

/// The scene the director `director_actor_id` was made to play.
pub(crate) fn scene_of(director_actor_id: u32) -> Option<String> {
    PENDING
        .lock()
        .ok()?
        .as_ref()?
        .get(&director_actor_id)
        .cloned()
}

/// A cutscene name as the client's `client/cut` folders spell it: lower
/// case letters, digits and `_`, at most 31 bytes (the event name slot).
pub(crate) fn clean_name(raw: &str) -> Option<String> {
    let name = raw.trim().to_ascii_lowercase();
    let ok = !name.is_empty()
        && name.len() <= 31
        && name
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_');
    ok.then_some(name)
}

/// Whether the client install the server knows (`XIVLEGACY_CLIENT_DIR` /
/// `XIV_CLIENT`) has the scene. `None` when the server has no install to
/// look in; the client then has the last word.
fn install_has(name: &str) -> Option<bool> {
    let dir =
        std::env::var_os("XIVLEGACY_CLIENT_DIR").or_else(|| std::env::var_os("XIV_CLIENT"))?;
    let cut = std::path::Path::new(&dir).join("client").join("cut");
    if !cut.is_dir() {
        return None;
    }
    Some(cut.join(name).join(name).is_file())
}

impl PacketProcessor {
    pub(super) async fn cutscene_command(
        &self,
        handle: &ActorHandle,
        line: &str,
        level: u8,
    ) -> Option<Result<String, String>> {
        let mut words = line.split_whitespace();
        let cmd = words.next()?;
        if !cmd.eq_ignore_ascii_case("cutscene") && !cmd.eq_ignore_ascii_case("cs") {
            return None;
        }
        if level < crate::command_permissions::get().required("cutscene") {
            return Some(Err("!cutscene needs a higher GM level".into()));
        }
        let usage = "usage: !cutscene <name> (a folder in the client's client/cut, e.g. man50250) | !cutscene stop";
        let Some(arg) = words.next() else {
            return Some(Err(usage.into()));
        };
        if arg.eq_ignore_ascii_case("stop") {
            return Some(Ok(if self.stop_cutscene(handle).await {
                "cutscene closed".into()
            } else {
                "no cutscene of yours to close".into()
            }));
        }
        let Some(name) = clean_name(arg) else {
            return Some(Err(usage.into()));
        };
        if install_has(&name) == Some(false) {
            return Some(Err(format!("the client has no cutscene {name}")));
        }
        Some(self.play_cutscene(handle, &name).await)
    }

    async fn play_cutscene(&self, handle: &ActorHandle, name: &str) -> Result<String, String> {
        let session = self
            .world
            .session(handle.session_id)
            .await
            .ok_or("no session")?;
        let zone_id = session.current_zone_id;
        let client = self
            .world
            .client(handle.session_id)
            .await
            .ok_or("no client")?;
        // A scene left open (or played before) goes first.
        self.stop_cutscene(handle).await;

        let (director, zone_actor, zone_name) = {
            let zone = self.world.zone(zone_id).await.ok_or("zone not loaded")?;
            let mut zone = zone.write().await;
            let id = zone.core.create_director(SERVER_SCRIPT, false);
            (id, zone.core.actor_id, zone.core.zone_name.clone())
        };
        if let Ok(mut p) = PENDING.lock() {
            p.get_or_insert_with(HashMap::new)
                .insert(director, name.to_string());
        }
        if let Ok(mut o) = OWNED.lock() {
            o.get_or_insert_with(HashMap::new)
                .insert(handle.actor_id, (director, zone_id));
        }

        let class_leaf = CLIENT_CLASS.rsplit('/').next().unwrap_or(CLIENT_CLASS);
        for mut sub in crate::world_manager::build_director_spawn_subpackets(
            director,
            zone_actor,
            CLIENT_CLASS,
            class_leaf,
            &zone_name,
        ) {
            sub.set_target_id(handle.session_id);
            client.send_bytes(sub.to_bytes()).await;
        }
        // The client loads the director's class script before it takes a
        // kick on it; a kick sent with the spawn comes back at once.
        tokio::time::sleep(KICK_DELAY).await;
        // The kick carries the name too; the script takes it from the
        // event start, else from `scene_of`.
        let mut kick = crate::packets::send::events::build_kick_event(
            handle.actor_id,
            director,
            "noticeEvent",
            crate::packets::send::events::script_kick_event_type(director),
            &[LuaParam::String(name.to_string())],
        );
        kick.set_target_id(handle.session_id);
        client.send_bytes(kick.to_bytes()).await;
        tracing::info!(
            player = handle.actor_id,
            director = format!("0x{director:08X}"),
            zone = zone_id,
            scene = name,
            "!cutscene: director spawned and kicked"
        );
        Ok(format!("playing cutscene {name}"))
    }

    /// End the player's open cutscene event and take the director off
    /// their client. False when they had none.
    async fn stop_cutscene(&self, handle: &ActorHandle) -> bool {
        let owned = OWNED
            .lock()
            .ok()
            .and_then(|mut o| o.as_mut()?.remove(&handle.actor_id));
        let Some((director, zone_id)) = owned else {
            return false;
        };
        if let Ok(mut p) = PENDING.lock()
            && let Some(p) = p.as_mut()
        {
            p.remove(&director);
        }
        if let Some(zone) = self.world.zone(zone_id).await {
            zone.write().await.core.delete_director(director);
        }
        // Still in its event (the scene playing, or stuck): end it.
        let mut outbox = crate::event::outbox::EventOutbox::new();
        {
            let mut c = handle.character.write().await;
            if c.event_session.current_event_owner == director {
                c.event_session.end_event(handle.actor_id, &mut outbox);
            }
        }
        for e in outbox.drain() {
            crate::event::dispatcher::dispatch_event_event(
                &e,
                &self.registry,
                &self.world,
                &self.db,
                self.lua.as_ref(),
            )
            .await;
        }
        if let Some(client) = self.world.client(handle.session_id).await {
            let mut sub = crate::packets::send::actor::build_remove_actor(director);
            sub.set_target_id(handle.session_id);
            client.send_bytes(sub.to_bytes()).await;
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_are_folder_names() {
        assert_eq!(clean_name("man50250").as_deref(), Some("man50250"));
        assert_eq!(clean_name("GC010110").as_deref(), Some("gc010110"));
        assert_eq!(clean_name("../etc"), None);
        assert_eq!(clean_name("man 1"), None);
        assert_eq!(clean_name(""), None);
        assert_eq!(clean_name(&"a".repeat(32)), None);
    }

    #[test]
    fn scene_is_kept_by_director() {
        PENDING
            .lock()
            .unwrap()
            .get_or_insert_with(HashMap::new)
            .insert(0x6000_0042, "man50250".into());
        assert_eq!(scene_of(0x6000_0042).as_deref(), Some("man50250"));
        assert_eq!(scene_of(0x6000_0043), None);
    }
}
