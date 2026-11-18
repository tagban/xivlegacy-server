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

//! Monster Points: the one reward for playing as a monster (Monster Mode),
//! like FFXI Monstrosity's Infamy. Spent at the Monster Points vendors
//! (scripts/lua/monsterpoints.lua).
//!
//! - A kill earns 15 points at even level, 3 more or less per level of
//!   difference (30 at most, nothing for prey 5 or more levels below the
//!   body). The 6th and later kill of the same monster kind within 10
//!   minutes earns half.
//! - Letting go earns 1 point for each minute in which a move was used, up
//!   to 20, if the session lasted 2 minutes.
//! - At most 600 a day and 3,000 a week (UTC; weeks start on Monday).
//! - A body taken with the tester form (`!monstermode <class id>`) earns
//!   nothing.
//!
//! The balance is a currency item in the money package; the caps and the
//! lifetime total are in `characters_monster_points` (migration 014).
//! Points are written as they are earned, never with the character.

use std::collections::{HashMap, VecDeque};
use std::sync::{Mutex, MutexGuard, OnceLock};

use crate::database::Database;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The currency item that holds the balance ("Monster Points" in the
/// XIVLegacy client).
pub const ITEM_ID: u32 = 1_000_124;
/// Points a day and a week.
pub const DAY_CAP: i32 = 600;
pub const WEEK_CAP: i32 = 3_000;
/// Points for an even-level kill, the most for one kill, and the change
/// per level of difference.
const EVEN_KILL: i32 = 15;
const MAX_KILL: i32 = 30;
const PER_LEVEL: i32 = 3;
/// Same-kind kills within this many seconds past this count earn half.
const FARM_WINDOW_SECS: u32 = 600;
const FARM_KILLS: usize = 5;
/// Session bonus: a point per active minute, up to this, if the session
/// lasted this many seconds.
pub const SESSION_MAX: i32 = 20;
pub const SESSION_MIN_SECS: u32 = 120;

/// Points for a kill by a body of `body_level` on prey of `prey_level`.
pub fn kill_points(body_level: i16, prey_level: i16) -> i32 {
    let diff = i32::from(prey_level) - i32::from(body_level);
    if diff <= -5 {
        return 0;
    }
    (EVEN_KILL + PER_LEVEL * diff).clamp(0, MAX_KILL)
}

/// What of `amount` fits under the caps, given today's and this week's
/// totals so far.
pub fn capped(amount: i32, today: i32, week: i32, day_cap: i32, week_cap: i32) -> i32 {
    amount.min(day_cap - today).min(week_cap - week).max(0)
}

/// The UTC day number and Monday-based week number of `unix` seconds.
pub fn day_and_week(unix: i64) -> (i32, i32) {
    let day = unix.div_euclid(86_400);
    // 1970-01-01 was a Thursday: day 4 is the first Monday.
    let week = (day + 3).div_euclid(7);
    (day as i32, week as i32)
}

/// player id -> their recent kills (monster class, unix seconds).
type RecentKills = HashMap<u32, VecDeque<(u32, u32)>>;

fn recent_kills() -> MutexGuard<'static, RecentKills> {
    static MAP: OnceLock<Mutex<RecentKills>> = OnceLock::new();
    MAP.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// Note a kill of `class_id` at `now` and say whether it is a farmed one
/// (more than [`FARM_KILLS`] of that kind in the window before it).
pub fn note_kill(player_id: u32, class_id: u32, now: u32) -> bool {
    let mut map = recent_kills();
    let kills = map.entry(player_id).or_default();
    while kills
        .front()
        .is_some_and(|(_, at)| now.saturating_sub(*at) > FARM_WINDOW_SECS)
    {
        kills.pop_front();
    }
    let farmed = kills.iter().filter(|(c, _)| *c == class_id).count() >= FARM_KILLS;
    kills.push_back((class_id, now));
    farmed
}

/// Grant `amount` points to `player_id` for `why` ("kill", "session"),
/// tell them in chat, and refresh their currency bag.
pub async fn award(
    player_id: u32,
    amount: i32,
    why: &'static str,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &std::sync::Arc<Database>,
) {
    if amount <= 0 {
        return;
    }
    let (day, week) = day_and_week(common::utils::unix_timestamp() as i64);
    let grant = match db
        .award_monster_points(player_id, ITEM_ID, amount, day, week, DAY_CAP, WEEK_CAP)
        .await
    {
        Ok(g) => g,
        Err(e) => {
            tracing::warn!(player = player_id, error = %e, "monster points: award failed");
            return;
        }
    };
    tracing::info!(
        player = player_id,
        why,
        asked = amount,
        granted = grant.granted,
        today = grant.today,
        week = grant.week,
        balance = grant.balance,
        "monster points awarded",
    );
    crate::runtime::monster_mode::log_points(player_id, why, grant.granted);
    let msg = if grant.granted > 0 {
        crate::runtime::quest_apply::send_inventory_package_update(
            player_id,
            crate::inventory::PKG_CURRENCY_CRYSTALS,
            crate::inventory::CAP_CURRENCY,
            Some(ITEM_ID),
            registry,
            world,
            db,
        )
        .await;
        let mut m = format!(
            "You earn {} Monster Point{} ({} today, {} in all).",
            grant.granted,
            if grant.granted == 1 { "" } else { "s" },
            grant.today,
            grant.balance
        );
        if grant.granted < amount {
            m.push_str(" That's all you can earn for now.");
        }
        m
    } else if grant.today >= DAY_CAP {
        "You can't earn more Monster Points today.".to_string()
    } else {
        "You can't earn more Monster Points this week.".to_string()
    };
    tell(player_id, msg, registry, world, db).await;
}

/// A system chat line to one player.
pub async fn tell(
    player_id: u32,
    message: String,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &std::sync::Arc<Database>,
) {
    use crate::social::{ChatKind, SocialEvent, SocialOutbox, dispatch_social_event};
    let mut ob = SocialOutbox::new();
    ob.push(SocialEvent::ChatSystemToPlayer {
        target_actor_id: player_id,
        kind: ChatKind::System,
        message,
    });
    for e in ob.drain() {
        dispatch_social_event(&e, registry, world, db).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn points_stop_at_the_caps_and_reset_on_a_new_day() {
        let db = Database::open(common::test_db::fresh().await.unwrap())
            .await
            .unwrap();
        let c = 7_301;
        let g = db
            .award_monster_points(c, ITEM_ID, 15, 100, 14, 30, 50)
            .await
            .unwrap();
        assert_eq!((g.granted, g.today, g.week, g.balance), (15, 15, 15, 15));
        let g = db
            .award_monster_points(c, ITEM_ID, 20, 100, 14, 30, 50)
            .await
            .unwrap();
        assert_eq!((g.granted, g.today, g.balance), (15, 30, 30), "day cap");
        let g = db
            .award_monster_points(c, ITEM_ID, 20, 100, 14, 30, 50)
            .await
            .unwrap();
        assert_eq!((g.granted, g.balance), (0, 30));
        // next day: the day count resets, the week cap still holds
        let g = db
            .award_monster_points(c, ITEM_ID, 30, 101, 14, 30, 50)
            .await
            .unwrap();
        assert_eq!(
            (g.granted, g.today, g.week, g.balance),
            (20, 20, 50, 50),
            "week cap"
        );
        // next week: both reset
        let g = db
            .award_monster_points(c, ITEM_ID, 10, 107, 15, 30, 50)
            .await
            .unwrap();
        assert_eq!((g.granted, g.today, g.week, g.balance), (10, 10, 10, 60));
        assert_eq!(db.currency_quantity(c, ITEM_ID).await.unwrap(), 60);
    }

    #[test]
    fn kills_scale_with_the_level_difference() {
        assert_eq!(kill_points(20, 20), 15);
        assert_eq!(kill_points(20, 21), 18);
        assert_eq!(kill_points(20, 25), 30);
        assert_eq!(kill_points(20, 40), 30);
        assert_eq!(kill_points(20, 19), 12);
        assert_eq!(kill_points(20, 16), 3);
        assert_eq!(kill_points(20, 15), 0);
        assert_eq!(kill_points(20, 1), 0);
    }

    #[test]
    fn caps_stop_the_grant() {
        assert_eq!(capped(15, 0, 0, 600, 3000), 15);
        assert_eq!(capped(15, 590, 1000, 600, 3000), 10);
        assert_eq!(capped(15, 600, 1000, 600, 3000), 0);
        assert_eq!(capped(15, 100, 2995, 600, 3000), 5);
        assert_eq!(capped(15, 700, 3100, 600, 3000), 0);
    }

    #[test]
    fn days_and_monday_weeks() {
        // 2026-11-16 was a Monday, 2026-11-15 a Sunday (UTC).
        let monday = 1_794_787_200; // 2026-11-16 00:00:00 UTC
        let (d, w) = day_and_week(monday);
        assert_eq!(day_and_week(monday + 6 * 86_400 + 86_399).1, w);
        assert_eq!(day_and_week(monday - 1).1, w - 1);
        assert_eq!(day_and_week(monday + 86_400).0, d + 1);
    }

    #[test]
    fn the_sixth_kill_of_a_kind_in_ten_minutes_is_farmed() {
        let p = 930_001;
        for i in 0..5 {
            assert!(!note_kill(p, 2_104_001, 1000 + i * 30), "kill {i}");
        }
        assert!(note_kill(p, 2_104_001, 1200));
        // another kind isn't
        assert!(!note_kill(p, 2_102_003, 1210));
        // ten minutes on, the old kills have aged out
        assert!(!note_kill(p, 2_104_001, 1200 + 601 + 150));
    }
}
