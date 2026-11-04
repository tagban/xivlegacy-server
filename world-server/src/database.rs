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

//! SQLite-backed world database queries. Ported from World Server/Database.cs.
//!
//! Several queries (linkshell member fetches, current-zone lookup) are
//! referenced by Phase-4 packet types that the Map Server will add; keep
//! them `#[allow(dead_code)]` for now so the API stays stable.
#![allow(dead_code)]


use anyhow::{Context, Result};
use common::db::ConnCallExt;
use common::sql::{OptionalExtension, named_params};
use common::sql::Connection;

use crate::group::{Linkshell, LinkshellMember, RetainerGroupMember};

pub struct Database {
    conn: Connection,
}

impl Database {
    pub async fn open(url: impl AsRef<str>) -> Result<Self> {
        let conn = common::db::open_or_create(url).await?;
        Ok(Self { conn })
    }

    #[cfg(test)]
    pub fn conn_for_test(&self) -> &Connection {
        &self.conn
    }

    pub async fn ping(&self) -> Result<()> {
        self.conn
            .call_db(|c| {
                c.query_row("SELECT 1", [], |_| Ok(()))?;
                Ok(())
            })
            .await
            .context("ping")
    }

    /// Populate `session` state from the `characters` row. Returns whether a
    /// row was found.
    pub async fn load_zone_session_info(
        &self,
        session_id: u32,
    ) -> Result<Option<SessionDbSnapshot>> {
        let row = self
            .conn
            .call_db(move |c| {
                let v = c
                    .query_row(
                        r"SELECT name, currentZoneId, destinationZoneId, currentActiveLinkshell
                          FROM characters WHERE id = :cid",
                        named_params! { ":cid": session_id },
                        |r| {
                            Ok(SessionDbSnapshot {
                                character_name: r.get::<_, String>(0).unwrap_or_default(),
                                current_zone_id: r.get::<_, u32>(1).unwrap_or(0),
                                destination_zone_id: r.get::<_, u32>(2).unwrap_or(0),
                                active_linkshell: r.get::<_, String>(3).unwrap_or_default(),
                            })
                        },
                    )
                    .optional()?;
                Ok(v)
            })
            .await?;
        Ok(row)
    }

    /// Read `server_zones` for zones that have a map-server endpoint
    /// configured. Returns `(zone_id, server_ip, server_port)` tuples.
    pub async fn get_server_zones(&self) -> Result<Vec<(u32, String, u16)>> {
        let rows = self
            .conn
            .call_db(|c| {
                let mut stmt = c.prepare(
                    r"SELECT id, serverIp, serverPort
                      FROM server_zones
                      WHERE serverIp IS NOT NULL AND serverIp <> '' AND serverPort > 0",
                )?;
                let rows: Vec<(u32, String, u16)> = stmt
                    .query_map([], |r| {
                        Ok((
                            r.get::<_, u32>(0)?,
                            r.get::<_, String>(1)?,
                            r.get::<_, u16>(2)?,
                        ))
                    })?
                    .collect::<common::sql::Result<_>>()?;
                Ok(rows)
            })
            .await?;
        Ok(rows)
    }

    pub async fn get_all_chara_names(&self) -> Result<Vec<(u32, String)>> {
        let rows = self
            .conn
            .call_db(|c| {
                let mut stmt = c.prepare("SELECT id, name FROM characters")?;
                let rows: Vec<(u32, String)> = stmt
                    .query_map([], |r| Ok((r.get::<_, u32>(0)?, r.get::<_, String>(1)?)))?
                    .collect::<common::sql::Result<_>>()?;
                Ok(rows)
            })
            .await?;
        Ok(rows)
    }

    pub async fn current_zone_for_session(&self, chara_id: u32) -> Result<u32> {
        let row = self
            .conn
            .call_db(move |c| {
                let v = c
                    .query_row(
                        "SELECT currentZoneId, destinationZoneId FROM characters WHERE id = :cid",
                        named_params! { ":cid": chara_id },
                        |r| Ok((r.get::<_, u32>(0)?, r.get::<_, u32>(1)?)),
                    )
                    .optional()?;
                Ok(v)
            })
            .await?;
        Ok(match row {
            Some((cur, dest)) if cur == 0 && dest != 0 => dest,
            Some((cur, dest)) if cur != 0 && dest == 0 => cur,
            _ => 0,
        })
    }

    pub async fn get_retainers(&self, chara_id: u32) -> Result<Vec<RetainerGroupMember>> {
        let rows = self
            .conn
            .call_db(move |c| {
                let mut stmt = c.prepare(
                    r"SELECT sr.id, sr.name, sr.actorClassId, sr.cdIDOffset,
                             sr.placeName, sr.conditions, sr.level
                      FROM server_retainers sr
                      INNER JOIN characters_retainers cr ON cr.retainerId = sr.id
                      WHERE cr.characterId = :cid",
                )?;
                let rows: Vec<RetainerGroupMember> = stmt
                    .query_map(named_params! { ":cid": chara_id }, |r| {
                        let id = r.get::<_, u32>(0)? | 0xE000_0000;
                        Ok(RetainerGroupMember::new(
                            id,
                            r.get::<_, String>(1)?,
                            r.get::<_, u32>(2)?,
                            r.get::<_, u8>(3)?,
                            r.get::<_, u16>(4)?,
                            r.get::<_, u8>(5)?,
                            r.get::<_, u8>(6)?,
                        ))
                    })?
                    .collect::<common::sql::Result<_>>()?;
                Ok(rows)
            })
            .await?;
        Ok(rows)
    }

    pub async fn get_linkshell_by_name(
        &self,
        group_index: u64,
        ls_name: &str,
    ) -> Result<Option<Linkshell>> {
        let ls_name = ls_name.to_owned();
        let row = self
            .conn
            .call_db(move |c| {
                let v = c
                    .query_row(
                        "SELECT id, name, crestIcon, master FROM server_linkshells WHERE name = :n",
                        named_params! { ":n": ls_name },
                        |r| {
                            Ok((
                                r.get::<_, u64>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, u16>(2)?,
                                r.get::<_, u32>(3)?,
                            ))
                        },
                    )
                    .optional()?;
                Ok(v)
            })
            .await?;
        Ok(row.map(|(id, name, crest, master)| {
            Linkshell::new(id, group_index, name, crest, master, Linkshell::RANK_MASTER)
        }))
    }

    pub async fn get_linkshell_by_id(
        &self,
        group_index: u64,
        ls_id: u64,
    ) -> Result<Option<Linkshell>> {
        let row = self
            .conn
            .call_db(move |c| {
                let v = c
                    .query_row(
                        "SELECT name, crestIcon, master FROM server_linkshells WHERE id = :i",
                        named_params! { ":i": ls_id as i64 },
                        |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, u16>(1)?,
                                r.get::<_, u32>(2)?,
                            ))
                        },
                    )
                    .optional()?;
                Ok(v)
            })
            .await?;
        Ok(row.map(|(name, crest, master)| {
            Linkshell::new(
                ls_id,
                group_index,
                name,
                crest,
                master,
                Linkshell::RANK_MASTER,
            )
        }))
    }

    pub async fn get_ls_members(&self, ls_id: u64) -> Result<Vec<LinkshellMember>> {
        let rows = self.conn
            .call_db(move |c| {
                let mut stmt = c.prepare(
                    "SELECT characterId, linkshellId, rank FROM characters_linkshells WHERE linkshellId = :i",
                )?;
                let mut rows: Vec<LinkshellMember> = stmt
                    .query_map(named_params! { ":i": ls_id as i64 }, |r| {
                        Ok(LinkshellMember {
                            character_id: r.get::<_, u32>(0)?,
                            linkshell_id: r.get::<_, u64>(1)?,
                            rank: r.get::<_, u8>(2)?,
                        })
                    })?
                    .collect::<common::sql::Result<_>>()?;
                rows.sort_by_key(|m| m.character_id);
                Ok(rows)
            })
            .await?;
        Ok(rows)
    }

    pub async fn get_player_ls_membership(&self, chara_id: u32) -> Result<Vec<LinkshellMember>> {
        let rows = self.conn
            .call_db(move |c| {
                let mut stmt = c.prepare(
                    "SELECT characterId, linkshellId, rank FROM characters_linkshells WHERE characterId = :cid",
                )?;
                let rows: Vec<LinkshellMember> = stmt
                    .query_map(named_params! { ":cid": chara_id }, |r| {
                        Ok(LinkshellMember {
                            character_id: r.get::<_, u32>(0)?,
                            linkshell_id: r.get::<_, u64>(1)?,
                            rank: r.get::<_, u8>(2)?,
                        })
                    })?
                    .collect::<common::sql::Result<_>>()?;
                Ok(rows)
            })
            .await?;
        Ok(rows)
    }

    pub async fn create_linkshell(&self, name: &str, crest: u16, master: u32) -> Result<u64> {
        let name = name.to_owned();
        let id = self
            .conn
            .call_db(move |c| {
                c.execute(
                    r"INSERT INTO server_linkshells (name, crestIcon, master, rank)
                      VALUES (:n, :c, :m, :r)",
                    named_params! {
                        ":n": name,
                        ":c": crest,
                        ":m": master,
                        ":r": Linkshell::RANK_MASTER,
                    },
                )?;
                Ok(c.last_insert_rowid() as u64)
            })
            .await?;
        Ok(id)
    }

    pub async fn linkshell_add_player(&self, ls_id: u64, chara_id: u32, rank: u8) -> Result<()> {
        self.conn
            .call_db(move |c| {
                c.execute(
                    r"INSERT INTO characters_linkshells(characterId, linkshellId, rank)
                      VALUES(:c, :l, :r)
                      ON DUPLICATE KEY UPDATE rank = VALUES(rank)",
                    named_params! { ":c": chara_id, ":l": ls_id as i64, ":r": rank },
                )?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    pub async fn linkshell_remove_player(&self, ls_id: u64, chara_id: u32) -> Result<()> {
        self.conn
            .call_db(move |c| {
                c.execute(
                    r"DELETE FROM characters_linkshells
                      WHERE characterId = :c AND linkshellId = :l",
                    named_params! { ":c": chara_id, ":l": ls_id as i64 },
                )?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    pub async fn change_linkshell_crest(&self, ls_id: u64, crest: u16) -> Result<()> {
        self.conn
            .call_db(move |c| {
                c.execute(
                    "UPDATE server_linkshells SET crestIcon = :c WHERE id = :l",
                    named_params! { ":c": crest, ":l": ls_id as i64 },
                )?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    pub async fn linkshell_change_rank(&self, ls_id: u64, chara_id: u32, rank: u8) -> Result<()> {
        self.conn
            .call_db(move |c| {
                c.execute(
                    r"UPDATE characters_linkshells SET rank = :r
                      WHERE characterId = :c AND linkshellId = :l",
                    named_params! { ":r": rank, ":c": chara_id, ":l": ls_id as i64 },
                )?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    pub async fn character_id_by_name(&self, name: &str) -> Result<Option<u32>> {
        let name = name.to_owned();
        let id = self
            .conn
            .call_db(move |c| {
                let v: Option<u32> = c
                    .query_row(
                        "SELECT id FROM characters WHERE name = :n",
                        named_params! { ":n": name },
                        |r| r.get(0),
                    )
                    .optional()?;
                Ok(v)
            })
            .await?;
        Ok(id)
    }

    pub async fn set_active_ls(&self, chara_id: u32, name: &str) -> Result<()> {
        let name = name.to_owned();
        self.conn
            .call_db(move |c| {
                c.execute(
                    "UPDATE characters SET currentActiveLinkshell = :n WHERE id = :c",
                    named_params! { ":n": name, ":c": chara_id },
                )?;
                Ok(())
            })
            .await?;
        Ok(())
    }

    pub async fn linkshell_exists(&self, name: &str) -> Result<bool> {
        let name = name.to_owned();
        let v = self
            .conn
            .call_db(move |c| {
                let row: Option<i64> = c
                    .query_row(
                        "SELECT id FROM server_linkshells WHERE name = :n",
                        named_params! { ":n": name },
                        |r| r.get(0),
                    )
                    .optional()?;
                Ok(row.is_some())
            })
            .await?;
        Ok(v)
    }
}

/// Unix seconds now.
fn now_s() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// `world_sessions` (seed 102): who is in the game. Only the world server
/// writes it; see docs/DESIGN.md, Sessions.
impl Database {
    /// At boot: nobody is online until they connect to this world server.
    pub async fn clear_world_sessions(&self) -> Result<usize> {
        self.conn
            .call_db(|c| c.execute("DELETE FROM world_sessions", []))
            .await
            .context("clearing world_sessions")
    }

    /// A character entering the world (state `connecting`). The row is keyed
    /// by account, so it replaces any session of another character on the
    /// same account; that character's id is returned so the caller can end it.
    pub async fn begin_world_session(&self, s: NewWorldSession) -> Result<Option<u32>> {
        self.conn
            .call_db(move |c| {
                let tx = c.transaction()?;
                let account: Option<i64> = tx
                    .query_row(
                        "SELECT userId FROM characters WHERE id = :c",
                        named_params! { ":c": s.character_id },
                        |r| r.get(0),
                    )
                    .optional()?;
                let Some(account) = account else {
                    return Ok(None);
                };
                let previous: Option<u32> = tx
                    .query_row(
                        "SELECT character_id FROM world_sessions WHERE account_id = :a",
                        named_params! { ":a": account },
                        |r| r.get(0),
                    )
                    .optional()?;
                // a session of this character under another account can't
                // exist (characters belong to one account), but the UNIQUE
                // character_id would refuse the insert if a stale one did
                tx.execute(
                    "DELETE FROM world_sessions WHERE character_id = :c",
                    named_params! { ":c": s.character_id },
                )?;
                let now = now_s();
                tx.execute(
                    r"REPLACE INTO world_sessions
                        (account_id, character_id, world_id, zone_id, map_server, client_ip,
                         conn_seq, started_at, last_seen_at, state)
                      VALUES (:a, :c, :w, :z, :m, :ip, :seq, :now, :now, 'connecting')",
                    named_params! {
                        ":a": account, ":c": s.character_id, ":w": s.world_id, ":z": s.zone_id,
                        ":m": s.map_server, ":ip": s.client_ip, ":seq": s.conn_seq as i64, ":now": now,
                    },
                )?;
                tx.commit()?;
                Ok(previous.filter(|&p| p != s.character_id))
            })
            .await
            .context("beginning a world session")
    }

    /// The map server accepted the character: `in_world`, and the character's
    /// last activity stamped.
    pub async fn world_session_in_world(&self, character_id: u32) -> Result<()> {
        self.conn
            .call_db(move |c| {
                let now = now_s();
                c.execute(
                    "UPDATE world_sessions SET state = 'in_world', last_seen_at = :now WHERE character_id = :c",
                    named_params! { ":c": character_id, ":now": now },
                )?;
                c.execute(
                    "UPDATE characters SET lastActiveAt = :now WHERE id = :c",
                    named_params! { ":c": character_id, ":now": now },
                )?;
                Ok(())
            })
            .await
            .context("marking a world session in the world")
    }

    /// The character is changing zones; `destination` is set once the map
    /// server says where (zone id, map server).
    pub async fn world_session_zoning(
        &self,
        character_id: u32,
        destination: Option<(u32, String)>,
    ) -> Result<()> {
        self.conn
            .call_db(move |c| {
                let now = now_s();
                match destination {
                    Some((zone, map)) => c.execute(
                        r"UPDATE world_sessions SET state = 'zoning', zone_id = :z, map_server = :m,
                          last_seen_at = :now WHERE character_id = :c",
                        named_params! { ":c": character_id, ":z": zone, ":m": map, ":now": now },
                    )?,
                    None => c.execute(
                        "UPDATE world_sessions SET state = 'zoning', last_seen_at = :now WHERE character_id = :c",
                        named_params! { ":c": character_id, ":now": now },
                    )?,
                };
                Ok(())
            })
            .await
            .context("marking a world session zoning")
    }

    /// The character left: the row goes, unless a newer connection (another
    /// `conn_seq`) has taken the session over since, and the character's last
    /// activity is stamped.
    pub async fn end_world_session(&self, character_id: u32, conn_seq: u64) -> Result<bool> {
        self.conn
            .call_db(move |c| {
                let n = c.execute(
                    "DELETE FROM world_sessions WHERE character_id = :c AND conn_seq = :seq",
                    named_params! { ":c": character_id, ":seq": conn_seq as i64 },
                )?;
                if n > 0 {
                    c.execute(
                        "UPDATE characters SET lastActiveAt = :now WHERE id = :c",
                        named_params! { ":c": character_id, ":now": now_s() },
                    )?;
                }
                Ok(n > 0)
            })
            .await
            .context("ending a world session")
    }

    /// Every 30 s: the characters still connected to this world server were
    /// seen now.
    pub async fn touch_world_sessions(&self, character_ids: Vec<u32>) -> Result<()> {
        self.conn
            .call_db(move |c| {
                let tx = c.transaction()?;
                let now = now_s();
                {
                    let mut stmt = tx.prepare(
                        "UPDATE world_sessions SET last_seen_at = :now WHERE character_id = :c",
                    )?;
                    for id in character_ids {
                        stmt.execute(named_params! { ":c": id, ":now": now })?;
                    }
                }
                tx.commit()
            })
            .await
            .context("refreshing world sessions")
    }
}

/// What `begin_world_session` records.
#[derive(Debug, Clone)]
pub struct NewWorldSession {
    pub character_id: u32,
    pub world_id: u32,
    pub zone_id: u32,
    pub map_server: String,
    pub client_ip: String,
    pub conn_seq: u64,
}

#[derive(Debug, Clone, Default)]
pub struct SessionDbSnapshot {
    pub character_name: String,
    pub current_zone_id: u32,
    pub destination_zone_id: u32,
    pub active_linkshell: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(character_id: u32, conn_seq: u64) -> NewWorldSession {
        NewWorldSession {
            character_id,
            world_id: 1,
            zone_id: 133,
            map_server: "127.0.0.1:1989".into(),
            client_ip: "10.0.0.5".into(),
            conn_seq,
        }
    }

    async fn rows(db: &Database) -> Vec<(u32, String, u64)> {
        db.conn_for_test()
            .call_db(|c| {
                let mut st = c.prepare("SELECT character_id, state, conn_seq FROM world_sessions ORDER BY character_id")?;
                st.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get::<_, i64>(2)? as u64)))?
                    .collect::<common::sql::Result<Vec<_>>>()
            })
            .await
            .unwrap()
    }

    #[tokio::test]
    async fn world_sessions_follow_the_lifecycle() {
        let db = Database::open(common::test_db::fresh().await.unwrap()).await.unwrap();
        db.conn_for_test()
            .call_db(|c| {
                c.execute_batch(
                    "INSERT INTO users (id, username, passwordHash) VALUES (1, 'a', 'x'), (2, 'b', 'x');
                     INSERT INTO characters (id, userId, slot, serverId, name) VALUES
                         (10, 1, 0, 1, 'Alpha One'), (11, 1, 1, 1, 'Alpha Two'), (20, 2, 0, 1, 'Beta One');",
                )
            })
            .await
            .unwrap();

        assert_eq!(db.begin_world_session(session(10, 1)).await.unwrap(), None);
        assert_eq!(db.begin_world_session(session(20, 2)).await.unwrap(), None);
        db.world_session_in_world(10).await.unwrap();
        assert_eq!(
            rows(&db).await,
            vec![(10, "in_world".into(), 1), (20, "connecting".into(), 2)]
        );

        // the same account with its other character: one row, the first character named
        assert_eq!(
            db.begin_world_session(session(11, 3)).await.unwrap(),
            Some(10)
        );
        assert_eq!(
            rows(&db).await,
            vec![(11, "connecting".into(), 3), (20, "connecting".into(), 2)]
        );

        // a reconnect of a character: the old connection's disconnect leaves the new session
        db.begin_world_session(session(20, 4)).await.unwrap();
        assert!(!db.end_world_session(20, 2).await.unwrap());
        db.world_session_zoning(20, Some((155, "127.0.0.1:1990".into())))
            .await
            .unwrap();
        assert_eq!(
            rows(&db).await,
            vec![(11, "connecting".into(), 3), (20, "zoning".into(), 4)]
        );
        assert!(db.end_world_session(20, 4).await.unwrap());
        let last: Option<i64> = db
            .conn_for_test()
            .call_db(|c| {
                c.query_row(
                    "SELECT lastActiveAt FROM characters WHERE id = 20",
                    [],
                    |r| r.get(0),
                )
            })
            .await
            .unwrap();
        assert!(last.is_some_and(|t| t > 1_700_000_000));

        db.touch_world_sessions(vec![11]).await.unwrap();
        assert_eq!(db.clear_world_sessions().await.unwrap(), 1);
        drop(db);
    }
}
