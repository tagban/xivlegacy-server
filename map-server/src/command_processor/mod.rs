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

//! GM console command parser. Ported from `CommandProcessor.cs` as a
//! string-dispatch table. The full retail catalogue is large; this wires
//! the commands that exercise the in-progress subsystems (revive / die /
//! givegil / giveexp) plus `reload` for live Lua hot-reload.
//!
//! Target-resolution convention: when a command expects a player target,
//! pass the character name as the last positional argument. We resolve
//! name → character id via the DB, then look up the live `ActorHandle`
//! through `ActorRegistry::by_session` (safe because for Players
//! `character_id == session_id == actor_id`, see `processor.rs:133`).

use std::sync::Arc;

use anyhow::Result;

use crate::database::Database;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

mod gm_tools;
pub(crate) mod world_end;

pub struct CommandProcessor {
    pub world: Arc<WorldManager>,
    pub registry: Arc<ActorRegistry>,
    pub db: Arc<Database>,
    pub lua: Arc<LuaEngine>,
    /// The finaldays module (`worldend`, `finale`) is enabled: without it
    /// those commands don't exist.
    pub final_days: bool,
}

/// How far `!usemove` looks for a monster when nothing is targeted.
const USEMOVE_RANGE: f32 = 30.0;

impl CommandProcessor {
    pub fn new(
        world: Arc<WorldManager>,
        registry: Arc<ActorRegistry>,
        db: Arc<Database>,
        lua: Arc<LuaEngine>,
    ) -> Self {
        Self {
            world,
            registry,
            db,
            lua,
            final_days: crate::modules::is_enabled(world_end::MODULE),
        }
    }

    /// Run a single console command. Returns the human-readable response
    /// that `main.rs` forwards to the log. Unknown commands echo back so
    /// the operator notices typos.
    pub async fn run(&self, line: &str) -> Result<String> {
        self.run_as(line, None).await
    }

    /// Variant carrying the invoking player's character name. The chat
    /// `!command` path uses this so commands whose trailing `<name>` arg
    /// is omitted target the sender — Meteor's command scripts get the
    /// invoking session's player as the implicit first argument
    /// (`onTrigger(player, ...)` in `Data/scripts/commands/gm/*.lua`)
    /// and the optional `<targetname>` only overrides it.
    pub async fn run_as(&self, line: &str, invoker: Option<&str>) -> Result<String> {
        self.run_checked(line, invoker, None).await
    }

    /// A command typed in chat by `invoker`, whose account has GM level
    /// `level`: refused unless `settings/commands.toml` gives the command to
    /// that level, and limited to the invoker themself below `target_others`
    /// (crate::command_permissions).
    pub async fn run_as_player(&self, line: &str, invoker: &str, level: u8) -> Result<String> {
        self.run_checked(line, Some(invoker), Some(level)).await
    }

    /// `level`: None for the console, which isn't limited.
    async fn run_checked(
        &self,
        line: &str,
        invoker: Option<&str>,
        level: Option<u8>,
    ) -> Result<String> {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            return Ok(String::new());
        }
        let mut tokens = trimmed.split_whitespace();
        let typed = tokens.next().unwrap_or("").to_lowercase();
        // the FFXI server's names for commands this server has under another
        let cmd = match typed.as_str() {
            "where" => "pos",
            "ver" => "version",
            "raise" => "revive",
            "kill" => "die",
            "release" => "endevent",
            "promote" => "setgm",
            "homepoint" => "home",
            "reloadglobal" => "reload",
            "giveitem" => "additem",
            "givekeyitem" => "addkeyitem",
            "fixspeed" => "speed",
            other => other,
        }
        .to_string();
        if !self.final_days && world_end::COMMANDS.contains(&cmd.as_str()) {
            return Ok(match level {
                Some(_) => format!("unknown command: !{cmd} (!help lists yours)"),
                None => format!(
                    "unknown command: {cmd} (it comes with the {} module, which is off)",
                    world_end::MODULE
                ),
            });
        }
        let perms = crate::command_permissions::get();
        if let Some(level) = level
            && level < perms.required(&cmd)
        {
            return Ok(format!("unknown command: !{cmd} (!help lists yours)"));
        }
        let mut rest: Vec<&str> = tokens.collect();
        if let Err(e) = self.db.log_gm_command(invoker, &cmd, &rest.join(" ")).await {
            tracing::warn!(error = %e, "logging a GM command");
        }
        if typed == "fixspeed" {
            rest.insert(0, "1"); // back to normal speed
        }
        let args =
            Args::new(rest, invoker).self_only(level.is_some_and(|l| l < perms.target_others));

        let response = match cmd.as_str() {
            "help" => Self::help(level, self.final_days),
            "version" => format!("map-server {}", env!("CARGO_PKG_VERSION")),
            "who" => format!("{} zone(s) loaded", self.world.zone_count().await),
            "reload" => {
                let n = self.lua.reload_scripts();
                format!("reloaded: {n} lua script(s) dropped from cache")
            }
            "zone" => self.handle_zone(&args).await,
            "camp" => self.handle_camp(&args).await,
            "setgm" => self.handle_setgm(&args, level).await,
            "pos" => self.handle_pos(&args).await,
            "endevent" => self.handle_endevent(&args).await,
            "goto" => self.handle_goto(&args).await,
            "bring" => self.handle_bring(&args).await,
            "bringall" => self.handle_bringall(&args).await,
            "send" => self.handle_send(&args).await,
            "return" => self.handle_return(&args).await,
            "up" => self.handle_updown(&args, 1.0).await,
            "down" => self.handle_updown(&args, -1.0).await,
            "posfix" => self.handle_posfix(&args).await,
            "jail" => self.handle_jail(&args).await,
            "pardon" => self.handle_pardon(&args).await,
            "togglegm" => self.handle_togglegm(&args).await,
            "logoff" => self.handle_logoff(&args).await,
            "announce" => self.handle_announce(&args).await,
            "getid" => self.handle_getid(&args).await,
            "setpos" => self.handle_setpos(&args).await,
            "gmgear" => self.handle_gmgear(&args).await,
            "additem" => self.handle_additem(&args, false).await,
            "addkeyitem" => self.handle_additem(&args, true).await,
            "delitem" => self.handle_delitem(&args, false).await,
            "delkeyitem" => self.handle_delitem(&args, true).await,
            "hasitem" => self.handle_hasitem(&args, false).await,
            "haskeyitem" => self.handle_hasitem(&args, true).await,
            "setgil" => self.handle_gil(&args, true).await,
            "takegil" => self.handle_gil(&args, false).await,
            "addquest" => self.handle_quest(&args, "add").await,
            "completequest" => self.handle_quest(&args, "complete").await,
            "delquest" => self.handle_quest(&args, "del").await,
            "addtitle" => self.handle_addtitle(&args).await,
            "addeffect" => self.handle_addeffect(&args).await,
            "addallaetherytes" => self.handle_addallaetherytes(&args).await,
            "setmusic" => self.handle_setmusic(&args).await,
            "setweather" => self.handle_setweather(&args).await,
            "revive" => self.handle_revive(&args).await,
            "home" => self.handle_home(&args).await,
            "sethome" => self.handle_set_home(&args).await,
            "die" => self.handle_die(&args).await,
            "settp" => self.handle_settp(&args).await,
            "usemove" => self.handle_usemove(&args).await,
            "givegil" => self.handle_givegil(&args).await,
            "giveexp" => self.handle_giveexp(&args).await,
            "hireretainer" => self.handle_hire_retainer(&args).await,
            "dismissretainer" => self.handle_dismiss_retainer(&args).await,
            "listretainers" => self.handle_list_retainers(&args).await,
            "setsleeping" => self.handle_set_sleeping(&args).await,
            "dream" => self.handle_dream(&args).await,
            "wake" => self.handle_wake(&args).await,
            "accruerest" => self.handle_accrue_rest(&args).await,
            "issuechocobo" => self.handle_issue_chocobo(&args).await,
            "rentchocobo" => self.handle_rent_chocobo(&args).await,
            "dismount" => self.handle_dismount(&args).await,
            "joingc" => self.handle_join_gc(&args).await,
            "setgcrank" => self.handle_set_gc_rank(&args).await,
            "addgcseals" => self.handle_add_gc_seals(&args).await,
            "warp" => self.handle_warp(&args).await,
            "talkto" => self.handle_talkto(&args).await,
            "pushtrigger" => self.handle_pushtrigger(&args).await,
            "setseq" => self.handle_setseq(&args).await,
            "speed" => self.handle_speed(&args).await,
            "worldend" => self.handle_worldend(&args).await,
            other => format!("unknown command: {other} (args={:?})", args.rest()),
        };
        if args.was_refused() {
            return Ok(format!("!{cmd} works only on yourself at your GM level"));
        }
        Ok(response)
    }

    /// The commands `level` may use (all of them on the console), leaving
    /// out the finaldays module's while it's off.
    fn help(level: Option<u8>, final_days: bool) -> String {
        const ALL: &[&str] = &[
            "help",
            "who",
            "version",
            "bug <what happened>",
            "pos [name]",
            "endevent [name]",
            "goto [name | npc name | class id]",
            "bring [name | npc name | class id]",
            "bringall",
            "send <name> to <name>",
            "return [name]",
            "up [yalms] [name]",
            "down [yalms] [name]",
            "posfix <name>",
            "jail <name> [cell] [reason]",
            "pardon <name>",
            "togglegm [name]",
            "logoff <name>",
            "announce <message>",
            "getid",
            "setpos",
            "gmgear [name]",
            "additem <item id> [qty] [name]",
            "delitem <item id> [qty] [name]",
            "addkeyitem <id> [name]",
            "delkeyitem <id> [name]",
            "hasitem <item id> [name]",
            "haskeyitem <id> [name]",
            "setgil <amount> [name]",
            "takegil <amount> [name]",
            "addquest <quest id> [name]",
            "completequest <quest id> [name]",
            "delquest <quest id> [name]",
            "addtitle <title id> [name]",
            "addeffect <status id> [seconds] [magnitude] [name]",
            "addallaetherytes [name]",
            "setmusic <music id> [name]",
            "setweather <weather id>",
            "worldend",
            "zone <zone id or name> [name]",
            "camp [camp name] [name]",
            "warp <x> <y> <z> [name] | warp <zone> <x> <y> <z> [name]",
            "home [name]",
            "revive [name]",
            "speed <multiplier> [name]",
            "dismount [name]",
            "wake [name]",
            "givegil <qty> [name]",
            "giveexp <qty> <class_id> [name]",
            "sethome <aetheryte_id> [name]",
            "joingc <gc> [name]",
            "setgcrank <gc> <rank> [name]",
            "addgcseals <gc> <amount> [name]",
            "accruerest <minutes> [name]",
            "issuechocobo <appearance> <chocobo_name> [name]",
            "rentchocobo <minutes> [name]",
            "hireretainer <retainer_id> [name]",
            "dismissretainer <retainer_id> [name]",
            "listretainers [name]",
            "setsleeping [name]",
            "dream <id> [name]",
            "die [name]",
            "settp <tp 0-3000> [name]",
            "usemove <command id> (target, else nearest monster)",
            "setgm <level 0-4> <name>",
            "reload",
            "talkto <actor_class_id> [name]",
            "pushtrigger <actor_class_id> [name]",
            "setseq <quest_id> <sequence> [name]",
        ];
        let perms = crate::command_permissions::get();
        let mine: Vec<&str> = ALL
            .iter()
            .filter(|c| {
                let name = c.split_whitespace().next().unwrap_or("");
                (final_days || !world_end::COMMANDS.contains(&name))
                    && (name != "bug" || crate::modules::is_enabled(common::bug_reports::MODULE))
                    && level.is_none_or(|l| l >= perms.required(name))
            })
            .copied()
            .collect();
        match level {
            Some(l) => format!(
                "your level: {} ({l}). commands: {}",
                crate::command_permissions::level_name(l),
                mine.join(", ")
            ),
            None => format!("commands: {}", mine.join(", ")),
        }
    }

    async fn handle_revive(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: revive <name>".into();
        };
        match self.resolve_live_target(&name).await {
            TargetLookup::Ok { actor_id, zone } => {
                crate::runtime::dispatcher::apply_revive(
                    actor_id,
                    &self.registry,
                    &self.world,
                    &zone,
                )
                .await;
                format!("revived {name} (actor {actor_id})")
            }
            TargetLookup::Err(e) => e,
        }
    }

    /// `settp <tp> [name]` — set a player's TP (0-3000) and refresh their
    /// gauge, so weaponskills can be tried without fighting for TP first.
    async fn handle_settp(&self, args: &Args<'_>) -> String {
        let usage = "usage: settp <tp 0-3000> <name>";
        let Some(tp) = args.rest().first().and_then(|t| t.parse::<u16>().ok()) else {
            return usage.into();
        };
        let tp = tp.min(3000);
        let Some(name) = args.rest_joined(1) else {
            return usage.into();
        };
        match self.resolve_live_target(&name).await {
            TargetLookup::Ok { actor_id, .. } => {
                crate::runtime::dispatcher::apply_set_tp(actor_id, tp, &self.registry, &self.world)
                    .await;
                format!("set {name}'s TP to {tp}")
            }
            TargetLookup::Err(e) => e,
        }
    }

    /// `usemove <command id>` — your targeted monster uses that move on
    /// its next combat tick, whatever its TP (for checking moves one by
    /// one in the client). The move joins that monster's list.
    async fn handle_usemove(&self, args: &Args<'_>) -> String {
        let usage = "usage: usemove <command id> (your target, else the nearest monster)";
        let Some(id) = args.rest().first().and_then(|t| t.parse::<u16>().ok()) else {
            return usage.into();
        };
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let target = match self.my_target(me).await {
            Ok(t) => t,
            Err(_) => match self.nearest_monster(me).await {
                Some(t) => t,
                None => {
                    return format!("no monster targeted or within {USEMOVE_RANGE} yalms ({usage})");
                }
            },
        };
        let cmd = {
            let Ok(cmds) = self.lua.catalogs().battle_commands.read() else {
                return "the command catalog is busy, try again".into();
            };
            match cmds.get(&id) {
                Some(gd) => gd.to_battle_command(),
                None => return format!("no battle command {id}"),
            }
        };
        let name = cmd.name.clone();
        let label = self.actor_label(target).await;
        let Some(handle) = self.registry.get(target).await else {
            return "that actor is gone".into();
        };
        let mut c = handle.character.write().await;
        let Some(ctrl) = c.ai_container.controller.as_mut() else {
            return "your target has no battle AI".into();
        };
        ctrl.battle.forced_skill = Some(cmd);
        // An idle monster only acts once it has a foe: point it at the GM.
        if !c.hate.has_hate_for(me) {
            c.hate.add_base_hate(me);
        }
        format!("{label} will use {name} ({id}) next")
    }

    /// The nearest living monster (not an ally) within [`USEMOVE_RANGE`] of `me`.
    async fn nearest_monster(&self, me: u32) -> Option<u32> {
        let handle = self.registry.get(me).await?;
        let pos = handle.character.read().await.base.position();
        let zone_arc = self.world.zone(handle.zone_id).await?;
        let mut near: Vec<(f32, u32)> = {
            let zone = zone_arc.read().await;
            zone.core
                .actors_around(me, USEMOVE_RANGE)
                .into_iter()
                .filter(|a| a.is_alive && a.kind == crate::zone::area::ActorKind::BattleNpc)
                .map(|a| {
                    let (dx, dz) = (a.position.x - pos.x, a.position.z - pos.z);
                    (dx * dx + dz * dz, a.actor_id)
                })
                .collect()
        };
        near.sort_by(|a, b| a.0.total_cmp(&b.0));
        for (_, id) in near {
            let ally = self
                .registry
                .get(id)
                .await
                .is_some_and(|h| h.kind == crate::runtime::actor_registry::ActorKindTag::Ally);
            if !ally {
                return Some(id);
            }
        }
        None
    }

    /// `home <name>` — server-driven home-point revive. Restores HP/MP
    /// + state via `apply_revive`, then warps the player to their
    ///   stored homepoint aetheryte. Mirrors the "bandaid fix for
    ///   returning while dead" branch in `TeleportCommand.lua` so we
    ///   can verify the death/revive flow without standing up the
    ///   client's death-overlay menu network.
    async fn handle_home(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: home <name>".into();
        };
        match self.resolve_live_target(&name).await {
            TargetLookup::Ok { actor_id, zone } => {
                let outcome = crate::runtime::dispatcher::apply_home_point_revive(
                    actor_id,
                    &self.registry,
                    &self.world,
                    &zone,
                )
                .await;
                match outcome {
                    crate::runtime::dispatcher::HomePointReviveOutcome::Warped {
                        homepoint,
                        zone_id,
                        x,
                        y,
                        z,
                    } => format!(
                        "home-point revived {name} (actor {actor_id}) to aetheryte {homepoint} \
                         → zone {zone_id} ({x:.2}, {y:.2}, {z:.2})"
                    ),
                    crate::runtime::dispatcher::HomePointReviveOutcome::InPlace => format!(
                        "revived {name} in place — no usable homepoint set (was 0 or unknown id)"
                    ),
                    crate::runtime::dispatcher::HomePointReviveOutcome::UnknownPlayer => {
                        format!("{name} dropped from registry mid-call")
                    }
                }
            }
            TargetLookup::Err(e) => e,
        }
    }

    /// `sethome <aetheryte_id> <name>` — admin shortcut to set a
    /// player's homepoint without walking them through the
    /// `AetheryteChild.lua` menu. Persists via the same DB path the
    /// in-game flow uses (`Database::save_player_home_points`) and
    /// mirrors into CharaState if the character is online.
    async fn handle_set_home(&self, args: &Args<'_>) -> String {
        let homepoint = match args.parse_u32(0) {
            Ok(id) => id,
            Err(e) => return format!("usage: sethome <aetheryte_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: sethome <aetheryte_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        // Read the existing inn id so we don't clobber it on the
        // homepoint write (the two share a DB row but represent
        // independent player choices).
        let inn = self
            .db
            .load_player_character(chara_id)
            .await
            .ok()
            .flatten()
            .map(|p| p.homepoint_inn)
            .unwrap_or(0);
        if let Err(e) = self
            .db
            .save_player_home_points(chara_id, homepoint, inn)
            .await
        {
            return format!("sethome failed: {e}");
        }
        if let Some(handle) = self.registry.get(chara_id).await {
            let mut c = handle.character.write().await;
            c.chara.homepoint = homepoint;
        }
        let resolved = crate::actor::aetheryte::lookup(homepoint)
            .map(|s| format!("zone {} at ({:.2}, {:.2}, {:.2})", s.zone_id, s.x, s.y, s.z))
            .unwrap_or_else(|| "(unknown aetheryte id; warp will in-place revive)".into());
        format!("set {name}'s homepoint to {homepoint} — {resolved}")
    }

    async fn handle_die(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: die <name>".into();
        };
        match self.resolve_live_target(&name).await {
            TargetLookup::Ok { actor_id, zone } => {
                crate::runtime::dispatcher::apply_die(
                    actor_id,
                    &self.registry,
                    &self.world,
                    &zone,
                    Some(&self.lua),
                    Some(&self.db),
                )
                .await;
                format!("killed {name} (actor {actor_id})")
            }
            TargetLookup::Err(e) => e,
        }
    }

    async fn handle_givegil(&self, args: &Args<'_>) -> String {
        let qty = match args.parse_i32(0) {
            Ok(q) => q,
            Err(e) => return format!("usage: givegil <qty> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: givegil <qty> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.add_gil(chara_id, qty).await {
            Ok(total) => format!("gave {qty} gil to {name} (total now {total})"),
            Err(e) => format!("givegil failed: {e}"),
        }
    }

    async fn handle_giveexp(&self, args: &Args<'_>) -> String {
        let qty = match args.parse_i32(0) {
            Ok(q) => q,
            Err(e) => return format!("usage: giveexp <qty> <class_id> <name> — {e}"),
        };
        let class_id = match args.parse_u8(1) {
            Ok(c) => c,
            Err(e) => return format!("usage: giveexp <qty> <class_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(2) else {
            return "usage: giveexp <qty> <class_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        // Read current exp + delta, then persist. The per-class column
        // is derived inside `Database::set_exp`; we don't expose the
        // column mapping here.
        let current = self
            .db
            .load_class_levels_and_exp(chara_id)
            .await
            .ok()
            .and_then(|row| row.skill_point.get(class_id as usize).copied())
            .unwrap_or(0);
        let new_exp = current.saturating_add(qty).max(0);
        match self.db.set_exp(chara_id, class_id, new_exp).await {
            Ok(()) => format!("gave {qty} exp to {name} (class {class_id}; total now {new_exp})"),
            Err(e) => format!("giveexp failed: {e}"),
        }
    }

    async fn handle_hire_retainer(&self, args: &Args<'_>) -> String {
        let retainer_id = match args.parse_i32(0) {
            Ok(id) => id,
            Err(e) => return format!("usage: hireretainer <retainer_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: hireretainer <retainer_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.hire_retainer(chara_id, retainer_id as u32).await {
            Ok(true) => format!("hired retainer {retainer_id} for {name}"),
            Ok(false) => {
                format!("{name} already owns retainer {retainer_id} (no-op)")
            }
            Err(e) => format!("hireretainer failed: {e}"),
        }
    }

    async fn handle_dismiss_retainer(&self, args: &Args<'_>) -> String {
        let retainer_id = match args.parse_i32(0) {
            Ok(id) => id,
            Err(e) => return format!("usage: dismissretainer <retainer_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: dismissretainer <retainer_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.dismiss_retainer(chara_id, retainer_id as u32).await {
            Ok(true) => format!("dismissed retainer {retainer_id} from {name}"),
            Ok(false) => {
                format!("{name} does not own retainer {retainer_id} (no-op)")
            }
            Err(e) => format!("dismissretainer failed: {e}"),
        }
    }

    async fn handle_list_retainers(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: listretainers <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.list_character_retainers(chara_id).await {
            Ok(list) if list.is_empty() => format!("{name} owns no retainers"),
            Ok(list) => {
                let mut out = format!("{name} owns {} retainer(s):\n", list.len());
                for (i, r) in list.iter().enumerate() {
                    out.push_str(&format!(
                        "  #{idx}: id={id} name={name} actorClass={ac} level={lv}\n",
                        idx = i + 1,
                        id = r.id,
                        name = r.name,
                        ac = r.actor_class_id,
                        lv = r.level,
                    ));
                }
                out
            }
            Err(e) => format!("listretainers failed: {e}"),
        }
    }

    async fn handle_set_sleeping(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: setsleeping <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let Some(zone_arc) = self.world.zone(handle.zone_id).await else {
            return format!("{name}'s zone {} not loaded", handle.zone_id);
        };
        let is_inn = { zone_arc.read().await.core.is_inn };
        if !is_inn {
            return format!("{name} is not in an inn zone (zone {})", handle.zone_id);
        }
        let (x, y, z) = {
            let c = handle.character.read().await;
            (c.base.position_x, c.base.position_y, c.base.position_z)
        };
        let inn_code = crate::actor::inn::inn_code_from_position((x, y, z), true);
        let Some(bed) = crate::actor::inn::sleeping_position_for_inn(inn_code) else {
            return format!(
                "{name} is in zone {} but not in any known inn room",
                handle.zone_id
            );
        };
        {
            let mut c = handle.character.write().await;
            c.base.position_x = bed.0;
            c.base.position_y = bed.1;
            c.base.position_z = bed.2;
            c.base.rotation = bed.3;
        }
        format!(
            "snapped {name} to inn-room {inn_code} bed ({:.2}, {:.2}, {:.2})",
            bed.0, bed.1, bed.2
        )
    }

    async fn handle_dream(&self, args: &Args<'_>) -> String {
        let dream_id = match args.parse_u8(0) {
            Ok(d) => d,
            Err(e) => return format!("usage: dream <id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: dream <id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.by_session(chara_id).await else {
            return format!("{name} is not online");
        };
        let session_id = handle.session_id;
        if session_id == 0 {
            return format!("{name} has no session");
        }
        if let Some(mut s) = self.world.session(session_id).await {
            s.current_dream_id = Some(dream_id);
            self.world.upsert_session(s).await;
        }
        format!(
            "set dream id {dream_id} on {name} (actor {})",
            handle.actor_id
        )
    }

    async fn handle_wake(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: wake <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.by_session(chara_id).await else {
            return format!("{name} is not online");
        };
        let session_id = handle.session_id;
        if session_id == 0 {
            return format!("{name} has no session");
        }
        if let Some(mut s) = self.world.session(session_id).await {
            s.current_dream_id = None;
            s.is_sleeping = false;
            self.world.upsert_session(s).await;
        }
        format!("cleared dream state on {name}")
    }

    async fn handle_issue_chocobo(&self, args: &Args<'_>) -> String {
        // issuechocobo <appearance> <chocobo_name> <player_name>
        // `chocobo_name` is a single token to keep parsing simple;
        // multi-word player names can still have spaces in the tail.
        let appearance = match args.parse_u8(0) {
            Ok(a) => a,
            Err(e) => {
                return format!(
                    "usage: issuechocobo <appearance> <chocobo_name> <player_name> — {e}"
                );
            }
        };
        let Some(chocobo_name) = args.token(1) else {
            return "usage: issuechocobo <appearance> <chocobo_name> <player_name>".into();
        };
        let Some(player_name) = args.rest_joined(2) else {
            return "usage: issuechocobo <appearance> <chocobo_name> <player_name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&player_name).await else {
            return format!("unknown character: {player_name}");
        };
        if let Err(e) = self
            .db
            .issue_player_chocobo(chara_id, appearance, chocobo_name)
            .await
        {
            return format!("issuechocobo failed: {e}");
        }
        // If the character is online, mirror into CharaState so the
        // next snapshot reads are right without a re-login.
        if let Some(handle) = self.registry.get(chara_id).await {
            let mut c = handle.character.write().await;
            c.chara.has_chocobo = true;
            c.chara.chocobo_appearance = appearance;
            c.chara.chocobo_name = chocobo_name.to_string();
        }
        format!("issued chocobo (appearance={appearance}, name={chocobo_name}) to {player_name}")
    }

    async fn handle_rent_chocobo(&self, args: &Args<'_>) -> String {
        let minutes = match args.parse_u8(0) {
            Ok(m) => m,
            Err(e) => return format!("usage: rentchocobo <minutes> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: rentchocobo <minutes> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let now = common::utils::unix_timestamp() as u32;
        {
            let mut c = handle.character.write().await;
            c.chara.rental_expire_time = now + (minutes as u32 * 60);
            c.chara.rental_min_left = minutes;
            c.chara.mount_state = 1;
            c.base.current_main_state = crate::actor::MAIN_STATE_MOUNTED;
            c.chara.new_main_state = crate::actor::MAIN_STATE_MOUNTED;
        }
        format!(
            "rented chocobo for {name} ({minutes}m; expires at unix {})",
            now + (minutes as u32 * 60)
        )
    }

    async fn handle_dismount(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return "usage: dismount <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        {
            let mut c = handle.character.write().await;
            c.chara.mount_state = 0;
            c.chara.rental_expire_time = 0;
            c.chara.rental_min_left = 0;
            c.base.current_main_state = crate::actor::MAIN_STATE_PASSIVE;
            c.chara.new_main_state = crate::actor::MAIN_STATE_PASSIVE;
        }
        format!("dismounted {name}")
    }

    /// `warp <zone> <x> <y> <z> <name>` — instant zone-change for
    /// headless testing. Mirrors Meteor's `!warp` GM command
    /// (`Data/scripts/commands/gm/warp.lua`) but without a director
    /// chain: we just mutate the session's destination + current
    /// zone and ship a `DoZoneChange` LuaCommand-style payload. For
    /// the `AfterQuestWarpDirector` flow this works as a standalone
    /// warp without the director piggyback (quest scripts can still
    /// create the director separately).
    async fn handle_warp(&self, args: &Args<'_>) -> String {
        const USAGE: &str = "usage: warp <x> <y> <z> [name] | warp <zone> <x> <y> <z> [name] | \
                             warp <zone> <privateAreaName> <paLevel> <x> <y> <z> [name]";
        // Meteor's `warp.lua` dispatches on argc: exactly three numeric
        // args means "move within the current zone" (the
        // `DoPlayerMoveInZone` branch); four or more is the cross-zone
        // `DoZoneChange` form. The private-area form (arg 1 non-numeric)
        // routes the player into the named PrivateArea instance — the
        // test harness for quest destinations like
        // `warp 133 PrivateAreaMasterPast 2 -459.62 40 196.37 <name>`.
        let same_zone_form = args.len() == 3
            && args.parse_f32(0).is_ok()
            && args.parse_f32(1).is_ok()
            && args.parse_f32(2).is_ok();
        let private_area_form =
            args.len() >= 6 && args.parse_u32(0).is_ok() && args.parse_f32(1).is_err();
        let (explicit_zone, private_area, private_area_type, x, y, z, name) = if same_zone_form {
            (
                None,
                None,
                0u32,
                args.parse_f32(0).unwrap(),
                args.parse_f32(1).unwrap(),
                args.parse_f32(2).unwrap(),
                args.rest_joined(3),
            )
        } else if private_area_form {
            let zone_id = match args.parse_u32(0) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let pa_name = match args.rest().get(1) {
                Some(s) => s.to_string(),
                None => return USAGE.into(),
            };
            let pa_level = match args.parse_u32(2) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let x = match args.parse_f32(3) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let y = match args.parse_f32(4) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let z = match args.parse_f32(5) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            (
                Some(zone_id),
                Some(pa_name),
                pa_level,
                x,
                y,
                z,
                args.rest_joined(6),
            )
        } else {
            let zone_id = match args.parse_u32(0) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let x = match args.parse_f32(1) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let y = match args.parse_f32(2) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            let z = match args.parse_f32(3) {
                Ok(v) => v,
                Err(e) => return format!("{USAGE} — {e}"),
            };
            (Some(zone_id), None, 0u32, x, y, z, args.rest_joined(4))
        };
        let Some(name) = name else {
            return USAGE.into();
        };
        self.teleport(
            &name,
            explicit_zone,
            private_area,
            private_area_type,
            (x, y, z),
        )
        .await
    }

    /// Move `name` (online) to (x, y, z) in `explicit_zone` (None: their
    /// current zone), optionally into a private area: the same zone change a
    /// GM warp makes in retail (spawn type 2).
    #[allow(clippy::too_many_arguments)]
    /// The spawn type GM warps arrive with: 0, SPAWNTYPE_FADEIN, which keeps
    /// the screen black until the player is in. With Meteor's 2
    /// (SPAWNTYPE_WARP_DUTY) the client draws the new zone through the
    /// whole load from a placeholder camera at floor level, before the
    /// player exists, so walking meanwhile looked like a broken camera.
    const SPAWN_FADE_IN: u8 = 0;
    /// Same-zone warps: SPAWNTYPE 0x11, a quick fade with no loading screen.
    const SPAWN_QUICK_WARP: u16 = 0x11;
    /// The embedded actor id for that quick warp: 0xC0000000 (Kodama's
    /// "no object"). With 0xFFFFFFFF ("self") the client moved the player
    /// but left the camera at the old spot until the next step.
    const QUICK_WARP_TARGET: i32 = 0xC000_0000_u32 as i32;

    async fn teleport(
        &self,
        name: &str,
        explicit_zone: Option<u32>,
        private_area: Option<String>,
        private_area_type: u32,
        (x, y, z): (f32, f32, f32),
    ) -> String {
        let Some(chara_id) = self.lookup_character_id(name).await else {
            return format!("unknown character: {name}");
        };
        if explicit_zone.is_some_and(|z| z != crate::jail::get().zone)
            && let Ok(Some(_)) = self.db.jail_of_character(chara_id).await
        {
            return format!("{name} is in Mordion Gaol: !pardon them first");
        }
        if let Some(h) = self.registry.get(chara_id).await {
            let c = h.character.read().await;
            gm_tools::remember_spot(
                chara_id,
                c.base.zone_id,
                c.base.position_x,
                c.base.position_y,
                c.base.position_z,
            );
        }
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        // Persist destination + base position on CharaState so the
        // next zone-in bundle reads them.
        let rotation;
        let current_zone_id;
        let zone_id;
        let actor_id = handle.actor_id;
        let session_id = handle.session_id;
        {
            let mut c = handle.character.write().await;
            current_zone_id = c.base.zone_id;
            rotation = c.base.rotation;
            zone_id = explicit_zone.unwrap_or(current_zone_id);
            c.base.zone_id = zone_id;
            c.base.position_x = x;
            c.base.position_y = y;
            c.base.position_z = z;
        }
        if let Some(mut session) = self.world.session(session_id).await {
            session.destination_zone_id = zone_id;
            session.destination_x = x;
            session.destination_y = y;
            session.destination_z = z;
            session.destination_spawn_type = Self::SPAWN_FADE_IN;
            self.world.upsert_session(session).await;
        }
        // Same-zone warp: one SetActorPosition with spawn type 0x11
        // (QuickWarp: fade out, move, fade in with the camera behind the
        // player; no loading screen) and the embedded actor id 0xC0000000,
        // as Kodama's `!pos` sends it. Meteor's `DoPlayerMoveInZone` sent a
        // 0xE2 (0x10) signal first, then type 0x00 with id 0xFFFFFFFF: the
        // scene reloaded and the camera looked at the ceiling for ~5 s.
        if current_zone_id == zone_id {
            if let Some(client) = self.world.client(session_id).await {
                // The world-server relay drops subpackets whose target_id
                // is 0 (`world-server/src/server.rs`, zone-reply fan-out),
                // so stamp the destination session — verified via
                // packet logs: un-stamped 0xE2/0xCE reached the world and
                // were never forwarded to the client.
                let mut pkt = crate::packets::send::build_set_actor_position(
                    actor_id,
                    Self::QUICK_WARP_TARGET,
                    x,
                    y,
                    z,
                    rotation,
                    Self::SPAWN_QUICK_WARP,
                    false,
                );
                pkt.set_target_id(session_id);
                client.send_bytes(pkt.to_bytes()).await;
            }
        } else {
            // Cross-zone warp — the full `DoZoneChange` flow: actor
            // migration, 0x00E2 latch, and the zone-in bundle with the
            // retail keep-list cleanup. Same-region destinations get the
            // retail ~6 s deferred bundle (see `apply_do_zone_change`),
            // which also makes this command the repeatable harness for
            // exercising that path without replaying a quest flow.
            crate::runtime::quest_apply::apply_do_zone_change(
                actor_id,
                zone_id,
                private_area.clone(),
                private_area_type,
                Self::SPAWN_FADE_IN,
                x,
                y,
                z,
                rotation,
                &self.registry,
                &self.db,
                &self.world,
                Some(&self.lua),
            )
            .await;
        }
        format!("warped {name} to zone {zone_id} at ({x:.2}, {y:.2}, {z:.2})")
    }

    /// `zone <zone id or name> [name]`: to a zone's spawn point (or beside
    /// its aetheryte, or where its first NPC stands).
    async fn handle_zone(&self, args: &Args<'_>) -> String {
        const USAGE: &str = "usage: zone <zone id or name> [name]";
        if args.len() == 0 {
            return USAGE.into();
        }
        // the zone is the first token, or a quoted-free run of words up to a
        // name that is online: try the longest zone query first
        for split in (1..=args.len()).rev() {
            let query = args.rest()[..split].join(" ");
            let Ok(zones) = self.db.zones_matching(&query).await else {
                return "zone lookup failed".into();
            };
            if zones.is_empty() {
                continue;
            }
            let Some(name) = args.rest_joined(split) else {
                return if args.was_refused() {
                    String::new()
                } else {
                    USAGE.into()
                };
            };
            // an id, or one place name: several zones can share a name (two
            // "Limsa Lominsa" areas), so the first of them with a known spot
            let by_id = zones.iter().find(|(id, _)| id.to_string() == query);
            let same_place: Vec<&(u32, String)> = match by_id {
                Some(z) => vec![z],
                None => {
                    let bare = |t: &str| t.replace(['\'', '’'], "").to_lowercase();
                    let exact: Vec<_> = zones
                        .iter()
                        .filter(|(_, p)| bare(p) == bare(&query))
                        .collect();
                    if !exact.is_empty() {
                        exact
                    } else if zones.iter().all(|(_, p)| bare(p) == bare(&zones[0].1)) {
                        zones.iter().collect()
                    } else {
                        Vec::new()
                    }
                }
            };
            let mut chosen = None;
            for z in &same_place {
                if matches!(self.db.zone_landing(z.0).await, Ok(Some(_))) {
                    chosen = Some((*z).clone());
                    break;
                }
            }
            let (zone_id, place) = match chosen.or_else(|| same_place.first().map(|z| (*z).clone()))
            {
                Some(z) => z,
                None => {
                    let list: Vec<String> = zones
                        .iter()
                        .take(8)
                        .map(|(id, p)| format!("{id} {p}"))
                        .collect();
                    return format!(
                        "more than one zone matches \"{query}\": {}",
                        list.join(", ")
                    );
                }
            };
            return match self.db.zone_landing(zone_id).await {
                Ok(Some((x, y, z))) => {
                    let r = self
                        .teleport(&name, Some(zone_id), None, 0, (x, y, z))
                        .await;
                    if r.starts_with("warped") {
                        format!("{name} → {place} (zone {zone_id})")
                    } else {
                        r
                    }
                }
                Ok(None) => format!(
                    "no known spot in zone {zone_id} ({place}); use !warp {zone_id} <x> <y> <z>"
                ),
                Err(e) => format!("zone lookup failed: {e}"),
            };
        }
        // nothing matched: the closest place name, for a typo
        let typed = args.rest().join(" ");
        match self.db.zones_matching("").await {
            Ok(all) => match closest(
                &typed,
                all.iter().map(|(_, p)| p.as_str()).filter(|p| p.len() > 1),
            ) {
                Some(best) => format!("no zone matches \"{typed}\"; did you mean {best}?"),
                None => format!("no zone matches \"{typed}\""),
            },
            Err(_) => format!("no zone matches \"{typed}\""),
        }
    }

    /// `camp [camp name] [name]`: to an aetheryte camp or gate by name (or
    /// aetheryte id); with no name, the list.
    async fn handle_camp(&self, args: &Args<'_>) -> String {
        use crate::actor::aetheryte::{AETHERYTE_NAMES, named_matching};
        if args.len() == 0 {
            let camps: Vec<&str> = AETHERYTE_NAMES
                .iter()
                .map(|(_, n)| *n)
                .filter(|n| n.starts_with("Camp "))
                .collect();
            return format!(
                "camps: {} (and the aetheryte gates around them: !camp <part of a name>)",
                camps.join(", ")
            );
        }
        for split in (1..=args.len()).rev() {
            let query = args.rest()[..split].join(" ");
            let hits = named_matching(&query);
            if hits.is_empty() {
                continue;
            }
            if hits.len() > 1 {
                let list: Vec<&str> = hits.iter().take(8).map(|(_, n)| *n).collect();
                return format!("more than one matches \"{query}\": {}", list.join(", "));
            }
            let Some(name) = args.rest_joined(split) else {
                return if args.was_refused() {
                    String::new()
                } else {
                    "usage: camp <camp name> [name]".into()
                };
            };
            let (a, camp) = hits[0];
            let r = self
                .teleport(&name, Some(a.zone_id), None, 0, (a.x, a.y, a.z))
                .await;
            return if r.starts_with("warped") {
                format!("{name} → {camp}")
            } else {
                r
            };
        }
        let typed = args.rest().join(" ");
        match closest(&typed, AETHERYTE_NAMES.iter().map(|(_, n)| *n)) {
            Some(best) => format!("no camp or aetheryte matches \"{typed}\"; did you mean {best}?"),
            None => format!("no camp or aetheryte matches \"{typed}\" (!camp lists the camps)"),
        }
    }

    /// `pos [name]`: the zone and coordinates of `name` (default: you), to
    /// note a spot and come back with `warp`.
    async fn handle_pos(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: pos <name>".into()
            };
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let (zone_id, x, y, z, rot) = {
            let c = handle.character.read().await;
            (
                c.base.zone_id,
                c.base.position_x,
                c.base.position_y,
                c.base.position_z,
                c.base.rotation,
            )
        };
        let place = match self.db.zones_matching(&zone_id.to_string()).await {
            Ok(z) => z
                .into_iter()
                .find(|(id, _)| *id == zone_id)
                .map(|(_, p)| p)
                .unwrap_or_default(),
            Err(_) => String::new(),
        };
        format!(
            "{name}: zone {zone_id} {place} at {x:.2} {y:.2} {z:.2} facing {rot:.2} (!warp {zone_id} {x:.2} {y:.2} {z:.2})"
        )
    }

    /// `endevent [name]`: end whatever event (talk, cutscene, menu) holds
    /// `name`, as the script's own `player:EndEvent()` would, and drop any
    /// script paused waiting on it.
    async fn handle_endevent(&self, args: &Args<'_>) -> String {
        let Some(name) = args.rest_joined(0) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: endevent <name>".into()
            };
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let purged = self
            .lua
            .scheduler()
            .lock()
            .map(|mut s| s.purge_owner(handle.actor_id))
            .unwrap_or(0);
        let mut outbox = crate::event::outbox::EventOutbox::new();
        {
            let mut c = handle.character.write().await;
            c.event_session.end_event(handle.actor_id, &mut outbox);
        }
        for e in outbox.drain() {
            crate::event::dispatcher::dispatch_event_event(
                &e,
                &self.registry,
                &self.world,
                &self.db,
                Some(&self.lua),
            )
            .await;
        }
        tracing::info!(player = %name, purged, by = ?args.invoker, "event ended by command");
        format!("ended {name}'s event")
    }

    /// `setgm <level 0-4> <name>`: the GM level of `name`'s account. Nobody
    /// can grant a level above their own (the console can grant any).
    async fn handle_setgm(&self, args: &Args<'_>, invoker_level: Option<u8>) -> String {
        const USAGE: &str = "usage: setgm <level 0-4> <name> (0 player, 1 helper, 2 GM, 3 senior GM, 4 administrator)";
        let level = match args.parse_u8(0) {
            Ok(l) if l <= crate::command_permissions::ADMINISTRATOR => l,
            _ => return USAGE.into(),
        };
        if args.len() < 2 {
            return USAGE.into();
        }
        let name = args.rest()[1..].join(" ");
        if let Some(mine) = invoker_level
            && level > mine
        {
            return format!("you can't grant a level above your own ({mine})");
        }
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.set_gm_level_of_character(chara_id, level).await {
            Ok(true) => {
                tracing::info!(character = %name, level, by = ?args.invoker, "GM level set");
                format!(
                    "{name}'s account is now level {level} ({})",
                    crate::command_permissions::level_name(level)
                )
            }
            Ok(false) => format!("{name} has no account"),
            Err(e) => format!("couldn't set the level: {e}"),
        }
    }

    async fn handle_join_gc(&self, args: &Args<'_>) -> String {
        let gc = match args.parse_u8(0) {
            Ok(g) => g,
            Err(e) => return format!("usage: joingc <gc> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: joingc <gc> <name>".into();
        };
        if !crate::actor::gc::is_valid_gc(gc) {
            return format!("invalid gc id {gc} (expected 1/2/3 = Maelstrom/TwinAdder/Flames)");
        }
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        if let Err(e) = self.db.set_gc_current(chara_id, gc).await {
            return format!("joingc failed: {e}");
        }
        // Start at Recruit if they've never been promoted in this GC.
        // `load_player_character` returns `Result<Option<LoadedPlayer>>`
        // — flatten the Result → Option layer first.
        let existing = self
            .db
            .load_player_character(chara_id)
            .await
            .ok()
            .flatten()
            .map(|p| match gc {
                1 => p.gc_limsa_rank,
                2 => p.gc_gridania_rank,
                3 => p.gc_uldah_rank,
                _ => 0,
            })
            .unwrap_or(0);
        let rank = if existing == 0 {
            crate::actor::gc::RANK_RECRUIT
        } else {
            existing
        };
        if let Err(e) = self.db.set_gc_rank(chara_id, gc, rank).await {
            return format!("joingc: set_gc_rank failed: {e}");
        }
        if let Some(handle) = self.registry.get(chara_id).await {
            let mut c = handle.character.write().await;
            c.chara.gc_current = gc;
            match gc {
                1 => c.chara.gc_rank_limsa = rank,
                2 => c.chara.gc_rank_gridania = rank,
                3 => c.chara.gc_rank_uldah = rank,
                _ => {}
            }
        }
        format!("{name} joined GC {gc} at rank {rank}")
    }

    async fn handle_set_gc_rank(&self, args: &Args<'_>) -> String {
        let gc = match args.parse_u8(0) {
            Ok(g) => g,
            Err(e) => return format!("usage: setgcrank <gc> <rank> <name> — {e}"),
        };
        let rank = match args.parse_u8(1) {
            Ok(r) => r,
            Err(e) => return format!("usage: setgcrank <gc> <rank> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(2) else {
            return "usage: setgcrank <gc> <rank> <name>".into();
        };
        if !crate::actor::gc::is_valid_gc(gc) {
            return format!("invalid gc id {gc} (expected 1/2/3)");
        }
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.set_gc_rank(chara_id, gc, rank).await {
            Ok(()) => {
                if let Some(handle) = self.registry.get(chara_id).await {
                    let mut c = handle.character.write().await;
                    match gc {
                        1 => c.chara.gc_rank_limsa = rank,
                        2 => c.chara.gc_rank_gridania = rank,
                        3 => c.chara.gc_rank_uldah = rank,
                        _ => {}
                    }
                }
                format!("set {name}'s GC {gc} rank to {rank}")
            }
            Err(e) => format!("setgcrank failed: {e}"),
        }
    }

    async fn handle_add_gc_seals(&self, args: &Args<'_>) -> String {
        let gc = match args.parse_u8(0) {
            Ok(g) => g,
            Err(e) => return format!("usage: addgcseals <gc> <amount> <name> — {e}"),
        };
        let amount = match args.parse_i32(1) {
            Ok(a) => a,
            Err(e) => return format!("usage: addgcseals <gc> <amount> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(2) else {
            return "usage: addgcseals <gc> <amount> <name>".into();
        };
        if !crate::actor::gc::is_valid_gc(gc) {
            return format!("invalid gc id {gc} (expected 1/2/3)");
        }
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        match self.db.add_seals(chara_id, gc, amount).await {
            Ok(total) => format!("granted {amount} GC {gc} seals to {name} (total now {total})"),
            Err(e) => format!("addgcseals failed: {e}"),
        }
    }

    async fn handle_accrue_rest(&self, args: &Args<'_>) -> String {
        let minutes = match args.parse_i32(0) {
            Ok(m) => m,
            Err(e) => return format!("usage: accruerest <minutes> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: accruerest <minutes> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let current = self.db.get_rest_bonus_exp_rate(chara_id).await.unwrap_or(0);
        // 1.x rest bonus: +1% per minute at an inn, capped at +100%.
        // The cap is Meteor's observed max (`Player.restBonus = restBonus`
        // assignments never exceed 100 in the commit history). A
        // negative `minutes` argument decays the bonus.
        let new_total = (current.saturating_add(minutes)).clamp(0, 100);
        match self.db.set_rest_bonus_exp_rate(chara_id, new_total).await {
            Ok(()) => {
                format!(
                    "rest bonus for {name}: {current}% → {new_total}% ({:+} min)",
                    minutes
                )
            }
            Err(e) => format!("accruerest failed: {e}"),
        }
    }

    async fn lookup_character_id(&self, name: &str) -> Option<u32> {
        self.db.character_id_by_name(name).await.ok().flatten()
    }

    async fn resolve_live_target(&self, name: &str) -> TargetLookup {
        let Some(chara_id) = self.lookup_character_id(name).await else {
            return TargetLookup::Err(format!("unknown character: {name}"));
        };
        let Some(handle) = self.registry.by_session(chara_id).await else {
            return TargetLookup::Err(format!("{name} is not online"));
        };
        let Some(zone) = self.world.zone(handle.zone_id).await else {
            return TargetLookup::Err(format!("{name}'s zone {} not loaded", handle.zone_id));
        };
        TargetLookup::Ok {
            actor_id: handle.actor_id,
            zone,
        }
    }

    /// `talkto <actor_class_id> <name>` — synthesise an EventStart from
    /// the server side. Resolves the named player + an NPC with the
    /// given `actor_class_id` in the player's zone, then drives the
    /// same `chara.event_session.start_event(...)` → `EventOutbox` →
    /// `dispatch_event_event` pipeline that `handle_event_start` runs
    /// when the client sends a real EventStart packet. Exercises the
    /// full quest `onTalk` dispatch + NPC-script `onEventStarted` flow
    /// without the client needing to physically walk to the NPC +
    /// press the interact key — which has proven unreliable to drive
    /// through ffxiv-actor's synthesised CGEvents.
    async fn handle_talkto(&self, args: &Args<'_>) -> String {
        let actor_class_id = match args.parse_u32(0) {
            Ok(v) => v,
            Err(e) => return format!("usage: talkto <actor_class_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: talkto <actor_class_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(player_handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let zone_id = player_handle.zone_id;

        // Find the NPC by its actor_class_id in the same zone.
        let mut npc_handle = None;
        let actors = self.registry.actors_in_zone(zone_id).await;
        for h in actors {
            let matches = {
                let c = h.character.read().await;
                c.chara.actor_class_id == actor_class_id
            };
            if matches {
                npc_handle = Some(h);
                break;
            }
        }
        let Some(npc_handle) = npc_handle else {
            return format!("no NPC with actor_class_id={actor_class_id} in zone {zone_id}",);
        };
        let owner_actor_id = npc_handle.actor_id;
        let npc_name = {
            let c = npc_handle.character.read().await;
            c.base.actor_name.clone()
        };

        // Start the event + drain the outbox. Same shape as
        // `handle_event_start` in processor.rs.
        let mut outbox = crate::event::outbox::EventOutbox::new();
        {
            let mut chara = player_handle.character.write().await;
            chara.event_session.start_event(
                player_handle.actor_id,
                owner_actor_id,
                "talkDefault".to_string(),
                0, // event_type
                Vec::new(),
                &mut outbox,
            );
        }
        for e in outbox.drain() {
            crate::event::dispatcher::dispatch_event_event(
                &e,
                &self.registry,
                &self.world,
                &self.db,
                Some(&self.lua),
            )
            .await;
        }

        let active_quests: Vec<u32> = {
            let c = player_handle.character.read().await;
            c.quest_journal
                .slots
                .iter()
                .flatten()
                .map(|q| q.quest_id())
                .collect()
        };

        // Mirror `handle_event_start` in processor.rs: after the
        // EventStarted dispatch (which targets the NPC's class script),
        // also fire `onTalk` on every active quest the player holds. The
        // 1.x convention is that the quest script — not the NPC class
        // script — owns the per-NPC dialogue branches (`seq000_onTalk`,
        // etc. in `man0l0.lua`). Without this call, `talkto Rostnsthal`
        // dispatches into the NPC class default but never reaches the
        // quest's branch that fires `processTtrNomal003`.
        let npc_spec = {
            let c = npc_handle.character.read().await;
            crate::lua::LuaNpcSpec {
                actor_id: c.base.actor_id,
                name: c.base.actor_name.clone(),
                class_name: c.base.class_name.clone(),
                class_path: c.base.class_path.clone(),
                unique_id: String::new(),
                zone_id: c.base.zone_id,
                zone_name: String::new(),
                state: c.base.current_main_state,
                pos: (c.base.position_x, c.base.position_y, c.base.position_z),
                rotation: c.base.rotation,
                actor_class_id: c.chara.actor_class_id,
                quest_graphic: 0,
            }
        };
        for quest_id in &active_quests {
            crate::runtime::quest_apply::fire_quest_on_talk_via_command(
                &player_handle,
                *quest_id,
                npc_spec.clone(),
                &self.registry,
                &self.db,
                &self.world,
                Some(&self.lua),
            )
            .await;
        }

        format!(
            "talkto fired event on player {chara_id} → NPC {owner_actor_id} (class {actor_class_id}, \"{npc_name}\"), {} active quest(s) in journal",
            active_quests.len()
        )
    }

    /// `setseq <quest_id> <sequence> <name>` — force a quest's sequence
    /// to the given value. Useful for E2E driving past content-area
    /// transitions (combat zones, instanced dungeons) whose
    /// `CreateContentArea` Lua bindings aren't ported yet — set the
    /// sequence, warp the player to the next phase's location, and the
    /// `onStateChange` hook fires the per-sequence `SetENpc` setup so
    /// the target NPCs become interactive.
    async fn handle_setseq(&self, args: &Args<'_>) -> String {
        let quest_id = match args.parse_u32(0) {
            Ok(v) => v,
            Err(e) => return format!("usage: setseq <quest_id> <sequence> <name> — {e}"),
        };
        let sequence = match args.parse_u32(1) {
            Ok(v) => v,
            Err(e) => return format!("usage: setseq <quest_id> <sequence> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(2) else {
            return "usage: setseq <quest_id> <sequence> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        if self.registry.get(chara_id).await.is_none() {
            return format!("{name} is not online");
        }
        crate::runtime::quest_apply::apply_quest_start_sequence(
            chara_id,
            quest_id,
            sequence,
            &self.registry,
            &self.db,
            &self.world,
            Some(&self.lua),
        )
        .await;
        format!("setseq quest {quest_id} → sequence {sequence} on {name} (actor {chara_id})")
    }

    /// `pushtrigger <actor_class_id> <name>` — server-side analog of
    /// `talkto`, but fires `onPush` rather than `onTalk`. Same NPC
    /// resolution, but routes through `fire_quest_on_push_via_command`
    /// so quest scripts that gate progression on a proximity push
    /// (door triggers, exit cones, the EXIT_TRIGGER on the opening
    /// quest's boat) can be advanced without the player having to walk
    /// into a possibly-untraversable mesh through synthesised input.
    async fn handle_pushtrigger(&self, args: &Args<'_>) -> String {
        let actor_class_id = match args.parse_u32(0) {
            Ok(v) => v,
            Err(e) => return format!("usage: pushtrigger <actor_class_id> <name> — {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: pushtrigger <actor_class_id> <name>".into();
        };
        let Some(chara_id) = self.lookup_character_id(&name).await else {
            return format!("unknown character: {name}");
        };
        let Some(player_handle) = self.registry.get(chara_id).await else {
            return format!("{name} is not online");
        };
        let zone_id = player_handle.zone_id;

        let mut npc_handle = None;
        for h in self.registry.actors_in_zone(zone_id).await {
            let matches = {
                let c = h.character.read().await;
                c.chara.actor_class_id == actor_class_id
            };
            if matches {
                npc_handle = Some(h);
                break;
            }
        }
        let Some(npc_handle) = npc_handle else {
            return format!("no NPC with actor_class_id={actor_class_id} in zone {zone_id}",);
        };

        let active_quests: Vec<u32> = {
            let c = player_handle.character.read().await;
            c.quest_journal
                .slots
                .iter()
                .flatten()
                .map(|q| q.quest_id())
                .collect()
        };

        let npc_spec = {
            let c = npc_handle.character.read().await;
            crate::lua::LuaNpcSpec {
                actor_id: c.base.actor_id,
                name: c.base.actor_name.clone(),
                class_name: c.base.class_name.clone(),
                class_path: c.base.class_path.clone(),
                unique_id: String::new(),
                zone_id: c.base.zone_id,
                zone_name: String::new(),
                state: c.base.current_main_state,
                pos: (c.base.position_x, c.base.position_y, c.base.position_z),
                rotation: c.base.rotation,
                actor_class_id: c.chara.actor_class_id,
                quest_graphic: 0,
            }
        };
        for quest_id in &active_quests {
            crate::runtime::quest_apply::fire_quest_on_push_via_command(
                &player_handle,
                *quest_id,
                npc_spec.clone(),
                &self.registry,
                &self.db,
                &self.world,
                Some(&self.lua),
            )
            .await;
        }

        format!(
            "pushtrigger fired onPush on player {chara_id} → NPC class {actor_class_id}, {} active quest(s)",
            active_quests.len()
        )
    }

    /// `speed <multiplier> [name]` - scale the target player's movement
    /// speed to `multiplier`x normal. `<= 0` resets to 1x; capped at
    /// 10x. Multiplier semantics are ours - the upstream GM script
    /// (`Data/scripts/commands/gm/speed.lua`) takes raw stop/walk/run
    /// bands and applies no clamp - but both funnel into the same
    /// 0x00D0 SetActorSpeed packet (C# `Actor.ChangeSpeed`).
    async fn handle_speed(&self, args: &Args<'_>) -> String {
        let requested = match args.parse_f32(0) {
            Ok(v) => v,
            Err(e) => return format!("usage: speed <multiplier> [name] - {e}"),
        };
        let Some(name) = args.rest_joined(1) else {
            return "usage: speed <multiplier> [name]".into();
        };
        match self.resolve_live_target(&name).await {
            TargetLookup::Ok { actor_id, zone } => {
                use crate::runtime::dispatcher::MovementSpeedOutcome;
                let outcome = crate::runtime::dispatcher::apply_movement_speed(
                    actor_id,
                    requested,
                    &self.registry,
                    &self.world,
                    &zone,
                )
                .await;
                match outcome {
                    MovementSpeedOutcome::Applied { multiplier } if requested > multiplier => {
                        format!(
                            "set {name}'s movement speed to {multiplier}x - capped from {requested}"
                        )
                    }
                    MovementSpeedOutcome::Applied { multiplier } => {
                        format!("set {name}'s movement speed to {multiplier}x")
                    }
                    MovementSpeedOutcome::Reset => {
                        format!("reset {name}'s movement speed to 1x")
                    }
                    MovementSpeedOutcome::UnknownPlayer => {
                        format!("{name} dropped from registry mid-call")
                    }
                }
            }
            TargetLookup::Err(e) => e,
        }
    }
}

enum TargetLookup {
    Ok {
        actor_id: u32,
        zone: Arc<tokio::sync::RwLock<crate::zone::zone::Zone>>,
    },
    Err(String),
}

/// The name in `names` closest to `typed` (edit distance, ignoring case,
/// apostrophes and a leading "camp "), if it's close enough to be a typo:
/// two letters wrong (a swapped pair is two), or a third of a long name.
fn closest<'n>(typed: &str, names: impl Iterator<Item = &'n str>) -> Option<&'n str> {
    let norm = |t: &str| {
        t.to_lowercase()
            .replace(['\'', '’'], "")
            .trim_start_matches("camp ")
            .to_string()
    };
    let t = norm(typed);
    if t.is_empty() {
        return None;
    }
    let dist = |a: &str, b: &str| {
        let b: Vec<char> = b.chars().collect();
        let mut row: Vec<usize> = (0..=b.len()).collect();
        for (i, ca) in a.chars().enumerate() {
            let mut prev = row[0];
            row[0] = i + 1;
            for j in 0..b.len() {
                let cur = row[j + 1];
                row[j + 1] = (prev + usize::from(ca != b[j]))
                    .min(row[j] + 1)
                    .min(cur + 1);
                prev = cur;
            }
        }
        row[b.len()]
    };
    names
        .map(|n| (dist(&t, &norm(n)), n))
        .min_by_key(|(d, _)| *d)
        .filter(|(d, _)| *d <= (t.chars().count() / 3).max(2))
        .map(|(_, n)| n)
}

/// Tiny typed-arg shim. The C# `CommandProcessor` punts arg parsing to
/// each command's own handler — we keep the same per-command contract
/// but centralise the "index + parse + error message" plumbing so each
/// handler is a couple of lines.
struct Args<'a> {
    tokens: Vec<&'a str>,
    /// Character name of the chat sender, when the command came in via
    /// the `!command` chat path. `None` on the stdin console, where
    /// there is no implicit target and `<name>` stays mandatory.
    invoker: Option<&'a str>,
    /// The invoker's GM level is below `target_others`: a name other than
    /// their own is refused (`rest_joined` returns None and sets `refused`).
    self_only: bool,
    refused: std::sync::atomic::AtomicBool,
}

impl<'a> Args<'a> {
    fn new(tokens: Vec<&'a str>, invoker: Option<&'a str>) -> Self {
        Self {
            tokens,
            invoker,
            self_only: false,
            refused: std::sync::atomic::AtomicBool::new(false),
        }
    }

    fn self_only(mut self, yes: bool) -> Self {
        self.self_only = yes;
        self
    }

    fn was_refused(&self) -> bool {
        self.refused.load(std::sync::atomic::Ordering::Relaxed)
    }

    fn len(&self) -> usize {
        self.tokens.len()
    }

    fn rest(&self) -> &[&'a str] {
        &self.tokens
    }

    fn parse_i32(&self, idx: usize) -> std::result::Result<i32, String> {
        let Some(raw) = self.tokens.get(idx) else {
            return Err(format!("missing arg {idx}"));
        };
        raw.parse::<i32>()
            .map_err(|_| format!("arg {idx} '{raw}' is not an integer"))
    }

    fn parse_u8(&self, idx: usize) -> std::result::Result<u8, String> {
        let Some(raw) = self.tokens.get(idx) else {
            return Err(format!("missing arg {idx}"));
        };
        raw.parse::<u8>()
            .map_err(|_| format!("arg {idx} '{raw}' is not a byte"))
    }

    fn parse_f32(&self, idx: usize) -> std::result::Result<f32, String> {
        let Some(raw) = self.tokens.get(idx) else {
            return Err(format!("missing arg {idx}"));
        };
        raw.parse::<f32>()
            .map_err(|_| format!("arg {idx} '{raw}' is not a float"))
    }

    fn parse_u32(&self, idx: usize) -> std::result::Result<u32, String> {
        let Some(raw) = self.tokens.get(idx) else {
            return Err(format!("missing arg {idx}"));
        };
        raw.parse::<u32>()
            .map_err(|_| format!("arg {idx} '{raw}' is not an unsigned int"))
    }

    /// Single token at position `idx`, or `None` if out of range.
    fn token(&self, idx: usize) -> Option<&'a str> {
        self.tokens.get(idx).copied()
    }

    /// Concatenate tokens `[from..]` into a single space-separated string
    /// for name-like trailing args ("First Last"). When no tokens exist
    /// at or after `from`, falls back to the chat invoker's name (self-
    /// targeting), or `None` on the console path.
    fn rest_joined(&self, from: usize) -> Option<String> {
        if from >= self.tokens.len() {
            return self.invoker.map(str::to_string);
        }
        let name = self.tokens[from..].join(" ");
        if self.self_only
            && !self
                .invoker
                .is_some_and(|me| me.eq_ignore_ascii_case(&name))
        {
            self.refused
                .store(true, std::sync::atomic::Ordering::Relaxed);
            return None;
        }
        Some(name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use common::db::ConnCallExt;
    use common::sql::named_params;

    fn tempdb() -> String {
        common::test_db::fresh_blocking()
    }

    async fn fixture() -> (CommandProcessor, Arc<Database>) {
        let world = Arc::new(WorldManager::new());
        let registry = Arc::new(ActorRegistry::new());
        let db = Arc::new(Database::open(tempdb()).await.unwrap());
        let lua = Arc::new(LuaEngine::new("/nonexistent"));
        let cmd = CommandProcessor::new(world, registry, db.clone(), lua);
        (cmd, db)
    }

    #[tokio::test]
    async fn help_lists_commands() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("help").await.unwrap();
        assert!(out.contains("revive"));
        assert!(out.contains("givegil"));
        assert!(out.contains("reload"));
        assert!(out.contains("speed <multiplier>"));
    }

    #[tokio::test]
    async fn reload_returns_cache_count() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("reload").await.unwrap();
        assert!(out.starts_with("reloaded: "));
    }

    #[tokio::test]
    async fn unknown_command_is_reported() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("frobnicate 1 2 3").await.unwrap();
        assert!(out.starts_with("unknown command: frobnicate"));
        assert!(out.contains("\"1\""));
    }

    #[tokio::test]
    async fn revive_without_name_reports_usage() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("revive").await.unwrap();
        assert_eq!(out, "usage: revive <name>");
    }

    #[tokio::test]
    async fn givegil_parses_and_writes_db() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (42, 0, 0, 0, 'Rich Frog')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        let out = cmd.run("givegil 5000 Rich Frog").await.unwrap();
        assert!(out.contains("gave 5000 gil"), "got {out}");
        let total: i32 = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    r"SELECT si.quantity
                      FROM characters_inventory ci
                      INNER JOIN server_items si ON ci.serverItemId = si.id
                      WHERE ci.characterId = 42 AND si.itemId = 1000001",
                    [],
                    |r| r.get(0),
                )
            })
            .await
            .unwrap();
        assert_eq!(total, 5000);
        let _ = named_params! { ":x": 0 };
    }

    #[tokio::test]
    async fn givegil_non_numeric_quantity_errors() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("givegil hello Somebody").await.unwrap();
        assert!(out.contains("not an integer"), "got {out}");
    }

    #[tokio::test]
    async fn settp_checks_its_arguments() {
        let (cmd, _db) = fixture().await;
        assert_eq!(
            cmd.run("settp").await.unwrap(),
            "usage: settp <tp 0-3000> <name>"
        );
        assert_eq!(
            cmd.run("settp lots Somebody").await.unwrap(),
            "usage: settp <tp 0-3000> <name>"
        );
        assert_eq!(
            cmd.run("settp 3000").await.unwrap(),
            "usage: settp <tp 0-3000> <name>"
        );
        assert_eq!(
            cmd.run("settp 3000 Nobody").await.unwrap(),
            "unknown character: Nobody"
        );
    }

    #[tokio::test]
    async fn revive_unknown_name_reports_unknown() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("revive Nobody").await.unwrap();
        assert_eq!(out, "unknown character: Nobody");
    }

    #[test]
    fn below_target_others_only_yourself() {
        let args = Args::new(vec!["2", "Other", "Player"], Some("First Last")).self_only(true);
        assert_eq!(args.rest_joined(1), None);
        assert!(args.was_refused());
        let args = Args::new(vec!["2", "first", "last"], Some("First Last")).self_only(true);
        assert_eq!(args.rest_joined(1).as_deref(), Some("first last"));
        let args = Args::new(vec!["2"], Some("First Last")).self_only(true);
        assert_eq!(args.rest_joined(1).as_deref(), Some("First Last"));
        assert!(!args.was_refused());
    }

    #[test]
    fn help_lists_only_what_the_level_may_use() {
        // without settings every command needs administrator
        let player = CommandProcessor::help(Some(0), false);
        assert!(player.starts_with("your level: player (0)") && !player.contains("givegil"));
        let console = CommandProcessor::help(None, false);
        assert!(console.contains("givegil") && console.contains("zone <zone id or name>"));
    }

    #[test]
    fn closest_name_catches_typos() {
        let names = ["Gridania", "Ul'dah", "Central Shroud", "Camp Bearded Rock"];
        assert_eq!(closest("gridnia", names.iter().copied()), Some("Gridania"));
        assert_eq!(closest("uldha", names.iter().copied()), Some("Ul'dah"));
        assert_eq!(
            closest("bearded rok", names.iter().copied()),
            Some("Camp Bearded Rock")
        );
        assert_eq!(closest("xyz", names.iter().copied()), None);
    }

    #[test]
    fn camps_match_by_part_of_their_name() {
        use crate::actor::aetheryte::named_matching;
        let hits = named_matching("bearded rock");
        assert_eq!(hits.len(), 1);
        assert_eq!((hits[0].1, hits[0].0.zone_id), ("Camp Bearded Rock", 128));
        assert_eq!(named_matching("Camp Black Brush")[0].1, "Camp Black Brush");
        assert_eq!(
            named_matching("revenants toll")[0].1,
            "Camp Revenant's Toll"
        );
        assert!(named_matching("zzz").is_empty());
        assert!(named_matching("lake").len() > 1);
        assert_eq!(named_matching("bent*")[0].1, "Camp Bentbranch");
    }

    #[test]
    fn rest_joined_falls_back_to_invoker() {
        let args = Args::new(vec!["100"], Some("First Last"));
        assert_eq!(args.rest_joined(1).as_deref(), Some("First Last"));
        // Explicit trailing name wins over the invoker.
        let args = Args::new(vec!["100", "Real", "Target"], Some("First Last"));
        assert_eq!(args.rest_joined(1).as_deref(), Some("Real Target"));
        // Console path (no invoker) keeps <name> mandatory.
        let args = Args::new(vec!["100"], None);
        assert_eq!(args.rest_joined(1), None);
    }

    #[tokio::test]
    async fn chat_invoker_is_implicit_target() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (43, 0, 0, 0, 'Implicit Hero')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // `!givegil 250` from chat — no trailing name, sender is target.
        let out = cmd
            .run_as("givegil 250", Some("Implicit Hero"))
            .await
            .unwrap();
        assert!(out.contains("gave 250 gil to Implicit Hero"), "got {out}");
    }

    #[tokio::test]
    async fn explicit_name_overrides_chat_invoker() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (44, 0, 0, 0, 'Real Target')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        let out = cmd
            .run_as("givegil 100 Real Target", Some("Somebody Else"))
            .await
            .unwrap();
        assert!(out.contains("gave 100 gil to Real Target"), "got {out}");
    }

    #[tokio::test]
    async fn warp_same_zone_form_targets_invoker() {
        let (cmd, _db) = fixture().await;
        // Three numeric args = Meteor's same-zone move. The invoker is
        // the implicit target; unknown name proves the parse + target
        // resolution path ran (no live registry in the fixture).
        let out = cmd.run_as("warp 1 2 3", Some("Nobody")).await.unwrap();
        assert_eq!(out, "unknown character: Nobody");
    }

    #[tokio::test]
    async fn warp_same_zone_form_on_console_requires_name() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("warp 1 2 3").await.unwrap();
        assert!(out.starts_with("usage: warp"), "got {out}");
    }

    #[tokio::test]
    async fn warp_offline_target_is_reported() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (45, 0, 0, 0, 'Warp Target')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // Cross-zone form, name omitted → invoker; character exists in
        // the DB but has no live ActorHandle.
        let out = cmd
            .run_as("warp 166 0 0 0", Some("Warp Target"))
            .await
            .unwrap();
        assert_eq!(out, "Warp Target is not online");
    }

    #[tokio::test]
    async fn speed_without_multiplier_reports_usage() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("speed").await.unwrap();
        assert!(out.starts_with("usage: speed <multiplier> [name]"));
    }

    #[tokio::test]
    async fn speed_non_numeric_multiplier_reports_usage() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("speed fast").await.unwrap();
        assert!(out.contains("is not a float"));
    }

    #[tokio::test]
    async fn speed_offline_target_is_reported() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (46, 0, 0, 0, 'Speed Target')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // Name omitted → invoker; character exists in the DB but has
        // no live ActorHandle.
        let out = cmd.run_as("speed 2.5", Some("Speed Target")).await.unwrap();
        assert_eq!(out, "Speed Target is not online");
    }

    #[tokio::test]
    async fn joingc_and_setgcrank_and_addgcseals_round_trip() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (300, 0, 0, 0, 'Company Hopeful')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // joingc 1 — enlists in Maelstrom at Recruit (127).
        let out = cmd.run("joingc 1 Company Hopeful").await.unwrap();
        assert!(out.contains("joined GC 1"), "got {out}");
        let (gc, l): (i64, i64) = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    r"SELECT gcCurrent, gcLimsaRank FROM characters WHERE id = 300",
                    [],
                    |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)?)),
                )
            })
            .await
            .unwrap();
        assert_eq!((gc, l), (1, 127));

        // setgcrank 1 15 — promote to Private First Class.
        let out2 = cmd.run("setgcrank 1 15 Company Hopeful").await.unwrap();
        assert!(out2.contains("rank to 15"), "got {out2}");
        let l2: i64 = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    r"SELECT gcLimsaRank FROM characters WHERE id = 300",
                    [],
                    |r| r.get::<_, i64>(0),
                )
            })
            .await
            .unwrap();
        assert_eq!(l2, 15);

        // addgcseals 1 2500 — seal upsert.
        let out3 = cmd.run("addgcseals 1 2500 Company Hopeful").await.unwrap();
        assert!(out3.contains("total now 2500"), "got {out3}");
        // Second deposit merges.
        let out4 = cmd.run("addgcseals 1 500 Company Hopeful").await.unwrap();
        assert!(out4.contains("total now 3000"), "got {out4}");

        // Invalid gc id reports.
        let out5 = cmd.run("joingc 9 Company Hopeful").await.unwrap();
        assert!(out5.contains("invalid gc id 9"), "got {out5}");
    }

    #[tokio::test]
    async fn issuechocobo_persists_and_is_idempotent() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (200, 0, 0, 0, 'Chocobo Get')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // issuechocobo <appearance> <chocobo_name> <player_name>
        let out = cmd.run("issuechocobo 5 Boco Chocobo Get").await.unwrap();
        assert!(out.contains("issued chocobo"), "got {out}");
        // DB persistence:
        let (has, app, name): (i64, i64, String) = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    r"SELECT hasChocobo, chocoboAppearance, chocoboName
                      FROM characters_chocobo WHERE characterId = 200",
                    [],
                    |r| {
                        Ok((
                            r.get::<_, i64>(0)?,
                            r.get::<_, i64>(1)?,
                            r.get::<_, String>(2)?,
                        ))
                    },
                )
            })
            .await
            .unwrap();
        assert_eq!(has, 1);
        assert_eq!(app, 5);
        assert_eq!(name, "Boco");

        // Re-issue overwrites (upsert semantics — Meteor's C# uses
        // ON CONFLICT DO UPDATE).
        let out2 = cmd
            .run("issuechocobo 9 Pecopeco Chocobo Get")
            .await
            .unwrap();
        assert!(out2.contains("issued chocobo"), "got {out2}");
        let (app2, name2): (i64, String) = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    r"SELECT chocoboAppearance, chocoboName
                      FROM characters_chocobo WHERE characterId = 200",
                    [],
                    |r| Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?)),
                )
            })
            .await
            .unwrap();
        assert_eq!(app2, 9);
        assert_eq!(name2, "Pecopeco");
    }

    #[tokio::test]
    async fn accruerest_rolls_up_and_caps_at_hundred() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (99, 0, 0, 0, 'Inn Sleeper')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        let out = cmd.run("accruerest 30 Inn Sleeper").await.unwrap();
        assert!(out.contains("0% → 30%"), "got {out}");
        let out2 = cmd.run("accruerest 90 Inn Sleeper").await.unwrap();
        assert!(out2.contains("30% → 100%"), "got {out2}");
        // Decay below zero clamps to 0.
        let out3 = cmd.run("accruerest -500 Inn Sleeper").await.unwrap();
        assert!(out3.contains("100% → 0%"), "got {out3}");
        // Final DB value is 0.
        assert_eq!(db.get_rest_bonus_exp_rate(99).await.unwrap(), 0);
    }

    #[tokio::test]
    async fn hire_and_dismiss_retainer_round_trip() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (88, 0, 0, 0, 'Retainer Hirer')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // Before hiring: listretainers shows empty.
        let out = cmd.run("listretainers Retainer Hirer").await.unwrap();
        assert!(out.contains("owns no retainers"), "got {out}");

        // Hire Wienta (seed id 1001).
        let hired = cmd.run("hireretainer 1001 Retainer Hirer").await.unwrap();
        assert!(hired.contains("hired retainer 1001"), "got {hired}");

        // Idempotent: second hire is a no-op.
        let again = cmd.run("hireretainer 1001 Retainer Hirer").await.unwrap();
        assert!(again.contains("already owns"), "got {again}");

        // List now shows one row.
        let listed = cmd.run("listretainers Retainer Hirer").await.unwrap();
        assert!(listed.contains("id=1001"), "got {listed}");
        assert!(listed.contains("name=Wienta"), "got {listed}");

        // Dismiss succeeds, second dismiss is a no-op.
        let dismissed = cmd
            .run("dismissretainer 1001 Retainer Hirer")
            .await
            .unwrap();
        assert!(dismissed.contains("dismissed"), "got {dismissed}");
        let again = cmd
            .run("dismissretainer 1001 Retainer Hirer")
            .await
            .unwrap();
        assert!(again.contains("does not own"), "got {again}");
    }

    /// `sethome` persists to DB even when the player is offline. The
    /// follow-up `home` command short-circuits at "not online" — but
    /// that's all we can prove without standing up a Zone + ActorHandle
    /// in a CommandProcessor fixture (the rest of the dispatcher is
    /// covered by `home_point_revive_tests` directly against
    /// `apply_home_point_revive`).
    #[tokio::test]
    async fn sethome_persists_aetheryte_id_for_offline_character() {
        let (cmd, db) = fixture().await;
        db.conn_for_test()
            .call_db(|c| {
                c.execute(
                    r"INSERT INTO characters (id, userId, slot, serverId, name)
                      VALUES (12, 0, 0, 0, 'Limsa Resident')",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();

        // Set homepoint to Limsa CAP (1280001).
        let out = cmd.run("sethome 1280001 Limsa Resident").await.unwrap();
        assert!(out.contains("homepoint to 1280001"), "got {out}");
        // Coords resolved from the Rust-side aetheryte table.
        assert!(out.contains("zone 230"), "got {out}");

        // DB row updated.
        let stored: u32 = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row("SELECT homepoint FROM characters WHERE id = 12", [], |r| {
                    r.get(0)
                })
            })
            .await
            .unwrap();
        assert_eq!(stored, 1_280_001);

        // Unknown aetheryte id still persists but the response notes it.
        let out2 = cmd.run("sethome 999999 Limsa Resident").await.unwrap();
        assert!(out2.contains("homepoint to 999999"), "got {out2}");
        assert!(out2.contains("unknown aetheryte"), "got {out2}");
    }

    #[tokio::test]
    async fn home_without_name_reports_usage() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("home").await.unwrap();
        assert_eq!(out, "usage: home <name>");
    }

    #[tokio::test]
    async fn home_unknown_player_reports_unknown() {
        let (cmd, _db) = fixture().await;
        let out = cmd.run("home Phantom").await.unwrap();
        assert!(out.contains("unknown character"), "got {out}");
    }
}
