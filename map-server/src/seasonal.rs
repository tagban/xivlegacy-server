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
//!
//! An event can also change the look and sound of some zones while it
//! runs (`[[<event>.zone]]`: a weather and/or a music id), and its
//! decorations are background objects baked into the client's town
//! layouts: an event spawn of class `MapObjOnlyShowHide` (5900006,
//! `SHOW_HIDE_CLASS`) bound to one of them (`server_eventnpc_mapobj`)
//! makes the client run the object's `show` schedule. When the event
//! stops, the server runs `hide` on it before taking the actor away.
//!
//! Some of an event's NPCs show only at night, Eorzean time (All Saints'
//! Wake's trickster imps: `night_classes`), and a script can make one
//! vanish for a while (`VanishSeasonalActor`, an imp after its riddle).

use std::collections::{BTreeMap, HashMap};
use std::sync::{OnceLock, RwLock};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

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

/// What an event changes in some zones while it runs.
#[derive(Debug, Clone, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct ZoneLook {
    pub zones: Vec<u32>,
    /// Weather id (`SetWeather`), shown instead of the zone's own.
    #[serde(default)]
    pub weather: Option<u16>,
    /// Music id (`SetMusic`), played instead of the zone's own.
    #[serde(default)]
    pub music: Option<u16>,
}

/// `/Chara/Npc/MapObj/MapObjOnlyShowHide` whose client `initForEvent`
/// runs the bound background object's `show` schedule (5900007 runs
/// `hide`).
pub const SHOW_HIDE_CLASS: u32 = 5_900_006;

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Event {
    pub mode: Mode,
    pub windows: Vec<Window>,
    /// Zones whose weather or music the event changes.
    pub zone: Vec<ZoneLook>,
    /// Actor classes of this event that show only at night.
    pub night_classes: Vec<u32>,
    /// Night, in Eorzean hours: from `night_start` up to (not including)
    /// `night_end`, over midnight when the end is the smaller.
    pub night_start: u32,
    pub night_end: u32,
}

impl Default for Event {
    fn default() -> Self {
        Self {
            mode: Mode::Auto,
            windows: Vec::new(),
            zone: Vec::new(),
            night_classes: Vec::new(),
            night_start: 19,
            night_end: 5,
        }
    }
}

impl Event {
    fn is_night(&self, hour: u32) -> bool {
        if self.night_start <= self.night_end {
            self.night_start <= hour && hour < self.night_end
        } else {
            hour >= self.night_start || hour < self.night_end
        }
    }
}

/// Real seconds in one Eorzean hour (1.0: an Eorzean day is 70 minutes).
const SECONDS_PER_EORZEA_HOUR: u64 = 175;

/// The Eorzean hour (0-23) at `unix_seconds`.
pub fn eorzea_hour_at(unix_seconds: u64) -> u32 {
    ((unix_seconds / SECONDS_PER_EORZEA_HOUR) % 24) as u32
}

pub fn eorzea_hour() -> u32 {
    eorzea_hour_at(
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0),
    )
}

/// What decides whether a tagged actor shows: the date, the Eorzean hour
/// and the moment (for vanished actors).
#[derive(Debug, Clone, Copy)]
pub struct Clock {
    pub day: MonthDay,
    pub hour: u32,
    pub now: Instant,
}

impl Clock {
    pub fn now() -> Self {
        Self {
            day: MonthDay::today(),
            hour: eorzea_hour(),
            now: Instant::now(),
        }
    }
}

#[derive(Debug, Default)]
struct State {
    events: BTreeMap<String, Event>,
    /// `!event` overrides (from `server_events`).
    overrides: BTreeMap<String, Mode>,
    /// Spawned NPCs that belong to an event (actor id -> event name and
    /// actor class).
    actors: HashMap<u32, (String, u32)>,
    /// Actors a script made vanish, until when.
    vanished: HashMap<u32, Instant>,
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

/// The quests `name`'s windows list, in order, without repeats.
pub fn quests_of(name: &str) -> Vec<u32> {
    let mut out: Vec<u32> = Vec::new();
    if let Ok(s) = state().read()
        && let Some(e) = s.events.get(&name.to_ascii_lowercase())
    {
        for q in e.windows.iter().flat_map(|w| w.quests.iter()) {
            if !out.contains(q) {
                out.push(*q);
            }
        }
    }
    out
}

/// The event a switch command (`!starlight`, `!halloween` ...) names.
pub fn switch_target(command: &str) -> Option<&'static str> {
    match command {
        "starlight" => Some("starlight"),
        "moonfire" => Some("moonfire"),
        "allsaints" | "halloween" => Some("allsaints"),
        "hatchingtide" | "easter" => Some("hatchingtide"),
        _ => None,
    }
}

/// The modes that run `target` alone: it on, every other event off.
pub fn solo_modes(target: &str) -> Vec<(String, Mode)> {
    names()
        .into_iter()
        .map(|n| {
            let m = if n == target { Mode::On } else { Mode::Off };
            (n, m)
        })
        .collect()
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

    fn hidden(&self, actor_id: u32, clock: Clock) -> bool {
        let Some((name, class_id)) = self.actors.get(&actor_id) else {
            return false;
        };
        if !self.active(name, clock.day) {
            return true;
        }
        if self
            .events
            .get(name)
            .is_some_and(|e| e.night_classes.contains(class_id) && !e.is_night(clock.hour))
        {
            return true;
        }
        self.vanished
            .get(&actor_id)
            .is_some_and(|until| clock.now < *until)
    }

    fn zone_look(&self, zone_id: u32, day: MonthDay) -> (Option<u16>, Option<u16>) {
        let (mut weather, mut music) = (None, None);
        for (name, e) in &self.events {
            if !self.active(name, day) {
                continue;
            }
            for z in e.zone.iter().filter(|z| z.zones.contains(&zone_id)) {
                weather = weather.or(z.weather);
                music = music.or(z.music);
            }
        }
        (weather, music)
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

/// Remember that spawned actor `actor_id` (of `class_id`) belongs to
/// `event`.
pub fn tag_actor(actor_id: u32, event: &str, class_id: u32) {
    if let Ok(mut s) = state().write() {
        s.actors
            .insert(actor_id, (event.to_ascii_lowercase(), class_id));
    }
}

/// Hide event actor `actor_id` for `seconds` (an imp gone after its
/// riddle). Untagged actors are left alone.
pub fn vanish(actor_id: u32, seconds: u64) -> bool {
    let Ok(mut s) = state().write() else {
        return false;
    };
    if !s.actors.contains_key(&actor_id) {
        return false;
    }
    let now = Instant::now();
    s.vanished.retain(|_, until| *until > now);
    s.vanished
        .insert(actor_id, now + Duration::from_secs(seconds));
    true
}

/// Whether `actor_id` is an event NPC players must not be sent now: its
/// event isn't running, it is a night NPC by day, or it vanished.
pub fn actor_hidden(actor_id: u32) -> bool {
    actor_hidden_at(actor_id, Clock::now())
}

pub fn actor_hidden_at(actor_id: u32, clock: Clock) -> bool {
    state().read().is_ok_and(|s| s.hidden(actor_id, clock))
}

/// The weather and music running events give `zone_id` (the first
/// running event, by name, that sets each wins).
pub fn zone_look(zone_id: u32) -> (Option<u16>, Option<u16>) {
    zone_look_on(zone_id, MonthDay::today())
}

pub fn zone_look_on(zone_id: u32, day: MonthDay) -> (Option<u16>, Option<u16>) {
    state()
        .read()
        .map(|s| s.zone_look(zone_id, day))
        .unwrap_or_default()
}

/// Whether any event, running or not, changes `zone_id`'s look.
pub fn zone_has_look(zone_id: u32) -> bool {
    state().read().is_ok_and(|s| {
        s.events
            .values()
            .any(|e| e.zone.iter().any(|z| z.zones.contains(&zone_id)))
    })
}

/// Names of the events running today, sorted; a change means zone looks
/// may have to be sent again.
pub fn running() -> Vec<String> {
    let day = MonthDay::today();
    state()
        .read()
        .map(|s| {
            s.events
                .keys()
                .filter(|n| s.active(n, day))
                .cloned()
                .collect()
        })
        .unwrap_or_default()
}

/// Whether hidden event actor `actor_id` is a decoration switch whose
/// object must be hidden again before the actor goes.
pub fn is_show_hide(actor_id: u32) -> bool {
    state().read().is_ok_and(|s| {
        s.actors
            .get(&actor_id)
            .is_some_and(|(_, class)| *class == SHOW_HIDE_CLASS)
    })
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
            night_classes: vec![900],
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
            zone: vec![
                ZoneLook {
                    zones: vec![155, 206],
                    weather: Some(8027),
                    music: None,
                },
                ZoneLook {
                    zones: vec![155],
                    weather: Some(8001),
                    music: Some(51),
                },
            ],
            ..Default::default()
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
    fn zone_looks_follow_the_event() {
        let s = with(None);
        let day = MonthDay(12, 20);
        // The first entry naming a zone wins each field.
        assert_eq!(s.zone_look(155, day), (Some(8027), Some(51)));
        assert_eq!(s.zone_look(206, day), (Some(8027), None));
        assert_eq!(s.zone_look(175, day), (None, None));
        assert_eq!(s.zone_look(155, MonthDay(7, 1)), (None, None));
        let off = with(Some(Mode::Off));
        assert_eq!(off.zone_look(155, day), (None, None));
    }

    #[test]
    fn zone_looks_parse_from_settings() {
        let e: Event = toml::from_str(
            "mode = \"on\"\n[[zone]]\nzones = [155]\nweather = 8027\n[[zone]]\nzones = [133]\nmusic = 59\n",
        )
        .unwrap();
        assert_eq!(e.zone.len(), 2);
        assert_eq!(e.zone[0].weather, Some(8027));
        assert_eq!(e.zone[1].music, Some(59));
    }

    #[test]
    fn unknown_events_are_off() {
        let s = with(None);
        assert!(!s.active("hatchingtide", MonthDay(12, 20)));
    }

    fn at(day: MonthDay, hour: u32) -> Clock {
        Clock {
            day,
            hour,
            now: Instant::now(),
        }
    }

    #[test]
    fn tagged_actors_follow_their_event() {
        let mut s = with(Some(Mode::Off));
        s.actors.insert(7, ("starlight".into(), 100));
        assert!(s.hidden(7, at(MonthDay(12, 20), 12)));
        s.overrides.insert("starlight".into(), Mode::Auto);
        assert!(!s.hidden(7, at(MonthDay(12, 20), 12)));
        assert!(s.hidden(7, at(MonthDay(7, 1), 12)));
        // untagged actors always show
        assert!(!s.hidden(8, at(MonthDay(7, 1), 12)));
    }

    #[test]
    fn night_classes_show_only_at_night() {
        let mut s = with(None);
        s.actors.insert(7, ("starlight".into(), 900));
        s.actors.insert(8, ("starlight".into(), 100));
        let day = MonthDay(12, 20);
        for (hour, night) in [
            (18, false),
            (19, true),
            (23, true),
            (0, true),
            (4, true),
            (5, false),
            (12, false),
        ] {
            assert_eq!(!s.hidden(7, at(day, hour)), night, "hour {hour}");
            assert!(!s.hidden(8, at(day, hour)), "day NPC at hour {hour}");
        }
    }

    #[test]
    fn vanished_actors_come_back() {
        let mut s = with(None);
        s.actors.insert(7, ("starlight".into(), 100));
        let c = at(MonthDay(12, 20), 12);
        s.vanished.insert(7, c.now + Duration::from_secs(60));
        assert!(s.hidden(7, c));
        let later = Clock {
            now: c.now + Duration::from_secs(61),
            ..c
        };
        assert!(!s.hidden(7, later));
    }

    #[test]
    fn eorzea_hours_turn_every_175_seconds() {
        assert_eq!(eorzea_hour_at(0), 0);
        assert_eq!(eorzea_hour_at(174), 0);
        assert_eq!(eorzea_hour_at(175), 1);
        assert_eq!(eorzea_hour_at(175 * 24), 0);
        assert_eq!(eorzea_hour_at(175 * 24 + 175 * 19), 19);
    }

    #[test]
    fn switch_commands_name_their_events() {
        assert_eq!(switch_target("halloween"), Some("allsaints"));
        assert_eq!(switch_target("allsaints"), Some("allsaints"));
        assert_eq!(switch_target("easter"), Some("hatchingtide"));
        assert_eq!(switch_target("moonfire"), Some("moonfire"));
        assert_eq!(switch_target("starlight"), Some("starlight"));
        assert_eq!(switch_target("event"), None);
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
        let a = &events["allsaints"];
        assert!(a.windows.iter().any(|w| w.quests == [110800]));
        assert_eq!(a.night_classes.len(), 9);
        // the yearly calendar
        let on = |name: &str, day: MonthDay| events[name].windows.iter().any(|w| w.contains(day));
        assert!(on("allsaints", MonthDay(10, 1)) && on("allsaints", MonthDay(10, 31)));
        assert!(!on("allsaints", MonthDay(9, 30)) && !on("allsaints", MonthDay(11, 1)));
        assert!(on("starlight", MonthDay(11, 1)) && on("starlight", MonthDay(1, 16)));
        assert!(!on("starlight", MonthDay(10, 31)) && !on("starlight", MonthDay(1, 17)));
        assert!(on("hatchingtide", MonthDay(4, 1)) && on("hatchingtide", MonthDay(4, 30)));
        assert!(!on("hatchingtide", MonthDay(3, 31)) && !on("hatchingtide", MonthDay(5, 1)));
        assert!(on("moonfire", MonthDay(6, 1)) && on("moonfire", MonthDay(8, 31)));
        assert!(!on("moonfire", MonthDay(5, 31)) && !on("moonfire", MonthDay(9, 1)));
        assert!(a.is_night(19) && a.is_night(4) && !a.is_night(5) && !a.is_night(18));
    }
}
