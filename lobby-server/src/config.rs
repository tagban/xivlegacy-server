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

/// Runtime configuration for the lobby server.
///
/// Loaded from a TOML file via `Config::load`; missing sections/fields fall
/// back to the `Default` impl below so a fresh checkout boots against
/// localhost without any config file at all.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
#[derive(Default)]
pub struct Config {
    pub server: ServerSection,
    pub database: DatabaseSection,
    pub servers: ServersSection,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ServerSection {
    pub bind_ip: String,
    pub port: u16,
    /// Preserved for round-trip config writes — the tracing subscriber owns
    /// timestamp formatting so this value is not consulted directly.
    pub show_timestamp: bool,
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
pub struct ServersSection {
    /// Path to the server-list TOML (the worlds shown at character select).
    /// Falls back to a built-in localhost world if the file is missing.
    pub path: PathBuf,
}

impl Default for ServerSection {
    fn default() -> Self {
        Self {
            bind_ip: "127.0.0.1".to_string(),
            port: 54994,
            show_timestamp: true,
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

impl Default for ServersSection {
    fn default() -> Self {
        Self {
            path: PathBuf::new(),
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
    /// A server list file to use over the defaults instead of
    /// settings/servers.toml (`[servers] path`; unset: None).
    pub fn servers_path(&self) -> Option<&Path> {
        (!self.servers.path.as_os_str().is_empty()).then_some(self.servers.path.as_path())
    }

    /// `settings/default/lobby.toml` with the operator's overrides over it
    /// (`override_path`, else `settings/lobby.toml`): see `common::settings`.
    pub fn load(override_path: Option<&Path>) -> Result<Self> {
        common::settings::load("lobby", override_path)
    }

    pub fn apply_launch_args(&mut self, args: LaunchArgs) {
        if let Some(ip) = args.ip {
            if ip.parse::<IpAddr>().is_ok() {
                self.server.bind_ip = ip;
            } else {
                tracing::warn!("invalid --ip ignored");
            }
        }
        if let Some(port) = args.port {
            self.server.port = port;
        }
        if let Some(db) = args.db_url {
            self.database.url = db;
        }
    }
}

#[derive(Parser, Debug, Clone, Default)]
#[command(version, about = "FFXIV 1.23b lobby server", long_about = None)]
pub struct LaunchArgs {
    /// Override bind IP (e.g. --ip 0.0.0.0)
    #[arg(long)]
    pub ip: Option<String>,
    /// Override bind port
    #[arg(long)]
    pub port: Option<u16>,
    /// Override the database URL (mysql://user:password@host:port/database)
    #[arg(long = "db-url")]
    pub db_url: Option<String>,
    /// Boot only far enough to validate config + DB, print a SMOKE_OK /
    /// SMOKE_FAIL marker, then exit (CI/dev fail-fast).
    #[arg(long)]
    pub smoke: bool,
    /// Suppress the interactive stdin console (no-op on servers without one).
    #[arg(long = "no-console")]
    pub no_console: bool,
    /// Override file merged over settings/default/lobby.toml (default:
    /// settings/lobby.toml)
    #[arg(long)]
    pub config: Option<PathBuf>,
}
