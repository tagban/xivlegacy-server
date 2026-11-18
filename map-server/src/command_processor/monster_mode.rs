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

//! `!monstermode`: Monster Mode. Stage 0 (spike) only swaps the
//! player's body: with a monster targeted, the player takes that
//! monster's model and appearance slots (0x00D6); a second
//! `!monstermode` puts the player's own appearance back. Nothing is
//! written to the database.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use super::{Args, CommandProcessor};
use crate::runtime::actor_registry::ActorKindTag;

/// The player's own (model id, appearance slots) while transformed.
type Saved = (u32, [u32; 28]);

fn saved_bodies() -> &'static Mutex<HashMap<u32, Saved>> {
    static SAVED: OnceLock<Mutex<HashMap<u32, Saved>>> = OnceLock::new();
    SAVED.get_or_init(|| Mutex::new(HashMap::new()))
}

impl CommandProcessor {
    pub(super) async fn handle_monstermode(&self, args: &Args<'_>) -> String {
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some(handle) = self.registry.get(me).await else {
            return "you are not in the world".into();
        };
        if args.rest().first() == Some(&"anim") {
            return self.monster_anim(me, args).await;
        }
        let own = saved_bodies().lock().ok().and_then(|mut m| m.remove(&me));
        if let Some((model_id, slots)) = own {
            {
                let mut c = handle.character.write().await;
                c.chara.model_id = model_id;
                c.chara.appearance_ids = slots;
            }
            self.send_body(me, model_id, slots).await;
            return "Monster Mode off: you are yourself again.".into();
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
                Err(_) => return "target a monster, then !monstermode".into(),
            },
        };
        let Some(mob) = self.registry.get(target).await else {
            return "your target is gone".into();
        };
        if mob.kind != ActorKindTag::BattleNpc {
            return "that is not a monster".into();
        }
        let (model_id, slots) = {
            let c = mob.character.read().await;
            (c.chara.model_id, c.chara.appearance_ids)
        };
        let label = self.actor_label(target).await;
        {
            let mut c = handle.character.write().await;
            if let Ok(mut m) = saved_bodies().lock() {
                m.insert(me, (c.chara.model_id, c.chara.appearance_ids));
            }
            c.chara.model_id = model_id;
            c.chara.appearance_ids = slots;
        }
        self.send_body(me, model_id, slots).await;
        tracing::info!(player = me, target, model_id, ?slots, "monstermode body swap");
        format!("Monster Mode: you take the body of {label} (model {model_id}). !monstermode again to return.")
    }

    /// Spike: `monstermode anim <command id>` plays that command's
    /// battle animation on the player's own body, aimed at the target.
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

    /// 0x00D6 to the player and everyone around.
    async fn send_body(&self, actor_id: u32, model_id: u32, slots: [u32; 28]) {
        let bytes =
            crate::packets::send::actor::build_set_actor_appearance(actor_id, model_id, &slots)
                .to_bytes();
        crate::runtime::dispatcher::send_to_self_if_player(
            &self.registry,
            &self.world,
            actor_id,
            bytes.clone(),
        )
        .await;
        crate::runtime::dispatcher::broadcast_to_neighbours(
            &self.world,
            &self.registry,
            actor_id,
            bytes,
        )
        .await;
    }
}
