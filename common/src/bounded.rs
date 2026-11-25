// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Bounded settings: a host-chosen number with a retail value, a safe range
//! and a hard range.
//!
//! Gameplay values (level cap, EXP rate, bag size...) are the host's call,
//! but some choices are risky and some break the client. [`Bounded::apply`]
//! checks one value at start-up and logs what it finds:
//!
//! | Value | Log | Value used |
//! | --- | --- | --- |
//! | the retail value | nothing | as set |
//! | not retail, inside the safe range | INFO `non-retail` | as set |
//! | outside the safe range, inside the hard range | WARN with the reason | as set |
//! | outside the hard range | ERROR with the reason | clamped to the hard range |
//!
//! A gameplay value never stops the server: past the hard range the server
//! uses the nearest value the client takes and says so.
//!
//! ```
//! use common::bounded::Bounded;
//! const WIDGETS: Bounded<i64> = Bounded {
//!     name: "example.widgets",
//!     retail: 100,
//!     safe: 0..=500,
//!     hard: 0..=10_000,
//!     risky: "above 500 widgets stop mattering",
//!     breaks: "the client shows at most 4 digits",
//! };
//! assert_eq!(WIDGETS.apply(200), 200); // INFO: non-retail
//! assert_eq!(WIDGETS.apply(800), 800); // WARN: risky, used as set
//! assert_eq!(WIDGETS.apply(20_000), 10_000); // ERROR: clamped
//! ```

use std::fmt::Display;
use std::ops::RangeInclusive;

/// One setting's limits. Make them `const`s next to the code that uses the
/// value, so the reasons live with the code they're about.
#[derive(Debug, Clone)]
pub struct Bounded<T> {
    /// `section.key`, as the host writes it in the settings file.
    pub name: &'static str,
    /// The 1.23b retail value (the shipped default, unless the project chose
    /// otherwise on purpose).
    pub retail: T,
    /// Values the server runs fine with. Outside it: a WARN.
    pub safe: RangeInclusive<T>,
    /// Values the client takes. Outside it: an ERROR and the nearest end.
    pub hard: RangeInclusive<T>,
    /// Why a value outside `safe` is risky (one line, for the WARN).
    pub risky: &'static str,
    /// What breaks outside `hard` (one line, for the ERROR).
    pub breaks: &'static str,
}

/// What [`Bounded::judge`] made of a value.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verdict<T> {
    /// The retail value.
    Retail,
    /// Not retail, inside the safe range.
    NonRetail,
    /// Outside the safe range, inside the hard range: used as set.
    Risky,
    /// Outside the hard range: `used` instead.
    Clamped { used: T },
}

impl<T: Copy + PartialOrd + Display> Bounded<T> {
    /// The value the server uses for `value` and why, without logging.
    pub fn judge(&self, value: T) -> (T, Verdict<T>) {
        if value < *self.hard.start() {
            let used = *self.hard.start();
            return (used, Verdict::Clamped { used });
        }
        if value > *self.hard.end() {
            let used = *self.hard.end();
            return (used, Verdict::Clamped { used });
        }
        if !self.safe.contains(&value) {
            return (value, Verdict::Risky);
        }
        if value != self.retail {
            return (value, Verdict::NonRetail);
        }
        (value, Verdict::Retail)
    }

    /// [`Self::judge`], logging anything that isn't retail. Returns the value
    /// to use.
    pub fn apply(&self, value: T) -> T {
        let (used, verdict) = self.judge(value);
        let (name, retail) = (self.name, self.retail);
        let (safe_lo, safe_hi) = (*self.safe.start(), *self.safe.end());
        let (hard_lo, hard_hi) = (*self.hard.start(), *self.hard.end());
        match verdict {
            Verdict::Retail => {}
            Verdict::NonRetail => {
                tracing::info!("non-retail setting: {name} = {value} (retail {retail})");
            }
            Verdict::Risky => tracing::warn!(
                "risky setting: {name} = {value} is outside the safe range \
                 {safe_lo}..={safe_hi} (retail {retail}): {}",
                self.risky
            ),
            Verdict::Clamped { used } => tracing::error!(
                "setting out of range: {name} = {value} is outside {hard_lo}..={hard_hi} \
                 ({}); using {used} instead",
                self.breaks
            ),
        }
        used
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const RATE: Bounded<i64> = Bounded {
        name: "progression.exp_rate_percent",
        retail: 100,
        safe: 0..=1000,
        hard: 0..=10_000,
        risky: "one kill levels a character several times",
        breaks: "beyond the whole level curve",
    };

    #[test]
    fn retail_value_is_retail() {
        assert_eq!(RATE.judge(100), (100, Verdict::Retail));
        assert_eq!(RATE.apply(100), 100);
    }

    #[test]
    fn in_safe_range_is_used_as_set() {
        assert_eq!(RATE.judge(200), (200, Verdict::NonRetail));
        assert_eq!(RATE.judge(0), (0, Verdict::NonRetail));
        assert_eq!(RATE.judge(1000), (1000, Verdict::NonRetail));
        assert_eq!(RATE.apply(250), 250);
    }

    #[test]
    fn above_safe_is_risky_but_used() {
        assert_eq!(RATE.judge(1001), (1001, Verdict::Risky));
        assert_eq!(RATE.judge(10_000), (10_000, Verdict::Risky));
        assert_eq!(RATE.apply(5000), 5000);
    }

    #[test]
    fn outside_hard_is_clamped() {
        assert_eq!(
            RATE.judge(10_001),
            (10_000, Verdict::Clamped { used: 10_000 })
        );
        assert_eq!(RATE.judge(-5), (0, Verdict::Clamped { used: 0 }));
        assert_eq!(RATE.apply(1_000_000), 10_000);
        assert_eq!(RATE.apply(-1), 0);
    }

    #[test]
    fn below_safe_is_risky() {
        const BAG: Bounded<i64> = Bounded {
            name: "storage.bag_slots",
            retail: 200,
            safe: 50..=200,
            hard: 1..=200,
            risky: "rewards stop fitting",
            breaks: "client crash",
        };
        assert_eq!(BAG.judge(49), (49, Verdict::Risky));
        assert_eq!(BAG.judge(0), (1, Verdict::Clamped { used: 1 }));
        assert_eq!(BAG.judge(201), (200, Verdict::Clamped { used: 200 }));
    }
}
