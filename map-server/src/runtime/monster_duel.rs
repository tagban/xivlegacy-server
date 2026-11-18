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

//! Monster Mode duels (stage 4): the only player-versus-player fighting.
//! Two transformed players agree to fight: one challenges
//! (`!monstermode duel <name>`), the other answers the same way. While the
//! duel lasts each counts as the other's enemy, and only the other's; the
//! fight ends when one monster body falls, and both get their own bodies
//! back. Leaving Monster Mode any other way (letting go, zoning, logging
//! out) forfeits. All of it is in memory, like the rest of Monster Mode.

use std::collections::HashMap;
use std::sync::{Mutex, MutexGuard, OnceLock};

/// Seconds a challenge waits for an answer.
pub const CHALLENGE_SECS: u32 = 60;

#[derive(Default)]
struct Duels {
    /// challenged player -> (challenger, unix time of the challenge)
    challenges: HashMap<u32, (u32, u32)>,
    /// each duelist -> their foe (both directions)
    foes: HashMap<u32, u32>,
    /// chat lines owed to players, sent when Monster Mode next settles
    notices: Vec<(u32, String)>,
}

fn duels() -> MutexGuard<'static, Duels> {
    static D: OnceLock<Mutex<Duels>> = OnceLock::new();
    D.get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// What a `!monstermode duel` did.
#[derive(Debug, PartialEq, Eq)]
pub enum Challenge {
    /// A challenge is now waiting for the other player.
    Sent,
    /// The other player had challenged us: the duel is on.
    Started,
}

/// `a` and `b` are dueling each other: each may fight the other.
pub fn foes(a: u32, b: u32) -> bool {
    a != b && duels().foes.get(&a) == Some(&b)
}

/// `from` challenges `to` at `now`, or accepts `to`'s challenge if it is
/// still waiting. Neither may already be in a duel.
pub fn challenge(from: u32, to: u32, now: u32) -> Result<Challenge, &'static str> {
    if from == to {
        return Err("You can't duel yourself.");
    }
    let mut d = duels();
    if d.foes.contains_key(&from) {
        return Err("You are already in a duel.");
    }
    if d.foes.contains_key(&to) {
        return Err("They are already in a duel.");
    }
    if let Some(&(challenger, at)) = d.challenges.get(&from)
        && challenger == to
        && now.saturating_sub(at) <= CHALLENGE_SECS
    {
        d.challenges.remove(&from);
        d.challenges.remove(&to);
        d.foes.insert(from, to);
        d.foes.insert(to, from);
        return Ok(Challenge::Started);
    }
    d.challenges.insert(to, (from, now));
    Ok(Challenge::Sent)
}

/// End `a`'s duel, if any, and drop challenges to or from them. Returns
/// the foe.
pub fn end(a: u32) -> Option<u32> {
    let mut d = duels();
    d.challenges.retain(|to, (from, _)| *to != a && *from != a);
    let foe = d.foes.remove(&a)?;
    d.foes.remove(&foe);
    Some(foe)
}

/// `quitter` left Monster Mode mid-duel: the duel is over and the foe is
/// told when Monster Mode next settles.
pub fn forfeit(quitter: u32) {
    if let Some(foe) = end(quitter) {
        duels()
            .notices
            .push((foe, "Your foe left the duel. You win by forfeit.".into()));
    }
}

/// Chat lines owed to players (see [`forfeit`]).
pub fn take_notices() -> Vec<(u32, String)> {
    std::mem::take(&mut duels().notices)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_duel_needs_both_to_agree() {
        let (a, b, c) = (930_001, 930_002, 930_003);
        assert_eq!(challenge(a, b, 1000), Ok(Challenge::Sent));
        assert!(!foes(a, b));
        // Someone else answering doesn't start it.
        assert_eq!(challenge(c, a, 1001), Ok(Challenge::Sent));
        assert!(!foes(a, c));
        assert_eq!(challenge(b, a, 1010), Ok(Challenge::Started));
        assert!(foes(a, b) && foes(b, a));
        assert!(!foes(a, c) && !foes(c, b));
        assert_eq!(challenge(c, b, 1011), Err("They are already in a duel."));
        assert_eq!(end(a), Some(b));
        assert!(!foes(a, b) && !foes(b, a));
        assert_eq!(end(b), None);
        end(c);
    }

    #[test]
    fn a_challenge_runs_out() {
        let (a, b) = (930_011, 930_012);
        assert_eq!(challenge(a, b, 1000), Ok(Challenge::Sent));
        assert_eq!(
            challenge(b, a, 1000 + CHALLENGE_SECS + 1),
            Ok(Challenge::Sent)
        );
        assert!(!foes(a, b));
        end(a);
        end(b);
    }

    #[test]
    fn leaving_forfeits_and_tells_the_foe() {
        let (a, b) = (930_021, 930_022);
        challenge(a, b, 1000).unwrap();
        challenge(b, a, 1001).unwrap();
        forfeit(a);
        assert!(!foes(a, b));
        let owed: Vec<_> = take_notices()
            .into_iter()
            .filter(|(p, _)| *p == b)
            .collect();
        assert_eq!(owed.len(), 1);
    }
}
