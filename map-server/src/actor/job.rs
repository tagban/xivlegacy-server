// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Jobs and their soul crystals (1.23b). Each job grows out of one class;
//! the job quest "Job 1" gives the soul crystal, which goes in the job
//! items package (101). The table is the client's own
//! (CharaBaseClass.hasJobStone and the gear window's job check).

/// (class, job, soul crystal)
pub const JOBS: &[(u8, u8, u32)] = &[
    (2, 15, 2000202),  // pugilist -> monk
    (3, 16, 2000201),  // gladiator -> paladin
    (4, 17, 2000203),  // marauder -> warrior
    (7, 18, 2000205),  // archer -> bard
    (8, 19, 2000204),  // lancer -> dragoon
    (22, 26, 2000207), // thaumaturge -> black mage
    (23, 27, 2000206), // conjurer -> white mage
];

/// The job a class grows into, and its soul crystal.
pub fn job_of_class(class_id: u8) -> Option<(u8, u32)> {
    JOBS.iter()
        .find(|(class, _, _)| *class == class_id)
        .map(|(_, job, crystal)| (*job, *crystal))
}

/// The class a job belongs to.
pub fn class_of_job(job_id: u8) -> Option<u8> {
    JOBS.iter()
        .find(|(_, job, _)| *job == job_id)
        .map(|(class, _, _)| *class)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn jobs_pair_with_their_classes() {
        assert_eq!(job_of_class(4), Some((17, 2000203)));
        assert_eq!(job_of_class(23), Some((27, 2000206)));
        assert_eq!(job_of_class(29), None);
        for (class, job, _) in JOBS {
            assert_eq!(class_of_job(*job), Some(*class));
        }
    }
}
