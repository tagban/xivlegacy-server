// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Modules: optional features an operator turns on, outside the core game
//! (docs/DESIGN.md, Modules; modules/README.md).
//!
//! ```text
//! modules/<name>/module.toml   name, version, description, hooks
//! modules/<name>/<name>.lua    Lua hooks the map server calls (optional)
//! modules/<name>/sql/*.sql     its own tables, module_<name>_*, applied once each (optional)
//! settings/modules.toml        enabled = ["status", ...]
//! ```
//!
//! A module written in Rust (the `status` module's web route) is compiled
//! into its service and only switched on here.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use serde::Deserialize;

/// `settings/modules.toml`.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ModulesSettings {
    /// The modules to run, by folder name.
    pub enabled: Vec<String>,
    /// Where the module folders are.
    pub folder: PathBuf,
}

impl Default for ModulesSettings {
    fn default() -> Self {
        Self {
            enabled: Vec::new(),
            folder: PathBuf::from("./modules"),
        }
    }
}

/// `modules/<name>/module.toml`.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
struct Manifest {
    name: String,
    version: String,
    #[serde(default)]
    description: String,
    /// The Lua hooks its script defines: on_login, on_zone_in, on_logout.
    #[serde(default)]
    hooks: Vec<String>,
}

/// An enabled module.
#[derive(Debug, Clone)]
pub struct Module {
    pub name: String,
    pub version: String,
    pub description: String,
    pub hooks: Vec<String>,
    pub dir: PathBuf,
    /// `<name>.lua`, if the module has one.
    pub lua: Option<PathBuf>,
    /// `sql/*.sql`, in name order.
    pub sql: Vec<PathBuf>,
}

impl Module {
    pub fn has_hook(&self, hook: &str) -> bool {
        self.hooks.iter().any(|h| h == hook)
    }
}

/// The modules `settings/modules.toml` enables. A listed module that isn't
/// there, or whose module.toml doesn't parse, is an error: a typo shouldn't
/// quietly switch a feature off.
pub fn enabled() -> Result<Vec<Module>> {
    let settings: ModulesSettings = crate::settings::load("modules", None)?;
    settings
        .enabled
        .iter()
        .map(|name| load(&settings.folder, name))
        .collect()
}

/// Whether `name` is enabled (false when the settings can't be read).
pub fn is_enabled(name: &str) -> bool {
    crate::settings::load::<ModulesSettings>("modules", None)
        .map(|s| s.enabled.iter().any(|n| n == name))
        .unwrap_or(false)
}

fn load(folder: &Path, name: &str) -> Result<Module> {
    if name.is_empty()
        || !name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
    {
        bail!("module name {name:?}: letters, digits, _ and - only");
    }
    let dir = folder.join(name);
    let manifest_path = dir.join("module.toml");
    let raw = std::fs::read_to_string(&manifest_path).with_context(|| {
        format!(
            "module {name} is enabled but {} can't be read",
            manifest_path.display()
        )
    })?;
    let m: Manifest =
        toml::from_str(&raw).with_context(|| format!("parsing {}", manifest_path.display()))?;
    if m.name != name {
        bail!(
            "{} names the module {:?}, but its folder is {name:?}",
            manifest_path.display(),
            m.name
        );
    }
    let lua = Some(dir.join(format!("{name}.lua"))).filter(|p| p.exists());
    if !m.hooks.is_empty() && lua.is_none() {
        bail!("module {name} lists hooks but has no {name}.lua");
    }
    let mut sql: Vec<PathBuf> = match std::fs::read_dir(dir.join("sql")) {
        Ok(rd) => rd
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|x| x == "sql"))
            .collect(),
        Err(_) => Vec::new(),
    };
    sql.sort();
    Ok(Module {
        name: m.name,
        version: m.version,
        description: m.description,
        hooks: m.hooks,
        dir,
        lua,
        sql,
    })
}

/// Apply the enabled modules' SQL files that haven't been, recording each in
/// `schema_migrations` as `module/<name>/<file>`, the same way as the core
/// migrations. Run by `db::open_or_create` after the core migrations.
pub fn apply_sql(c: &mut crate::sql::Conn, modules: &[Module]) -> Result<usize> {
    let tx = c.transaction_with_behavior(crate::sql::TransactionBehavior::Immediate)?;
    let mut applied = 0;
    for m in modules {
        for path in &m.sql {
            let file = path
                .file_name()
                .map(|f| f.to_string_lossy().into_owned())
                .unwrap_or_default();
            let key = format!("module/{}/{file}", m.name);
            let done: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE name = ?1)",
                [&key],
                |r| r.get(0),
            )?;
            if done {
                continue;
            }
            let sql = std::fs::read_to_string(path)
                .with_context(|| format!("reading {}", path.display()))?;
            tx.execute_batch(&sql)
                .with_context(|| format!("applying {}", path.display()))?;
            tx.execute("INSERT INTO schema_migrations(name) VALUES(?1)", [&key])?;
            tracing::info!(migration = %key, "module migration applied");
            applied += 1;
        }
    }
    tx.commit()?;
    Ok(applied)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn module_dir(root: &Path, name: &str, manifest: &str) -> PathBuf {
        let dir = root.join(name);
        std::fs::create_dir_all(dir.join("sql")).unwrap();
        std::fs::write(dir.join("module.toml"), manifest).unwrap();
        dir
    }

    #[tokio::test]
    async fn loads_a_module_and_applies_its_sql_once() {
        let root = crate::test_tmp::dir().join(format!("xivl-modules-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let dir = module_dir(
            &root,
            "greet",
            "name = \"greet\"\nversion = \"1.0\"\ndescription = \"hi\"\nhooks = [\"on_login\"]\n",
        );
        std::fs::write(dir.join("greet.lua"), "function on_login(player) end\n").unwrap();
        std::fs::write(
            dir.join("sql/001_seen.sql"),
            "CREATE TABLE module_greet_seen (id INTEGER);\n",
        )
        .unwrap();
        let m = load(&root, "greet").unwrap();
        assert!(m.has_hook("on_login") && m.lua.is_some() && m.sql.len() == 1);

        let conn = crate::sql::Connection::open(&crate::test_db::empty().await.unwrap())
            .await
            .unwrap();
        conn.call(|c| {
            c.execute_batch(
                "CREATE TABLE schema_migrations (name VARCHAR(255) PRIMARY KEY, \
                 checksum VARCHAR(32) NOT NULL DEFAULT '', applied_at TEXT)",
            )
        })
        .await
        .unwrap();
        let (m1, m2) = (m.clone(), m);
        let first = conn
            .call(move |c| Ok(apply_sql(c, std::slice::from_ref(&m1)).unwrap()))
            .await
            .unwrap();
        let again = conn
            .call(move |c| Ok(apply_sql(c, &[m2]).unwrap()))
            .await
            .unwrap();
        assert_eq!((first, again), (1, 0));

        module_dir(&root, "bad", "name = \"other\"\nversion = \"1\"\n");
        assert!(load(&root, "bad").is_err());
        assert!(load(&root, "missing").is_err());
        assert!(load(&root, "../etc").is_err());
        std::fs::remove_dir_all(&root).unwrap();
    }

    /// Every module shipped in modules/ applies on the MariaDB baseline. The
    /// bug report table also takes the held-back i64::MAX in nextTryAt.
    #[tokio::test]
    async fn shipped_module_sql_applies_on_mariadb() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../modules");
        let mut modules = Vec::new();
        for e in std::fs::read_dir(&root).unwrap() {
            let e = e.unwrap();
            if e.path().join("module.toml").is_file() {
                modules.push(load(&root, &e.file_name().to_string_lossy()).unwrap());
            }
        }
        assert!(
            modules
                .iter()
                .any(|m| m.name == "bugreport" && !m.sql.is_empty())
        );
        let conn = crate::sql::Connection::open(&crate::test_db::fresh().await.unwrap())
            .await
            .unwrap();
        let count = modules.iter().map(|m| m.sql.len()).sum::<usize>();
        let applied = conn
            .call(move |c| Ok(apply_sql(c, &modules).unwrap()))
            .await
            .unwrap();
        assert_eq!(applied, count);
        let held: i64 = conn
            .call(|c| {
                c.execute(
                    "INSERT INTO module_bugreport_reports(userId, characterId, characterName, \
                     zoneId, createdAt, nextTryAt) VALUES(1, 9, 'God Washere', 128, 1, ?1)",
                    [i64::MAX],
                )?;
                c.query_row("SELECT nextTryAt FROM module_bugreport_reports", [], |r| {
                    r.get(0)
                })
            })
            .await
            .unwrap();
        assert_eq!(held, i64::MAX);
    }
}
