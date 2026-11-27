// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! `!atomos [open|close] [camp|all]`: show the Atomos camps
//! (`crate::atomos`), or open or close one now. With no camp named it is
//! the camp in the GM's zone, else all five. The event itself switches with
//! `!event atomos on|off|auto`.

use super::{Args, CommandProcessor};

const USAGE: &str = "usage: atomos [open|close] [camp|all] (camps: dragonhead, emeraldmoss, crimsonbark, blackbrush, horizon)";

impl CommandProcessor {
    pub(super) async fn handle_atomos(&self, args: &Args<'_>) -> String {
        let (verb, rest) = match args.tokens.split_first() {
            None => return crate::atomos::describe(&self.registry).await,
            Some((v, rest)) => (v.to_ascii_lowercase(), rest),
        };
        let open = match verb.as_str() {
            "open" => true,
            "close" => false,
            _ => return USAGE.into(),
        };
        let camps: Vec<usize> = if rest.is_empty() {
            let here = match self.invoker_id(args).await {
                Ok(me) => self
                    .spot_of(me)
                    .await
                    .and_then(|(zone, ..)| crate::atomos::camp_in_zone(zone)),
                Err(_) => None,
            };
            match here {
                Some(i) => vec![i],
                None => (0..crate::atomos::CAMPS.len()).collect(),
            }
        } else if rest.len() == 1 && rest[0].eq_ignore_ascii_case("all") {
            (0..crate::atomos::CAMPS.len()).collect()
        } else {
            match crate::atomos::camp_by_key(&rest.join(" ")) {
                Some(i) => vec![i],
                None => return USAGE.into(),
            }
        };
        let mut lines = Vec::new();
        for i in camps {
            let name = crate::atomos::CAMPS[i].name;
            if open {
                match crate::atomos::open_now(&self.world, &self.registry, &self.db, i).await {
                    Ok(l) | Err(l) => lines.push(l),
                }
            } else if crate::atomos::close_now(&self.world, &self.registry, &self.db, i).await {
                lines.push(format!("{name} closed"));
            } else {
                lines.push(format!("{name} wasn't open"));
            }
        }
        let mut out = lines.join("; ");
        if open && !crate::atomos::running() {
            out.push_str(
                ". The Atomos event isn't running, so Teleport to the camps costs anima as usual \
                 (`!event atomos on` starts it)",
            );
        }
        out
    }
}
