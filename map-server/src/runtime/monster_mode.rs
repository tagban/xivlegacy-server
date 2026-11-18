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

//! Monster Mode: a player possesses the monster they target (the idea of
//! FFXI's Monstrosity). The monster vanishes and the player plays it:
//! its body, level, HP, MP and stats.
//!
//! The player's own body is kept here, in memory only. Nothing about the
//! monster body is ever written to the database: every exit puts the
//! player's own body back first (toggle, defeat, zone change, logout),
//! and a server crash simply loses the in-memory monster, leaving the
//! saved character as it was before the possession.
//!
//! While transformed a player earns no EXP, seals, leve or quest credit,
//! monsters leave them alone until they attack (Gestation), and they
//! cannot change gear or class.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};

use tokio::sync::RwLock;

use crate::actor::modifier::ModifierMap;
use crate::actor::{CharaState, Character};
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// What the player's own body was when they took a monster's.
#[derive(Debug, Clone)]
pub struct OwnBody {
    pub model_id: u32,
    pub appearance_ids: [u32; 28],
    pub hp: i16,
    pub max_hp: i16,
    pub mp: i16,
    pub max_mp: i16,
    pub tp: u16,
    pub level: i16,
    pub mods: ModifierMap,
    pub stats: [i16; 36],
    pub hotbar: Vec<crate::gamedata::HotbarEntry>,
}

impl OwnBody {
    pub fn take(c: &CharaState) -> Self {
        Self {
            model_id: c.model_id,
            appearance_ids: c.appearance_ids,
            hp: c.hp,
            max_hp: c.max_hp,
            mp: c.mp,
            max_mp: c.max_mp,
            tp: c.tp,
            level: c.level,
            mods: c.mods.clone(),
            stats: c.stats,
            hotbar: c.hotbar.clone(),
        }
    }

    pub fn put(&self, c: &mut CharaState) {
        c.model_id = self.model_id;
        c.appearance_ids = self.appearance_ids;
        c.hp = self.hp;
        c.max_hp = self.max_hp;
        c.mp = self.mp;
        c.max_mp = self.max_mp;
        c.tp = self.tp;
        c.level = self.level;
        c.mods = self.mods.clone();
        c.stats = self.stats;
        c.hotbar = self.hotbar.clone();
    }
}

/// Put the monster's body, level, pools and stats on the player.
/// TP starts at zero, as it does for a fresh monster.
pub fn wear_monster(player: &mut CharaState, mob: &CharaState) {
    player.model_id = mob.model_id;
    player.appearance_ids = mob.appearance_ids;
    player.level = mob.level.max(1);
    player.max_hp = mob.max_hp.max(1);
    player.hp = mob.hp.clamp(1, player.max_hp);
    player.max_mp = mob.max_mp.max(0);
    player.mp = mob.mp.clamp(0, player.max_mp);
    player.tp = 0;
    player.mods = mob.mods.clone();
    player.stats = mob.stats;
}

/// TP a monster move costs a player in Monster Mode: monsters use their
/// moves at 1000 TP.
pub const MOVE_TP: i16 = 1000;

/// The monster's moves and spells, in list order, for the hotbar.
pub fn monster_moves(mob: &Character) -> Vec<u16> {
    let Some(ctrl) = mob.ai_container.controller.as_ref() else {
        return Vec::new();
    };
    best_tiers(
        ctrl.battle
            .skills
            .iter()
            .chain(ctrl.battle.spells.iter())
            .map(|c| (c.id, c.name.as_str())),
    )
}

/// One hotbar slot per move: a list can hold several tiers of one move
/// (the same name, unlocked at higher levels, later in the list); keep
/// the last, strongest one in the first one's place.
pub fn best_tiers<'a>(moves: impl Iterator<Item = (u16, &'a str)>) -> Vec<u16> {
    let mut out: Vec<(u16, &str)> = Vec::new();
    for (id, name) in moves {
        match out
            .iter_mut()
            .find(|(i, n)| *i == id || (!name.is_empty() && *n == name))
        {
            Some(slot) => *slot = (id, name),
            None => out.push((id, name)),
        }
    }
    out.truncate(crate::runtime::quest_apply::HOTBAR_SLOTS as usize);
    out.into_iter().map(|(id, _)| id).collect()
}

/// The hotbar of a player in Monster Mode: the monster's moves from
/// slot 1 on, nothing else.
pub fn monster_hotbar(moves: &[u16]) -> Vec<crate::gamedata::HotbarEntry> {
    moves
        .iter()
        .enumerate()
        .map(|(slot, id)| crate::gamedata::HotbarEntry {
            hotbar_slot: slot as u16,
            command_id: u32::from(*id),
            recast_time: 0,
        })
        .collect()
}

/// The TP this command costs the player, if it is one of their monster's
/// moves (at least [`MOVE_TP`]).
pub fn move_tp_cost(player_id: u32, command_id: u16, listed_cost: i16) -> Option<i16> {
    possessions()
        .get(&player_id)
        .filter(|p| p.moves.contains(&command_id))
        .map(|_| listed_cost.max(MOVE_TP))
}

/// The monster moves the player holds (for tests and the reply line).
pub fn moves_of(player_id: u32) -> Vec<u16> {
    possessions()
        .get(&player_id)
        .map(|p| p.moves.clone())
        .unwrap_or_default()
}

/// One player's possession.
pub struct Possession {
    pub mob_id: u32,
    pub mob_name: String,
    pub own: OwnBody,
    /// The monster's moves, on the player's hotbar.
    pub moves: Vec<u16>,
    player: Arc<RwLock<Character>>,
    mob: Arc<RwLock<Character>>,
}

/// player id -> possession.
fn possessions() -> MutexGuard<'static, HashMap<u32, Possession>> {
    static MAP: OnceLock<Mutex<HashMap<u32, Possession>>> = OnceLock::new();
    MAP.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// Possessed monsters, hidden from clients until they respawn.
/// `true` while a player still holds the body (no respawn yet).
fn vanished() -> MutexGuard<'static, HashMap<u32, bool>> {
    static MAP: OnceLock<Mutex<HashMap<u32, bool>>> = OnceLock::new();
    MAP.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// Monsters a player fought while transformed: monster id -> players.
/// Finishing one of them after letting go earns nothing, so a strong
/// monster body can't soften a fight for the player's own EXP. Cleared
/// when the monster dies or respawns.
fn fought() -> MutexGuard<'static, HashMap<u32, std::collections::HashSet<u32>>> {
    static MAP: OnceLock<Mutex<HashMap<u32, std::collections::HashSet<u32>>>> = OnceLock::new();
    MAP.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// Did this player fight this monster while transformed?
pub fn fought_as_monster(player_id: u32, mob_id: u32) -> bool {
    fought()
        .get(&mob_id)
        .is_some_and(|s| s.contains(&player_id))
}

/// No kill rewards for this player and monster: a transformed player's
/// kill, or a monster they fought while transformed.
pub fn no_rewards(player_id: u32, mob_id: u32) -> bool {
    is_transformed(player_id) || fought_as_monster(player_id, mob_id)
}

/// The monster died or respawned: forget who fought it.
pub fn forget_fights(mob_id: u32) {
    fought().remove(&mob_id);
}

/// Is this player in Monster Mode?
pub fn is_transformed(player_id: u32) -> bool {
    possessions().contains_key(&player_id)
}

/// The monster this player holds, if any.
pub fn possessed_mob(player_id: u32) -> Option<(u32, String)> {
    possessions()
        .get(&player_id)
        .map(|p| (p.mob_id, p.mob_name.clone()))
}

/// Gestation: monsters don't go for a transformed player on sight. They
/// still fight back once the player attacks them.
pub fn ignored_by_monsters(player_id: u32) -> bool {
    is_transformed(player_id)
}

/// Keep this actor off clients (a possessed monster's body).
pub fn is_hidden(actor_id: u32) -> bool {
    vanished().contains_key(&actor_id)
}

/// May this dead monster respawn? Not while a player holds it.
pub fn may_respawn(actor_id: u32) -> bool {
    vanished().get(&actor_id) != Some(&true)
}

/// The ticker respawned this monster: show it to clients again.
pub fn on_respawn(actor_id: u32) {
    vanished().remove(&actor_id);
    forget_fights(actor_id);
}

/// Monster Mode is for the open world: field zones only (`sea0Field01`,
/// not the instanced `sea0Field01a` copies, towns, dungeons or inns).
pub fn is_field_zone(zone_name: &str) -> bool {
    let b = zone_name.as_bytes();
    b.len() == 11
        && b[3] == b'0'
        && &zone_name[4..9] == "Field"
        && b[9..].iter().all(u8::is_ascii_digit)
}

/// Take the monster's body. The monster is quietly marked dead (no
/// death animation, no rewards) and held: it doesn't respawn until the
/// player lets go. The caller hides it from clients.
pub async fn possess(
    player_id: u32,
    player: Arc<RwLock<Character>>,
    mob_id: u32,
    mob: Arc<RwLock<Character>>,
    mob_name: String,
) -> Result<(), String> {
    if is_transformed(player_id) {
        return Err("you are already in Monster Mode".into());
    }
    if is_hidden(mob_id) {
        return Err("someone else is that monster".into());
    }
    {
        let mut p = player.write().await;
        let mut m = mob.write().await;
        if m.base.current_main_state == crate::actor::MAIN_STATE_DEAD || m.chara.hp <= 0 {
            return Err("that monster is dead".into());
        }
        let own = OwnBody::take(&p.chara);
        wear_monster(&mut p.chara, &m.chara);
        let moves = monster_moves(&m);
        p.chara.hotbar = monster_hotbar(&moves);
        m.chara.hp = 0;
        m.base.current_main_state = crate::actor::MAIN_STATE_DEAD;
        m.chara.new_main_state = crate::actor::MAIN_STATE_DEAD;
        m.chara.time_of_death_utc = common::utils::unix_timestamp() as u32;
        m.ai_container.clear_states();
        m.hate.clear_hate(None);
        drop(m);
        drop(p);
        vanished().insert(mob_id, true);
        possessions().insert(
            player_id,
            Possession {
                mob_id,
                mob_name,
                own,
                moves,
                player,
                mob,
            },
        );
    }
    Ok(())
}

/// Give the player their own body back, in memory. Safe to call on any
/// exit and when the player isn't transformed (returns `None`). The
/// monster is let go and respawns on the next ticker pass.
pub async fn release(player_id: u32) -> Option<Possession> {
    let p = possessions().remove(&player_id)?;
    {
        let mut c = p.player.write().await;
        // Whoever the monster body was fighting stays off the reward list.
        let mut foes: Vec<u32> = c.hate.entries().map(|e| e.actor_id).collect();
        if let Some(s) = c.ai_container.current_state() {
            foes.push(s.target_actor_id);
        }
        {
            let mut f = fought();
            for foe in foes {
                if foe != 0 && foe != player_id && foe != crate::actor::INVALID_ACTORID {
                    f.entry(foe).or_default().insert(player_id);
                }
            }
        }
        p.own.put(&mut c.chara);
    }
    {
        let mut m = p.mob.write().await;
        // Backdate the death so the ticker respawns it now.
        m.chara.time_of_death_utc = (common::utils::unix_timestamp() as u32)
            .saturating_sub(crate::runtime::ticker::BNPC_DEFAULT_RESPAWN_SECS)
            .max(1);
    }
    if let Some(held) = vanished().get_mut(&p.mob_id) {
        *held = false;
    }
    tracing::info!(
        player = player_id,
        mob = p.mob_id,
        "monstermode: own body back"
    );
    Some(p)
}

/// Players whose Monster Mode ended in a zone change: the client keeps
/// drawing its own monster body through the zone-in, so it is redrawn
/// once the new zone has loaded.
fn redraw_after_zone_in() -> MutexGuard<'static, std::collections::HashSet<u32>> {
    static SET: OnceLock<Mutex<std::collections::HashSet<u32>>> = OnceLock::new();
    SET.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// A zone change ends Monster Mode (own body back in memory, and the
/// client redrawn after zone-in).
pub async fn release_for_zone_change(player_id: u32) {
    if release(player_id).await.is_some() {
        redraw_after_zone_in().insert(player_id);
    }
}

/// Zone-in finished: redraw the player's own body if a zone change
/// ended their Monster Mode.
pub async fn after_zone_in(registry: &ActorRegistry, world: &WorldManager, player_id: u32) {
    if redraw_after_zone_in().remove(&player_id) {
        refresh_client(registry, world, player_id).await;
    }
}

/// Send the player's current body to them and everyone around: model and
/// appearance (0x00D6), HP/MP/TP, and the level on the nameplate.
pub async fn refresh_client(registry: &ActorRegistry, world: &WorldManager, player_id: u32) {
    use crate::runtime::dispatcher::{broadcast_to_neighbours, send_to_self_if_player};
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    let (model_id, slots, hp, max_hp, class, level) = {
        let c = handle.character.read().await;
        (
            c.chara.model_id,
            c.chara.appearance_ids,
            c.chara.hp.max(0) as u16,
            c.chara.max_hp.max(0) as u16,
            c.chara.class.max(0) as u8,
            c.chara.level.max(1) as u16,
        )
    };
    let mut packets = vec![
        crate::packets::send::actor::build_set_actor_appearance(player_id, model_id, &slots)
            .to_bytes(),
    ];
    for sub in crate::packets::send::actor::build_player_state_at_quickly_for_all(
        player_id, hp, max_hp, class, level,
    ) {
        packets.push(sub.to_bytes());
    }
    for bytes in packets {
        send_to_self_if_player(registry, world, player_id, bytes.clone()).await;
        broadcast_to_neighbours(world, registry, player_id, bytes).await;
    }
    crate::runtime::dispatcher::sync_pools_after_tick(registry, world, player_id).await;
    // The hotbar: the monster's moves, or the player's own commands back.
    for slot in 0..crate::runtime::quest_apply::HOTBAR_SLOTS {
        crate::runtime::quest_apply::send_hotbar_slot_update(
            player_id, slot, registry, world, None,
        )
        .await;
    }
}

/// The transformed player's monster body was defeated: they stand up in
/// their own body, with the HP and MP they had before.
pub async fn on_defeat(
    player_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    zone: &Arc<RwLock<crate::zone::zone::Zone>>,
) {
    if !is_transformed(player_id) {
        return;
    }
    crate::runtime::dispatcher::apply_revive(player_id, registry, world, zone).await;
    if release(player_id).await.is_some() {
        refresh_client(registry, world, player_id).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_slot_per_move_strongest_tier() {
        let moves = [
            (23121, "quickchant"),
            (23122, "frenetic_flurry"),
            (23168, "quickchant"),
            (23125, "forbidden_magicks"),
            (23172, "quickchant"),
            (23177, "forbidden_magicks"),
        ];
        assert_eq!(best_tiers(moves.into_iter()), vec![23172, 23122, 23177]);
    }

    #[test]
    fn fighting_as_a_monster_bars_rewards_until_respawn() {
        fought().entry(910_001).or_default().insert(910_002);
        assert!(no_rewards(910_002, 910_001));
        assert!(!no_rewards(910_003, 910_001));
        on_respawn(910_001);
        assert!(!no_rewards(910_002, 910_001));
    }

    #[test]
    fn field_zones_only() {
        assert!(is_field_zone("sea0Field01"));
        assert!(is_field_zone("fst0Field05"));
        assert!(is_field_zone("roc0Field03"));
        assert!(!is_field_zone("sea0Field01a"));
        assert!(!is_field_zone("sea0Town01"));
        assert!(!is_field_zone("fst0Dungeon01"));
        assert!(!is_field_zone("wil0Battle01"));
        assert!(!is_field_zone("prv0Inn01"));
        assert!(!is_field_zone(""));
    }

    fn chara(model: u32, hp: i16, max_hp: i16, level: i16) -> CharaState {
        let mut c = Character::new(1).chara;
        c.model_id = model;
        c.hp = hp;
        c.max_hp = max_hp;
        c.level = level;
        c.tp = 1500;
        c
    }

    #[test]
    fn wearing_and_restoring_round_trips() {
        let mut me = chara(1, 300, 320, 20);
        me.appearance_ids[3] = 77;
        me.mods
            .set(crate::actor::modifier::Modifier::Strength, 42.0);
        let mob = chara(10502, 90, 120, 5);
        let own = OwnBody::take(&me);
        wear_monster(&mut me, &mob);
        assert_eq!(me.model_id, 10502);
        assert_eq!((me.hp, me.max_hp, me.level, me.tp), (90, 120, 5, 0));
        assert_eq!(me.mods.get(crate::actor::modifier::Modifier::Strength), 0.0);
        own.put(&mut me);
        assert_eq!(
            (me.model_id, me.hp, me.max_hp, me.level, me.tp),
            (1, 300, 320, 20, 1500)
        );
        assert_eq!(me.appearance_ids[3], 77);
        assert_eq!(
            me.mods.get(crate::actor::modifier::Modifier::Strength),
            42.0
        );
    }

    #[tokio::test]
    async fn possess_and_release() {
        let player = Arc::new(RwLock::new(Character::new(900_001)));
        let mob = Arc::new(RwLock::new(Character::new(900_002)));
        {
            let mut p = player.write().await;
            p.chara = chara(1, 300, 320, 20);
            let mut m = mob.write().await;
            m.chara = chara(10502, 90, 120, 5);
        }
        possess(900_001, player.clone(), 900_002, mob.clone(), "rat".into())
            .await
            .unwrap();
        assert!(is_transformed(900_001));
        assert!(is_hidden(900_002));
        assert!(!may_respawn(900_002));
        assert_eq!(player.read().await.chara.model_id, 10502);
        assert_eq!(
            mob.read().await.base.current_main_state,
            crate::actor::MAIN_STATE_DEAD
        );
        // A second possession of the same monster is refused.
        let other = Arc::new(RwLock::new(Character::new(900_003)));
        assert!(
            possess(900_003, other, 900_002, mob.clone(), "rat".into())
                .await
                .is_err()
        );

        let back = release(900_001).await.expect("was transformed");
        assert_eq!(back.mob_id, 900_002);
        assert!(!is_transformed(900_001));
        assert!(release(900_001).await.is_none());
        let c = player.read().await;
        assert_eq!((c.chara.model_id, c.chara.hp, c.chara.level), (1, 300, 20));
        // Let go: hidden until the ticker respawns it, which it may now do.
        assert!(is_hidden(900_002));
        assert!(may_respawn(900_002));
        on_respawn(900_002);
        assert!(!is_hidden(900_002));
    }
}
