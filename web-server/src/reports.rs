// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Activity reports for GMs, read from the `log_*` tables (migration 002).
//!
//! - `GET /reports`: the last day (or `?days=N`) at a glance: sessions,
//!   gil and items in and out, quests, GM commands.
//! - `GET /reports/character?name=`: one character's history, newest first.
//!
//! Sign-in is a GM account's game login (`/reports/login`), kept in an
//! HttpOnly cookie scoped to `/reports`. Accounts below `[reports] gm_level`
//! in settings/web.toml are refused.

use std::fmt::Write;

use axum::extract::{Form, Query, State};
use axum::http::{HeaderMap, header};
use axum::response::{Html, IntoResponse, Redirect, Response};
use common::db::ConnCallExt;
use common::sql::{OptionalExtension, named_params};
use serde::Deserialize;

use crate::handlers::AppState;

const COOKIE: &str = "xl_reports";

// ---------------------------------------------------------------------------
// Sign-in
// ---------------------------------------------------------------------------

fn session_cookie(headers: &HeaderMap) -> Option<String> {
    headers
        .get_all(header::COOKIE)
        .iter()
        .filter_map(|v| v.to_str().ok())
        .flat_map(|v| v.split(';'))
        .filter_map(|kv| kv.trim().split_once('='))
        .find(|(k, _)| *k == COOKIE)
        .map(|(_, v)| v.to_string())
}

/// The signed-in GM's account id, or None.
async fn gm(state: &AppState, headers: &HeaderMap) -> Option<i64> {
    let sid = session_cookie(headers)?;
    let user = state.db.user_of_session(&sid).await.ok()??;
    let level = state.db.gm_level(user).await.ok()?;
    (level >= state.reports_gm_level as i64).then_some(user)
}

#[derive(Debug, Deserialize, Default)]
pub struct LoginQuery {
    #[serde(default)]
    pub err: Option<String>,
}

pub async fn login_form(Query(q): Query<LoginQuery>) -> Html<String> {
    let mut body = String::from(
        r#"<section class="signin"><h1>Activity reports</h1>
<p class="muted">Sign in with a GM account.</p>"#,
    );
    if let Some(err) = q.err.as_deref() {
        let _ = write!(body, r#"<p class="error">{}</p>"#, esc(err));
    }
    body.push_str(
        r#"<form method="post" action="/reports/login">
<label for="u">Username</label><input id="u" name="username" autocomplete="username" required>
<label for="p">Password</label><input id="p" name="password" type="password" autocomplete="current-password" required>
<button type="submit">Sign in</button></form></section>"#,
    );
    Html(page("Sign in", &body))
}

#[derive(Debug, Deserialize)]
pub struct LoginForm {
    pub username: String,
    pub password: String,
}

pub async fn login_submit(State(state): State<AppState>, Form(form): Form<LoginForm>) -> Response {
    let refuse = |msg: &str| {
        Redirect::to(&format!("/reports/login?err={}", crate::handlers::pct(msg))).into_response()
    };
    let user = match state.db.find_user_by_username(form.username.trim()).await {
        Ok(Some(u)) if crate::handlers::verify_password(&form.password, &u.password_hash) => u,
        Ok(_) => return refuse("Invalid username or password."),
        Err(e) => {
            tracing::error!(error = %e, "reports login: lookup failed");
            return refuse("Server error, please try again.");
        }
    };
    match state.db.gm_level(user.id).await {
        Ok(level) if level >= state.reports_gm_level as i64 => {}
        Ok(_) => return refuse("That account isn't a GM."),
        Err(e) => {
            tracing::error!(error = %e, "reports login: gm level lookup failed");
            return refuse("Server error, please try again.");
        }
    }
    let sid = crate::session::generate();
    if let Err(e) = state
        .db
        .insert_session(&sid, user.id, state.session_hours)
        .await
    {
        tracing::error!(error = %e, "reports login: session insert failed");
        return refuse("Server error, please try again.");
    }
    tracing::info!(user_id = user.id, "reports: GM signed in");
    let cookie = format!(
        "{COOKIE}={sid}; Path=/reports; HttpOnly; SameSite=Strict; Max-Age={}",
        state.session_hours as u64 * 3600
    );
    ([(header::SET_COOKIE, cookie)], Redirect::to("/reports")).into_response()
}

pub async fn logout() -> Response {
    let cookie = format!("{COOKIE}=; Path=/reports; HttpOnly; SameSite=Strict; Max-Age=0");
    (
        [(header::SET_COOKIE, cookie)],
        Redirect::to("/reports/login"),
    )
        .into_response()
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Default)]
pub struct OverviewQuery {
    #[serde(default)]
    pub days: Option<u32>,
}

#[derive(Default)]
pub struct Overview {
    pub logins: i64,
    pub characters: i64,
    pub gil_in: i64,
    pub gil_out: i64,
    pub items_in: i64,
    pub items_out: i64,
    pub quests_done: i64,
    pub leves_done: i64,
    pub kills: i64,
    pub deaths: i64,
    pub gm_commands: i64,
    pub zones: Vec<(String, i64)>,
    pub sessions: Vec<(i64, String, String, String)>,
    pub commands: Vec<(i64, String, String, String)>,
}

pub async fn overview(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<OverviewQuery>,
) -> Response {
    if gm(&state, &headers).await.is_none() {
        return Redirect::to("/reports/login").into_response();
    }
    let days = q.days.unwrap_or(1).clamp(1, 365);
    let since = chrono::Utc::now().timestamp() - days as i64 * 86_400;
    let o = match state.db.report_overview(since).await {
        Ok(o) => o,
        Err(e) => return server_error(e),
    };

    let mut b = String::new();
    b.push_str(r#"<header class="top"><h1>Activity</h1><nav class="range">"#);
    for (d, label) in [(1, "Day"), (7, "Week"), (30, "Month")] {
        let cls = if d == days { " class=\"on\"" } else { "" };
        let _ = write!(b, r#"<a href="/reports?days={d}"{cls}>{label}</a>"#);
    }
    b.push_str(r#"</nav>"#);
    b.push_str(SEARCH_FORM);
    b.push_str("</header>");

    let tiles: [(&str, String); 10] = [
        ("Logins", num(o.logins)),
        ("Characters", num(o.characters)),
        ("Gil earned", num(o.gil_in)),
        ("Gil spent", num(o.gil_out)),
        ("Items gained", num(o.items_in)),
        ("Items lost", num(o.items_out)),
        ("Quests done", num(o.quests_done)),
        ("Leves done", num(o.leves_done)),
        ("Monsters defeated", num(o.kills)),
        ("Deaths", num(o.deaths)),
    ];
    b.push_str(r#"<section class="tiles">"#);
    for (label, value) in tiles {
        let _ = write!(
            b,
            r#"<div class="tile"><span>{label}</span><strong>{value}</strong></div>"#
        );
    }
    b.push_str("</section>");

    b.push_str(r#"<div class="cols"><section><h2>Zones entered</h2>"#);
    if o.zones.is_empty() {
        b.push_str(r#"<p class="muted">Nobody changed zones.</p>"#);
    } else {
        b.push_str(
            r#"<table><thead><tr><th>Zone</th><th class="n">Entries</th></tr></thead><tbody>"#,
        );
        for (zone, n) in &o.zones {
            let _ = write!(
                b,
                r#"<tr><td>{}</td><td class="n">{}</td></tr>"#,
                esc(zone),
                num(*n)
            );
        }
        b.push_str("</tbody></table>");
    }
    let _ = write!(
        b,
        r#"</section><section><h2>GM commands <small>{}</small></h2>"#,
        num(o.gm_commands)
    );
    if o.commands.is_empty() {
        b.push_str(r#"<p class="muted">None.</p>"#);
    } else {
        b.push_str(
            r#"<table><thead><tr><th>When</th><th>Who</th><th>Command</th></tr></thead><tbody>"#,
        );
        for (at, who, cmd, args) in &o.commands {
            let _ = write!(
                b,
                r#"<tr><td class="t">{}</td><td>{}</td><td><code>!{} {}</code></td></tr>"#,
                when(*at),
                who_link(who),
                esc(cmd),
                esc(args)
            );
        }
        b.push_str("</tbody></table>");
    }
    b.push_str(r#"</section></div><section><h2>Sessions</h2>"#);
    if o.sessions.is_empty() {
        b.push_str(r#"<p class="muted">No logins or logouts.</p>"#);
    } else {
        b.push_str(r#"<table><thead><tr><th>When</th><th>Who</th><th>Event</th><th>Where</th></tr></thead><tbody>"#);
        for (at, who, event, zone) in &o.sessions {
            let _ = write!(
                b,
                r#"<tr><td class="t">{}</td><td>{}</td><td>{}</td><td>{}</td></tr>"#,
                when(*at),
                who_link(who),
                esc(event),
                esc(zone)
            );
        }
        b.push_str("</tbody></table>");
    }
    b.push_str("</section>");
    Html(page("Activity", &b)).into_response()
}

// ---------------------------------------------------------------------------
// One character
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Default)]
pub struct CharacterQuery {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub kind: Option<String>,
}

/// The kinds the timeline can be narrowed to, as (query value, label).
const KINDS: [(&str, &str); 7] = [
    ("session", "Sessions"),
    ("item", "Items"),
    ("gil", "Gil"),
    ("progress", "Classes and levels"),
    ("quest", "Quests and leves"),
    ("combat", "Kills and deaths"),
    ("gm", "GM commands"),
];

pub struct Event {
    pub at: i64,
    pub kind: String,
    pub text: String,
}

pub async fn character(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<CharacterQuery>,
) -> Response {
    if gm(&state, &headers).await.is_none() {
        return Redirect::to("/reports/login").into_response();
    }
    let name = q.name.trim().to_string();
    let kind = q.kind.filter(|k| KINDS.iter().any(|(v, _)| v == k));
    let found = match state.db.report_character(&name, kind.clone()).await {
        Ok(f) => f,
        Err(e) => return server_error(e),
    };

    let mut b = String::from(r#"<header class="top"><h1><a href="/reports">Activity</a> / "#);
    let _ = write!(b, "{}</h1>", esc(&name));
    b.push_str(SEARCH_FORM);
    b.push_str("</header>");
    let Some((chara_id, gil, events)) = found else {
        b.push_str(r#"<p class="muted">No character by that name.</p>"#);
        return Html(page("Character", &b)).into_response();
    };
    let _ = write!(
        b,
        r#"<p class="muted">Character {chara_id} · {} gil now</p><nav class="range">"#,
        num(gil)
    );
    let base = format!("/reports/character?name={}", crate::handlers::pct(&name));
    let on = |k: Option<&str>| {
        if kind.as_deref() == k {
            " class=\"on\""
        } else {
            ""
        }
    };
    let _ = write!(b, r#"<a href="{base}"{}>Everything</a>"#, on(None));
    for (v, label) in KINDS {
        let _ = write!(
            b,
            r#"<a href="{base}&amp;kind={v}"{}>{label}</a>"#,
            on(Some(v))
        );
    }
    b.push_str("</nav>");
    if events.is_empty() {
        b.push_str(r#"<p class="muted">Nothing recorded yet.</p>"#);
    } else {
        b.push_str(r#"<table class="timeline"><thead><tr><th>When</th><th>What</th><th>Detail</th></tr></thead><tbody>"#);
        for e in &events {
            let label = KINDS
                .iter()
                .find(|(v, _)| *v == e.kind)
                .map_or("", |(_, l)| l);
            let _ = write!(
                b,
                r#"<tr><td class="t">{}</td><td><span class="kind k-{}">{}</span></td><td>{}</td></tr>"#,
                when(e.at),
                esc(&e.kind),
                label,
                esc(&e.text)
            );
        }
        b.push_str("</tbody></table>");
        if events.len() >= TIMELINE_ROWS {
            let _ = write!(
                b,
                r#"<p class="muted">The newest {TIMELINE_ROWS} shown.</p>"#
            );
        }
    }
    Html(page(&name, &b)).into_response()
}

pub const TIMELINE_ROWS: usize = 500;

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

impl crate::database::Database {
    pub async fn gm_level(&self, user_id: i64) -> anyhow::Result<i64> {
        self.conn()
            .call_db(move |c| {
                Ok(c.query_row(
                    "SELECT gmLevel FROM users WHERE id = :u",
                    named_params! { ":u": user_id },
                    |r| r.get(0),
                )
                .optional()?
                .unwrap_or(0))
            })
            .await
    }

    pub async fn report_overview(&self, since: i64) -> anyhow::Result<Overview> {
        self.conn()
            .call_db(move |c| {
                let p = named_params! { ":s": since };
                let one = |sql: &str| -> common::sql::Result<i64> {
                    c.query_row(sql, named_params! { ":s": since }, |r| r.get::<_, Option<i64>>(0))
                        .map(|v| v.unwrap_or(0))
                };
                let mut o = Overview {
                    logins: one("SELECT COUNT(*) FROM log_sessions WHERE at >= :s AND event = 'login'")?,
                    characters: one("SELECT COUNT(DISTINCT characterId) FROM log_sessions WHERE at >= :s AND event = 'login'")?,
                    gil_in: one("SELECT SUM(delta) FROM log_gil WHERE at >= :s AND delta > 0")?,
                    gil_out: -one("SELECT SUM(delta) FROM log_gil WHERE at >= :s AND delta < 0")?,
                    items_in: one("SELECT SUM(quantity) FROM log_items WHERE at >= :s AND quantity > 0 AND itemId <> 1000001")?,
                    items_out: -one("SELECT SUM(quantity) FROM log_items WHERE at >= :s AND quantity < 0 AND itemId <> 1000001")?,
                    quests_done: one("SELECT COUNT(*) FROM log_quests WHERE at >= :s AND kind = 'quest' AND event = 'complete'")?,
                    leves_done: one("SELECT COUNT(*) FROM log_quests WHERE at >= :s AND kind = 'leve' AND event = 'complete'")?,
                    gm_commands: one("SELECT COUNT(*) FROM log_gm WHERE at >= :s")?,
                    kills: one("SELECT COUNT(*) FROM log_combat WHERE at >= :s AND kind = 'kill'")?,
                    deaths: one("SELECT COUNT(*) FROM log_combat WHERE at >= :s AND kind = 'death'")?,
                    ..Overview::default()
                };
                let mut st = c.prepare(
                    r"SELECT COALESCE(NULLIF(z.placeName, ''), z.zoneName, CONCAT('Zone ', l.zoneId)), COUNT(*) AS n
                      FROM log_sessions l LEFT JOIN server_zones z ON z.id = l.zoneId AND l.zoneId > 0
                      WHERE l.at >= :s AND l.event = 'zone'
                      GROUP BY l.zoneId ORDER BY n DESC LIMIT 15",
                )?;
                o.zones = st.query_map(p, |r| Ok((r.get(0)?, r.get(1)?)))?.collect::<common::sql::Result<_>>()?;
                let mut st = c.prepare(
                    r"SELECT l.at, COALESCE(c.name, ''), l.event,
                             COALESCE(NULLIF(z.placeName, ''), z.zoneName, '')
                      FROM log_sessions l
                      LEFT JOIN characters c ON c.id = l.characterId
                      LEFT JOIN server_zones z ON z.id = l.zoneId AND l.zoneId > 0
                      WHERE l.at >= :s AND l.event IN ('login', 'logout')
                      ORDER BY l.at DESC, l.id DESC LIMIT 25",
                )?;
                o.sessions = st
                    .query_map(named_params! { ":s": since }, |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))?
                    .collect::<common::sql::Result<_>>()?;
                let mut st = c.prepare(
                    r"SELECT l.at, COALESCE(c.name, 'console'), l.command, l.args
                      FROM log_gm l LEFT JOIN characters c ON c.id = l.characterId
                      WHERE l.at >= :s ORDER BY l.at DESC, l.id DESC LIMIT 25",
                )?;
                o.commands = st
                    .query_map(named_params! { ":s": since }, |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))?
                    .collect::<common::sql::Result<_>>()?;
                Ok(o)
            })
            .await
    }

    /// The character named `name`: its id, gil now, and its newest events
    /// (of one kind, or all).
    pub async fn report_character(
        &self,
        name: &str,
        kind: Option<String>,
    ) -> anyhow::Result<Option<(i64, i64, Vec<Event>)>> {
        let name = name.to_owned();
        self.conn()
            .call_db(move |c| {
                let Some(id): Option<i64> = c
                    .query_row(
                        "SELECT id FROM characters WHERE name = :n AND state <> 1 ORDER BY id DESC LIMIT 1",
                        named_params! { ":n": name },
                        |r| r.get(0),
                    )
                    .optional()?
                else {
                    return Ok(None);
                };
                let gil: i64 = c
                    .query_row(
                        r"SELECT COALESCE(SUM(si.quantity), 0) FROM characters_inventory ci
                          INNER JOIN server_items si ON si.id = ci.serverItemId
                          WHERE ci.characterId = :c AND ci.itemPackage = 99 AND si.itemId = 1000001",
                        named_params! { ":c": id },
                        |r| r.get(0),
                    )?;
                // One SELECT per log table, each already shaped as
                // (at, id, kind, text), so the page is one sorted list.
                let parts: [(&str, &str); 7] = [
                    ("session", r"SELECT l.at, l.id, 'session',
                        CONCAT(l.event, CASE WHEN z.id IS NULL THEN '' ELSE CONCAT(' · ', COALESCE(NULLIF(z.placeName, ''), z.zoneName)) END)
                        FROM log_sessions l LEFT JOIN server_zones z ON z.id = l.zoneId AND l.zoneId > 0 WHERE l.characterId = :c"),
                    ("item", r"SELECT l.at, l.id, 'item',
                        CONCAT(CASE WHEN l.quantity > 0 THEN '+' ELSE '' END, l.quantity, ' × ',
                               COALESCE(NULLIF(i.name, ''), CONCAT('item ', l.itemId)),
                               ' · ', l.reason, ' · bag ', l.itemPackage)
                        FROM log_items l LEFT JOIN gamedata_items i ON i.catalogID = l.itemId
                        WHERE l.characterId = :c AND l.itemId <> 1000001"),
                    ("gil", r"SELECT at, id, 'gil',
                        CONCAT(CASE WHEN delta > 0 THEN '+' ELSE '' END, delta, ' gil → ', balance)
                        FROM log_gil WHERE characterId = :c"),
                    ("progress", r"SELECT at, id, 'progress', CONCAT(kind, ' ', classId, ' = ', value)
                        FROM log_progress WHERE characterId = :c"),
                    ("quest", r"SELECT at, id, 'quest',
                        CONCAT(kind, ' ', questId, ' ', event, CASE WHEN sequence > 0 THEN CONCAT(' (step ', sequence, ')') ELSE '' END)
                        FROM log_quests WHERE characterId = :c"),
                    ("combat", r"SELECT l.at, l.id, 'combat',
                        CONCAT(CASE WHEN l.kind = 'kill' THEN 'defeated ' ELSE 'killed by ' END,
                               COALESCE((SELECT p.name FROM server_battlenpc_pools p WHERE p.actorClassId = l.targetId LIMIT 1),
                                        (SELECT c.name FROM characters c WHERE c.id = l.targetId),
                                        CONCAT('actor ', l.targetId)),
                               CASE WHEN l.kind = 'kill' THEN CONCAT(' (level ', l.amount, ')') ELSE '' END,
                               CASE WHEN z.id IS NULL THEN '' ELSE CONCAT(' · ', COALESCE(NULLIF(z.placeName, ''), z.zoneName)) END)
                        FROM log_combat l LEFT JOIN server_zones z ON z.id = l.zoneId AND l.zoneId > 0 WHERE l.characterId = :c"),
                    ("gm", r"SELECT at, id, 'gm', CONCAT('!', command, ' ', args) FROM log_gm WHERE characterId = :c"),
                ];
                let sql = parts
                    .iter()
                    .filter(|(k, _)| kind.as_deref().is_none_or(|want| want == *k))
                    .map(|(_, q)| format!("({q})"))
                    .collect::<Vec<_>>()
                    .join(" UNION ALL ");
                let sql = format!("SELECT * FROM ({sql}) e ORDER BY 1 DESC, 2 DESC LIMIT {TIMELINE_ROWS}");
                let mut st = c.prepare(&sql)?;
                let events = st
                    .query_map(named_params! { ":c": id }, |r| {
                        Ok(Event { at: r.get(0)?, kind: r.get(2)?, text: r.get(3)? })
                    })?
                    .collect::<common::sql::Result<_>>()?;
                Ok(Some((id, gil, events)))
            })
            .await
    }
}

// ---------------------------------------------------------------------------
// Markup
// ---------------------------------------------------------------------------

const SEARCH_FORM: &str = r#"<form class="search" method="get" action="/reports/character">
<label for="q" class="vh">Character name</label>
<input id="q" name="name" placeholder="Character name" required><button type="submit">Look up</button></form>"#;

fn server_error(e: anyhow::Error) -> Response {
    tracing::error!(error = %format!("{e:#}"), "reports query failed");
    (
        axum::http::StatusCode::INTERNAL_SERVER_ERROR,
        Html(page(
            "Error",
            r#"<p class="error">The report query failed; the web server log has the error.</p>"#,
        )),
    )
        .into_response()
}

fn who_link(name: &str) -> String {
    if name.is_empty() || name == "console" {
        return esc(if name.is_empty() { "?" } else { name });
    }
    format!(
        r#"<a href="/reports/character?name={}">{}</a>"#,
        crate::handlers::pct(name),
        esc(name)
    )
}

fn when(unix: i64) -> String {
    chrono::DateTime::from_timestamp(unix, 0)
        .map(|t| t.format("%Y-%m-%d %H:%M").to_string())
        .unwrap_or_default()
}

fn num(n: i64) -> String {
    let s = n.unsigned_abs().to_string();
    let mut out = String::new();
    for (i, ch) in s.chars().enumerate() {
        if i > 0 && (s.len() - i).is_multiple_of(3) {
            out.push(',');
        }
        out.push(ch);
    }
    if n < 0 { format!("-{out}") } else { out }
}

fn esc(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            _ => out.push(c),
        }
    }
    out
}

fn page(title: &str, body: &str) -> String {
    format!(
        r#"<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{} · XIVLegacy reports</title><style>{STYLE}</style></head>
<body><main>{body}<footer><span>Times are UTC.</span><form method="post" action="/reports/logout"><button class="link">Sign out</button></form></footer></main></body></html>"#,
        esc(title)
    )
}

const STYLE: &str = r#"
:root { --bg:#f6f4f0; --panel:#fff; --fg:#22201c; --muted:#6d675e; --line:#e2ddd4; --accent:#8a5a1c; --err:#a3261b; color-scheme: light; }
@media (prefers-color-scheme: dark) { :root { --bg:#141218; --panel:#1d1a22; --fg:#e8e4dc; --muted:#9a93a8; --line:#332c3d; --accent:#d9a55b; --err:#ff8a7a; color-scheme: dark; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
main { max-width:1100px; margin:0 auto; padding:24px max(16px, env(safe-area-inset-left, 0px)) 48px; display:flex; flex-direction:column; gap:24px; }
h1 { font-size:1.4rem; margin:0; } h1 a { color:inherit; text-decoration:none; }
h2 { font-size:.8rem; text-transform:uppercase; letter-spacing:.08em; color:var(--muted); margin:0 0 8px; }
h2 small { color:var(--fg); font-size:inherit; margin-left:6px; }
a { color:var(--accent); }
.muted { color:var(--muted); margin:0; } .error { color:var(--err); }
.top { display:flex; flex-wrap:wrap; gap:12px 20px; align-items:center; }
.range { display:flex; flex-wrap:wrap; gap:4px; }
.range a { padding:4px 10px; border:1px solid var(--line); border-radius:999px; text-decoration:none; color:var(--fg); font-size:.85rem; }
.range a.on { background:var(--accent); border-color:var(--accent); color:var(--bg); }
.search { display:flex; gap:6px; margin-left:auto; }
input { font:inherit; padding:6px 10px; border:1px solid var(--line); border-radius:6px; background:var(--panel); color:var(--fg); min-width:0; }
button { font:inherit; padding:6px 12px; border:1px solid var(--accent); border-radius:6px; background:var(--accent); color:var(--bg); cursor:pointer; }
button.link { background:none; border:0; color:var(--accent); padding:0; text-decoration:underline; }
.tiles { display:grid; grid-template-columns:repeat(auto-fit, minmax(140px, 1fr)); gap:12px; }
.tile { background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:12px 14px; display:flex; flex-direction:column; gap:2px; }
.tile span { font-size:.75rem; text-transform:uppercase; letter-spacing:.06em; color:var(--muted); }
.tile strong { font-size:1.5rem; font-variant-numeric:tabular-nums; }
.cols { display:grid; grid-template-columns:repeat(auto-fit, minmax(320px, 1fr)); gap:24px; }
.cols > section { min-width:0; overflow-x:auto; }
section { min-width:0; overflow-x:auto; }
table { width:100%; border-collapse:collapse; background:var(--panel); border:1px solid var(--line); border-radius:8px; }
th, td { text-align:left; padding:6px 10px; border-bottom:1px solid var(--line); vertical-align:top; }
th { font-size:.75rem; text-transform:uppercase; letter-spacing:.06em; color:var(--muted); font-weight:600; }
tr:last-child td { border-bottom:0; }
td.n, th.n { text-align:right; font-variant-numeric:tabular-nums; }
td.t { white-space:nowrap; color:var(--muted); font-variant-numeric:tabular-nums; }
@media (max-width: 600px) { td.t { white-space:normal; min-width:6.5em; } th, td { padding:6px; } }
code { font:13px ui-monospace, SFMono-Regular, Menlo, monospace; word-break:break-word; }
.kind { font-size:.75rem; padding:1px 8px; border-radius:999px; border:1px solid var(--line); white-space:nowrap; }
.signin { max-width:340px; display:flex; flex-direction:column; gap:8px; }
.signin form { display:flex; flex-direction:column; gap:6px; }
.signin label { font-size:.85rem; color:var(--muted); margin-top:6px; }
.signin button { margin-top:12px; }
.vh { position:absolute; width:1px; height:1px; overflow:hidden; clip:rect(0 0 0 0); }
footer { display:flex; justify-content:space-between; gap:12px; color:var(--muted); font-size:.85rem; border-top:1px solid var(--line); padding-top:12px; }
footer form { margin:0; }
"#;

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn kills_and_deaths_show_in_the_reports() {
        use common::db::ConnCallExt;
        let db = crate::database::Database::open(common::test_db::fresh().await.unwrap())
            .await
            .unwrap();
        db.conn()
            .call_db(|c| {
                c.execute(
                    "INSERT INTO characters (id, userId, slot, serverId, name) VALUES (7101, 0, 0, 0, 'Hunter')",
                    (),
                )?;
                c.execute(
                    "INSERT INTO log_combat (at, characterId, targetId, kind, amount, zoneId) VALUES \
                     (100, 7101, 2104001, 'kill', 12, 0), (200, 7101, 2104001, 'death', 0, 0)",
                    (),
                )
            })
            .await
            .unwrap();
        let o = db.report_overview(0).await.unwrap();
        assert_eq!((o.kills, o.deaths), (1, 1));
        let (_, _, events) = db
            .report_character("Hunter", Some("combat".into()))
            .await
            .unwrap()
            .unwrap();
        let texts: Vec<_> = events.iter().map(|e| e.text.clone()).collect();
        assert_eq!(texts.len(), 2, "{texts:?}");
        assert!(texts[0].starts_with("killed by "), "{texts:?}");
        assert!(texts[1].starts_with("defeated ") && texts[1].ends_with("(level 12)"), "{texts:?}");
    }

    #[test]
    fn numbers_get_thousands_separators() {
        assert_eq!(num(0), "0");
        assert_eq!(num(999), "999");
        assert_eq!(num(1000), "1,000");
        assert_eq!(num(-1234567), "-1,234,567");
    }

    #[test]
    fn the_session_cookie_is_found_among_others() {
        let mut h = HeaderMap::new();
        h.insert(header::COOKIE, "a=1; xl_reports=abc; b=2".parse().unwrap());
        assert_eq!(session_cookie(&h).as_deref(), Some("abc"));
        assert_eq!(session_cookie(&HeaderMap::new()), None);
    }
}
