// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The world chat bot's status line on Discord ("Watching 3 players
//! online"). A bot's status can only be set over Discord's gateway (a
//! websocket), so this keeps one small gateway connection open for it and
//! nothing else: intents 0 (no events wanted), no resume (a fresh identify
//! on every reconnect), a status update when the count changes but at most
//! one every [`MIN_GAP`].
//!
//! It runs on its own thread; a Discord outage only delays the status line.
//! The bot token is never logged.

use std::io::ErrorKind;
use std::net::{TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicU32, Ordering};
use std::time::{Duration, Instant};

use serde_json::{Value, json};
use tungstenite::stream::MaybeTlsStream;
use tungstenite::{HandshakeError, Message, WebSocket};

use super::DiscordSettings;

/// The shortest time between two status updates (Discord allows about five
/// a minute).
pub const MIN_GAP: Duration = Duration::from_secs(20);

/// The status text when `presence_text` is empty.
pub const DEFAULT_TEXT: &str = "{online} players online";

/// Discord's longest activity name.
const ACTIVITY_MAX: usize = 128;

/// The status text for `online` players: `{online}` becomes the count, and
/// for one player "{online} players" reads "1 player".
pub fn text(template: &str, online: u32) -> String {
    let t = if template.trim().is_empty() {
        DEFAULT_TEXT
    } else {
        template.trim()
    };
    let t = if online == 1 {
        t.replace("{online} players", "{online} player")
    } else {
        t.to_string()
    };
    t.replace("{online}", &online.to_string())
        .chars()
        .take(ACTIVITY_MAX)
        .collect()
}

/// The presence object: "Watching <text>", status online.
pub fn presence(text: &str) -> Value {
    json!({
        "since": null,
        "activities": [{ "name": text, "type": 3 }],
        "status": "online",
        "afk": false,
    })
}

/// Op 3, Presence Update.
pub fn presence_update(text: &str) -> Value {
    json!({ "op": 3, "d": presence(text) })
}

/// Op 2, Identify: no intents, and the status from the start.
pub fn identify(token: &str, text: &str) -> Value {
    json!({
        "op": 2,
        "d": {
            "token": token,
            "intents": 0,
            "properties": {
                "os": std::env::consts::OS,
                "browser": "xivlegacy-server",
                "device": "xivlegacy-server",
            },
            "presence": presence(text),
        },
    })
}

/// Op 1, Heartbeat, with the last sequence number seen.
pub fn heartbeat(seq: Option<u64>) -> Value {
    json!({ "op": 1, "d": seq })
}

/// When to send a status update: the latest count, when it differs from
/// what Discord shows and the last update is at least `gap` old.
#[derive(Debug)]
pub struct Limiter {
    gap: Duration,
    last: Option<Instant>,
    shown: Option<u32>,
}

impl Limiter {
    pub fn new(gap: Duration) -> Self {
        Self {
            gap,
            last: None,
            shown: None,
        }
    }

    /// The count to send now, if any.
    pub fn due(&self, now: Instant, online: u32) -> Option<u32> {
        if self.shown == Some(online) {
            return None;
        }
        if let Some(last) = self.last
            && now.duration_since(last) < self.gap
        {
            return None;
        }
        Some(online)
    }

    /// `online` was sent at `now` (an update, or the identify's presence).
    pub fn sent(&mut self, now: Instant, online: u32) {
        self.last = Some(now);
        self.shown = Some(online);
    }
}

/// The wait before reconnect number `attempt` (0 first): 5 s, doubling, at
/// most 5 minutes. Never under 5 s, Discord's identify limit.
pub fn backoff(attempt: u32) -> Duration {
    Duration::from_secs((5u64 << attempt.min(7)).min(300))
}

/// Gateway close codes that won't get better by reconnecting, with what to
/// tell the operator: a bad token, or a request Discord refuses.
pub fn fatal_close(code: u16) -> Option<&'static str> {
    match code {
        4004 => Some("Discord rejected the bot token"),
        4010..=4014 => Some("Discord refused the gateway connection"),
        _ => None,
    }
}

/// How a connection ended.
enum End {
    /// Reconnect (after the backoff).
    Again,
    /// Give up until the server restarts (already logged).
    Stop,
}

/// Keep the bot's status showing `online` until a fatal error.
pub(super) fn run(d: &DiscordSettings, online: &AtomicU32) {
    let token = d.bot_token.trim().to_string();
    let agent = super::discord::agent();
    let mut limiter = Limiter::new(MIN_GAP);
    let mut attempt = 0u32;
    let mut failing = false;
    loop {
        let started = Instant::now();
        let result = match gateway_url(&agent, &d.api, &token) {
            Ok(Some(url)) => session(&url, &token, d, online, &mut limiter, &mut failing),
            Ok(None) => Ok(End::Stop),
            Err(e) => Err(e),
        };
        match result {
            Ok(End::Stop) => return,
            Ok(End::Again) => {}
            Err(why) => {
                if !failing {
                    tracing::warn!(
                        error = %why,
                        "world chat: the bot's Discord status connection failed; retrying"
                    );
                    failing = true;
                }
            }
        }
        if started.elapsed() >= Duration::from_secs(300) {
            attempt = 0;
        }
        std::thread::sleep(backoff(attempt));
        attempt = attempt.saturating_add(1);
    }
}

/// The gateway's websocket URL, from `GET /gateway/bot`. None: Discord
/// rejected the token, which stops the status for good (logged here).
fn gateway_url(agent: &ureq::Agent, api: &str, token: &str) -> Result<Option<String>, String> {
    let url = format!("{}/gateway/bot", api.trim_end_matches('/'));
    match agent
        .get(&url)
        .set("Authorization", &format!("Bot {token}"))
        .call()
    {
        Ok(resp) => {
            let v: Value = resp.into_json().map_err(|e| e.kind().to_string())?;
            let base = v
                .get("url")
                .and_then(|u| u.as_str())
                .ok_or("no gateway url in Discord's answer")?;
            Ok(Some(format!(
                "{}/?v=10&encoding=json",
                base.trim_end_matches('/')
            )))
        }
        Err(ureq::Error::Status(401, _)) => {
            tracing::warn!(
                "world chat: Discord rejected the bot token (HTTP 401); the bot's status \
                 stays off until the map server restarts"
            );
            Ok(None)
        }
        Err(e) => Err(super::discord::why(&e)),
    }
}

type Socket = WebSocket<MaybeTlsStream<TcpStream>>;

/// A websocket to `url` (wss://host[:port]/…), reading with a 1 s timeout
/// so the heartbeat and status keep their times.
fn connect(url: &str) -> Result<Socket, String> {
    let rest = url
        .strip_prefix("wss://")
        .ok_or("the gateway url isn't wss://")?;
    let authority = rest.split(['/', '?']).next().unwrap_or(rest);
    let (host, port) = match authority.rsplit_once(':') {
        Some((h, p)) => (h, p.parse::<u16>().map_err(|_| "bad gateway port")?),
        None => (authority, 443),
    };
    let addr = (host, port)
        .to_socket_addrs()
        .map_err(|e| format!("resolving the gateway: {}", e.kind()))?
        .next()
        .ok_or("the gateway's name has no address")?;
    let tcp = TcpStream::connect_timeout(&addr, Duration::from_secs(15))
        .map_err(|e| format!("connecting to the gateway: {}", e.kind()))?;
    let io = |e: std::io::Error| e.kind().to_string();
    tcp.set_read_timeout(Some(Duration::from_secs(15)))
        .map_err(io)?;
    tcp.set_write_timeout(Some(Duration::from_secs(15)))
        .map_err(io)?;
    let handle = tcp.try_clone().map_err(io)?;
    let (ws, _) = tungstenite::client_tls(url, tcp).map_err(|e| match e {
        HandshakeError::Failure(e) => format!("gateway handshake: {e}"),
        HandshakeError::Interrupted(_) => "gateway handshake timed out".to_string(),
    })?;
    handle
        .set_read_timeout(Some(Duration::from_secs(1)))
        .map_err(io)?;
    Ok(ws)
}

fn send(ws: &mut Socket, v: &Value) -> Result<(), String> {
    ws.send(Message::text(v.to_string()))
        .map_err(|e| format!("gateway send: {e}"))
}

/// One gateway connection: Hello, Identify, then heartbeats and status
/// updates until Discord asks for a reconnect or the connection drops.
fn session(
    url: &str,
    token: &str,
    d: &DiscordSettings,
    online: &AtomicU32,
    limiter: &mut Limiter,
    failing: &mut bool,
) -> Result<End, String> {
    let mut ws = connect(url)?;

    // Hello (op 10) carries the heartbeat interval
    let hello_by = Instant::now() + Duration::from_secs(20);
    let interval = loop {
        if Instant::now() >= hello_by {
            return Err("no Hello from the gateway".into());
        }
        match read(&mut ws)? {
            Some(Read::Op(10, v)) => {
                let ms = v["d"]["heartbeat_interval"].as_u64().unwrap_or(41_250);
                break Duration::from_millis(ms.max(1000));
            }
            Some(Read::Closed(code)) => return closed(code),
            _ => {}
        }
    };
    // the first beat at a random point in the interval, as Discord asks
    let mut next_beat = Instant::now() + interval.mul_f64(rand::random::<f64>());
    let mut acked = true;
    let mut seq: Option<u64> = None;
    let mut ready = false;

    let n = online.load(Ordering::Relaxed);
    send(&mut ws, &identify(token, &text(&d.presence_text, n)))?;
    limiter.sent(Instant::now(), n);

    loop {
        let now = Instant::now();
        if now >= next_beat {
            if !acked {
                return Err("the gateway stopped answering heartbeats".into());
            }
            send(&mut ws, &heartbeat(seq))?;
            acked = false;
            next_beat = now + interval;
        }
        if ready && let Some(n) = limiter.due(now, online.load(Ordering::Relaxed)) {
            send(&mut ws, &presence_update(&text(&d.presence_text, n)))?;
            limiter.sent(now, n);
        }
        match read(&mut ws)? {
            None => {}
            Some(Read::Closed(code)) => return closed(code),
            Some(Read::Op(op, v)) => {
                if let Some(s) = v.get("s").and_then(|s| s.as_u64()) {
                    seq = Some(s);
                }
                match op {
                    // a dispatch; the only one asked for is READY
                    0 if v.get("t").and_then(|t| t.as_str()) == Some("READY") => {
                        ready = true;
                        if *failing {
                            tracing::info!("world chat: the bot's Discord status is back");
                            *failing = false;
                        } else {
                            tracing::info!("world chat: the bot's Discord status is on");
                        }
                    }
                    // Discord wants a heartbeat now
                    1 => {
                        send(&mut ws, &heartbeat(seq))?;
                        acked = false;
                        next_beat = Instant::now() + interval;
                    }
                    // Reconnect, Invalid Session: a fresh identify after the backoff
                    7 | 9 => {
                        tracing::debug!(op, "world chat: the gateway asked for a reconnect");
                        return Ok(End::Again);
                    }
                    11 => acked = true,
                    _ => {}
                }
            }
        }
    }
}

enum Read {
    /// A gateway payload: its op and the whole JSON.
    Op(u64, Value),
    /// The gateway closed the connection (its close code, if any).
    Closed(Option<u16>),
}

/// The next gateway payload, or None when nothing came within the read
/// timeout (or it wasn't JSON).
fn read(ws: &mut Socket) -> Result<Option<Read>, String> {
    match ws.read() {
        Ok(Message::Text(t)) => {
            let Ok(v) = serde_json::from_str::<Value>(t.as_str()) else {
                return Ok(None);
            };
            let op = v.get("op").and_then(|o| o.as_u64()).unwrap_or(u64::MAX);
            Ok(Some(Read::Op(op, v)))
        }
        Ok(Message::Close(frame)) => Ok(Some(Read::Closed(frame.map(|f| u16::from(f.code))))),
        Ok(_) => Ok(None),
        Err(tungstenite::Error::Io(e))
            if matches!(e.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) =>
        {
            Ok(None)
        }
        Err(tungstenite::Error::ConnectionClosed | tungstenite::Error::AlreadyClosed) => {
            Ok(Some(Read::Closed(None)))
        }
        Err(e) => Err(format!("gateway read: {e}")),
    }
}

/// What a close code means: stop for good (logged once), or reconnect.
fn closed(code: Option<u16>) -> Result<End, String> {
    if let Some(c) = code
        && let Some(why) = fatal_close(c)
    {
        tracing::warn!(
            close_code = c,
            "world chat: {why}; the bot's status stays off until the map server restarts"
        );
        return Ok(End::Stop);
    }
    match code {
        Some(c) => Err(format!("the gateway closed the connection (code {c})")),
        None => Err("the gateway closed the connection".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_text_counts_players() {
        assert_eq!(text(DEFAULT_TEXT, 0), "0 players online");
        assert_eq!(text(DEFAULT_TEXT, 1), "1 player online");
        assert_eq!(text(DEFAULT_TEXT, 12), "12 players online");
        assert_eq!(text("", 3), "3 players online", "empty: the default");
        assert_eq!(
            text("Eorzea: {online} adventurers", 1),
            "Eorzea: 1 adventurers",
            "only \"players\" is made singular"
        );
        assert_eq!(text(&"x".repeat(300), 2).chars().count(), 128);
    }

    #[test]
    fn payloads_are_what_discord_expects() {
        assert_eq!(
            presence_update("3 players online"),
            json!({
                "op": 3,
                "d": {
                    "since": null,
                    "activities": [{ "name": "3 players online", "type": 3 }],
                    "status": "online",
                    "afk": false,
                }
            })
        );
        let id = identify("tok", "1 player online");
        assert_eq!(id["op"], 2);
        assert_eq!(id["d"]["token"], "tok");
        assert_eq!(id["d"]["intents"], 0, "no intents: presence needs none");
        assert_eq!(
            id["d"]["presence"]["activities"][0]["name"],
            "1 player online"
        );
        assert_eq!(id["d"]["presence"]["activities"][0]["type"], 3);
        assert_eq!(heartbeat(None), json!({ "op": 1, "d": null }));
        assert_eq!(heartbeat(Some(42)), json!({ "op": 1, "d": 42 }));
    }

    #[test]
    fn at_most_one_update_per_gap_with_the_latest_count() {
        let t0 = Instant::now();
        let s = |n| t0 + Duration::from_secs(n);
        let mut l = Limiter::new(MIN_GAP);
        // nothing shown yet: the first count goes out at once
        assert_eq!(l.due(t0, 0), Some(0));
        l.sent(t0, 0);
        // the same count: nothing to send
        assert_eq!(l.due(s(60), 0), None);
        // a change right away waits for the gap...
        assert_eq!(l.due(s(1), 1), None);
        assert_eq!(l.due(s(19), 2), None);
        // ...and then the latest count goes, once
        assert_eq!(l.due(s(20), 3), Some(3));
        l.sent(s(20), 3);
        assert_eq!(l.due(s(25), 4), None);
        assert_eq!(l.due(s(39), 5), None);
        assert_eq!(l.due(s(40), 5), Some(5));
        // back to what is shown before the gap: nothing to send
        l.sent(s(40), 5);
        assert_eq!(l.due(s(70), 5), None);

        // over a busy stretch, never two updates within the gap
        let mut l = Limiter::new(MIN_GAP);
        let mut sent = Vec::new();
        for sec in 0..300u64 {
            let now = s(sec);
            if let Some(n) = l.due(now, sec as u32) {
                l.sent(now, n);
                sent.push(sec);
            }
        }
        assert!(sent.windows(2).all(|w| w[1] - w[0] >= 20), "{sent:?}");
        assert_eq!(sent.len(), 15);
    }

    #[test]
    fn zero_players_still_shows_the_status() {
        // on connect the identify carries the status, at 0 too, and online
        let id = identify("tok", &text(DEFAULT_TEXT, 0));
        let p = &id["d"]["presence"];
        assert_eq!(p["status"], "online");
        assert_eq!(p["activities"][0]["name"], "0 players online");
        assert_eq!(p["activities"][0]["type"], 3);
        // a fresh limiter sends 0 like any count
        let t0 = Instant::now();
        let mut l = Limiter::new(MIN_GAP);
        assert_eq!(l.due(t0, 0), Some(0));
        // and when everyone logs out, 0 goes out (still status online)
        l.sent(t0, 2);
        assert_eq!(l.due(t0 + MIN_GAP, 0), Some(0));
        assert_eq!(
            presence_update(&text(DEFAULT_TEXT, 0))["d"]["status"],
            "online"
        );
    }

    #[test]
    fn reconnects_back_off_from_5_seconds_to_5_minutes() {
        let secs: Vec<u64> = (0..10).map(|a| backoff(a).as_secs()).collect();
        assert_eq!(secs, [5, 10, 20, 40, 80, 160, 300, 300, 300, 300]);
        assert_eq!(backoff(u32::MAX), Duration::from_secs(300));
    }

    #[test]
    fn bad_tokens_stop_and_other_closes_reconnect() {
        assert!(fatal_close(4004).is_some());
        assert!(fatal_close(4013).is_some());
        assert!(fatal_close(4014).is_some());
        for code in [1000, 1001, 4000, 4007, 4008, 4009] {
            assert!(fatal_close(code).is_none(), "{code}");
        }
        assert!(matches!(closed(Some(4004)), Ok(End::Stop)));
        assert!(closed(Some(4000)).is_err());
        assert!(closed(None).is_err());
    }
}
