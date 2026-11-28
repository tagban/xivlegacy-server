// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The journal's page for a held regional leve (#479).
//!
//! Opening the page runs `RequestInformationCommand` with `("activegl",
//! slot)`, the leve's 1-based journal slot. The client answers a
//! `requestedData` packet tagged `activegl` by calling the page's
//! `setDetailData` with the values after the leve id:
//!
//! 1. offer limit: times the leve can still be retried; Retry is enabled
//!    only for a failed leve when this is above 0
//! 2. (not read for regional leves)
//! 3. first reward item id (0 hides the line, 1000001 = gil) and
//! 4. its amount
//! 5. second reward item id and
//! 6. its amount
//! 7. evaluation: compared with 1, so it must be a number (0 hides the
//!    line). A nil here is the "(40000)4" script error that logged the
//!    player out
//! 8. whether the stage icon shows
//!
//! The page's Abandon button then runs `JournalCommand` with (leve id,
//! [`ABANDON`]).

use super::*;

/// The item id the journal shows as gil.
const GIL_ITEM: i32 = 1_000_001;
/// `JournalCommand`'s second value when Abandon was chosen on the page
/// (Retry sends 4).
pub const ABANDON: i32 = 2;

/// The `requestedData` values for the leve's journal page: the tag, the
/// leve id and the eight values in the module docs. `gil` is the reward
/// the leve pays (0 hides the reward line).
pub fn detail_params(gl_id: u32, gil: i32) -> Vec<LuaParam> {
    let (reward_item, reward_amount) = if gil > 0 { (GIL_ITEM, gil) } else { (0, 0) };
    vec![
        LuaParam::String("requestedData".to_string()),
        LuaParam::String("activegl".to_string()),
        LuaParam::Int32(gl_id as i32),
        LuaParam::Int32(0),
        LuaParam::Int32(0),
        LuaParam::Int32(reward_item),
        LuaParam::Int32(reward_amount),
        LuaParam::Int32(0),
        LuaParam::Int32(0),
        LuaParam::Int32(0),
        LuaParam::False,
    ]
}

/// The leve in the player's 1-based journal `slot` (the slot order of
/// `work.guildleveId[]`).
pub fn held_in_slot(held: &[GuildleveRegionalEntry], slot: i64) -> Option<u32> {
    let slot = u16::try_from(slot.checked_sub(1)?).ok()?;
    held.iter()
        .find(|e| e.slot == slot && e.guildleve_id != 0)
        .map(|e| u32::from(e.guildleve_id))
}

/// The gil the leve's page shows: what the running leve pays, otherwise
/// the one-star reward, after the host's gil setting.
pub fn shown_gil(player_id: u32, gl_id: u32, level: u16) -> i32 {
    let difficulty = current(player_id)
        .filter(|&(id, _)| id == gl_id)
        .map_or(1, |(_, d)| d);
    crate::gameplay::current()
        .gil_reward(i64::from(reward_gil(level, difficulty)))
        .clamp(0, i64::from(i32::MAX)) as i32
}

/// The page values for the leve in the player's journal `slot`; None when
/// the slot holds no leve.
pub async fn detail(
    player_id: u32,
    slot: i64,
    registry: &ActorRegistry,
    lua: Option<&Arc<LuaEngine>>,
) -> Option<Vec<LuaParam>> {
    let handle = registry.get(player_id).await?;
    let gl_id = {
        let c = handle.character.read().await;
        held_in_slot(&c.chara.guildleves_regional, slot)?
    };
    let gil = gamedata(lua, gl_id).map_or(0, |gd| shown_gil(player_id, gl_id, gd.level));
    Some(detail_params(gl_id, gil))
}

/// Abandon from the journal: give up `gl_id` if the player holds it. A
/// running leve ends the way abandoning it in the field does; a leve not
/// started just leaves the journal. False when the player doesn't hold it
/// (a quest id), so the caller can treat it as a quest.
pub async fn abandon_held(
    player_id: u32,
    gl_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    now_ms: u64,
) -> bool {
    let Some(handle) = registry.get(player_id).await else {
        return false;
    };
    let held = handle
        .character
        .read()
        .await
        .chara
        .guildleves_regional
        .iter()
        .any(|e| u32::from(e.guildleve_id) == gl_id);
    if !held {
        return false;
    }
    if current(player_id).is_some_and(|(id, _)| id == gl_id) {
        // ends it (and frees the holder's slot), or takes a party member
        // off it; either way the remove below drops what is left
        abandon(player_id, registry, world, db, now_ms).await;
    } else {
        message(
            registry,
            world,
            player_id,
            TEXT_ABANDON,
            &[LuaParam::Int32(gl_id as i32)],
        )
        .await;
    }
    remove(player_id, gl_id, registry, world, db).await;
    tracing::info!(
        player = player_id,
        gl_id,
        "guildleve abandoned from the journal"
    );
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(slot: u16, id: u16) -> GuildleveRegionalEntry {
        GuildleveRegionalEntry {
            slot,
            guildleve_id: id,
            ..Default::default()
        }
    }

    #[test]
    fn page_values_are_all_set() {
        let p = detail_params(12422, 140);
        assert_eq!(p.len(), 11);
        assert_eq!(p[1], LuaParam::String("activegl".to_string()));
        assert_eq!(p[2], LuaParam::Int32(12422));
        // the client compares the evaluation (7th value) with 1: never nil
        assert!(p[3..].iter().all(|v| *v != LuaParam::Nil));
        assert_eq!(p[9], LuaParam::Int32(0));
        assert_eq!(
            (&p[5], &p[6]),
            (&LuaParam::Int32(GIL_ITEM), &LuaParam::Int32(140))
        );
        assert_eq!(p[10], LuaParam::False);
        // no gil: the reward line is hidden with item id 0
        let p = detail_params(12422, 0);
        assert_eq!((&p[5], &p[6]), (&LuaParam::Int32(0), &LuaParam::Int32(0)));
    }

    #[test]
    fn journal_slots_count_from_one() {
        let held = vec![entry(0, 12421), entry(1, 12422), entry(7, 12428)];
        assert_eq!(held_in_slot(&held, 1), Some(12421));
        assert_eq!(held_in_slot(&held, 2), Some(12422));
        assert_eq!(held_in_slot(&held, 8), Some(12428));
        assert_eq!(held_in_slot(&held, 3), None);
        assert_eq!(held_in_slot(&held, 0), None);
        assert_eq!(held_in_slot(&held, -1), None);
    }
}
