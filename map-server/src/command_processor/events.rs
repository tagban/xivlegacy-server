// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `!event [name] [on|off|auto]`: show or switch the seasonal events of
//! `settings/events.toml` (see `crate::seasonal`).

use super::{Args, CommandProcessor};
use crate::seasonal::{self, Mode};

const USAGE: &str = "usage: event [name] [on|off|auto]";

impl CommandProcessor {
    pub(super) async fn handle_event(&self, args: &Args<'_>) -> String {
        let (name, mode) = match args.tokens.as_slice() {
            [] => return seasonal::describe(),
            [name] => (name.to_ascii_lowercase(), None),
            [name, mode] => match Mode::parse(mode) {
                Some(m) => (name.to_ascii_lowercase(), Some(m)),
                None => return USAGE.into(),
            },
            _ => return USAGE.into(),
        };
        if !seasonal::exists(&name) {
            return format!(
                "no event {name:?} (events: {})",
                seasonal::names().join(", ")
            );
        }
        let Some(mode) = mode else {
            return seasonal::describe()
                .split("; ")
                .find(|l| l.starts_with(&format!("{name}:")))
                .unwrap_or_default()
                .to_string();
        };
        seasonal::set_mode(&name, mode);
        if let Err(e) = self.db.save_event_override(&name, mode.as_str()).await {
            tracing::warn!(error = %e, event = %name, "saving an event override");
        }
        let removed = self.world.remove_inactive_seasonal_actors().await;
        tracing::info!(event = %name, mode = mode.as_str(), removed, "seasonal event switched");
        let state = if seasonal::is_active(&name) {
            "running"
        } else {
            "not running"
        };
        format!(
            "{name} set to {}: {state}. Its NPCs show as players move; quest offers update on the next zone change.",
            mode.as_str()
        )
    }
}
