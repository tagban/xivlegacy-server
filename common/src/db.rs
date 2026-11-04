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

//! MariaDB setup shared by every server.
//!
//! `open_or_create` is the entry point. It creates the database if the
//! server account may, lays down the baseline schema on an empty database,
//! reloads every game-data file whose contents changed, applies new
//! numbered migrations, then the enabled modules' SQL. The whole pass runs
//! under a MariaDB named lock, so four servers booting together take turns
//! instead of racing.
//!
//! `ConnCallExt::call_db` is the shape every `database.rs` uses to run its
//! queries on the connection's worker thread.

use std::future::Future;
use std::time::Instant;

use anyhow::{Context, Result, bail};

use crate::migrations;
pub use crate::sql::Connection;
use crate::sql::{self, Conn, OptionalExtension, named_params};

const BOOKKEEPING_DDL: &str = r#"
CREATE TABLE IF NOT EXISTS schema_migrations (
    name       VARCHAR(255) NOT NULL PRIMARY KEY,
    checksum   VARCHAR(32)  NOT NULL DEFAULT '',
    applied_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS static_data_versions (
    name      VARCHAR(255) NOT NULL PRIMARY KEY,
    checksum  VARCHAR(32)  NOT NULL,
    loaded_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"#;

/// Seconds a booting server waits for another one's setup pass.
const SETUP_LOCK_WAIT_SECS: u32 = 300;

/// The server part of a database URL (everything before the database name),
/// for creating the database itself.
fn server_url(url: &str) -> (String, String) {
    let (base, query) = match url.split_once('?') {
        Some((b, q)) => (b, format!("?{q}")),
        None => (url, String::new()),
    };
    let (scheme, rest) = base.split_once("://").unwrap_or(("mysql", base));
    let (authority, db) = rest.split_once('/').unwrap_or((rest, ""));
    (format!("{scheme}://{authority}/{query}"), db.to_string())
}

/// Create the database named in `url` when it doesn't exist and the account
/// is allowed to. A missing grant is fine when the database already exists.
pub async fn ensure_database(url: &str) -> Result<()> {
    let (server, name) = server_url(url);
    if name.is_empty() {
        bail!("the database url names no database");
    }
    if !name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_') {
        bail!("database name {name:?} may only use letters, digits and _");
    }
    let admin = Connection::open(&server)
        .await
        .with_context(|| format!("connecting to the MariaDB server for database {name}"))?;
    let create = format!(
        "CREATE DATABASE IF NOT EXISTS `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    );
    if let Err(e) = admin.call(move |c| c.execute_batch(&create)).await {
        tracing::debug!(error = %e, database = %name, "could not create the database; assuming it exists");
    }
    Ok(())
}

/// Open the database at `url`, creating and bringing it up to date first.
pub async fn open_or_create(url: impl AsRef<str>) -> Result<Connection> {
    let url = url.as_ref();
    ensure_database(url).await?;
    let conn = Connection::open(url)
        .await
        .with_context(|| format!("opening database {}", sql::database_name(url)))?;
    setup(&conn).await?;
    Ok(conn)
}

/// Bring an open database up to date (see the module docs).
pub async fn setup(conn: &Connection) -> Result<()> {
    let got: Option<i64> = conn
        .call(|c| c.query_row(
                &format!("SELECT GET_LOCK(CONCAT('xivlegacy_setup_', DATABASE()), {SETUP_LOCK_WAIT_SECS})"),
                (),
                |r| r.get(0),
            ))
        .await
        .context("taking the database setup lock")?;
    if got != Some(1) {
        bail!("another server held the database setup lock for {SETUP_LOCK_WAIT_SECS}s");
    }
    let result = setup_locked(conn).await;
    let _ = conn
        .call(|c| c.execute_batch("DO RELEASE_LOCK(CONCAT('xivlegacy_setup_', DATABASE()))"))
        .await;
    result
}

async fn setup_locked(conn: &Connection) -> Result<()> {
    let fresh: bool = conn
        .call(|c| {
            c.query_row(
                "SELECT COUNT(*) = 0 FROM information_schema.tables \
                 WHERE table_schema = DATABASE() AND table_name = 'schema_migrations'",
                (),
                |r| r.get(0),
            )
        })
        .await
        .context("checking for an empty database")?;

    if fresh {
        tracing::info!("empty database: laying down the baseline schema");
        let schema = migrations::schema();
        conn.call(move |c| c.execute_batch(&schema))
            .await
            .context("applying the baseline schema (sql/schema.sql)")?;
    }
    conn.call(|c| c.execute_batch(BOOKKEEPING_DDL))
        .await
        .context("creating schema_migrations and static_data_versions")?;
    reload_data(conn).await?;
    apply_migrations(conn).await?;

    let modules = crate::modules::enabled()?;
    if modules.iter().any(|m| !m.sql.is_empty()) {
        conn.call(move |c| Ok(crate::modules::apply_sql(c, &modules)))
            .await
            .context("applying module migrations")??;
    }
    Ok(())
}

/// Reload every game-data file whose text changed since it was last loaded.
pub async fn reload_data(conn: &Connection) -> Result<usize> {
    let files: Vec<(String, String, String)> = migrations::data()
        .map(|f| (f.name.to_string(), migrations::checksum(&f.sql), f.sql))
        .collect();
    let reloaded = conn
        .call(move |c| {
            let mut n = 0;
            for (name, sum, body) in &files {
                let have: Option<String> = c
                    .query_row(
                        "SELECT checksum FROM static_data_versions WHERE name = :n",
                        named_params! { ":n": name },
                        |r| r.get(0),
                    )
                    .optional()?;
                if have.as_deref() == Some(sum.as_str()) {
                    continue;
                }
                let started = Instant::now();
                let tx = c.unchecked_transaction()?;
                tx.execute_batch(body)
                    .map_err(|e| sql::Error::Other(format!("loading sql/data/{name}: {e}")))?;
                tx.execute(
                    "INSERT INTO static_data_versions (name, checksum) VALUES (:n, :c) \
                     ON DUPLICATE KEY UPDATE checksum = VALUES(checksum), loaded_at = CURRENT_TIMESTAMP",
                    named_params! { ":n": name, ":c": sum },
                )?;
                tx.commit()?;
                tracing::info!(file = %name, took_ms = started.elapsed().as_millis() as u64, "game data loaded");
                n += 1;
            }
            Ok(n)
        })
        .await
        .context("reloading game data")?;
    if reloaded > 0 {
        tracing::info!(files = reloaded, "game data reloaded");
    }
    Ok(reloaded)
}

/// Apply each bundled migration not yet recorded in `schema_migrations`.
/// A recorded migration whose text has since changed stops the boot: edit
/// a released migration by adding a new one.
pub async fn apply_migrations(conn: &Connection) -> Result<usize> {
    let files: Vec<(String, String, String)> = migrations::iter()
        .map(|m| (m.name.to_string(), migrations::checksum(&m.sql), m.sql))
        .collect();
    let total = files.len();
    let applied_now = conn
        .call(move |c| {
            let mut count = 0usize;
            for (name, sum, body) in &files {
                let have: Option<String> = c
                    .query_row(
                        "SELECT checksum FROM schema_migrations WHERE name = :n",
                        named_params! { ":n": name },
                        |r| r.get(0),
                    )
                    .optional()?;
                match have {
                    Some(h) if h == *sum || h.is_empty() => continue,
                    Some(h) => {
                        return Err(sql::Error::Other(format!(
                            "migration {name} was changed after it was applied \
                             (recorded {h}, bundled {sum}); add a new migration instead"
                        )));
                    }
                    None => {}
                }
                let started = Instant::now();
                c.execute_batch(body)
                    .map_err(|e| sql::Error::Other(format!("migration {name} failed: {e}")))?;
                c.execute(
                    "INSERT INTO schema_migrations (name, checksum) VALUES (:n, :c)",
                    named_params! { ":n": name, ":c": sum },
                )?;
                tracing::info!(
                    migration = %name,
                    took_ms = started.elapsed().as_millis() as u64,
                    "migration applied",
                );
                count += 1;
            }
            Ok(count)
        })
        .await
        .context("applying migrations")?;
    tracing::info!(
        total_bundled = total,
        newly_applied = applied_now,
        "migration pass complete"
    );
    Ok(applied_now)
}

/// Pins the closure's error type to [`sql::Error`] and the result to
/// `anyhow`, so query closures don't need type annotations.
pub trait ConnCallExt {
    fn call_db<F, R>(&self, f: F) -> impl Future<Output = Result<R>> + Send
    where
        F: FnOnce(&mut Conn) -> sql::Result<R> + Send + 'static,
        R: Send + 'static;
}

impl ConnCallExt for Connection {
    #[allow(clippy::manual_async_fn)]
    fn call_db<F, R>(&self, f: F) -> impl Future<Output = Result<R>> + Send
    where
        F: FnOnce(&mut Conn) -> sql::Result<R> + Send + 'static,
        R: Send + 'static,
    {
        async move { self.call(f).await.map_err(anyhow::Error::from) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn count(conn: &Connection, sql: &'static str) -> i64 {
        conn.call(move |c| c.query_row(sql, (), |r| r.get(0)))
            .await
            .unwrap()
    }

    #[tokio::test]
    async fn setup_lays_down_an_empty_database() {
        let url = crate::test_db::empty().await.unwrap();
        let conn = open_or_create(&url).await.unwrap();

        let migrations = count(&conn, "SELECT COUNT(*) FROM schema_migrations").await;
        assert_eq!(
            migrations as usize,
            migrations::count(),
            "every bundled migration recorded"
        );
        let data = count(&conn, "SELECT COUNT(*) FROM static_data_versions").await;
        assert_eq!(
            data as usize,
            migrations::data().count(),
            "every data file loaded"
        );
        assert!(count(&conn, "SELECT COUNT(*) FROM gamedata_items").await > 0);
        // Migration 001 ran on top of the baseline.
        let job_col = count(
            &conn,
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() \
             AND table_name = 'characters_parametersave' AND column_name = 'currentJob'",
        )
        .await;
        assert_eq!(job_col, 1);

        // A second boot finds nothing to do.
        assert_eq!(reload_data(&conn).await.unwrap(), 0);
        assert_eq!(apply_migrations(&conn).await.unwrap(), 0);
    }

    #[tokio::test]
    async fn a_changed_data_file_is_reloaded() {
        let conn = crate::test_db::open_fresh().await.unwrap();
        let file = migrations::data().next().unwrap();
        let table = file.name.trim_end_matches(".sql").to_string();
        let name = file.name.to_string();
        let before: i64 = {
            let t = table.clone();
            conn.call(move |c| {
                c.query_row(&format!("SELECT COUNT(*) FROM \"{t}\""), (), |r| r.get(0))
            })
            .await
            .unwrap()
        };
        assert!(before > 0, "{table} has rows to lose");
        {
            let t = table.clone();
            conn.call(move |c| {
                c.execute_batch(&format!("DELETE FROM \"{t}\""))?;
                c.execute(
                    "UPDATE static_data_versions SET checksum = 'stale' WHERE name = :n",
                    named_params! { ":n": name },
                )
            })
            .await
            .unwrap();
        }

        assert_eq!(
            reload_data(&conn).await.unwrap(),
            1,
            "only the changed file reloads"
        );
        let after: i64 = conn
            .call(move |c| {
                c.query_row(&format!("SELECT COUNT(*) FROM \"{table}\""), (), |r| {
                    r.get(0)
                })
            })
            .await
            .unwrap();
        assert_eq!(after, before);
    }

    #[tokio::test]
    async fn an_edited_migration_is_refused() {
        let conn = crate::test_db::open_fresh().await.unwrap();
        let name = migrations::iter().next().unwrap().name.to_string();
        let n2 = name.clone();
        conn.call(move |c| {
            c.execute(
                "UPDATE schema_migrations SET checksum = 'edited' WHERE name = :n",
                named_params! { ":n": n2 },
            )
        })
        .await
        .unwrap();
        let err = format!("{:#}", apply_migrations(&conn).await.unwrap_err());
        assert!(
            err.contains(&name) && err.contains("changed after it was applied"),
            "{err}"
        );
    }

    #[test]
    fn server_url_splits_off_the_database() {
        assert_eq!(
            server_url("mysql://u:p@127.0.0.1:3306/xivlegacy"),
            (
                "mysql://u:p@127.0.0.1:3306/".to_string(),
                "xivlegacy".to_string()
            )
        );
        assert_eq!(
            server_url("mysql://u:p@h/db?socket=/tmp/m.sock"),
            (
                "mysql://u:p@h/?socket=/tmp/m.sock".to_string(),
                "db".to_string()
            )
        );
    }
}
