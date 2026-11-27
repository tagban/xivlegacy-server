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

//! Event-condition metadata attached to NPC actors. Port of
//! `Map Server/Actors/EventList.cs`.
//!
//! Parsed from the JSON blob stored on `ActorClass::event_conditions`
//! and held on `BaseActor` so the zone-in spawn emitter can fan the
//! corresponding `SetTalkEventCondition` / `SetNoticeEventCondition` /
//! `SetEmoteEventCondition` / `SetPushEventConditionWith{Circle,Fan,Box}`
//! packets for each active condition. Without these writes the 1.x
//! client ignores subsequent `KickEvent` calls on the matching
//! `conditionName`.

use serde::Deserialize;

#[derive(Debug, Clone, Default)]
pub struct EventConditionList {
    pub talk: Vec<TalkCondition>,
    pub notice: Vec<NoticeCondition>,
    pub emote: Vec<EmoteCondition>,
    pub push_circle: Vec<PushCircleCondition>,
    pub push_fan: Vec<PushFanCondition>,
    pub push_box: Vec<PushBoxCondition>,
}

impl EventConditionList {
    pub fn is_empty(&self) -> bool {
        self.talk.is_empty()
            && self.notice.is_empty()
            && self.emote.is_empty()
            && self.push_circle.is_empty()
            && self.push_fan.is_empty()
            && self.push_box.is_empty()
    }
}

impl EventConditionList {
    /// The emote id (the 100-range `EmoteStandardCommand` id) the client
    /// matched to fire emote condition `condition_name` ("emoteDefault2"),
    /// or `None` if this actor has no such condition.
    pub fn emote_id_for(&self, condition_name: &str) -> Option<u32> {
        self.emote
            .iter()
            .find(|c| c.condition_name == condition_name)
            .map(|c| c.emote_id)
    }
}

/// `EmoteStandardCommand.lua`'s `emoteTable`: emote id -> (animation id,
/// motion text id) for `player:DoEmote`. When the player's emote hits an
/// NPC emote condition the client sends the condition's event instead of
/// the emote command, so an emote no quest wants is replayed from here.
/// Kept in step with the script by the `emote_motions_match_the_command_script`
/// test.
const STANDARD_EMOTES: &[(u32, u32, u32)] = &[
    (101, 1, 21001),
    (102, 2, 21011),
    (103, 3, 21021),
    (104, 4, 21031),
    (105, 5, 21041),
    (106, 6, 21051),
    (107, 7, 21061),
    (108, 8, 21071),
    (109, 9, 21081),
    (110, 10, 21091),
    (111, 11, 21101),
    (112, 12, 21111),
    (113, 13, 21121),
    (114, 14, 21131),
    (115, 15, 21141),
    (116, 16, 21151),
    (117, 17, 21161),
    (118, 18, 21171),
    (119, 19, 21181),
    (120, 20, 21191),
    (121, 21, 21201),
    (122, 22, 21211),
    (123, 23, 21221),
    (124, 24, 21231),
    (125, 25, 21241),
    (126, 26, 21251),
    (127, 27, 21261),
    (128, 28, 21271),
    (129, 29, 21281),
    (130, 30, 21291),
    (131, 31, 21301),
    (132, 32, 21311),
    (133, 33, 21321),
    (134, 34, 21331),
    (135, 35, 21341),
    (136, 36, 21351),
    (137, 37, 21361),
    (138, 38, 21371),
    (139, 39, 21381),
    (140, 40, 21391),
    (141, 41, 21401),
    (142, 42, 21411),
    (143, 43, 21421),
    (144, 44, 21423),
    (145, 53, 21425),
    (146, 50, 21427),
    (147, 51, 21429),
    (148, 52, 21431),
    (149, 45, 21433),
    (151, 47, 21435),
    (152, 48, 21437),
    (153, 49, 21439),
    (154, 46, 10105),
    (155, 54, 21442),
    (156, 55, 21445),
];

/// `(animation id, motion text id)` for standard emote `emote_id`.
pub fn standard_emote_motion(emote_id: u32) -> Option<(u32, u32)> {
    STANDARD_EMOTES
        .iter()
        .find(|(id, _, _)| *id == emote_id)
        .map(|(_, anim, text)| (*anim, *text))
}

#[derive(Debug, Clone, Default)]
pub struct TalkCondition {
    pub condition_name: String,
    pub unknown1: u8,
    pub is_disabled: bool,
}

#[derive(Debug, Clone, Default)]
pub struct NoticeCondition {
    pub condition_name: String,
    pub unknown1: u8,
    pub unknown2: u8,
}

#[derive(Debug, Clone, Default)]
pub struct EmoteCondition {
    pub condition_name: String,
    pub unknown1: u8,
    pub unknown2: u8,
    pub emote_id: u32,
}

#[derive(Debug, Clone, Default)]
pub struct PushCircleCondition {
    pub condition_name: String,
    pub radius: f32,
    pub outwards: bool,
    pub silent: bool,
    /// The actor-class default enable state (`"isEnabled"` in the JSON).
    /// Mirrors Meteor's per-condition flag: a streamed push trigger comes
    /// in at this state and only flips when a `quest:SetENpc(..)` broadcast
    /// overrides it. Defaults to `false` (disabled) when the field is
    /// absent — the canonical data for every quest trigger ships
    /// `"isEnabled": "false"`, so the circle stays inert until the owning
    /// quest enables it.
    pub is_enabled: bool,
}

#[derive(Debug, Clone, Default)]
pub struct PushFanCondition {
    pub condition_name: String,
    pub radius: f32,
    pub outwards: bool,
    pub silent: bool,
    /// See [`PushCircleCondition::is_enabled`].
    pub is_enabled: bool,
}

#[derive(Debug, Clone, Default)]
pub struct PushBoxCondition {
    pub condition_name: String,
    pub react_name: String,
    pub bg_obj: u32,
    pub layout: u32,
    pub outwards: bool,
    pub silent: bool,
    /// See [`PushCircleCondition::is_enabled`].
    pub is_enabled: bool,
}

/// Parse Meteor's nested `EventList` JSON. Returns an empty list if the
/// blob is empty/whitespace; returns `Err` only on malformed JSON.
pub fn parse_event_conditions(s: &str) -> Result<EventConditionList, serde_json::Error> {
    let trimmed = s.trim();
    if trimmed.is_empty() || trimmed == "{}" {
        return Ok(EventConditionList::default());
    }
    let raw: EventListRaw = serde_json::from_str(trimmed)?;
    Ok(raw.into())
}

#[derive(Deserialize, Default)]
struct EventListRaw {
    #[serde(default, rename = "talkEventConditions")]
    talk: Vec<TalkRaw>,
    #[serde(default, rename = "noticeEventConditions")]
    notice: Vec<NoticeRaw>,
    #[serde(default, rename = "emoteEventConditions")]
    emote: Vec<EmoteRaw>,
    #[serde(default, rename = "pushWithCircleEventConditions")]
    push_circle: Vec<PushCircleRaw>,
    #[serde(default, rename = "pushWithFanEventConditions")]
    push_fan: Vec<PushFanRaw>,
    #[serde(default, rename = "pushWithBoxEventConditions")]
    push_box: Vec<PushBoxRaw>,
}

impl From<EventListRaw> for EventConditionList {
    fn from(raw: EventListRaw) -> Self {
        Self {
            talk: raw.talk.into_iter().map(Into::into).collect(),
            notice: raw.notice.into_iter().map(Into::into).collect(),
            emote: raw.emote.into_iter().map(Into::into).collect(),
            push_circle: raw.push_circle.into_iter().map(Into::into).collect(),
            push_fan: raw.push_fan.into_iter().map(Into::into).collect(),
            push_box: raw.push_box.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Deserialize, Default)]
struct TalkRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default)]
    unknown1: JsonU8,
    #[serde(default, rename = "isDisabled")]
    is_disabled: JsonBool,
}
impl From<TalkRaw> for TalkCondition {
    fn from(r: TalkRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            unknown1: r.unknown1.0,
            is_disabled: r.is_disabled.0,
        }
    }
}

#[derive(Deserialize, Default)]
struct NoticeRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default)]
    unknown1: JsonU8,
    #[serde(default)]
    unknown2: JsonU8,
}
impl From<NoticeRaw> for NoticeCondition {
    fn from(r: NoticeRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            unknown1: r.unknown1.0,
            unknown2: r.unknown2.0,
        }
    }
}

#[derive(Deserialize, Default)]
struct EmoteRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default)]
    unknown1: JsonU8,
    #[serde(default)]
    unknown2: JsonU8,
    #[serde(default, rename = "emoteId")]
    emote_id: JsonU32,
}
impl From<EmoteRaw> for EmoteCondition {
    fn from(r: EmoteRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            unknown1: r.unknown1.0,
            unknown2: r.unknown2.0,
            emote_id: r.emote_id.0,
        }
    }
}

#[derive(Deserialize, Default)]
struct PushCircleRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default)]
    radius: JsonF32,
    #[serde(default)]
    outwards: JsonBool,
    #[serde(default)]
    silent: JsonBool,
    #[serde(default, rename = "isEnabled")]
    is_enabled: JsonBool,
}
impl From<PushCircleRaw> for PushCircleCondition {
    fn from(r: PushCircleRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            radius: r.radius.0,
            outwards: r.outwards.0,
            silent: r.silent.0,
            is_enabled: r.is_enabled.0,
        }
    }
}

#[derive(Deserialize, Default)]
struct PushFanRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default)]
    radius: JsonF32,
    #[serde(default)]
    outwards: JsonBool,
    #[serde(default)]
    silent: JsonBool,
    #[serde(default, rename = "isEnabled")]
    is_enabled: JsonBool,
}
impl From<PushFanRaw> for PushFanCondition {
    fn from(r: PushFanRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            radius: r.radius.0,
            outwards: r.outwards.0,
            silent: r.silent.0,
            is_enabled: r.is_enabled.0,
        }
    }
}

#[derive(Deserialize, Default)]
struct PushBoxRaw {
    #[serde(default, rename = "conditionName")]
    condition_name: String,
    #[serde(default, rename = "reactName")]
    react_name: String,
    #[serde(default, rename = "bgObj")]
    bg_obj: JsonU32,
    #[serde(default)]
    layout: JsonU32,
    #[serde(default)]
    outwards: JsonBool,
    #[serde(default)]
    silent: JsonBool,
    #[serde(default, rename = "isEnabled")]
    is_enabled: JsonBool,
}
impl From<PushBoxRaw> for PushBoxCondition {
    fn from(r: PushBoxRaw) -> Self {
        Self {
            condition_name: r.condition_name,
            react_name: r.react_name,
            bg_obj: r.bg_obj.0,
            layout: r.layout.0,
            outwards: r.outwards.0,
            silent: r.silent.0,
            is_enabled: r.is_enabled.0,
        }
    }
}

// JSON value coercion helpers — the Meteor dumps mix bare JSON numbers /
// bools with their stringified equivalents (`"radius": "2.0"`) in the
// same payload. Each helper accepts both forms.

#[derive(Default)]
struct JsonU8(u8);
#[derive(Default)]
struct JsonU32(u32);
#[derive(Default)]
struct JsonF32(f32);
#[derive(Default)]
struct JsonBool(bool);

impl<'de> Deserialize<'de> for JsonU8 {
    fn deserialize<D: serde::Deserializer<'de>>(de: D) -> Result<Self, D::Error> {
        Ok(Self(coerce_u64(serde_json::Value::deserialize(de)?)? as u8))
    }
}
impl<'de> Deserialize<'de> for JsonU32 {
    fn deserialize<D: serde::Deserializer<'de>>(de: D) -> Result<Self, D::Error> {
        Ok(Self(coerce_u64(serde_json::Value::deserialize(de)?)? as u32))
    }
}
impl<'de> Deserialize<'de> for JsonF32 {
    fn deserialize<D: serde::Deserializer<'de>>(de: D) -> Result<Self, D::Error> {
        Ok(Self(coerce_f64(serde_json::Value::deserialize(de)?)? as f32))
    }
}
impl<'de> Deserialize<'de> for JsonBool {
    fn deserialize<D: serde::Deserializer<'de>>(de: D) -> Result<Self, D::Error> {
        Ok(Self(coerce_bool(serde_json::Value::deserialize(de)?)?))
    }
}

fn coerce_u64<E: serde::de::Error>(v: serde_json::Value) -> Result<u64, E> {
    match v {
        serde_json::Value::Null => Ok(0),
        serde_json::Value::Number(n) => n.as_u64().ok_or_else(|| E::custom("negative u64")),
        serde_json::Value::String(s) => s.parse::<u64>().map_err(E::custom),
        other => Err(E::custom(format!("expected integer, got {other:?}"))),
    }
}

fn coerce_f64<E: serde::de::Error>(v: serde_json::Value) -> Result<f64, E> {
    match v {
        serde_json::Value::Null => Ok(0.0),
        serde_json::Value::Number(n) => n.as_f64().ok_or_else(|| E::custom("non-finite f64")),
        serde_json::Value::String(s) => s.parse::<f64>().map_err(E::custom),
        other => Err(E::custom(format!("expected float, got {other:?}"))),
    }
}

fn coerce_bool<E: serde::de::Error>(v: serde_json::Value) -> Result<bool, E> {
    match v {
        serde_json::Value::Null => Ok(false),
        serde_json::Value::Bool(b) => Ok(b),
        serde_json::Value::String(s) => match s.as_str() {
            "true" | "True" | "1" => Ok(true),
            "false" | "False" | "0" | "" => Ok(false),
            other => Err(E::custom(format!("bad bool string: {other}"))),
        },
        serde_json::Value::Number(n) => Ok(n.as_u64().unwrap_or(0) != 0),
        other => Err(E::custom(format!("expected bool, got {other:?}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The Rust copy of the emote table must match the command script the
    /// free emotes use, so an emote replayed for a quest NPC looks the same.
    #[test]
    fn emote_motions_match_the_command_script() {
        let script = std::fs::read_to_string(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../scripts/lua/commands/EmoteStandardCommand.lua"
        ))
        .unwrap();
        let mut seen = 0;
        for line in script.lines() {
            let line = line.trim();
            let Some(rest) = line.strip_prefix('[') else {
                continue;
            };
            let Some((id, rest)) = rest.split_once(']') else {
                continue;
            };
            let num = |key: &str| -> u32 {
                let at = rest.find(key).unwrap() + key.len();
                rest[at..]
                    .trim_start()
                    .chars()
                    .take_while(char::is_ascii_digit)
                    .collect::<String>()
                    .parse()
                    .unwrap()
            };
            let id: u32 = id.trim().parse().unwrap();
            assert_eq!(
                standard_emote_motion(id),
                Some((num("animId ="), num("descId ="))),
                "emote {id}"
            );
            seen += 1;
        }
        assert_eq!(seen, STANDARD_EMOTES.len());
    }

    #[test]
    fn emote_id_for_condition_name() {
        let blob = r#"{"emoteEventConditions":[
            {"unknown1":4,"unknown2":0,"emoteId":111,"conditionName":"emoteDefault1"},
            {"unknown1":4,"unknown2":0,"emoteId":156,"conditionName":"emoteDefault2"}]}"#;
        let list = parse_event_conditions(blob).unwrap();
        assert_eq!(list.emote_id_for("emoteDefault2"), Some(156));
        assert_eq!(list.emote_id_for("emoteDefault3"), None);
        assert_eq!(standard_emote_motion(156), Some((55, 21445)));
    }

    #[test]
    fn parses_monster_notice_only() {
        let blob = r#"{
            "talkEventConditions": [],
            "noticeEventConditions": [
                {"unknown1": 0, "unknown2": 1, "conditionName": "noticeEvent"}
            ],
            "emoteEventConditions": [],
            "pushWithCircleEventConditions": []
        }"#;
        let list = parse_event_conditions(blob).unwrap();
        assert_eq!(list.notice.len(), 1);
        assert_eq!(list.notice[0].condition_name, "noticeEvent");
        assert_eq!(list.notice[0].unknown2, 1);
        assert!(list.talk.is_empty());
    }

    #[test]
    fn parses_stringified_primitives() {
        let blob = r#"{
            "pushWithCircleEventConditions": [
                {"radius": "2.0", "outwards": "false", "silent": "false", "conditionName": "pushDefault"}
            ]
        }"#;
        let list = parse_event_conditions(blob).unwrap();
        assert_eq!(list.push_circle.len(), 1);
        let pc = &list.push_circle[0];
        assert_eq!(pc.condition_name, "pushDefault");
        assert!((pc.radius - 2.0).abs() < 1e-6);
        assert!(!pc.outwards);
        assert!(!pc.silent);
    }

    #[test]
    fn empty_blob_is_empty_list() {
        assert!(parse_event_conditions("").unwrap().is_empty());
        assert!(parse_event_conditions("{}").unwrap().is_empty());
    }

    #[test]
    fn push_circle_is_enabled_parses_from_canonical_data() {
        // The canonical project-meteor-server trigger data ships
        // `"isEnabled": "false"` (stringified) — the trigger streams in
        // disabled and only its owning quest enables it. (Garlemald-Server #46.)
        let blob = r#"{
            "pushWithCircleEventConditions": [
                {"isEnabled": "false", "radius": "6.0", "outwards": "false",
                 "silent": "false", "conditionName": "pushDefault"}
            ]
        }"#;
        let list = parse_event_conditions(blob).unwrap();
        assert_eq!(list.push_circle.len(), 1);
        assert!(!list.push_circle[0].is_enabled);
    }

    #[test]
    fn push_circle_is_enabled_true_and_absent() {
        let enabled = parse_event_conditions(
            r#"{"pushWithCircleEventConditions":[{"isEnabled":"true","conditionName":"p"}]}"#,
        )
        .unwrap();
        assert!(enabled.push_circle[0].is_enabled);

        // Numeric-format conditions (no isEnabled field) coerce to false.
        let absent = parse_event_conditions(
            r#"{"pushWithCircleEventConditions":[{"radius":3.0,"conditionName":"p"}]}"#,
        )
        .unwrap();
        assert!(!absent.push_circle[0].is_enabled);
    }

    /// The city lifts (Ul'dah's Wellhead, Limsa's Crow's) have no quest to
    /// enable their push circle, so the class data must stream the
    /// push-in circle enabled; otherwise walking into a lift does nothing
    /// and the Ul'dah airship landing has no way down (#466).
    #[test]
    fn city_lifts_stream_their_push_in_enabled() {
        let sql = include_str!("../../../common/sql/data/gamedata_actor_class.sql");
        let mut lifts = 0;
        for (at, _) in sql.match_indices("'/Chara/Npc/Object/ElevatorStandard', ") {
            let id_start = sql[..at].rfind('(').unwrap() + 1;
            let id = &sql[id_start..at].trim_end_matches(", ");
            let rest = &sql[at..];
            let json_start = rest.find("'{").unwrap() + 1;
            let json_end = rest.find("}'").unwrap() + 1;
            let list = parse_event_conditions(&rest[json_start..json_end]).unwrap();
            let push_in = list
                .push_circle
                .iter()
                .find(|c| c.condition_name == "pushCommandIn")
                .unwrap_or_else(|| panic!("lift {id} has no pushCommandIn"));
            assert!(
                push_in.is_enabled,
                "lift {id} streams its pushCommandIn disabled"
            );
            lifts += 1;
        }
        assert_eq!(lifts, 7);
    }
}
