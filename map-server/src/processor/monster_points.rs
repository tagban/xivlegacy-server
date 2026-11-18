// garlemald-server — Rust port of a FINAL FANTASY XIV v1.23b server emulator (lobby/world/map)
// Copyright (C) 2026  Samuel Stegall
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `!mp`: Monster Points in chat, for every player. The command lives in
//! Lua (`commands/gm/mp.lua`, with the goods in `monsterpoints.lua`); this
//! runs its `onTrigger(player, argc, verb, number)` for the typer and
//! applies what it queues, like `!dungeon`.

use super::PacketProcessor;
use crate::runtime::actor_registry::ActorHandle;

impl PacketProcessor {
    pub(super) async fn monster_points_command(
        &self,
        handle: &ActorHandle,
        line: &str,
        level: u8,
    ) -> Option<Result<String, String>> {
        let mut words = line.split_whitespace();
        if !words.next()?.eq_ignore_ascii_case("mp") {
            return None;
        }
        if !crate::runtime::monster_mode::enabled() {
            return Some(Err(format!(
                "Monster Mode isn't enabled on this server (the {} module is off).",
                crate::runtime::monster_mode::MODULE
            )));
        }
        if level < crate::command_permissions::get().required("mp") {
            return Some(Err("unknown command: !mp (!help lists yours)".into()));
        }
        let args: Vec<&str> = words.take(2).collect();
        let Some(lua) = self.lua.as_ref() else {
            return Some(Err("no Lua engine on this map server".into()));
        };
        let script = lua.resolver().gm_command("mp");
        if !script.exists() {
            return Some(Err(format!("{} is missing", script.display())));
        }
        let mut snapshot = {
            let c = handle.character.read().await;
            super::build_player_snapshot_from_character(&c)
        };
        // the balance and the price check read the money package
        match self.db.item_totals(snapshot.actor_id).await {
            Ok(items) => snapshot.inventory = items,
            Err(e) => return Some(Err(format!("!mp: reading your items failed: {e}"))),
        }
        match lua.call_player_hook_with_args(&script, "onTrigger", snapshot, &args) {
            Ok(result) => {
                for cmd in result.commands {
                    self.apply_login_lua_command(handle, cmd).await;
                }
                // the script answers in chat itself
                Some(Ok(String::new()))
            }
            Err(e) => Some(Err(format!("!mp failed: {e}"))),
        }
    }
}
