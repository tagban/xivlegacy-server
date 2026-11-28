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

//! Leve allowances: how many leves a character may still take.
//!
//! Patch 1.19 replaced the server-wide 36-hour leve refresh with
//! allowances (xivlegacy-reference finding `lv-allowances`, from the
//! archived FF14 Online Wiki guildleve page, captured 2012-12):
//!
//! - 4 allowances come back every 12 real hours, stockpiled up to 99;
//! - taking a leve spends one, and the pool is shared by regional
//!   (battlecraft and fieldcraft), local (crafting), faction and Grand
//!   Company leves (findings `faction-leve-flow`, `gc-leves`);
//! - retrying a failed leve spends one.
//!
//! Not confirmed: whether 1.0 refilled at fixed clock times for everyone or
//! 12 hours after each character's own clock, and what a new character
//! started with. This server runs a per-character clock (like anima) and
//! starts every character, new or existing, at the cap.
//!
//! The 1.23b client keeps no count of its own: the levemete
//! (`eventTalkType`), the Grand Company officer (`talkOfferWelcome`) and the
//! retry prompt (`askRetryRegionalleve`) show the number the server passes.
//!
//! The count is stored with the unix time it was last brought up to date
//! (`characters_leve_allowances`, migration 021; no row = the cap).
//! [`refill`] works out what has come back since, so no timer runs.
//! `[leves]` in settings/map.toml (crate::gameplay) sets the cap, the amount
//! per period and the period.

use crate::database::Database;
use crate::runtime::actor_registry::ActorRegistry;

/// 1.0's stockpile cap.
pub const RETAIL_CAP: u16 = 99;

/// What the player hears when a leve is refused for want of allowances.
pub const NONE_LEFT: &str = "You have no leve allowances remaining.";

/// The rules in force: (cap, amount per period, period in seconds).
pub fn rules() -> (u16, u16, i64) {
    let g = crate::gameplay::current();
    (
        g.leve_allowance_cap,
        g.leve_allowance_refill_amount,
        i64::from(g.leve_allowance_refill_hours.max(1)) * 3600,
    )
}

/// The most allowances a character can hold now.
pub fn cap() -> u16 {
    rules().0
}

/// Bring `(have, stamp)` up to `now`: `amount` allowances per whole
/// `period` seconds since `stamp`, up to `cap`. The stamp moves forward by
/// the whole periods counted, so a part-finished period carries on; at or
/// above the cap it is `now` (nothing builds up while full). A count above
/// the cap (the cap was lowered) is kept and gains nothing until spent
/// below it. A stamp in the future (a clock set back) counts as no time
/// passed. With `amount` 0 nothing comes back.
pub fn refill(have: u16, stamp: i64, now: i64, cap: u16, amount: u16, period: i64) -> (u16, i64) {
    if have >= cap || amount == 0 {
        return (have, now);
    }
    let period = period.max(1);
    let periods = (now - stamp).max(0) / period;
    let total = i64::from(have).saturating_add(periods.saturating_mul(i64::from(amount)));
    if total >= i64::from(cap) {
        (cap, now)
    } else {
        (total as u16, stamp + periods * period)
    }
}

/// The allowances held now, from what is stored, with the rules in force.
pub fn held(have: u16, stamp: i64, now: i64) -> (u16, i64) {
    let (cap, amount, period) = rules();
    refill(have, stamp, now, cap, amount, period)
}

/// One allowance spent from `have`, or `None` at 0.
pub fn spend_from(have: u16) -> Option<u16> {
    have.checked_sub(1)
}

/// Now, in unix seconds.
pub fn now() -> i64 {
    crate::runtime::anima::now()
}

/// Spend one of the player's allowances under the character lock and
/// return the (count, stamp) to store, or `None` at 0 (the refilled count
/// is kept either way). For callers that already hold the lock.
pub fn take_one(c: &mut crate::actor::CharaState, now: i64) -> Option<(u16, i64)> {
    let (have, stamp) = held(c.leve_allowances, c.leve_allowance_stamp, now);
    c.leve_allowances = have;
    c.leve_allowance_stamp = stamp;
    let left = spend_from(have)?;
    c.leve_allowances = left;
    Some((left, stamp))
}

/// Store a character's count.
pub async fn save(player_id: u32, (have, stamp): (u16, i64), db: &Database) {
    if let Err(e) = db.save_leve_allowances(player_id, have, stamp).await {
        tracing::warn!(player = player_id, error = %e, "leve allowances: save failed");
    }
}

/// Spend one of the player's allowances (`player:SpendLeveAllowance()`,
/// a retry) and store it. The count left, or `None` at 0.
pub async fn spend(player_id: u32, registry: &ActorRegistry, db: &Database) -> Option<u16> {
    let handle = registry.get(player_id).await?;
    let taken = {
        let mut c = handle.character.write().await;
        take_one(&mut c.chara, now())
    };
    let Some(taken) = taken else {
        tracing::info!(player = player_id, "leve allowances: none left");
        return None;
    };
    save(player_id, taken, db).await;
    tracing::info!(player = player_id, left = taken.0, "leve allowance spent");
    Some(taken.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    const T: i64 = 1_800_000_000;
    const P: i64 = 12 * 3600;

    #[test]
    fn retail_rules() {
        let g = crate::gameplay::Gameplay::RETAIL;
        assert_eq!(g.leve_allowance_cap, RETAIL_CAP);
        assert_eq!(g.leve_allowance_refill_amount, 4);
        assert_eq!(g.leve_allowance_refill_hours, 12);
    }

    #[test]
    fn spend_takes_one_and_refuses_at_zero() {
        assert_eq!(spend_from(99), Some(98));
        assert_eq!(spend_from(1), Some(0));
        assert_eq!(spend_from(0), None);
    }

    #[test]
    fn take_one_spends_and_keeps_the_refill_when_refused() {
        let mut c = crate::actor::CharaState {
            leve_allowances: 1,
            leve_allowance_stamp: T,
            ..Default::default()
        };
        assert_eq!(take_one(&mut c, T + 60), Some((0, T)));
        assert_eq!(c.leve_allowances, 0);
        // nothing left until a period passes
        assert_eq!(take_one(&mut c, T + P - 1), None);
        assert_eq!(c.leve_allowances, 0);
        // a period later: 4 back, one spent
        assert_eq!(take_one(&mut c, T + P), Some((3, T + P)));
        // refused at 0 with the clock kept
        c.leve_allowances = 0;
        c.leve_allowance_stamp = T + P;
        assert_eq!(take_one(&mut c, T + P), None);
        assert_eq!((c.leve_allowances, c.leve_allowance_stamp), (0, T + P));
    }

    #[test]
    fn refill_counts_whole_periods_and_keeps_the_part() {
        // 2 periods and an hour: +8, the hour carries over
        let (n, s) = refill(10, T, T + 2 * P + 3600, 99, 4, P);
        assert_eq!((n, s), (18, T + 2 * P));
        assert_eq!(refill(n, s, T + 3 * P - 1, 99, 4, P).0, 18);
        assert_eq!(refill(n, s, T + 3 * P, 99, 4, P).0, 22);
        // nothing before a whole period
        assert_eq!(refill(0, T, T + P - 1, 99, 4, P), (0, T));
    }

    #[test]
    fn refill_stops_at_the_cap() {
        // 97 + 4 is past 99: 99, and the clock stops
        assert_eq!(refill(97, T, T + P, 99, 4, P), (99, T + P));
        assert_eq!(refill(99, T, T + 5 * P, 99, 4, P), (99, T + 5 * P));
        // empty for a month fills right up
        assert_eq!(refill(0, T, T + 60 * P, 99, 4, P), (99, T + 60 * P));
    }

    #[test]
    fn full_starts_the_clock_at_the_first_spend() {
        // full at T: the stamp is T, the first refill is at T + 12 h
        let (have, stamp) = refill(99, 0, T, 99, 4, P);
        let left = spend_from(have).unwrap();
        assert_eq!((left, stamp), (98, T));
        assert_eq!(refill(left, stamp, T + P - 1, 99, 4, P).0, 98);
        assert_eq!(refill(left, stamp, T + P, 99, 4, P).0, 99);
    }

    #[test]
    fn a_lowered_cap_keeps_what_is_held() {
        assert_eq!(refill(150, T, T + 10 * P, 99, 4, P), (150, T + 10 * P));
        assert_eq!(refill(98, T, T + P, 99, 4, P).0, 99);
    }

    #[test]
    fn no_refill_amount_and_clock_trouble() {
        assert_eq!(refill(5, T, T + 100 * P, 99, 0, P), (5, T + 100 * P));
        // a stamp in the future: no time passed
        assert_eq!(refill(5, T + 1000, T, 99, 4, P), (5, T + 1000));
        // huge amounts and gaps don't overflow
        assert_eq!(refill(0, 0, i64::MAX, 999, 999, 3600).0, 999);
    }

    #[test]
    fn a_changed_period_applies_to_the_time_since_the_stamp() {
        assert_eq!(refill(10, T, T + 6 * 3600, 99, 4, P).0, 10);
        assert_eq!(refill(10, T, T + 6 * 3600, 99, 4, 3600), (34, T + 6 * 3600));
    }
}
