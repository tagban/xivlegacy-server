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

//! Commands that only change what one player hears or sees on their own
//! screen (`!setmusic`, `!myweather`), safe to give every player.

use super::{Args, CommandProcessor};
use crate::lua::LuaCommandKind as LC;

/// Music ids with a name, from where the server's own data plays them:
/// zone and private-area rows (`server_zones*.sql`: day and battle
/// music) and the scripts (mount, crafting, gathering, guildleves,
/// duties). Any other id still plays by number.
pub(super) const MUSIC_NAMES: &[(u16, &str)] = &[
    (2, "Adders' Nest"),
    (3, "Maelstrom Command"),
    (4, "Hall of Flames"),
    (7, "Rhotano Sea"),
    (11, "Mor Dhona battle"),
    (13, "Black Shroud battle"),
    (15, "Coerthas battle"),
    (21, "La Noscea battle"),
    (25, "Thanalan battle"),
    (22, "Guildleve 1"),
    (14, "Guildleve 2"),
    (26, "Guildleve 3"),
    (16, "Guildleve 4"),
    (81, "Leve victory"),
    (37, "Duty"),
    (40, "The Past"),
    (48, "Market wards"),
    (49, "Mor Dhona"),
    (51, "Gridania"),
    (52, "Black Shroud"),
    (55, "Coerthas"),
    (59, "Limsa Lominsa"),
    (60, "La Noscea"),
    (61, "Inn room"),
    (65, "Strait of Merlthor"),
    (66, "Ul'dah"),
    (68, "Thanalan"),
    (73, "Crafting"),
    (101, "Gathering done"),
    (83, "Chocobo"),
    (64, "Rental chocobo"),
    (98, "Goobbue"),
];

/// Weather ids with a name: the server's default sky (`settings/map.toml`)
/// and the two the events use (`settings/events.toml`, `!worldend`).
pub(super) const WEATHER_NAMES: &[(u16, &str)] = &[(1, "clear"), (8027, "snow"), (8032, "dalamud")];

/// Lowercase, apostrophes and doubled spaces dropped: "ul dah" and
/// "Ul'dah" compare alike.
fn fold(s: &str) -> String {
    s.chars()
        .filter(|c| *c != '\'')
        .flat_map(char::to_lowercase)
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

/// The music `typed` names: an exact name wins, else every name it's part
/// of (an empty list: none).
pub(super) fn music_matching(typed: &str) -> Vec<(u16, &'static str)> {
    let t = fold(typed);
    if t.is_empty() {
        return Vec::new();
    }
    if let Some(&hit) = MUSIC_NAMES.iter().find(|(_, n)| fold(n) == t) {
        return vec![hit];
    }
    MUSIC_NAMES
        .iter()
        .filter(|(_, n)| fold(n).contains(&t))
        .copied()
        .collect()
}

/// `id Name` for a music id, or the bare id when it has no name.
pub(super) fn music_label(id: u16) -> String {
    match MUSIC_NAMES.iter().find(|(m, _)| *m == id) {
        Some((_, n)) => format!("{id} {n}"),
        None => format!("music {id}"),
    }
}

/// What `!setmusic` was asked to play.
#[derive(Debug, PartialEq)]
pub(super) enum MusicPick {
    /// This id, for the player named from token `from` on (else you).
    Play(u16, usize),
    /// Back to the area's own music, for the player named from token 1 on.
    Off,
    /// The list of named music.
    List,
    /// A message to show instead (usage, no match, more than one match).
    Say(String),
}

const SETMUSIC_USAGE: &str = "usage: !setmusic <music id or name> | !setmusic list | !setmusic off (back to the zone's music)";

/// Read `!setmusic`'s words. A GM's trailing player name comes after a
/// number, `off`, or a one-word music name.
pub(super) fn parse_setmusic(tokens: &[&str]) -> MusicPick {
    let Some(first) = tokens.first() else {
        return MusicPick::Say(SETMUSIC_USAGE.into());
    };
    match first.to_ascii_lowercase().as_str() {
        "list" => return MusicPick::List,
        "off" | "reset" | "zone" => return MusicPick::Off,
        _ => {}
    }
    if let Ok(id) = first.parse::<u16>() {
        return if id == 0 {
            MusicPick::Say(
                "music ids start at 1; !setmusic off goes back to the zone's music".into(),
            )
        } else {
            MusicPick::Play(id, 1)
        };
    }
    let all = tokens.join(" ");
    let found = music_matching(&all);
    match found.as_slice() {
        [(id, _)] => return MusicPick::Play(*id, tokens.len()),
        [] => {}
        many => {
            let list: Vec<String> = many.iter().map(|(id, n)| format!("{id} {n}")).collect();
            return MusicPick::Say(format!("\"{all}\" could be: {}", list.join(", ")));
        }
    }
    if tokens.len() > 1
        && let [(id, _)] = music_matching(first).as_slice()
    {
        return MusicPick::Play(*id, 1);
    }
    MusicPick::Say(format!("no music called \"{all}\" (!setmusic list)"))
}

/// The named music in chat lines of at most `width` bytes.
pub(super) fn music_list_lines(width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    let mut line = String::new();
    for (id, name) in MUSIC_NAMES {
        let item = format!("{id} {name}");
        if !line.is_empty() && line.len() + 2 + item.len() > width {
            lines.push(std::mem::take(&mut line));
        }
        if !line.is_empty() {
            line.push_str(", ");
        }
        line.push_str(&item);
    }
    if !line.is_empty() {
        lines.push(line);
    }
    lines
}

impl CommandProcessor {
    /// `setmusic <music id or name> [name] | setmusic list | setmusic off
    /// [name]`: music only that player hears. It stays through zoning,
    /// border crossings, rides and crafting (which play their own track,
    /// then come back to it) until `off` or logout.
    pub(super) async fn handle_setmusic(&self, args: &Args<'_>) -> String {
        let (pick, from) = match parse_setmusic(args.rest()) {
            MusicPick::Say(text) => return text,
            MusicPick::List => return self.music_list(args).await,
            MusicPick::Play(id, from) => (Some(id), from),
            MusicPick::Off => (None, 1),
        };
        let Some(name) = args.rest_joined(from) else {
            return if args.was_refused() {
                String::new()
            } else {
                "usage: setmusic <music id> <name> | setmusic off <name>".into()
            };
        };
        let id = match self.online_id(&name).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some(handle) = self.registry.get(id).await else {
            return format!("{name} is not online");
        };
        let Some(session) = self.world.set_music_choice(handle.session_id, pick).await else {
            return format!("{name} has no session");
        };
        let music = match pick {
            Some(m) => m,
            None => self.world.area_music(&session).await,
        };
        if music != 0 {
            self.run_lua(vec![LC::ChangeMusic {
                player_id: id,
                music_id: music,
            }])
            .await;
        }
        let me = args.invoker.is_some_and(|i| i.eq_ignore_ascii_case(&name));
        match (pick, me) {
            (Some(_), true) => format!(
                "playing {} for you until !setmusic off or logout",
                music_label(music)
            ),
            (Some(_), false) => format!("playing {} for {name}", music_label(music)),
            (None, true) => "back to the zone's music".into(),
            (None, false) => format!("{name} is back to the zone's music"),
        }
    }

    /// `setmusic list`: the named music, a few lines in your chat log.
    async fn music_list(&self, args: &Args<'_>) -> String {
        let lines = music_list_lines(400);
        let me = match args.invoker {
            Some(name) => self.lookup_character_id(name).await,
            None => None,
        };
        match me {
            Some(actor_id) if self.registry.get(actor_id).await.is_some() => {
                for line in lines {
                    self.tell_player(actor_id, line).await;
                }
                "!setmusic <id or name> plays one (other ids play by number too); !setmusic off goes back to the zone's".into()
            }
            _ => lines.join("\n"),
        }
    }

    /// `myweather <weather id | clear | snow | dalamud | off>`: a sky only
    /// you see, until you zone or the server changes the weather.
    pub(super) async fn handle_myweather(&self, args: &Args<'_>) -> String {
        let names: Vec<&str> = WEATHER_NAMES.iter().map(|(_, n)| *n).collect();
        let usage = format!(
            "usage: !myweather <weather id | {} | off>",
            names.join(" | ")
        );
        let Some(word) = args.token(0).map(str::to_ascii_lowercase) else {
            return usage;
        };
        let me = match self.invoker_id(args).await {
            Ok(id) => id,
            Err(e) => return e,
        };
        let Some((zone, ..)) = self.spot_of(me).await else {
            return "you are not in the world".into();
        };
        let off = matches!(word.as_str(), "off" | "reset" | "zone");
        let weather = if off {
            self.world.zone_weather(zone)
        } else if let Some((id, _)) = WEATHER_NAMES.iter().find(|(_, n)| *n == word) {
            *id
        } else {
            match word.parse::<u16>() {
                Ok(id) if id != 0 => id,
                _ => return usage,
            }
        };
        let Some(handle) = self.registry.get(me).await else {
            return "you are not in the world".into();
        };
        let Some(client) = self.world.client(handle.session_id).await else {
            return "you are not in the world".into();
        };
        let mut pkt = crate::packets::send::misc::build_set_weather(handle.actor_id, weather, 0);
        pkt.set_target_id(handle.session_id);
        client.send_bytes(pkt.to_bytes()).await;
        if off {
            "back to the zone's weather".into()
        } else {
            format!("weather {weather} for you until you zone (!myweather off to undo)")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn music_names_are_unique() {
        let mut ids: Vec<u16> = MUSIC_NAMES.iter().map(|(id, _)| *id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), MUSIC_NAMES.len());
        let mut names: Vec<String> = MUSIC_NAMES.iter().map(|(_, n)| fold(n)).collect();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), MUSIC_NAMES.len());
    }

    #[test]
    fn music_by_name_or_part_of_one() {
        assert_eq!(music_matching("gridania"), vec![(51, "Gridania")]);
        assert_eq!(music_matching("uldah"), vec![(66, "Ul'dah")]);
        // an exact name beats the longer names it's part of
        assert_eq!(music_matching("black shroud"), vec![(52, "Black Shroud")]);
        assert_eq!(music_matching("chocobo"), vec![(83, "Chocobo")]);
        assert!(music_matching("battle").len() >= 5);
        assert!(music_matching("zzz").is_empty());
    }

    #[test]
    fn setmusic_words() {
        assert_eq!(parse_setmusic(&["51"]), MusicPick::Play(51, 1));
        assert_eq!(
            parse_setmusic(&["51", "Some", "One"]),
            MusicPick::Play(51, 1)
        );
        assert_eq!(
            parse_setmusic(&["Limsa", "Lominsa"]),
            MusicPick::Play(59, 2)
        );
        assert_eq!(
            parse_setmusic(&["gridania", "Some", "One"]),
            MusicPick::Play(51, 1)
        );
        assert_eq!(parse_setmusic(&["OFF"]), MusicPick::Off);
        assert_eq!(parse_setmusic(&["reset"]), MusicPick::Off);
        assert_eq!(parse_setmusic(&["list"]), MusicPick::List);
        assert!(matches!(parse_setmusic(&[]), MusicPick::Say(_)));
        assert!(matches!(parse_setmusic(&["0"]), MusicPick::Say(_)));
        assert!(matches!(parse_setmusic(&["shroud"]), MusicPick::Say(t) if t.contains("could be")));
        assert!(
            matches!(parse_setmusic(&["nothing"]), MusicPick::Say(t) if t.contains("no music"))
        );
    }

    #[test]
    fn music_list_fits_chat_lines() {
        let lines = music_list_lines(400);
        assert!(lines.len() <= 4, "{lines:?}");
        assert!(lines.iter().all(|l| l.len() <= 400));
        let all = lines.join(", ");
        assert!(
            MUSIC_NAMES
                .iter()
                .all(|(id, n)| all.contains(&format!("{id} {n}")))
        );
    }
}
