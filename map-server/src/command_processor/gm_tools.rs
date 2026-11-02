// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! GM tools brought over from the FFXI server's command set (LandSandBoat,
//! as moghouse.cc runs it) where 1.23b has the same idea: moving players,
//! the gaol, the GM tag, items and gil, quests, music and weather. Character
//! names in 1.23b are always two words, which is how a name is told apart
//! from the arguments after it.

use super::{Args, CommandProcessor};
use crate::inventory::{PKG_KEYITEMS, PKG_NORMAL};
use crate::lua::LuaCommandKind as LC;

/// Where each character stood before their last command teleport (`return`):
/// character id → (zone, x, y, z).
type Spots = std::sync::Mutex<std::collections::HashMap<u32, (u32, f32, f32, f32)>>;

fn last_spots() -> &'static Spots {
    static SPOTS: std::sync::OnceLock<Spots> = std::sync::OnceLock::new();
    SPOTS.get_or_init(Default::default)
}

pub(super) fn remember_spot(chara_id: u32, zone: u32, x: f32, y: f32, z: f32) {
    if let Ok(mut m) = last_spots().lock() {
        m.insert(chara_id, (zone, x, y, z));
    }
}

/// The home city of a starting town (characters.initialTown) and its zone.
fn home_city(town: u32) -> u32 {
    match town {
        2 => 155,
        3 => 175,
        _ => 133,
    }
}

impl CommandProcessor {
    /// (zone, x, y, z, rotation) of an online character.
    pub(super) async fn spot_of(&self, chara_id: u32) -> Option<(u32, f32, f32, f32, f32)> {
        let handle = self.registry.get(chara_id).await?;
        let c = handle.character.read().await;
        Some((
            c.base.zone_id,
            c.base.position_x,
            c.base.position_y,
            c.base.position_z,
            c.base.rotation,
        ))
    }

    /// The invoker's character id (chat commands only).
    pub(super) async fn invoker_id(&self, args: &Args<'_>) -> Result<u32, String> {
        let me = args
            .invoker
            .ok_or("this command needs a character: use it in game")?;
        self.lookup_character_id(me)
            .await
            .ok_or_else(|| format!("unknown character: {me}"))
    }

    async fn run_lua(&self, cmds: Vec<LC>) {
        crate::runtime::quest_apply::apply_runtime_lua_commands(
            cmds,
            &self.registry,
            &self.db,
            &self.world,
            Some(&self.lua),
        )
        .await;
    }

    async fn online_id(&self, name: &str) -> Result<u32, String> {
        let id = self
            .lookup_character_id(name)
            .await
            .ok_or_else(|| format!("unknown character: {name}"))?;
        if self.registry.get(id).await.is_none() {
            return Err(format!("{name} is not online"));
        }
        Ok(id)
    }

    /// A system message in one player's chat log.
    pub(super) async fn tell_player(&self, actor_id: u32, message: String) {
        use crate::social::{ChatKind, SocialEvent, SocialOutbox, dispatch_social_event};
        let mut ob = SocialOutbox::new();
        ob.push(SocialEvent::ChatSystemToPlayer {
            target_actor_id: actor_id,
            kind: ChatKind::System,
            message,
        });
        for e in ob.drain() {
            dispatch_social_event(&e, &self.registry, &self.world, &self.db).await;
        }
    }

    // --- moving players ------------------------------------------------------------------------

    /// The invoker's current target, or an error line.
    async fn my_target(&self, me: u32) -> Result<u32, String> {
        let handle = self
            .registry
            .get(me)
            .await
            .ok_or("you are not in the world")?;
        let target = handle.character.read().await.chara.current_target;
        if target == 0 || target == crate::actor::INVALID_ACTORID || target == me {
            return Err("nothing targeted".into());
        }
        Ok(target)
    }

    /// An NPC or monster in `me`'s zone by name (case-insensitive: the start
    /// of its display name, or part of its spawn name or class path, such as
    /// "dodo"), actor class id or actor id: the nearest match.
    async fn find_npc(&self, me: u32, what: &str) -> Option<u32> {
        let (zone, mx, mz) = {
            let h = self.registry.get(me).await?;
            let c = h.character.read().await;
            (c.base.zone_id, c.base.position_x, c.base.position_z)
        };
        let number = what
            .strip_prefix("0x")
            .and_then(|h| u32::from_str_radix(h, 16).ok())
            .or_else(|| what.parse::<u32>().ok());
        let want = what.to_lowercase();
        let mut best: Option<(f32, u32)> = None;
        for h in self.registry.actors_in_zone(zone).await {
            if h.session_id != 0 || h.actor_id == me {
                continue;
            }
            let c = h.character.read().await;
            let hit = match number {
                Some(n) => n == h.actor_id || n == c.chara.actor_class_id,
                // monster names are client text, so the class path
                // (".../Monster/Dodo/...") and spawn name stand in for them
                None => {
                    c.base.display_name().to_lowercase().starts_with(&want)
                        || c.base.unique_id.to_lowercase().contains(&want)
                        || c.base.class_path.to_lowercase().contains(&want)
                }
            };
            if !hit {
                continue;
            }
            let d = (c.base.position_x - mx).powi(2) + (c.base.position_z - mz).powi(2);
            if best.is_none_or(|(bd, _)| d < bd) {
                best = Some((d, h.actor_id));
            }
        }
        best.map(|(_, id)| id)
    }

    /// "name (actor 0x…)" for replies; a monster's class (its name is
    /// client text).
    async fn actor_label(&self, actor_id: u32) -> String {
        let Some(h) = self.registry.get(actor_id).await else {
            return format!("actor 0x{actor_id:08X}");
        };
        let c = h.character.read().await;
        let name = match c.base.display_name() {
            "" => c.base.class_name.as_str(),
            n => n,
        };
        format!("{name} (actor 0x{actor_id:08X})")
    }

    /// `goto [name]`: to your target, a player, or an NPC or monster in your
    /// zone (by name, class id or actor id).
    pub(super) async fn handle_goto(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let what = args.tokens.join(" ");
        let tid = if what.is_empty() {
            match self.my_target(me).await {
                Ok(t) => t,
                Err(e) => return format!("{e} (usage: goto [name | npc name | class id])"),
            }
        } else if let Ok(id) = self.online_id(&what).await {
            id
        } else if let Some(id) = self.find_npc(me, &what).await {
            id
        } else {
            return format!("no player online or NPC in your zone called {what}");
        };
        let Some((zone, x, y, z, _)) = self.spot_of(tid).await else {
            return "that actor is gone".into();
        };
        let my_name = args.invoker.unwrap_or_default().to_string();
        self.teleport(&my_name, Some(zone), None, 0, x, y, z).await;
        format!("went to {} (zone {zone})", self.actor_label(tid).await)
    }

    /// `bring [name]`: someone to where you are; with no name, your target;
    /// or an NPC or monster in your zone by name, class id or actor id (it
    /// runs over and stays until a restart; `setpos` saves the spot).
    pub(super) async fn handle_bring(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some((zone, x, y, z, rot)) = self.spot_of(me).await else {
            return "you are not in the world".into();
        };
        let what = args.tokens.join(" ");
        let npc = if what.is_empty() {
            match self.my_target(me).await {
                Ok(t) => Some(t),
                Err(e) => return format!("{e} (usage: bring [name | npc name | class id])"),
            }
        } else if self.online_id(&what).await.is_err() {
            match self.find_npc(me, &what).await {
                Some(t) => Some(t),
                None => return format!("no player online or NPC in your zone called {what}"),
            }
        } else {
            None
        };
        if let Some(tid) = npc {
            let Some(h) = self.registry.get(tid).await else {
                return "that actor is gone".into();
            };
            if h.session_id != 0 {
                let name = h.character.read().await.base.display_name().to_string();
                return self.teleport(&name, Some(zone), None, 0, x, y, z).await;
            }
            if h.zone_id != zone {
                return "your target is in another zone".into();
            }
            // a monster's AI and respawn go back to its spawn point, so move
            // that too (until a restart; `setpos` saves it)
            {
                let mut c = h.character.write().await;
                if c.chara.bnpc_id != 0 {
                    c.chara.spawn_x = x;
                    c.chara.spawn_y = y;
                    c.chara.spawn_z = z;
                }
            }
            crate::runtime::quest_apply::apply_move_actor_to_position(
                tid,
                x,
                y,
                z,
                rot,
                2,
                &self.registry,
                &self.world,
            )
            .await;
            return format!(
                "brought {} to {x:.2} {y:.2} {z:.2} (!setpos saves it)",
                self.actor_label(tid).await
            );
        }
        let r = self.teleport(&what, Some(zone), None, 0, x, y, z).await;
        if r.starts_with("warped") {
            format!("brought {what} to you")
        } else {
            r
        }
    }

    /// `bringall`: every player online to where you are.
    pub(super) async fn handle_bringall(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some((zone, x, y, z, _)) = self.spot_of(me).await else {
            return "you are not in the world".into();
        };
        let mut n = 0;
        for s in self.world.all_sessions().await {
            if s.id == me {
                continue;
            }
            if let Ok(Some(name)) = self.db.character_name(s.id).await
                && self
                    .teleport(&name, Some(zone), None, 0, x, y, z)
                    .await
                    .starts_with("warped")
            {
                n += 1;
            }
        }
        format!("brought {n} player(s) to you")
    }

    /// `send <name> to <name>`: one player to another.
    pub(super) async fn handle_send(&self, args: &Args<'_>) -> String {
        const USAGE: &str = "usage: send <name> to <name>";
        let Some(at) = args
            .tokens
            .iter()
            .position(|t| t.eq_ignore_ascii_case("to"))
        else {
            return USAGE.into();
        };
        let (who, to) = (args.tokens[..at].join(" "), args.tokens[at + 1..].join(" "));
        if who.is_empty() || to.is_empty() {
            return USAGE.into();
        }
        let Ok(tid) = self.online_id(&to).await else {
            return format!("{to} is not online");
        };
        let Some((zone, x, y, z, _)) = self.spot_of(tid).await else {
            return format!("{to} is not online");
        };
        let r = self.teleport(&who, Some(zone), None, 0, x, y, z).await;
        if r.starts_with("warped") {
            format!("sent {who} to {to}")
        } else {
            r
        }
    }

    /// `return [name]`: back to where they were before their last command
    /// teleport.
    pub(super) async fn handle_return(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: return <name>".into()
            };
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let spot = last_spots().lock().ok().and_then(|m| m.get(&id).copied());
        let Some((zone, x, y, z)) = spot else {
            return format!("{name} hasn't been moved by a command since the server started");
        };
        let r = self.teleport(&name, Some(zone), None, 0, x, y, z).await;
        if r.starts_with("warped") {
            format!("returned {name} to zone {zone}")
        } else {
            r
        }
    }

    /// `up [yalms] [name]` / `down [yalms] [name]`: straight up or down
    /// (default 5 yalms), to get over or under something.
    pub(super) async fn handle_updown(&self, args: &Args<'_>, sign: f32) -> String {
        let (dist, from) = match args.tokens.first().and_then(|t| t.parse::<f32>().ok()) {
            Some(d) => (d, 1),
            None => (5.0, 0),
        };
        let Some(name) = args.rest_joined(from) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: up|down [yalms] <name>".into()
            };
        };
        let Ok(id) = self.online_id(&name).await else {
            return format!("{name} is not online");
        };
        let Some((zone, x, y, z, _)) = self.spot_of(id).await else {
            return format!("{name} is not online");
        };
        self.teleport(&name, Some(zone), None, 0, x, y + sign * dist, z)
            .await
    }

    /// `posfix <name>`: to their home city's spawn point; works offline too
    /// (for a character who can't log in where they are).
    pub(super) async fn handle_posfix(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: posfix <name>".into()
            };
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let zone = home_city(self.db.initial_town_of_character(id).await.unwrap_or(0));
        let Ok(Some((x, y, z))) = self.db.zone_landing(zone).await else {
            return format!("no spawn point known in zone {zone}");
        };
        if self.registry.get(id).await.is_some() {
            return self.teleport(&name, Some(zone), None, 0, x, y, z).await;
        }
        match self.db.set_character_position(id, zone, x, y, z).await {
            Ok(true) => format!("{name} will log in at their home city (zone {zone})"),
            Ok(false) => format!("unknown character: {name}"),
            Err(e) => format!("posfix failed: {e}"),
        }
    }

    // --- the gaol and the GM tag ----------------------------------------------------------------

    /// `jail <name> [cell] [reason]`: hold someone in a Mordion Gaol cell.
    pub(super) async fn handle_jail(&self, args: &Args<'_>) -> String {
        const USAGE: &str = "usage: jail <First Last> [cell number] [reason]";
        if args.len() < 2 {
            return USAGE.into();
        }
        let name = args.tokens[..2].join(" ");
        let (cell, reason_from) = match args.tokens.get(2).and_then(|t| t.parse::<u32>().ok()) {
            Some(n) if n >= 1 => (n, 3),
            _ => (1, 2),
        };
        let cells = crate::jail::get().cells.len() as u32;
        if cell > cells {
            return format!("there are {cells} cell(s) in settings/jail.toml");
        }
        let reason = args
            .tokens
            .get(reason_from..)
            .map(|r| r.join(" "))
            .unwrap_or_default();
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        if let Err(e) = self
            .db
            .set_jail_of_character(id, Some((cell, reason.clone())))
            .await
        {
            return format!("jail failed: {e}");
        }
        tracing::info!(character = %name, cell, %reason, by = ?args.invoker, "jailed");
        let c = crate::jail::cell(cell);
        let zone = crate::jail::get().zone;
        if self.registry.get(id).await.is_some() {
            self.teleport(&name, Some(zone), None, 0, c.x, c.y, c.z)
                .await;
            format!("{name} is in Mordion Gaol, cell {cell}")
        } else {
            let _ = self
                .db
                .set_character_position(id, zone, c.x, c.y, c.z)
                .await;
            format!("{name} will be in Mordion Gaol, cell {cell}, at their next login")
        }
    }

    /// `pardon <name>`: release someone from the gaol, to their home city.
    pub(super) async fn handle_pardon(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0).filter(|_| args.len() > 0) else {
            return "usage: pardon <name>".into();
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.jail_of_character(id).await {
            Ok(Some(_)) => {}
            Ok(None) => return format!("{name} isn't jailed"),
            Err(e) => return format!("pardon failed: {e}"),
        }
        if let Err(e) = self.db.set_jail_of_character(id, None).await {
            return format!("pardon failed: {e}");
        }
        tracing::info!(character = %name, by = ?args.invoker, "pardoned");
        let r = self
            .handle_posfix(&Args::new(name.split_whitespace().collect(), args.invoker))
            .await;
        format!("released {name}: {r}")
    }

    /// `togglegm [name]`: the GM icon on or off (it shows for GM level 2+).
    pub(super) async fn handle_togglegm(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: togglegm <name>".into()
            };
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let (level, tag) = match self.db.gm_status_of_character(id).await {
            Ok(s) => s,
            Err(e) => return format!("togglegm failed: {e}"),
        };
        let on = !tag;
        if let Err(e) = self.db.set_gm_tag_of_character(id, on).await {
            return format!("togglegm failed: {e}");
        }
        let shows = on && level >= crate::gm_tags::TAG_LEVEL;
        crate::gm_tags::set(id, shows);
        if let Some(handle) = self.registry.get(id).await {
            let icon = crate::gm_tags::icon(id);
            let mut pkt = crate::packets::send::actor::build_set_actor_icon(handle.actor_id, icon);
            if let Some(client) = self.world.client(handle.session_id).await {
                pkt.set_target_id(handle.session_id);
                client.send_bytes(pkt.to_bytes()).await;
            }
            let zone_id = handle.character.read().await.base.zone_id;
            if let Some(zone) = self.world.zone(zone_id).await {
                let bytes =
                    crate::packets::send::actor::build_set_actor_icon(handle.actor_id, icon)
                        .to_bytes();
                crate::runtime::broadcast::broadcast_around_actor(
                    &self.world,
                    &self.registry,
                    &zone,
                    handle.actor_id,
                    bytes,
                )
                .await;
            }
        }
        match (on, shows) {
            (true, true) => format!("{name}'s GM tag is on"),
            (true, false) => format!(
                "{name}'s GM tag is on, but shows only at GM level 2 or above (now {level})"
            ),
            (false, _) => format!("{name}'s GM tag is off"),
        }
    }

    /// `logoff <name>`: disconnect someone.
    pub(super) async fn handle_logoff(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0).filter(|_| args.len() > 0) else {
            return "usage: logoff <name>".into();
        };
        let Ok(id) = self.online_id(&name).await else {
            return format!("{name} is not online");
        };
        let Some(handle) = self.registry.get(id).await else {
            return format!("{name} is not online");
        };
        let Some(client) = self.world.client(handle.session_id).await else {
            return format!("{name} is already disconnecting");
        };
        let mut pkt = crate::packets::send::handshake::build_logout(handle.actor_id);
        pkt.set_target_id(handle.session_id);
        client.send_bytes(pkt.to_bytes()).await;
        tracing::info!(character = %name, by = ?args.invoker, "logged off by command");
        format!("logged {name} off")
    }

    /// `announce <message>`: a message to everyone online.
    pub(super) async fn handle_announce(&self, args: &Args<'_>) -> String {
        if args.len() == 0 {
            return "usage: announce <message>".into();
        }
        let text = format!("[Announcement] {}", args.tokens.join(" "));
        let mut n = 0;
        for s in self.world.all_sessions().await {
            if let Some(h) = self.registry.by_session(s.id).await {
                self.tell_player(h.actor_id, text.clone()).await;
                n += 1;
            }
        }
        format!("announced to {n} player(s)")
    }

    /// `getid`: what you have targeted.
    pub(super) async fn handle_getid(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some(handle) = self.registry.get(me).await else {
            return "you are not in the world".into();
        };
        let target = handle.character.read().await.chara.current_target;
        if target == 0 || target == crate::actor::INVALID_ACTORID {
            return "nothing targeted".into();
        }
        match self.registry.get(target).await {
            Some(t) => {
                let c = t.character.read().await;
                format!(
                    "target: actor {target} (0x{target:08X}), class {}, \"{}\", at {:.2} {:.2} {:.2}",
                    c.chara.actor_class_id,
                    c.base.display_name(),
                    c.base.position_x,
                    c.base.position_y,
                    c.base.position_z
                )
            }
            None => format!("target: actor {target} (0x{target:08X})"),
        }
    }

    /// `setpos`: save where your target NPC or monster stands now (after a
    /// `bring`, say) as its spawn point in the world database, and give the
    /// seed SQL for the same change.
    pub(super) async fn handle_setpos(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let tid = match self.my_target(me).await {
            Ok(t) => t,
            Err(e) => return e,
        };
        let Some(h) = self.registry.get(tid).await else {
            return "that actor is gone".into();
        };
        if h.session_id != 0 {
            return "setpos is for NPCs and monsters".into();
        }
        let (bnpc_id, class_id, unique_id, x, y, z, rot) = {
            let c = h.character.read().await;
            (
                c.chara.bnpc_id,
                c.chara.actor_class_id,
                c.base.unique_id.clone(),
                c.base.position_x,
                c.base.position_y,
                c.base.position_z,
                c.base.rotation,
            )
        };
        let label = self.actor_label(tid).await;
        if bnpc_id != 0 {
            {
                let mut c = h.character.write().await;
                c.chara.spawn_x = x;
                c.chara.spawn_y = y;
                c.chara.spawn_z = z;
            }
            return match self
                .db
                .set_battle_npc_spawn_position(bnpc_id, x, y, z, rot)
                .await
            {
                Ok(true) => format!(
                    "saved {label} spawn: UPDATE server_battlenpc_spawn_locations SET positionX = {x:.2}, \
                     positionY = {y:.2}, positionZ = {z:.2}, rotation = {rot:.2} WHERE bnpcId = {bnpc_id};"
                ),
                Ok(false) => format!("{label}: bnpc {bnpc_id} has no spawn row"),
                Err(e) => format!("setpos failed: {e}"),
            };
        }
        if unique_id.is_empty() {
            return format!("{label} has no spawn row (spawned by a script)");
        }
        let area = h.private_area.as_ref().map(|a| a.0.clone());
        match self
            .db
            .set_npc_spawn_position(h.zone_id, class_id, unique_id.clone(), area, x, y, z, rot)
            .await
        {
            Ok(0) => format!(
                "{label}: no spawn row for {unique_id} in zone {}",
                h.zone_id
            ),
            Ok(n) => format!(
                "saved {label} ({n} row): UPDATE server_spawn_locations SET positionX = {x:.2}, \
                 positionY = {y:.2}, positionZ = {z:.2}, rotation = {rot:.2} WHERE zoneId = {} \
                 AND actorClassId = {class_id} AND uniqueId = '{unique_id}';",
                h.zone_id
            ),
            Err(e) => format!("setpos failed: {e}"),
        }
    }

    // --- items, gil, quests -----------------------------------------------------------------------

    /// `<id> [qty] [name]` as used by the item commands.
    fn id_qty_name(args: &Args<'_>) -> Option<(u32, i32, usize)> {
        let id = args.tokens.first()?.parse::<u32>().ok()?;
        match args.tokens.get(1).and_then(|t| t.parse::<i32>().ok()) {
            Some(q) => Some((id, q.max(1), 2)),
            None => Some((id, 1, 1)),
        }
    }

    /// `additem` / `addkeyitem <id> [qty] [name]`.
    pub(super) async fn handle_additem(&self, args: &Args<'_>, key_item: bool) -> String {
        let usage = if key_item {
            "usage: addkeyitem <key item id> [name]"
        } else {
            "usage: additem <item id> [quantity] [name]"
        };
        let Some((item, qty, from)) = Self::id_qty_name(args) else {
            return usage.into();
        };
        let Some(name) = args.rest_joined(from) else {
            return if args.was_refused() {
                String::new()
            } else {
                usage.into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let package = if key_item { PKG_KEYITEMS } else { PKG_NORMAL };
        let qty = if key_item { 1 } else { qty };
        self.run_lua(vec![LC::AddItem {
            actor_id: id,
            item_package: package,
            item_id: item,
            quantity: qty,
        }])
        .await;
        format!("gave {name} {qty} × item {item}")
    }

    /// `gmgear [name]`: the Judge's set, 1.0's GM outfit (wearable by every
    /// race, no level): coif, haubergeon, skirt, vambraces, sollerets.
    pub(super) async fn handle_gmgear(&self, args: &Args<'_>) -> String {
        const JUDGES: [u32; 5] = [8011708, 8031716, 8050808, 8070243, 8081208];
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: gmgear <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let cmds = JUDGES
            .iter()
            .map(|&item| LC::AddItem {
                actor_id: id,
                item_package: PKG_NORMAL,
                item_id: item,
                quantity: 1,
            })
            .collect();
        self.run_lua(cmds).await;
        format!("gave {name} the Judge's set (coif, haubergeon, skirt, vambraces, sollerets)")
    }

    /// `delitem` / `delkeyitem <id> [qty] [name]`.
    pub(super) async fn handle_delitem(&self, args: &Args<'_>, key_item: bool) -> String {
        let usage = if key_item {
            "usage: delkeyitem <key item id> [name]"
        } else {
            "usage: delitem <item id> [quantity] [name]"
        };
        let Some((item, qty, from)) = Self::id_qty_name(args) else {
            return usage.into();
        };
        let Some(name) = args.rest_joined(from) else {
            return if args.was_refused() {
                String::new()
            } else {
                usage.into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let package = if key_item { PKG_KEYITEMS } else { PKG_NORMAL };
        crate::runtime::quest_apply::apply_remove_item(
            id,
            package,
            item,
            qty,
            &self.registry,
            Some(&self.world),
            &self.db,
        )
        .await;
        format!("took {qty} × item {item} from {name}")
    }

    /// `hasitem` / `haskeyitem <id> [name]`.
    pub(super) async fn handle_hasitem(&self, args: &Args<'_>, key_item: bool) -> String {
        let Some(item) = args.tokens.first().and_then(|t| t.parse::<u32>().ok()) else {
            return "usage: hasitem <item id> [name]".into();
        };
        let Some(name) = args.rest_joined(1) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: hasitem <item id> <name>".into()
            };
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let package = if key_item { PKG_KEYITEMS } else { PKG_NORMAL };
        match self.db.item_count(id, package, item).await {
            Ok(0) => format!("{name} has no item {item}"),
            Ok(n) => format!("{name} has {n} × item {item}"),
            Err(e) => format!("hasitem failed: {e}"),
        }
    }

    /// `setgil <amount> [name]` / `takegil <amount> [name]`.
    pub(super) async fn handle_gil(&self, args: &Args<'_>, set: bool) -> String {
        let usage = if set {
            "usage: setgil <amount> [name]"
        } else {
            "usage: takegil <amount> [name]"
        };
        let Some(amount) = args
            .tokens
            .first()
            .and_then(|t| t.parse::<i32>().ok())
            .filter(|a| *a >= 0)
        else {
            return usage.into();
        };
        let Some(name) = args.rest_joined(1) else {
            return if args.was_refused() {
                String::new()
            } else {
                usage.into()
            };
        };
        let Some(id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let now = match self.db.get_gil(id).await {
            Ok(g) => g,
            Err(e) => return format!("gil lookup failed: {e}"),
        };
        let delta = if set { amount - now } else { -amount.min(now) };
        if self.registry.get(id).await.is_some() {
            self.run_lua(vec![LC::AddGil {
                actor_id: id,
                amount: delta,
            }])
            .await;
            format!("{name} has {} gil", now + delta)
        } else {
            match self.db.add_gil(id, delta).await {
                Ok(total) => format!("{name} has {total} gil"),
                Err(e) => format!("gil change failed: {e}"),
            }
        }
    }

    /// `addquest` / `completequest` / `delquest <quest id> [name]`.
    pub(super) async fn handle_quest(&self, args: &Args<'_>, verb: &str) -> String {
        let Some(quest) = args.tokens.first().and_then(|t| t.parse::<u32>().ok()) else {
            return format!("usage: {verb}quest <quest id> [name]");
        };
        let Some(name) = args.rest_joined(1) else {
            return if args.was_refused() {
                String::new()
            } else {
                format!("usage: {verb}quest <quest id> <name>")
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let cmd = match verb {
            "add" => LC::AddQuest {
                player_id: id,
                quest_id: quest,
            },
            "complete" => LC::CompleteQuest {
                player_id: id,
                quest_id: quest,
            },
            _ => LC::AbandonQuest {
                player_id: id,
                quest_id: quest,
            },
        };
        self.run_lua(vec![cmd]).await;
        format!("{verb} quest {quest} for {name}: done")
    }

    /// `addtitle <title id> [name]`.
    pub(super) async fn handle_addtitle(&self, args: &Args<'_>) -> String {
        let Some(title) = args.tokens.first().and_then(|t| t.parse::<u32>().ok()) else {
            return "usage: addtitle <title id> [name]".into();
        };
        let Some(name) = args.rest_joined(1) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: addtitle <title id> <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        self.run_lua(vec![LC::SetTitle {
            actor_id: id,
            title_id: title,
        }])
        .await;
        format!("{name}'s title is now {title}")
    }

    /// `addeffect <status id> [seconds] [name]`.
    pub(super) async fn handle_addeffect(&self, args: &Args<'_>) -> String {
        let Some(status) = args.tokens.first().and_then(|t| t.parse::<u32>().ok()) else {
            return "usage: addeffect <status id> [seconds] [name]".into();
        };
        let (secs, from) = match args.tokens.get(1).and_then(|t| t.parse::<u32>().ok()) {
            Some(s) => (s, 2),
            None => (60, 1),
        };
        let Some(name) = args.rest_joined(from) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: addeffect <status id> [seconds] <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        self.run_lua(vec![LC::TryStatus {
            source_actor_id: id,
            target_actor_id: id,
            status_id: status,
            duration_s: secs,
            magnitude: 0.0,
            tick_ms: 3000,
            tier: 0,
        }])
        .await;
        format!("gave {name} status {status} for {secs} s")
    }

    /// `addallaetherytes [name]`: attune to every aetheryte (1.23b's take on
    /// FFXI's !addallmaps).
    pub(super) async fn handle_addallaetherytes(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: addallaetherytes <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let cmds: Vec<LC> = crate::actor::aetheryte::AETHERYTE_SPAWNS
            .iter()
            .map(|a| LC::UnlockAetheryte {
                player_id: id,
                aetheryte_id: a.aetheryte_id,
            })
            .collect();
        let n = cmds.len();
        self.run_lua(cmds).await;
        format!("{name} is attuned to all {n} aetherytes")
    }

    // --- the world around you -----------------------------------------------------------------------

    /// `setmusic <music id> [name]`.
    pub(super) async fn handle_setmusic(&self, args: &Args<'_>) -> String {
        let Some(music) = args.tokens.first().and_then(|t| t.parse::<u16>().ok()) else {
            return "usage: setmusic <music id> [name]".into();
        };
        let Some(name) = args.rest_joined(1) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: setmusic <music id> <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        self.run_lua(vec![LC::ChangeMusic {
            player_id: id,
            music_id: music,
        }])
        .await;
        format!("playing music {music} for {name}")
    }

    /// `setweather <weather id>`: the weather for everyone in your zone.
    pub(super) async fn handle_setweather(&self, args: &Args<'_>) -> String {
        let Some(weather) = args.tokens.first().and_then(|t| t.parse::<u16>().ok()) else {
            return "usage: setweather <weather id>".into();
        };
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some((zone, ..)) = self.spot_of(me).await else {
            return "you are not in the world".into();
        };
        let mut n = 0;
        for s in self.world.all_sessions().await {
            if s.current_zone_id != zone {
                continue;
            }
            if let (Some(h), Some(client)) = (
                self.registry.by_session(s.id).await,
                self.world.client(s.id).await,
            ) {
                let mut pkt = crate::packets::send::misc::build_set_weather(h.actor_id, weather, 0);
                pkt.set_target_id(s.id);
                client.send_bytes(pkt.to_bytes()).await;
                n += 1;
            }
        }
        format!("weather {weather} for {n} player(s) in zone {zone}")
    }
}
