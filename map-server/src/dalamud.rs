//! Dalamud, the red moon, and how big it hangs in each player's sky.
//!
//! How the 1.23b client draws it (from the client's weather code):
//! - Every field sky layout carries "satellite groups": `sgrp_meteor`
//!   plus one per patch stage, `sgrp_meteor117` .. `sgrp_meteor123`
//!   (1.17 to 1.23, the moon growing as the Calamity neared). The
//!   client's name table has 8 slots: index 0 = `sgrp_meteor`,
//!   1 = 117, 2 = 118, 3 = 119, 4 = 120, 5 = 121, 6 = 122, 7 = 123.
//!   The shipped skies have no `sgrp_meteor119`, so index 3 shows
//!   nothing.
//! - What each index looks like in the client (night sky, Lower La
//!   Noscea, 1280x720): 0 and 7 the same big red moon (~145 px across),
//!   6 ~80 px, 5 ~44 px, 4 a small orange star (~20 px); 1, 2 and 3 draw
//!   nothing. So there are four sizes: 4 < 5 < 6 < 7.
//! - `SetDalamud` (0x0010) byte 0 is read as an UNSIGNED stage index.
//!   On its next update the client shows that one group and hides the
//!   other seven. Anything from 8 to 255 hides them all (an `i8` -1
//!   therefore hides Dalamud).
//! - The packet works at any time, not only at zone-in, and lasts until
//!   the next one (every zone-in sends one).
//! - In the Dalamud weathers (8030, 8032) the client hides every stage
//!   group itself: those skies draw their own red moon.
//!
//! The server picks the stage from how far the player is in the main
//! story (`stage_for_story`); `[world] dalamud_by_story = false` sends
//! `[world] dalamud_phase` to everyone instead.

use crate::actor::quest::QuestJournal;

/// The largest stage index the client knows (`sgrp_meteor123`).
pub const LARGEST: u8 = 7;
/// Any index past the client's 8 groups: no Dalamud at all.
pub const HIDDEN: u8 = 0xFF;

/// Main story steps, earliest first, and the stage each one earns once
/// completed. A player earns the stage of the last step they finished;
/// one who finished none gets `STORY_START`.
///
/// With four sizes for five story parts, Dalamud stays a star through
/// Man0 and grows at the end of Man1, Man3 and Man4, closest at the end
/// as in 1.0's last months. Man1's three city versions count the same.
const STORY_STEPS: &[(&[u32], u8)] = &[
    // Man1: Legends Adrift, Whispers in the Wood, Golden Sacrifices.
    (&[110003, 110007, 110011], 5),
    // Man3's last quest: Lord Errant.
    (&[110017], 6),
    // Man4's last quest: Futures Perfect (the last playable one).
    (&[110019], LARGEST),
];

/// Before Man1 is done: Dalamud a small orange star.
pub const STORY_START: u8 = 4;

/// The stage a player's main-story progress earns.
pub fn stage_for_story(journal: &QuestJournal) -> u8 {
    stage_for(|id| journal.is_completed(id))
}

fn stage_for(completed: impl Fn(u32) -> bool) -> u8 {
    STORY_STEPS
        .iter()
        .rev()
        .find(|(quests, _)| quests.iter().any(|&q| completed(q)))
        .map(|(_, stage)| *stage)
        .unwrap_or(STORY_START)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stages_grow_with_the_story() {
        assert_eq!(stage_for(|_| false), STORY_START);
        // Man0 and Man2 keep the size they had
        assert_eq!(stage_for(|id| id == 110002), STORY_START);
        // any city's Man1 counts
        for q in [110003, 110007, 110011] {
            assert_eq!(stage_for(|id| id == q), 5);
        }
        assert_eq!(stage_for(|id| id == 110014), STORY_START);
        assert_eq!(stage_for(|id| id == 110017), 6);
        assert_eq!(stage_for(|id| id == 110019), LARGEST);
        // the furthest step wins, even with gaps (GM-set quests)
        assert_eq!(stage_for(|id| id == 110002 || id == 110019), LARGEST);
    }

    #[test]
    fn every_story_stage_is_visible_and_grows() {
        // 1-3 draw nothing in the shipped skies; 4..=7 grow
        let mut last = STORY_START;
        assert!((4..=LARGEST).contains(&last));
        for (_, stage) in STORY_STEPS {
            assert!(*stage > last && *stage <= LARGEST, "{stage}");
            last = *stage;
        }
    }
}
