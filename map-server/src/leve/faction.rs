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

//! Faction leves (ids below the regional range): the levemete's faction
//! menus (Brotherhood of the Broken Blade, Azeyma's Shields, the Horn and
//! Hand) and the credits they cost.
//!
//! The client stores nothing: the levemete prints the totals the server
//! passes, and a faction leve's card shows its cost from the leve sheet
//! (`factionCreditRequired`). Accepting one spends the credits; the leve
//! then runs as a battle leve ([`crate::leve::battle`]) from its camp.

use std::collections::HashMap;
use std::sync::Arc;

use crate::database::Database;
use crate::gamedata::GuildleveGamedata;
use crate::lua::LuaEngine;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// Most credits a character holds with one faction (the client's text:
/// "up to 1,000 credits").
pub const CAP: u16 = 1_000;

/// Credits a completed regional leve gives its sponsoring faction (the
/// user's call, 2026-11-13). The client's text says a faction whose
/// standing in the area is low gives more; standings aren't kept, so it is
/// always this.
pub const CREDITS_PER_LEVE: i32 = 10;

/// Which faction sponsors the regional leves of each city's region
/// (`GuildleveGamedata::location`): (city, faction, why). No source names
/// a regional leve's sponsor, so (the user's call, 2026-11-13) every
/// regional leve of a region goes to one faction. Change it here.
const SPONSOR_BY_CITY: &[(u8, u8, &str)] = &[
    // Limsa Lominsa, La Noscea: the Broken Blade's vigilantes against the
    // Sahagin, Kobolds and pirates (its first operations run from Skull
    // Valley and Bloodshore).
    (1, 1, "La Noscea: Brotherhood of the Broken Blade"),
    // Gridania, the Black Shroud: the Horn and Hand's merchants.
    (2, 3, "the Black Shroud: the Horn and Hand"),
    // Ul'dah, Thanalan: Azeyma's Shields, named for Ul'dah's patron.
    (3, 2, "Thanalan: Azeyma's Shields"),
];

/// The faction (1 Broken Blade, 2 Azeyma's Shields, 3 Horn and Hand) that
/// sponsors regional leve `gd`, or `None` for any other leve.
pub fn sponsor_of(gd: &GuildleveGamedata) -> Option<u8> {
    if !crate::leve::battle::is_regional(gd.id) {
        return None;
    }
    SPONSOR_BY_CITY
        .iter()
        .find(|(city, _, _)| *city == gd.location)
        .map(|&(_, faction, _)| faction)
}

/// Cards in one faction menu page.
const CARDS: usize = 8;

/// The faction (1 Broken Blade, 2 Azeyma's Shields, 3 Horn and Hand) a
/// leve belongs to, from its issuing authority.
pub fn faction_of(gd: &GuildleveGamedata) -> Option<u8> {
    match gd.authority {
        40019 => Some(1),
        40020 => Some(2),
        40021 => Some(3),
        _ => None,
    }
}

/// A faction leve id (`1001..`, below the regional leves).
pub fn is_faction_leve(gl_id: u32) -> bool {
    (1_001..10_801).contains(&gl_id)
}

/// The faction leves the levemete lists for `faction` at level `level`
/// (the band picked in the menu: 20, 30, 40): those the battle runtime
/// can run, at most 8, in id order.
pub fn offers(catalog: &HashMap<u32, GuildleveGamedata>, faction: u8, level: u32) -> Vec<u32> {
    let mut ids: Vec<u32> = catalog
        .values()
        .filter(|g| {
            is_faction_leve(g.id)
                && faction_of(g) == Some(faction)
                && u32::from(g.level) == level
                && crate::leve::battle::is_supported(g)
        })
        .map(|g| g.id)
        .collect();
    ids.sort_unstable();
    ids.truncate(CARDS);
    ids
}

/// `credits` changed by `delta`, kept within 0..=[`CAP`]. `None` when it
/// would go below zero (not enough credits to spend).
pub fn apply(credits: u16, delta: i32) -> Option<u16> {
    let n = i32::from(credits) + delta;
    if n < 0 {
        return None;
    }
    Some(n.min(i32::from(CAP)) as u16)
}

/// Change the player's credits with `faction` by `delta` and store them.
/// The new total, or `None` when spending more than they hold (nothing
/// changes then).
pub async fn add_credits(
    player_id: u32,
    faction: u8,
    delta: i32,
    registry: &ActorRegistry,
    db: &Database,
) -> Option<u16> {
    if !(1..=3).contains(&faction) {
        return None;
    }
    let handle = registry.get(player_id).await?;
    let total = {
        let mut c = handle.character.write().await;
        let slot = &mut c.chara.faction_credits[usize::from(faction - 1)];
        let total = apply(*slot, delta)?;
        *slot = total;
        total
    };
    if let Err(e) = db.save_faction_credits(player_id, faction, total).await {
        tracing::warn!(player = player_id, faction, error = %e, "faction credits: save failed");
    }
    tracing::info!(player = player_id, faction, delta, total, "faction credits");
    Some(total)
}

/// Accept faction leve `gl_id`: spend its cost and put it in a leve slot.
/// False (and nothing spent) when the player lacks the credits or has no
/// free slot.
pub async fn accept(
    player_id: u32,
    gl_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
) -> bool {
    let Some(gd) = crate::leve::battle::gamedata(lua, gl_id) else {
        return false;
    };
    let Some(faction) = faction_of(&gd).filter(|_| is_faction_leve(gl_id)) else {
        return false;
    };
    let cost = gd.faction_credit_required as i32;
    if add_credits(player_id, faction, -cost, registry, db)
        .await
        .is_none()
    {
        tracing::info!(
            player = player_id,
            gl_id,
            cost,
            "faction leve: not enough credits"
        );
        return false;
    }
    if crate::leve::battle::add(player_id, gl_id, registry, world, db).await {
        return true;
    }
    // no free slot (or already held): give the credits back
    add_credits(player_id, faction, cost, registry, db).await;
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_region_sponsors_its_regional_leves() {
        let mut gd = leve(10_801, 40001, 20);
        for (city, faction) in [(1, 1), (2, 3), (3, 2)] {
            gd.location = city;
            assert_eq!(sponsor_of(&gd), Some(faction));
        }
        gd.location = 9;
        assert_eq!(sponsor_of(&gd), None);
        // faction and GC leves earn nothing
        for id in [1_001, 20_901] {
            let mut gd = leve(id, 40019, 20);
            gd.location = 1;
            assert_eq!(sponsor_of(&gd), None);
        }
    }

    #[test]
    fn credits_stay_within_zero_and_the_cap() {
        assert_eq!(apply(300, -100), Some(200));
        assert_eq!(apply(100, -200), None);
        assert_eq!(apply(950, 100), Some(CAP));
        assert_eq!(apply(0, 0), Some(0));
    }

    fn leve(id: u32, authority: u32, level: u16) -> GuildleveGamedata {
        GuildleveGamedata {
            id,
            authority,
            level,
            class_type: 1,
            plate_id: 20021,
            aim_num: [3, 0, 0, 0],
            mobs: [3200101, 0, 0, 0],
            ..Default::default()
        }
    }

    #[test]
    fn a_faction_menu_lists_its_own_leves_at_the_chosen_level() {
        let catalog: HashMap<u32, GuildleveGamedata> = [
            leve(1003, 40019, 30),
            leve(1001, 40019, 20),
            leve(1002, 40019, 20),
            leve(1101, 40020, 20),
            leve(10821, 40019, 20),
        ]
        .into_iter()
        .map(|g| (g.id, g))
        .collect();
        assert_eq!(offers(&catalog, 1, 20), vec![1001, 1002]);
        assert_eq!(offers(&catalog, 1, 30), vec![1003]);
        assert_eq!(offers(&catalog, 2, 20), vec![1101]);
        assert!(offers(&catalog, 3, 20).is_empty());
    }
}
