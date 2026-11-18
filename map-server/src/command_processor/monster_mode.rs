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

//! `!monstermode`: Monster Mode. With a monster targeted, the player
//! possesses it: the monster vanishes and the player takes its body,
//! level, HP, MP and stats (see `runtime::monster_mode`). `!monstermode`
//! again lets go (after a 4-second countdown in combat). Testers can
//! name a monster class instead of targeting: `!monstermode <class id>`
//! takes the nearest one.
//!
//! Testers mark the move they just used (or one they name) for the move
//! tracker: `!monstermode ok [move]`, `!monstermode bad [move] [note]`.
//! The marks go to `log_monster_mode` with every move used.

use std::time::Duration;

use super::{Args, CommandProcessor};
use crate::runtime::actor_registry::ActorKindTag;
use crate::runtime::monster_mode as mm;

/// How far away a monster can be possessed.
const POSSESS_RANGE: f32 = 30.0;
/// Seconds to let go while in combat (FFXI's Relinquish countdown).
const RELINQUISH_SECS: u64 = 4;

impl CommandProcessor {
    pub(super) async fn handle_monstermode(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some(handle) = self.registry.get(me).await else {
            return "you are not in the world".into();
        };
        match args.rest().first() {
            Some(&"anim") => return self.monster_anim(me, args).await,
            Some(&"ok") => return self.monster_verdict(me, true, args).await,
            Some(&"bad") => return self.monster_verdict(me, false, args).await,
            _ => {}
        }
        if let Some((_, name)) = mm::possessed_mob(me) {
            let engaged = handle.character.read().await.ai_container.is_engaged();
            if !engaged {
                mm::release(me, "off").await;
                mm::refresh_client(&self.registry, &self.world, me).await;
                return format!("You let go of {name} and are yourself again.");
            }
            self.relinquish_later(me);
            return format!("Letting go of {name} in {RELINQUISH_SECS}...");
        }

        // Where may it happen: the open world, not a duty or private area.
        let (zone_id, alive, in_content) = {
            let c = handle.character.read().await;
            (
                c.base.zone_id,
                c.is_alive(),
                !c.chara.content_area_name.is_empty(),
            )
        };
        if !alive {
            return "you can't do that while knocked out".into();
        }
        let in_private = self
            .world
            .session(handle.session_id)
            .await
            .is_some_and(|s| s.current_private_area_name.is_some_and(|n| !n.is_empty()));
        let zone_name = match self.world.zone(zone_id).await {
            Some(z) => z.read().await.core.zone_name.clone(),
            None => String::new(),
        };
        if in_content || in_private || !mm::is_field_zone(&zone_name) {
            return "Monster Mode works only out in the field.".into();
        }

        let target = match args.rest().first() {
            // `!monstermode <class id>`: the nearest monster of that class.
            Some(word) => match word.parse::<u32>() {
                Ok(class_id) => match self.nearest_monster_of(me, class_id).await {
                    Some(t) => t,
                    None => return format!("no monster of class {class_id} nearby"),
                },
                Err(_) => return "usage: monstermode [actor class id]".into(),
            },
            None => match self.my_target(me).await {
                Ok(t) => t,
                Err(_) => return "Target a monster, then !monstermode.".into(),
            },
        };
        let Some(mob) = self.registry.get(target).await else {
            return "your target is gone".into();
        };
        if mob.kind != ActorKindTag::BattleNpc
            || target & crate::world_manager::CONTENT_ACTOR_BAND_BIT != 0
        {
            return "That is not a monster you can become.".into();
        }
        let far = {
            let (a, b) = (
                handle.character.read().await.base.position(),
                mob.character.read().await.base.position(),
            );
            (a.x - b.x).hypot(a.z - b.z) > POSSESS_RANGE
        };
        if far {
            return "That monster is too far away.".into();
        }
        let label = monster_name(&self.actor_label(target).await);
        if let Err(e) = mm::possess(
            me,
            handle.character.clone(),
            target,
            mob.character.clone(),
            label.clone(),
        )
        .await
        {
            return e;
        }
        self.vanish_monster(target, zone_id).await;
        mm::refresh_client(&self.registry, &self.world, me).await;
        let (level, hp) = {
            let c = handle.character.read().await;
            (c.chara.level, c.chara.hp)
        };
        tracing::info!(player = me, target, level, hp, "monstermode: possessed");
        let moves = mm::moves_of(me).len();
        let moves = match moves {
            0 => "no moves".to_string(),
            1 => "1 move on your hotbar".to_string(),
            n => format!("{n} moves on your hotbar"),
        };
        format!(
            "Monster Mode: you are {label} (level {level}, {hp} HP, {moves}). !monstermode again to let go."
        )
    }

    /// Take a possessed monster off every client, and stop anyone who
    /// was fighting it (as a death would, without the death).
    async fn vanish_monster(&self, mob_id: u32, zone_id: u32) {
        for other in self.registry.actors_in_zone(zone_id).await {
            if other.actor_id == mob_id {
                continue;
            }
            let mut oc = other.character.write().await;
            let targeting = oc
                .ai_container
                .current_state()
                .is_some_and(|s| s.target_actor_id == mob_id);
            oc.hate.clear_hate(Some(mob_id));
            if targeting {
                oc.ai_container.clear_states();
            }
        }
        self.world.forget_actor_for_all_sessions(mob_id).await;
    }

    /// Relinquish: in combat, letting go takes a short countdown.
    fn relinquish_later(&self, me: u32) {
        let (registry, world, db) = (self.registry.clone(), self.world.clone(), self.db.clone());
        tokio::spawn(async move {
            let tell = |msg: String| {
                let (registry, world, db) = (registry.clone(), world.clone(), db.clone());
                async move {
                    use crate::social::{
                        ChatKind, SocialEvent, SocialOutbox, dispatch_social_event,
                    };
                    let mut ob = SocialOutbox::new();
                    ob.push(SocialEvent::ChatSystemToPlayer {
                        target_actor_id: me,
                        kind: ChatKind::System,
                        message: msg,
                    });
                    for e in ob.drain() {
                        dispatch_social_event(&e, &registry, &world, &db).await;
                    }
                }
            };
            for n in (1..RELINQUISH_SECS).rev() {
                tokio::time::sleep(Duration::from_secs(1)).await;
                if !mm::is_transformed(me) {
                    return;
                }
                tell(format!("{n}...")).await;
            }
            tokio::time::sleep(Duration::from_secs(1)).await;
            if mm::release(me, "off").await.is_some() {
                mm::refresh_client(&registry, &world, me).await;
                tell("You are yourself again.".into()).await;
            }
        });
    }

    /// Spike: `monstermode anim <command id>` plays that command's
    /// battle animation on the player's own body, aimed at the target.
    /// A tester's mark on a monster move: the one named (an id, or a move
    /// name of the body they have now) or else the last one they used.
    async fn monster_verdict(&self, me: u32, ok: bool, args: &Args<'_>) -> String {
        let words: Vec<&str> = args.rest().iter().skip(1).copied().collect();
        let names: Vec<(u16, String)> = {
            let Ok(cmds) = self.lua.catalogs().battle_commands.read() else {
                return "the command catalog is busy, try again".into();
            };
            mm::moves_of(me)
                .into_iter()
                .filter_map(|id| cmds.get(&id).map(|gd| (id, gd.to_battle_command().name)))
                .collect()
        };
        let (named, note) = pick_move(&words, &names);
        let Some((class_id, level, move_id)) = mm::verdict_move(me, named) else {
            return "Use a monster move first, or name one: !monstermode ok <move id>".into();
        };
        let zone_id = match self.registry.get(me).await {
            Some(h) => h.zone_id,
            None => 0,
        };
        mm::log_verdict(me, class_id, level, move_id, ok, &note, zone_id);
        let name = self
            .lua
            .catalogs()
            .battle_commands
            .read()
            .ok()
            .and_then(|c| {
                c.get(&move_id)
                    .map(|gd| move_title(&gd.to_battle_command().name))
            })
            .unwrap_or_else(|| "move".into());
        let mark = if ok { "works" } else { "is broken" };
        if note.is_empty() {
            format!("Noted: {name} ({move_id}) {mark}.")
        } else {
            format!("Noted: {name} ({move_id}) {mark}: {note}")
        }
    }

    async fn monster_anim(&self, me: u32, args: &Args<'_>) -> String {
        let Some(id) = args.rest().get(1).and_then(|t| t.parse::<u16>().ok()) else {
            return "usage: monstermode anim <command id>".into();
        };
        let (anim, name) = {
            let Ok(cmds) = self.lua.catalogs().battle_commands.read() else {
                return "the command catalog is busy, try again".into();
            };
            match cmds.get(&id) {
                Some(gd) => (gd.battle_animation, gd.to_battle_command().name),
                None => return format!("no battle command {id}"),
            }
        };
        let target = self.my_target(me).await.unwrap_or(me);
        let row = crate::packets::send::actor_battle::CommandResult {
            target_id: target,
            hit_num: 1,
            sub_command: 0,
            hit_effect: 0,
            mitigated_amount: 0,
            amount: 0,
            command_type: 0,
            animation_id: anim,
            worldmaster_text_id: 0,
            param: 0,
            action_property: 0,
        };
        let bytes =
            crate::packets::send::actor_battle::build_command_result_x01(me, anim, id, &row)
                .to_bytes();
        crate::runtime::dispatcher::send_to_self_if_player(
            &self.registry,
            &self.world,
            me,
            bytes.clone(),
        )
        .await;
        crate::runtime::dispatcher::broadcast_to_neighbours(&self.world, &self.registry, me, bytes)
            .await;
        format!("played {name} ({id}) animation 0x{anim:08X}")
    }

    /// The nearest living monster of `class_id` around `me`.
    async fn nearest_monster_of(&self, me: u32, class_id: u32) -> Option<u32> {
        let handle = self.registry.get(me).await?;
        let pos = handle.character.read().await.base.position();
        let zone_arc = self.world.zone(handle.zone_id).await?;
        let mut near: Vec<(f32, u32)> = {
            let zone = zone_arc.read().await;
            zone.core
                .actors_around(me, 50.0)
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
            if let Some(h) = self.registry.get(id).await
                && h.character.read().await.chara.actor_class_id == class_id
            {
                return Some(id);
            }
        }
        None
    }
}

/// "LemmingStandard (actor 0x44038000)" -> "LemmingStandard".
fn monster_name(label: &str) -> String {
    label
        .split(" (actor")
        .next()
        .unwrap_or(label)
        .trim()
        .to_string()
}

/// A move's name for chat: `frenetic_flurry` -> `Frenetic Flurry`.
fn move_title(raw: &str) -> String {
    raw.split('_')
        .filter(|w| !w.is_empty())
        .map(|w| {
            let mut c = w.chars();
            c.next()
                .map(|f| f.to_uppercase().chain(c).collect::<String>())
                .unwrap_or_default()
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// Split a verdict's words into the move they name and the note. A move
/// is named by its id, or by its name (spaces or underscores, any case)
/// among `moves`; whatever follows is the note.
fn pick_move(words: &[&str], moves: &[(u16, String)]) -> (Option<u16>, String) {
    if let Some(id) = words.first().and_then(|w| w.parse::<u16>().ok()) {
        return (Some(id), words[1..].join(" "));
    }
    for take in (1..=words.len()).rev() {
        let wanted = words[..take].join("_").to_ascii_lowercase();
        if let Some((id, _)) = moves.iter().find(|(_, n)| n.to_ascii_lowercase() == wanted) {
            return (Some(*id), words[take..].join(" "));
        }
    }
    (None, words.join(" "))
}

#[cfg(test)]
mod verdict_tests {
    use super::{move_title, pick_move};

    #[test]
    fn move_titles_read_as_words() {
        assert_eq!(move_title("frenetic_flurry"), "Frenetic Flurry");
        assert_eq!(move_title("romp"), "Romp");
    }

    #[test]
    fn a_verdict_names_a_move_by_id_or_name() {
        let moves = vec![
            (23122, "frenetic_flurry".to_string()),
            (23123, "romp".to_string()),
        ];
        assert_eq!(
            pick_move(&["23123", "no", "anim"], &moves),
            (Some(23123), "no anim".into())
        );
        assert_eq!(
            pick_move(&["Frenetic", "Flurry", "too", "weak"], &moves),
            (Some(23122), "too weak".into())
        );
        assert_eq!(pick_move(&["romp"], &moves), (Some(23123), String::new()));
        assert_eq!(
            pick_move(&["no", "damage", "number"], &moves),
            (None, "no damage number".into())
        );
        assert_eq!(pick_move(&[], &moves), (None, String::new()));
    }
}
