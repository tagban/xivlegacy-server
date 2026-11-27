// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `!event [name] [on|off|auto]`: show or switch the seasonal events of
//! `settings/events.toml` (see `crate::seasonal`); `!event auto` puts every
//! event back on its calendar. `!starlight`, `!moonfire`, `!halloween`
//! (`!allsaints`) and `!easter` (`!hatchingtide`) run that one event and
//! stop the others.

use super::{Args, CommandProcessor};
use crate::seasonal::{self, Mode};

const USAGE: &str = "usage: event [name] [on|off|auto] | event auto";

impl CommandProcessor {
    pub(super) async fn handle_event(&self, args: &Args<'_>) -> String {
        let (name, mode) = match args.tokens.as_slice() {
            [] => return seasonal::describe(),
            [all] if all.eq_ignore_ascii_case("auto") && !seasonal::exists("auto") => {
                let modes = seasonal::names()
                    .into_iter()
                    .map(|n| (n, Mode::Auto))
                    .collect();
                self.apply_event_modes(modes).await;
                return format!(
                    "every event back on its calendar. Now: {}",
                    seasonal::describe()
                );
            }
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
        self.apply_event_modes(vec![(name.clone(), mode)]).await;
        let state = if seasonal::is_active(&name) {
            "running"
        } else {
            "not running"
        };
        format!(
            "{name} set to {}: {state}. Its NPCs and decorations show as players move; quest offers update on the next zone change.",
            mode.as_str()
        )
    }

    /// `!starlight`, `!moonfire`, `!halloween`/`!allsaints`,
    /// `!easter`/`!hatchingtide`: run that event alone (on), every other
    /// event off. `!event auto` puts them all back on the calendar.
    pub(super) async fn handle_event_switch(&self, command: &str) -> String {
        let Some(target) = seasonal::switch_target(command) else {
            return USAGE.into();
        };
        if !seasonal::exists(target) {
            return format!("no event {target:?} in settings/events.toml");
        }
        let stopped: Vec<String> = seasonal::names()
            .into_iter()
            .filter(|n| n != target && seasonal::is_active(n))
            .collect();
        self.apply_event_modes(seasonal::solo_modes(target)).await;
        let stopped = if stopped.is_empty() {
            "nothing else was running".to_string()
        } else {
            format!("stopped {}", stopped.join(", "))
        };
        format!(
            "{target} on ({stopped}). {} `!event auto` goes back to the calendar.",
            self.event_readiness(target)
        )
    }

    /// Which of the event's quests have no script yet (they are never
    /// offered), so a GM knows what the event still lacks.
    fn event_readiness(&self, name: &str) -> String {
        let quests = seasonal::quests_of(name);
        let metas = self.lua.catalogs().quests.read();
        let missing: Vec<String> = quests
            .iter()
            .filter_map(|id| {
                let meta = metas.as_ref().ok()?.get(id)?;
                let code = meta.class_name.to_lowercase();
                (!self.lua.resolver().quest(&code).exists())
                    .then(|| format!("{} {id}", meta.class_name))
            })
            .collect();
        match (quests.len(), missing.len()) {
            (0, _) => "It has no quests.".to_string(),
            (n, 0) => format!("All {n} of its quests are ready."),
            (n, m) => format!(
                "Not built yet: {m} of its {n} quests ({}); they won't be offered.",
                missing.join(", ")
            ),
        }
    }

    /// Store and apply event modes, then bring every player's world up to
    /// date: event NPCs and decorations go (decorations are hidden first)
    /// or come, and zone looks follow.
    async fn apply_event_modes(&self, modes: Vec<(String, Mode)>) {
        for (name, mode) in &modes {
            seasonal::set_mode(name, *mode);
            if let Err(e) = self.db.save_event_override(name, mode.as_str()).await {
                tracing::warn!(error = %e, event = %name, "saving an event override");
            }
        }
        let removed = self.world.remove_inactive_seasonal_actors().await;
        self.world.refresh_seasonal_looks(&self.registry).await;
        self.world.refresh_special_event_work(&self.registry).await;
        // an Atomos camp open when its event stopped closes now
        crate::atomos::tick(&self.world, &self.registry, &self.db).await;
        tracing::info!(?modes, removed, "seasonal events switched");
    }
}
