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

//! The SQL bundled into every server binary (see `build.rs`): the MariaDB
//! baseline schema, one game-data file per table, and numbered migrations.

use std::io::Read;

use flate2::read::GzDecoder;

include!(concat!(env!("OUT_DIR"), "/sql_manifest.rs"));

/// One bundled SQL file.
pub struct SqlFile {
    pub name: &'static str,
    pub sql: String,
}

fn inflate(name: &str, gz: &[u8]) -> String {
    let mut dec = GzDecoder::new(gz);
    let mut sql = String::new();
    dec.read_to_string(&mut sql)
        .unwrap_or_else(|e| panic!("decompressing bundled {name}: {e}"));
    sql
}

fn files(set: &'static [(&'static str, &'static [u8])]) -> impl Iterator<Item = SqlFile> {
    set.iter().map(|(name, gz)| SqlFile {
        name,
        sql: inflate(name, gz),
    })
}

/// The baseline schema, for an empty database.
pub fn schema() -> String {
    inflate(SCHEMA[0].0, SCHEMA[0].1)
}

/// Game-data files, one per table, in name order.
pub fn data() -> impl Iterator<Item = SqlFile> {
    files(DATA)
}

/// Numbered migrations, in name order.
pub fn iter() -> impl Iterator<Item = SqlFile> {
    files(MIGRATIONS)
}

pub fn count() -> usize {
    MIGRATIONS.len()
}

/// FNV-1a 64 of a file's text: how a changed data file or an edited
/// migration is noticed.
pub fn checksum(sql: &str) -> String {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for b in sql.as_bytes() {
        h ^= *b as u64;
        h = h.wrapping_mul(0x0000_0100_0000_01b3);
    }
    format!("{h:016x}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_creates_tables() {
        let s = schema();
        assert!(s.matches("CREATE TABLE IF NOT EXISTS").count() > 50);
    }

    #[test]
    fn every_data_file_reloads_its_own_table() {
        let mut n = 0;
        for f in data() {
            let table = f.name.trim_end_matches(".sql");
            assert!(
                f.sql.contains(&format!("DELETE FROM `{table}`;")),
                "{} must start by clearing {table}",
                f.name
            );
            n += 1;
        }
        assert!(n > 30, "expected the game-data files, found {n}");
    }

    #[test]
    fn migrations_are_numbered_and_sorted() {
        let names: Vec<&str> = iter().map(|m| m.name).collect();
        let mut sorted = names.clone();
        sorted.sort();
        assert_eq!(names, sorted);
        for n in names {
            assert!(
                n.len() > 4 && n[..3].bytes().all(|b| b.is_ascii_digit()) && &n[3..4] == "_",
                "migration {n} must be named NNN_description.sql"
            );
        }
    }
}
