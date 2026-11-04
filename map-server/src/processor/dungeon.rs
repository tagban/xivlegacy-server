// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! GM `!dungeon <name>` / `!dungeon leave`: enter one of the 1.0 dungeons
//! in your own copy (your party comes along), or walk out of it.
//!
//! The dungeons themselves live in Lua (`scripts/lua/dungeon.lua`); this
//! runs `commands/gm/dungeon.lua`'s `enter<Name>(player)` or
//! `leave(player)` for the typer and applies what it queues, the same way
//! the login hooks are applied. Retail entered through queue NPCs by each
//! dungeon; until those are scripted, this is the way in.

use super::PacketProcessor;
use crate::runtime::actor_registry::ActorHandle;

const DUNGEONS: &[(&str, &str)] = &[
    ("totorak", "enterTotorak"),
    ("dzemael", "enterDzemael"),
    ("aurum", "enterAurum"),
    ("cutters", "enterCutters"),
];

impl PacketProcessor {
    pub(super) async fn dungeon_command(
        &self,
        handle: &ActorHandle,
        line: &str,
        level: u8,
    ) -> Option<Result<String, String>> {
        let mut words = line.split_whitespace();
        if !words.next()?.eq_ignore_ascii_case("dungeon") {
            return None;
        }
        if level < crate::command_permissions::get().required("dungeon") {
            return Some(Err("!dungeon needs a higher GM level".into()));
        }
        let usage = || {
            let names: Vec<&str> = DUNGEONS.iter().map(|(n, _)| *n).collect();
            format!("usage: !dungeon <{}> | !dungeon leave", names.join("|"))
        };
        let arg = match words.next() {
            Some(a) => a.to_ascii_lowercase(),
            None => return Some(Err(usage())),
        };
        let function = if arg == "leave" {
            "leave"
        } else {
            match DUNGEONS
                .iter()
                .find(|(n, _)| arg.starts_with(n) || n.starts_with(arg.as_str()))
            {
                Some((_, f)) => *f,
                None => return Some(Err(usage())),
            }
        };
        let Some(lua) = self.lua.as_ref() else {
            return Some(Err("no Lua engine on this map server".into()));
        };
        let script = lua.resolver().gm_command("dungeon");
        if !script.exists() {
            return Some(Err(format!("{} is missing", script.display())));
        }
        let snapshot = {
            let c = handle.character.read().await;
            super::build_player_snapshot_from_character(&c)
        };
        match lua.call_player_hook(&script, function, snapshot) {
            Ok(result) => {
                for cmd in result.commands {
                    self.apply_login_lua_command(handle, cmd).await;
                }
                Some(Ok(if function == "leave" {
                    "leaving the dungeon".into()
                } else {
                    format!("entering {arg}")
                }))
            }
            Err(e) => Some(Err(format!("!dungeon failed: {e}"))),
        }
    }
}
