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

use std::net::IpAddr;
use std::path::{Path, PathBuf};

use anyhow::Result;
use clap::Parser;
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
#[derive(Default)]
pub struct Config {
    pub server: ServerSection,
    pub database: DatabaseSection,
    pub scripting: ScriptingSection,
    pub world: WorldSection,
    pub progression: crate::gameplay::ProgressionSection,
    pub storage: crate::gameplay::StorageSection,
    pub economy: crate::gameplay::EconomySection,
    pub drops: crate::gameplay::DropsSection,
    pub anima: AnimaSection,
    pub atomos: crate::atomos::AtomosSection,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ServerSection {
    pub bind_ip: String,
    pub port: u16,
    pub show_timestamp: bool,
    pub world_id: u32,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct DatabaseSection {
    /// The MariaDB database, as `mysql://user:password@host:port/database`.
    /// `XIVLEGACY_DB_URL` in the environment takes its place when set.
    pub url: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ScriptingSection {
    /// Filesystem root of the Lua script tree (`scripts/`).
    pub script_root: PathBuf,
    /// When `false`, skip the DB loaders + `spawn_all_actors`. Used by the
    /// integration test harness.
    pub load_from_database: bool,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct WorldSection {
    /// Dalamud stage emitted at zone-in (`SetDalamud`, 0x0010) when
    /// `dalamud_by_story` is off: the client's sky group index, 0-7
    /// (4 = a small orange star, 5 and 6 bigger, 0 and 7 the big red moon
    /// of 1.0's last days; 1-3 draw nothing), and -1 or any value past 7
    /// hides Dalamud. See `crate::dalamud`.
    pub dalamud_phase: i8,
    /// When true (the default) each player's Dalamud grows with their
    /// main story progress (`crate::dalamud::stage_for_story`) and
    /// `dalamud_phase` is unused.
    pub dalamud_by_story: bool,
    /// Weather id emitted at zone-in (`SetWeather`, 0x000D). Default 1 = clear.
    pub weather_id: u16,
    /// Weather transition time emitted alongside `weather_id`. Default 1.
    pub weather_transition: u16,
}

/// `[anima]`: the teleport currency (crate::runtime::anima).
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct AnimaSection {
    /// Off: teleports and gate hops cost nothing and the menu shows full.
    pub enabled: bool,
    /// The most anima a character can store (1.x: 100), held to 100..=255.
    pub max_stored: i64,
    /// Minutes per anima regained (1.x: 240), at least 1.
    pub regen_minutes: i64,
}

impl Default for AnimaSection {
    fn default() -> Self {
        Self {
            enabled: true,
            max_stored: 200,
            regen_minutes: crate::runtime::anima::RETAIL_REGEN_SECS / 60,
        }
    }
}

impl Default for ServerSection {
    fn default() -> Self {
        Self {
            bind_ip: "127.0.0.1".to_string(),
            port: 1989,
            show_timestamp: true,
            world_id: 1,
        }
    }
}

impl Default for DatabaseSection {
    fn default() -> Self {
        Self {
            url: common::sql::DEFAULT_URL.to_string(),
        }
    }
}

impl Default for ScriptingSection {
    fn default() -> Self {
        Self {
            script_root: PathBuf::from("./scripts"),
            load_from_database: true,
        }
    }
}

impl Default for WorldSection {
    fn default() -> Self {
        Self {
            dalamud_phase: 0,
            dalamud_by_story: true,
            weather_id: 1,
            weather_transition: 1,
        }
    }
}

impl Config {
    pub fn bind_ip(&self) -> &str {
        &self.server.bind_ip
    }
    pub fn port(&self) -> u16 {
        self.server.port
    }
    /// The database URL to connect to (see `DatabaseSection::url`).
    pub fn db_url(&self) -> String {
        common::sql::configured_url(&self.database.url)
    }
    pub fn script_root(&self) -> &Path {
        &self.scripting.script_root
    }
    pub fn load_from_database(&self) -> bool {
        self.scripting.load_from_database
    }
    #[allow(dead_code)]
    pub fn world_id(&self) -> u32 {
        self.server.world_id
    }

    /// `settings/default/map.toml` with the operator's overrides over it
    /// (`override_path`, else `settings/map.toml`): see `common::settings`.
    pub fn load(override_path: Option<&Path>) -> Result<Self> {
        common::settings::load("map", override_path)
    }

    pub fn apply_launch_args(&mut self, args: LaunchArgs) {
        if let Some(ip) = args.ip
            && ip.parse::<IpAddr>().is_ok()
        {
            self.server.bind_ip = ip;
        }
        if let Some(port) = args.port {
            self.server.port = port;
        }
        if let Some(db) = args.db_url {
            self.database.url = db;
        }
        if let Some(world_id) = args.world_id {
            self.server.world_id = world_id;
        }
    }
}

#[derive(Parser, Debug, Clone, Default)]
#[command(version, about = "FFXIV 1.23b map server", long_about = None)]
pub struct LaunchArgs {
    #[arg(long)]
    pub ip: Option<String>,
    #[arg(long)]
    pub port: Option<u16>,
    /// Override the database URL (mysql://user:password@host:port/database)
    #[arg(long = "db-url")]
    pub db_url: Option<String>,
    #[arg(long = "world-id")]
    pub world_id: Option<u32>,
    /// Boot only far enough to validate config + DB + content load, print a
    /// SMOKE_OK / SMOKE_FAIL marker, then exit (CI/dev fail-fast).
    #[arg(long)]
    pub smoke: bool,
    /// Suppress the interactive stdin console reader.
    #[arg(long = "no-console")]
    pub no_console: bool,
    /// Override file merged over settings/default/map.toml (default:
    /// settings/map.toml)
    #[arg(long)]
    pub config: Option<PathBuf>,
}
