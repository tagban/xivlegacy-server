// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Seasonal events (`settings/events.toml`): the Starlight Celebration and
//! its kind. Each event has date windows, and each window opens some
//! quests. While an event is off, its NPCs (`server_spawn_location_events`)
//! are hidden and its quests aren't offered.
//!
//! An event's mode is `auto` (follow the windows, by the server's local
//! date), `on` (every window open) or `off`. The settings give the mode;
//! `!event <name> <on|off|auto>` overrides it and stores the override in
//! `server_events`, so it survives a restart.

use std::collections::{BTreeMap, HashMap};
use std::sync::{OnceLock, RwLock};

use chrono::Datelike;
use serde::Deserialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    #[default]
    Auto,
    On,
    Off,
}

impl Mode {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_lowercase().as_str() {
            "auto" => Some(Self::Auto),
            "on" => Some(Self::On),
            "off" => Some(Self::Off),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::On => "on",
            Self::Off => "off",
        }
    }
}

/// A month and day ("MM-DD").
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct MonthDay(pub u32, pub u32);

impl MonthDay {
    pub fn today() -> Self {
        let d = chrono::Local::now().date_naive();
        Self(d.month(), d.day())
    }

    fn parse(s: &str) -> Option<Self> {
        let (m, d) = s.trim().split_once('-')?;
        let (m, d) = (m.parse().ok()?, d.parse().ok()?);
        ((1..=12).contains(&m) && (1..=31).contains(&d)).then_some(Self(m, d))
    }
}

impl<'de> Deserialize<'de> for MonthDay {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        Self::parse(&s)
            .ok_or_else(|| serde::de::Error::custom(format!("bad date {s:?} (want MM-DD)")))
    }
}

/// One stretch of the calendar, start and end days included. An end
/// before the start runs over the new year.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Window {
    #[serde(default)]
    pub name: String,
    pub start: MonthDay,
    pub end: MonthDay,
    /// Quests offered only while this window is open.
    #[serde(default)]
    pub quests: Vec<u32>,
}

impl Window {
    pub fn contains(&self, day: MonthDay) -> bool {
        if self.start <= self.end {
            self.start <= day && day <= self.end
        } else {
            day >= self.start || day <= self.end
        }
    }
}

#[derive(Debug, Clone, Deserialize, Default)]
#[serde(default, deny_unknown_fields)]
pub struct Event {
    pub mode: Mode,
    pub windows: Vec<Window>,
}

#[derive(Debug, Default)]
struct State {
    events: BTreeMap<String, Event>,
    /// `!event` overrides (from `server_events`).
    overrides: BTreeMap<String, Mode>,
    /// Spawned NPCs that belong to an event (actor id -> event name).
    actors: HashMap<u32, String>,
}

static STATE: OnceLock<RwLock<State>> = OnceLock::new();

fn state() -> &'static RwLock<State> {
    STATE.get_or_init(Default::default)
}

/// Read `settings/events.toml` once, at start-up.
pub fn init() -> anyhow::Result<()> {
    let events: BTreeMap<String, Event> = common::settings::load("events", None)?;
    for (name, e) in &events {
        tracing::info!(event = %name, mode = e.mode.as_str(), windows = e.windows.len(), "seasonal event loaded");
    }
    set_events(events);
    Ok(())
}

pub fn set_events(events: BTreeMap<String, Event>) {
    if let Ok(mut s) = state().write() {
        s.events = events;
    }
}

/// Apply the stored `!event` overrides (unknown names are kept, harmless).
pub fn set_overrides(rows: Vec<(String, String)>) {
    if let Ok(mut s) = state().write() {
        s.overrides = rows
            .into_iter()
            .filter_map(|(n, m)| Some((n.to_ascii_lowercase(), Mode::parse(&m)?)))
            .collect();
    }
}

/// Override one event's mode; `Auto` drops back to the windows.
pub fn set_mode(name: &str, mode: Mode) {
    if let Ok(mut s) = state().write() {
        s.overrides.insert(name.to_ascii_lowercase(), mode);
    }
}

pub fn names() -> Vec<String> {
    state()
        .read()
        .map(|s| s.events.keys().cloned().collect())
        .unwrap_or_default()
}

pub fn exists(name: &str) -> bool {
    state()
        .read()
        .is_ok_and(|s| s.events.contains_key(&name.to_ascii_lowercase()))
}

impl State {
    fn mode(&self, name: &str) -> Mode {
        match self.overrides.get(name) {
            Some(m) if *m != Mode::Auto => *m,
            _ => self.events.get(name).map(|e| e.mode).unwrap_or(Mode::Off),
        }
    }

    fn window_open(&self, name: &str, w: &Window, day: MonthDay) -> bool {
        match self.mode(name) {
            Mode::On => true,
            Mode::Off => false,
            Mode::Auto => w.contains(day),
        }
    }

    fn active(&self, name: &str, day: MonthDay) -> bool {
        self.events
            .get(name)
            .is_some_and(|e| e.windows.iter().any(|w| self.window_open(name, w, day)))
    }

    fn hidden(&self, actor_id: u32, day: MonthDay) -> bool {
        self.actors
            .get(&actor_id)
            .is_some_and(|e| !self.active(e, day))
    }

    fn quest_open(&self, quest_id: u32, day: MonthDay) -> bool {
        let mut seasonal = false;
        for (name, e) in &self.events {
            for w in e.windows.iter().filter(|w| w.quests.contains(&quest_id)) {
                seasonal = true;
                if self.window_open(name, w, day) {
                    return true;
                }
            }
        }
        !seasonal
    }
}

/// Whether event `name` is running today (any of its windows open).
pub fn is_active(name: &str) -> bool {
    is_active_on(name, MonthDay::today())
}

pub fn is_active_on(name: &str, day: MonthDay) -> bool {
    state()
        .read()
        .is_ok_and(|s| s.active(&name.to_ascii_lowercase(), day))
}

/// Whether `quest_id` may be offered today. A quest no window lists is
/// always open.
pub fn quest_open(quest_id: u32) -> bool {
    quest_open_on(quest_id, MonthDay::today())
}

pub fn quest_open_on(quest_id: u32, day: MonthDay) -> bool {
    state().read().map_or(true, |s| s.quest_open(quest_id, day))
}

/// Remember that spawned actor `actor_id` belongs to `event`.
pub fn tag_actor(actor_id: u32, event: &str) {
    if let Ok(mut s) = state().write() {
        s.actors.insert(actor_id, event.to_ascii_lowercase());
    }
}

/// Whether `actor_id` is an event NPC whose event isn't running, so
/// players must not be sent it.
pub fn actor_hidden(actor_id: u32) -> bool {
    actor_hidden_on(actor_id, MonthDay::today())
}

pub fn actor_hidden_on(actor_id: u32, day: MonthDay) -> bool {
    state().read().is_ok_and(|s| s.hidden(actor_id, day))
}

/// One line per event for `!event`.
pub fn describe() -> String {
    let day = MonthDay::today();
    let Ok(s) = state().read() else {
        return String::new();
    };
    if s.events.is_empty() {
        return "no seasonal events in settings/events.toml".into();
    }
    s.events
        .iter()
        .map(|(name, e)| {
            let windows = e
                .windows
                .iter()
                .map(|w| {
                    format!(
                        "{} {:02}-{:02}..{:02}-{:02}{}",
                        if w.name.is_empty() { "window" } else { &w.name },
                        w.start.0,
                        w.start.1,
                        w.end.0,
                        w.end.1,
                        if s.window_open(name, w, day) {
                            " (open)"
                        } else {
                            ""
                        }
                    )
                })
                .collect::<Vec<_>>()
                .join(", ");
            format!(
                "{name}: {} ({}) [{windows}]",
                if s.active(name, day) {
                    "running"
                } else {
                    "not running"
                },
                s.mode(name).as_str()
            )
        })
        .collect::<Vec<_>>()
        .join("; ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn starlight() -> Event {
        Event {
            mode: Mode::Auto,
            windows: vec![
                Window {
                    name: "a".into(),
                    start: MonthDay(12, 16),
                    end: MonthDay(12, 31),
                    quests: vec![110801],
                },
                Window {
                    name: "b".into(),
                    start: MonthDay(12, 31),
                    end: MonthDay(1, 16),
                    quests: vec![110802],
                },
            ],
        }
    }

    fn with(mode: Option<Mode>) -> State {
        let mut s = State::default();
        s.events.insert("starlight".into(), starlight());
        if let Some(m) = mode {
            s.overrides.insert("starlight".into(), m);
        }
        s
    }

    #[test]
    fn windows_follow_the_calendar() {
        let s = with(None);
        assert!(!s.active("starlight", MonthDay(12, 15)));
        assert!(s.active("starlight", MonthDay(12, 16)));
        assert!(s.active("starlight", MonthDay(1, 16)));
        assert!(!s.active("starlight", MonthDay(1, 17)));
        assert!(!s.active("starlight", MonthDay(7, 1)));
    }

    #[test]
    fn quests_open_only_in_their_window() {
        let s = with(None);
        assert!(s.quest_open(110801, MonthDay(12, 20)));
        assert!(!s.quest_open(110802, MonthDay(12, 20)));
        assert!(s.quest_open(110801, MonthDay(12, 31)));
        assert!(s.quest_open(110802, MonthDay(12, 31)));
        assert!(!s.quest_open(110801, MonthDay(1, 5)));
        assert!(s.quest_open(110802, MonthDay(1, 5)));
        // Quests no window lists are never held back.
        assert!(s.quest_open(110001, MonthDay(7, 1)));
    }

    #[test]
    fn overrides_win_over_the_calendar() {
        let on = with(Some(Mode::On));
        assert!(on.active("starlight", MonthDay(7, 1)));
        assert!(on.quest_open(110801, MonthDay(7, 1)));
        assert!(on.quest_open(110802, MonthDay(7, 1)));
        let off = with(Some(Mode::Off));
        assert!(!off.active("starlight", MonthDay(12, 20)));
        assert!(!off.quest_open(110801, MonthDay(12, 20)));
        let auto = with(Some(Mode::Auto));
        assert!(auto.active("starlight", MonthDay(12, 20)));
    }

    #[test]
    fn unknown_events_are_off() {
        let s = with(None);
        assert!(!s.active("hatchingtide", MonthDay(12, 20)));
    }

    #[test]
    fn tagged_actors_follow_their_event() {
        let mut s = with(Some(Mode::Off));
        s.actors.insert(7, "starlight".into());
        assert!(s.hidden(7, MonthDay(12, 20)));
        s.overrides.insert("starlight".into(), Mode::Auto);
        assert!(!s.hidden(7, MonthDay(12, 20)));
        assert!(s.hidden(7, MonthDay(7, 1)));
        // untagged actors always show
        assert!(!s.hidden(8, MonthDay(7, 1)));
    }

    #[test]
    fn month_day_parses() {
        assert_eq!(MonthDay::parse("12-16"), Some(MonthDay(12, 16)));
        assert_eq!(MonthDay::parse("01-05"), Some(MonthDay(1, 5)));
        assert_eq!(MonthDay::parse("13-01"), None);
        assert_eq!(MonthDay::parse("x"), None);
    }

    #[test]
    fn shipped_settings_parse() {
        let text = include_str!("../../settings/default/events.toml");
        let events: BTreeMap<String, Event> = toml::from_str(text).expect("events.toml parses");
        let e = &events["starlight"];
        assert_eq!(e.windows.len(), 2);
        assert!(e.windows.iter().any(|w| w.quests == [110801]));
        assert!(e.windows.iter().any(|w| w.quests == [110802]));
    }
}
