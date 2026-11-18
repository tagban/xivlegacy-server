// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Throwaway MariaDB databases for tests.
//!
//! [`fresh`] hands each test its own database holding the full baseline and
//! game data. Building that from SQL takes a couple of seconds, so it is
//! built once into a template database (named after a checksum of the
//! bundled SQL, kept between runs). Each test process keeps a small pool of
//! copies: when the last connection to a test's database closes, the
//! database is reset to the template's contents and handed to a later test,
//! because creating 75 InnoDB tables per test is slow. A process's
//! databases are dropped when it exits; a crashed run's are swept by the
//! next one.
//!
//! The MariaDB server comes from `XIVLEGACY_TEST_DB_URL`
//! (`mysql://user:pass@host:port/`), else `XIV_DB_ADMIN_URL` in
//! `~/.config/xivlegacy/db.env`. The account needs rights on databases
//! named `xivlegacy%`.

use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use tokio::sync::OnceCell;

use crate::sql::Connection;

static CREATED: Mutex<Vec<String>> = Mutex::new(Vec::new());
static COUNTER: AtomicUsize = AtomicUsize::new(0);
static TEMPLATE: OnceCell<String> = OnceCell::const_new();
static SERVER: std::sync::OnceLock<String> = std::sync::OnceLock::new();

unsafe extern "C" {
    fn atexit(cb: extern "C" fn()) -> std::ffi::c_int;
    fn kill(pid: i32, sig: i32) -> std::ffi::c_int;
}

/// The MariaDB server URL tests use, ending in `/`.
pub fn server_url() -> String {
    SERVER
        .get_or_init(|| {
            let url = std::env::var("XIVLEGACY_TEST_DB_URL").ok().or_else(|| {
                let home = std::env::var("HOME").ok()?;
                let env =
                    std::fs::read_to_string(format!("{home}/.config/xivlegacy/db.env")).ok()?;
                env.lines().find_map(|l| {
                    l.strip_prefix("XIV_DB_ADMIN_URL=")
                        .map(|s| s.trim().to_string())
                })
            });
            let mut url = url.unwrap_or_else(|| "mysql://xivlegacy@127.0.0.1:3306/".to_string());
            if !url.ends_with('/') {
                url.push('/');
            }
            url
        })
        .clone()
}

fn bundle_checksum() -> String {
    let mut all = crate::migrations::schema();
    for f in crate::migrations::data() {
        all.push_str(f.name);
        all.push_str(&f.sql);
    }
    for f in crate::migrations::iter() {
        all.push_str(f.name);
        all.push_str(&f.sql);
    }
    crate::migrations::checksum(&all)
}

extern "C" fn drop_created() {
    let names = std::mem::take(&mut *CREATED.lock().unwrap_or_else(|e| e.into_inner()));
    if names.is_empty() {
        return;
    }
    if let Ok(opts) = mysql::Opts::from_url(&server_url())
        && let Ok(mut c) = mysql::Conn::new(opts)
    {
        use mysql::prelude::Queryable;
        for n in names {
            let _ = c.query_drop(format!("DROP DATABASE IF EXISTS `{n}`"));
        }
    }
}

async fn admin() -> Result<Connection> {
    Connection::open(&server_url())
        .await
        .context("connecting to the test MariaDB server (set XIVLEGACY_TEST_DB_URL)")
}

/// Drop test databases left by processes that are no longer running, and
/// templates built from older SQL.
async fn sweep(admin: &Connection, keep_template: String) -> Result<()> {
    let names: Vec<String> = admin
        .call(|c| {
            let mut st = c.prepare("SHOW DATABASES LIKE 'xivlegacy\\_t%'")?;
            st.query_map((), |r| r.get(0))?.collect()
        })
        .await?;
    for n in names {
        let stale = if let Some(rest) = n.strip_prefix("xivlegacy_t_") {
            let pid: i32 = rest
                .split('_')
                .next()
                .and_then(|p| p.parse().ok())
                .unwrap_or(0);
            // SAFETY: signal 0 only asks whether the process exists.
            pid > 0 && unsafe { kill(pid, 0) } != 0
        } else if n.starts_with("xivlegacy_tpl_") {
            n != keep_template
        } else {
            false
        };
        if stale {
            let sql = format!("DROP DATABASE IF EXISTS `{n}`");
            let _ = admin.call(move |c| c.execute_batch(&sql)).await;
        }
    }
    Ok(())
}

async fn template() -> Result<String> {
    TEMPLATE
        .get_or_try_init(|| async {
            let name = format!("xivlegacy_tpl_{}", bundle_checksum());
            let admin = admin().await?;
            // Several test binaries may start at once; one builds the template.
            admin
                .call(|c| {
                    c.query_row("SELECT GET_LOCK('xivlegacy_test_template', 600)", (), |r| {
                        r.get::<_, i64>(0)
                    })
                })
                .await?;
            let result = async {
                let _ = sweep(&admin, name.clone()).await;
                let check = name.clone();
                let ready: bool = admin
                    .call(move |c| {
                        c.query_row(
                            "SELECT COUNT(*) > 0 FROM information_schema.tables \
                             WHERE table_schema = :db AND table_name = '_template_ready'",
                            crate::sql::named_params! { ":db": check },
                            |r| r.get(0),
                        )
                    })
                    .await?;
                if !ready {
                    let drop = format!("DROP DATABASE IF EXISTS `{name}`");
                    admin.call(move |c| c.execute_batch(&drop)).await?;
                    let url = format!("{}{name}", server_url());
                    let conn = crate::db::open_or_create(&url).await?;
                    conn.call(|c| {
                        c.execute_batch("CREATE TABLE _template_ready (id INT PRIMARY KEY)")
                    })
                    .await?;
                }
                anyhow::Ok(name.clone())
            }
            .await;
            let _ = admin
                .call(|c| c.execute_batch("DO RELEASE_LOCK('xivlegacy_test_template')"))
                .await;
            result
        })
        .await
        .cloned()
}

fn next_name() -> String {
    let n = COUNTER.fetch_add(1, Ordering::Relaxed);
    let name = format!("xivlegacy_t_{}_{n}", std::process::id());
    let mut created = CREATED.lock().unwrap_or_else(|e| e.into_inner());
    if created.is_empty() && n == 0 {
        // SAFETY: registers a plain function with the C runtime.
        unsafe {
            atexit(drop_created);
        }
    }
    created.push(name.clone());
    name
}

/// What a reset needs to know about the template: every table, and the
/// checksum of each table that holds game data.
struct TemplateInfo {
    tables: Vec<String>,
    data: HashMap<String, Option<i64>>,
}

static TEMPLATE_INFO: OnceCell<TemplateInfo> = OnceCell::const_new();

async fn template_info(tpl: &str) -> Result<&'static TemplateInfo> {
    TEMPLATE_INFO
        .get_or_try_init(|| async {
            let admin = admin().await?;
            let tpl = tpl.to_string();
            let info = admin
                .call(move |c| {
                    let tables: Vec<String> = {
                        let mut st = c.prepare(
                            "SELECT table_name FROM information_schema.tables \
                             WHERE table_schema = :db AND table_type = 'BASE TABLE' \
                             AND table_name <> '_template_ready' ORDER BY table_name",
                        )?;
                        st.query_map(crate::sql::named_params! { ":db": tpl }, |r| r.get(0))?
                            .collect::<crate::sql::Result<_>>()?
                    };
                    let mut data = HashMap::new();
                    for t in &tables {
                        let rows: i64 =
                            c.query_row(&format!("SELECT COUNT(*) FROM `{tpl}`.`{t}`"), (), |r| {
                                r.get(0)
                            })?;
                        if rows > 0 {
                            let sum: Option<i64> =
                                c.query_row(&format!("CHECKSUM TABLE `{tpl}`.`{t}`"), (), |r| {
                                    r.get(1)
                                })?;
                            data.insert(t.clone(), sum);
                        }
                    }
                    Ok(TemplateInfo { tables, data })
                })
                .await?;
            anyhow::Ok(info)
        })
        .await
}

/// Test databases this process made, and who has them open. A database
/// goes back to the pool when its last connection closes, and is reset to
/// the template's contents when it is handed out again.
#[derive(Default)]
struct Pool {
    all: HashSet<String>,
    open: HashMap<String, usize>,
    free: VecDeque<(String, Instant)>,
}

static POOL: Mutex<Option<Pool>> = Mutex::new(None);

fn with_pool<R>(f: impl FnOnce(&mut Pool) -> R) -> R {
    let mut g = POOL.lock().unwrap_or_else(|e| e.into_inner());
    f(g.get_or_insert_with(Pool::default))
}

/// A connection to `db` opened (called by `sql::Connection`).
pub(crate) fn note_open(db: &str) {
    with_pool(|p| {
        if p.all.contains(db) {
            *p.open.entry(db.to_string()).or_default() += 1;
            p.free.retain(|(n, _)| n != db);
        }
    });
}

/// A connection to `db` closed (called by `sql::Connection`).
pub(crate) fn note_close(db: &str) {
    with_pool(|p| {
        if let Some(n) = p.open.get_mut(db) {
            *n = n.saturating_sub(1);
            if *n == 0 {
                p.open.remove(db);
                p.free.push_back((db.to_string(), Instant::now()));
            }
        }
    });
}

/// A pooled database whose last connection closed a while ago. The wait
/// leaves a test that drops its database and reopens it at once (to check
/// what was saved) with the database it had.
fn take_free() -> Option<String> {
    with_pool(|p| {
        let idx = p
            .free
            .iter()
            .position(|(_, at)| at.elapsed() > Duration::from_secs(2))?;
        p.free.remove(idx).map(|(n, _)| n)
    })
}

/// Put a used database back to the template's contents: empty every table
/// the template has empty, reload any game-data table a test changed, and
/// drop tables a test added.
async fn reset(name: &str, tpl: &str) -> Result<()> {
    let info = template_info(tpl).await?;
    let admin = admin().await?;
    let (name, tpl) = (name.to_string(), tpl.to_string());
    admin
        .call(move |c| {
            let here: Vec<(String, Option<i64>)> = {
                let mut st = c.prepare(
                    "SELECT table_name, auto_increment FROM information_schema.tables \
                     WHERE table_schema = :db AND table_type = 'BASE TABLE'",
                )?;
                st.query_map(crate::sql::named_params! { ":db": name }, |r| Ok((r.get(0)?, r.get(1)?)))?
                    .collect::<crate::sql::Result<_>>()?
            };
            let mut script = String::from(
                "SET SESSION sql_mode = CONCAT(@@sql_mode, ',NO_AUTO_VALUE_ON_ZERO'); SET FOREIGN_KEY_CHECKS = 0;\n",
            );
            for (t, auto) in &here {
                if !info.tables.contains(t) {
                    script.push_str(&format!("DROP TABLE `{name}`.`{t}`;\n"));
                    continue;
                }
                if let Some(want) = info.data.get(t) {
                    let have: Option<i64> =
                        c.query_row(&format!("CHECKSUM TABLE `{name}`.`{t}`"), (), |r| r.get(1))?;
                    if have != *want {
                        script.push_str(&format!(
                            "DELETE FROM `{name}`.`{t}`; INSERT INTO `{name}`.`{t}` SELECT * FROM `{tpl}`.`{t}`;\n"
                        ));
                    }
                } else {
                    script.push_str(&format!("DELETE FROM `{name}`.`{t}`;\n"));
                    if auto.is_some_and(|a| a > 1) {
                        script.push_str(&format!("ALTER TABLE `{name}`.`{t}` AUTO_INCREMENT = 1;\n"));
                    }
                }
            }
            script.push_str("SET FOREIGN_KEY_CHECKS = 1;\n");
            c.execute_batch(&script)
        })
        .await?;
    Ok(())
}

/// A database holding the baseline schema and game data and nothing else:
/// a reset one from the pool, or a new copy of the template.
pub async fn fresh() -> Result<String> {
    let tpl = template().await?;
    if let Some(name) = take_free() {
        reset(&name, &tpl)
            .await
            .with_context(|| format!("resetting test database {name}"))?;
        return Ok(format!("{}{name}", server_url()));
    }
    let name = next_name();
    let admin = admin().await?;
    let (tpl2, name2) = (tpl.clone(), name.clone());
    admin
        .call(move |c| {
            c.execute_batch(&format!(
                "CREATE DATABASE `{name2}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            ))?;
            let tables: Vec<String> = {
                let mut st = c.prepare(
                    "SELECT table_name FROM information_schema.tables \
                     WHERE table_schema = :db AND table_type = 'BASE TABLE' AND table_name <> '_template_ready'",
                )?;
                st.query_map(crate::sql::named_params! { ":db": tpl2 }, |r| r.get(0))?
                    .collect::<crate::sql::Result<_>>()?
            };
            let mut script = String::from("SET SESSION sql_mode = CONCAT(@@sql_mode, ',NO_AUTO_VALUE_ON_ZERO');\n");
            for t in &tables {
                script.push_str(&format!("CREATE TABLE `{name2}`.`{t}` LIKE `{tpl2}`.`{t}`;\n"));
                script.push_str(&format!("INSERT INTO `{name2}`.`{t}` SELECT * FROM `{tpl2}`.`{t}`;\n"));
            }
            c.execute_batch(&script)
        })
        .await
        .with_context(|| format!("copying test database {name} from {tpl}"))?;
    with_pool(|p| {
        p.all.insert(name.clone());
    });
    Ok(format!("{}{name}", server_url()))
}

/// [`fresh`] for synchronous callers (test helpers that return a URL).
pub fn fresh_blocking() -> String {
    std::thread::spawn(|| {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("test runtime")
            .block_on(fresh())
            .expect("creating a test database")
    })
    .join()
    .expect("test database thread")
}

/// The URL of a new, empty database (no schema at all).
pub async fn empty() -> Result<String> {
    let name = next_name();
    let admin = admin().await?;
    let create =
        format!("CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    admin.call(move |c| c.execute_batch(&create)).await?;
    Ok(format!("{}{name}", server_url()))
}

/// A connection to a new database holding the baseline and game data.
pub async fn open_fresh() -> Result<Connection> {
    let url = fresh().await?;
    Ok(Connection::open(&url).await?)
}
