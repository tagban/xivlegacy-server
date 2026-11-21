// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The `status` module's web route (modules/status): `GET /status`, who is
//! playing, for server status pages such as moghouse.cc. Public, read-only,
//! cacheable for 30 s. The shape (modules/status/README.md) is shared with the
//! FFXI server's exporter, so one website plugin reads both games.

use axum::extract::State;
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use serde::Serialize;

use crate::handlers::AppState;

/// How many recently active characters the page lists.
const RECENT: usize = 10;

#[derive(Serialize)]
pub struct Status {
    pub game: &'static str,
    pub world: String,
    pub players_online: u32,
    pub recent: Vec<RecentCharacter>,
    /// When this answer was made (RFC 3339, UTC).
    pub updated: String,
}

#[derive(Serialize)]
pub struct RecentCharacter {
    pub name: String,
    /// The starting city: "Limsa Lominsa", "Gridania", "Ul'dah" (empty if unknown).
    pub city: &'static str,
    /// The same as a short id for a flag image: "limsa", "gridania", "uldah".
    pub city_id: &'static str,
    pub online: bool,
    /// Where the character is (or was last): the zone's place name, such as
    /// "Lower La Noscea" (empty if unknown).
    pub zone: String,
    /// When the character last entered or left the world (RFC 3339, UTC).
    pub last_active: String,
}

/// `characters.initialTown`.
pub fn city(town: i64) -> (&'static str, &'static str) {
    match town {
        1 => ("Limsa Lominsa", "limsa"),
        2 => ("Gridania", "gridania"),
        3 => ("Ul'dah", "uldah"),
        _ => ("", ""),
    }
}

fn rfc3339(unix: i64) -> String {
    chrono::DateTime::from_timestamp(unix, 0)
        .map(|t| t.to_rfc3339_opts(chrono::SecondsFormat::Secs, true))
        .unwrap_or_default()
}

pub async fn status(State(state): State<AppState>) -> Response {
    match state.db.status(RECENT).await {
        Ok((online, rows)) => {
            let body = Status {
                game: "FINAL FANTASY XIV 1.23b",
                world: state.world_name.clone(),
                players_online: online,
                recent: rows
                    .into_iter()
                    .map(|(name, town, last, on, zone)| {
                        let (city, city_id) = city(town);
                        RecentCharacter {
                            name,
                            city,
                            city_id,
                            online: on,
                            zone,
                            last_active: rfc3339(last),
                        }
                    })
                    .collect(),
                updated: rfc3339(chrono::Utc::now().timestamp()),
            };
            (
                [
                    (header::CONTENT_TYPE, "application/json"),
                    (header::ACCESS_CONTROL_ALLOW_ORIGIN, "*"),
                    (header::CACHE_CONTROL, "max-age=30"),
                ],
                serde_json::to_string(&body).unwrap_or_default(),
            )
                .into_response()
        }
        Err(e) => {
            tracing::error!(error = %e, "status query failed");
            (StatusCode::SERVICE_UNAVAILABLE, "status unavailable").into_response()
        }
    }
}
