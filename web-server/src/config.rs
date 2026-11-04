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

/// Runtime configuration for the web (login/signup) server.
///
/// Mirrors the lobby / world / map config shape: TOML on disk, CLI overrides
/// via [`LaunchArgs`], localhost-safe defaults when a file is missing.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
    pub server: ServerSection,
    pub database: DatabaseSection,
    pub session: SessionSection,
    pub reports: ReportsSection,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ReportsSection {
    /// The lowest account GM level (`users.gmLevel`) that may sign in to
    /// the activity reports at /reports.
    pub gm_level: u8,
}

impl Default for ReportsSection {
    fn default() -> Self {
        Self { gm_level: 1 }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ServerSection {
    pub bind_ip: String,
    pub port: u16,
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
pub struct SessionSection {
    /// Lifetime of a session row inserted on successful login. After this
    /// expires, the lobby server rejects the token and the user has to
    /// re-authenticate through the webview.
    pub hours: u32,
}

impl Default for ServerSection {
    fn default() -> Self {
        Self {
            bind_ip: "127.0.0.1".to_string(),
            port: 54993,
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

impl Default for SessionSection {
    fn default() -> Self {
        Self { hours: 24 }
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
    pub fn reports_gm_level(&self) -> u8 {
        self.reports.gm_level.max(1)
    }
    pub fn session_hours(&self) -> u32 {
        self.session.hours
    }

    /// `settings/default/web.toml` with the operator's overrides over it
    /// (`override_path`, else `settings/web.toml`): see `common::settings`.
    pub fn load(override_path: Option<&Path>) -> Result<Self> {
        common::settings::load("web", override_path)
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
        if let Some(hours) = args.session_hours {
            self.session.hours = hours;
        }
    }
}

#[derive(Parser, Debug, Clone, Default)]
#[command(version, about = "Garlemald web (login/signup) server", long_about = None)]
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
    /// Override the session lifetime in hours
    #[arg(long)]
    pub session_hours: Option<u32>,
    /// Boot only far enough to validate config + DB, print a SMOKE_OK /
    /// SMOKE_FAIL marker, then exit (CI/dev fail-fast).
    #[arg(long)]
    pub smoke: bool,
    /// Suppress the interactive stdin console (no-op on servers without one).
    #[arg(long = "no-console")]
    pub no_console: bool,
    /// Override file merged over settings/default/web.toml (default:
    /// settings/web.toml)
    #[arg(long)]
    pub config: Option<PathBuf>,
}
