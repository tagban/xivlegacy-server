// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The worldchat module (modules/worldchat, off by default): /say reaches
//! every player online in every zone, a line goes to everyone when someone
//! logs in, and, when set up, both go to a Discord channel and that
//! channel's messages come back into the game (`settings/worldchat.toml`).
//!
//! Discord out is a webhook; Discord in is a bot token polling the channel
//! with the REST API. With a bot token the bot's status shows the players
//! online ("Watching 3 players online"), over a small gateway connection
//! used for nothing else (`presence`). Each side is off while its settings
//! are empty. Tokens and webhook URLs are never logged.

mod presence;

use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::mpsc::{SyncSender, TrySendError};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde::Deserialize;

use crate::runtime::actor_registry::{ActorHandle, ActorRegistry};
use crate::social::chat::CHAT_SAY;
use crate::world_manager::WorldManager;

pub const MODULE: &str = "worldchat";

/// The longest text the client's chat packet carries (bytes, 0x200 less
/// the terminator), and the longest sender name (0x20 less the terminator).
const PACKET_TEXT: usize = 0x1FF;
const PACKET_NAME: usize = 0x1F;
/// Discord's limit for one message.
const DISCORD_MAX: usize = 2000;

/// `settings/worldchat.toml`.
#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Settings {
    /// "<name> has logged in." to everyone online (and Discord).
    pub announce_logins: bool,
    /// World lines one character may say a minute; past it they're told to
    /// slow down and the line goes nowhere.
    pub max_per_minute: u32,
    /// The longest line (characters) a player's /say carries world-wide.
    pub max_length: usize,
    pub discord: DiscordSettings,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            announce_logins: true,
            max_per_minute: 12,
            max_length: 300,
            discord: DiscordSettings::default(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct DiscordSettings {
    /// Game to Discord: a channel webhook URL. Empty: off.
    /// `XIVLEGACY_WORLDCHAT_DISCORD_WEBHOOK` wins over this.
    pub webhook: String,
    /// The name the webhook posts under (empty: the webhook's own).
    pub username: String,
    /// Discord to game: a bot token and the channel to read. Either empty:
    /// off. `XIVLEGACY_WORLDCHAT_DISCORD_BOT_TOKEN` wins over the token.
    pub bot_token: String,
    pub channel_id: String,
    /// How often the channel is read (seconds, at least 2).
    pub poll_seconds: u64,
    /// Discord messages brought into the game per poll; the rest are
    /// skipped.
    pub max_per_poll: usize,
    /// The longest Discord message (characters) brought into the game.
    pub max_length: usize,
    /// Before a Discord name in the game: "[Discord] Name".
    pub prefix: String,
    /// Game lines waiting for Discord; past it new ones are dropped.
    pub queue: usize,
    pub api: String,
    /// The bot's status shows the players online (needs `bot_token`).
    pub presence: bool,
    /// That status, after "Watching": `{online}` is the count ("1 player"
    /// when it is one).
    pub presence_text: String,
}

impl Default for DiscordSettings {
    fn default() -> Self {
        Self {
            webhook: String::new(),
            username: String::new(),
            bot_token: String::new(),
            channel_id: String::new(),
            poll_seconds: 5,
            max_per_poll: 5,
            max_length: 200,
            prefix: "[Discord]".into(),
            queue: 100,
            api: "https://discord.com/api/v10".into(),
            presence: true,
            presence_text: presence::DEFAULT_TEXT.into(),
        }
    }
}

impl DiscordSettings {
    /// The settings with the environment's secrets over the file's.
    fn with_env(mut self) -> Self {
        if let Ok(v) = std::env::var("XIVLEGACY_WORLDCHAT_DISCORD_WEBHOOK")
            && !v.trim().is_empty()
        {
            self.webhook = v.trim().to_string();
        }
        if let Ok(v) = std::env::var("XIVLEGACY_WORLDCHAT_DISCORD_BOT_TOKEN")
            && !v.trim().is_empty()
        {
            self.bot_token = v.trim().to_string();
        }
        self
    }

    pub fn outbound(&self) -> bool {
        !self.webhook.trim().is_empty()
    }

    pub fn inbound(&self) -> bool {
        !self.bot_token.trim().is_empty() && !self.channel_id.trim().is_empty()
    }

    /// The bot's status line: on with a bot token, unless `presence` is off.
    pub fn presence_on(&self) -> bool {
        self.presence && !self.bot_token.trim().is_empty()
    }
}

/// The module's state while it is on.
pub struct WorldChat {
    pub settings: Settings,
    recent: Mutex<HashMap<u32, VecDeque<Instant>>>,
    discord_out: Mutex<Option<SyncSender<String>>>,
}

static STATE: OnceLock<WorldChat> = OnceLock::new();

/// Read `settings/worldchat.toml` when the module is enabled.
pub fn init() -> anyhow::Result<()> {
    if !crate::modules::is_enabled(MODULE) {
        return Ok(());
    }
    let mut settings: Settings = common::settings::load(MODULE, None)?;
    settings.discord = settings.discord.with_env();
    tracing::info!(
        announce_logins = settings.announce_logins,
        discord_out = settings.discord.outbound(),
        discord_in = settings.discord.inbound(),
        discord_status = settings.discord.presence_on(),
        "world chat on"
    );
    let _ = STATE.set(WorldChat::new(settings));
    Ok(())
}

/// The module, when it is on.
pub fn get() -> Option<&'static WorldChat> {
    STATE.get()
}

/// Start the Discord side (if it is set up).
pub fn start(
    world: Arc<WorldManager>,
    registry: Arc<ActorRegistry>,
    db: Arc<crate::database::Database>,
) {
    let Some(wc) = get() else {
        return;
    };
    let d = wc.settings.discord.clone();
    if d.outbound() {
        let (tx, rx) = std::sync::mpsc::sync_channel::<String>(d.queue.max(1));
        if let Ok(mut out) = wc.discord_out.lock() {
            *out = Some(tx);
        }
        let d = d.clone();
        std::thread::Builder::new()
            .name("worldchat-discord-out".into())
            .spawn(move || discord::post_loop(&d, rx))
            .ok();
    }
    if d.presence_on() {
        start_presence(d.clone(), db);
    }
    if d.inbound() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<(String, String)>();
        std::thread::Builder::new()
            .name("worldchat-discord-in".into())
            .spawn(move || discord::poll_loop(&d, tx))
            .ok();
        tokio::spawn(async move {
            while let Some((author, text)) = rx.recv().await {
                if let Some(wc) = get() {
                    wc.relay_discord(&registry, &world, &author, &text).await;
                }
            }
        });
    }
}

/// The bot's status: the players online, counted every 10 seconds as `GET
/// /status` counts them, shown by the gateway thread (`presence`), which
/// starts once the first count is in.
fn start_presence(d: DiscordSettings, db: Arc<crate::database::Database>) {
    let online = Arc::new(AtomicU32::new(0));
    tokio::spawn(async move {
        let mut gateway = false;
        let mut failing = false;
        loop {
            match db.players_online().await {
                Ok(n) => {
                    online.store(n, Ordering::Relaxed);
                    failing = false;
                }
                Err(e) => {
                    if !failing {
                        tracing::warn!(error = %e, "world chat: counting the players online failed");
                        failing = true;
                    }
                }
            }
            if !gateway {
                gateway = true;
                let (d, online) = (d.clone(), online.clone());
                std::thread::Builder::new()
                    .name("worldchat-discord-status".into())
                    .spawn(move || presence::run(&d, &online))
                    .ok();
            }
            tokio::time::sleep(Duration::from_secs(10)).await;
        }
    });
}

/// What became of a player's /say.
#[derive(Debug, PartialEq, Eq)]
pub enum Said {
    /// Delivered to this many players.
    World(usize),
    /// Past `max_per_minute`: delivered to no one.
    TooFast,
}

impl WorldChat {
    pub fn new(settings: Settings) -> Self {
        Self {
            settings,
            recent: Mutex::new(HashMap::new()),
            discord_out: Mutex::new(None),
        }
    }

    /// A player's /say: to every player online, and to Discord.
    pub async fn say(
        &self,
        registry: &ActorRegistry,
        world: &WorldManager,
        sender: &ActorHandle,
        sender_name: &str,
        message: &str,
    ) -> Said {
        if !self.allow(sender.actor_id, Instant::now()) {
            return Said::TooFast;
        }
        let text = cap_chars(message.trim(), self.settings.max_length);
        if text.is_empty() {
            return Said::World(0);
        }
        let n = send_to_all(
            registry,
            world,
            Some(sender.session_id),
            CHAT_SAY,
            sender_name,
            &text,
        )
        .await;
        self.to_discord(discord::player_line(sender_name, &text));
        Said::World(n)
    }

    /// "<name> has logged in." to everyone online (and Discord).
    pub async fn login(&self, registry: &ActorRegistry, world: &WorldManager, name: &str) -> usize {
        if !self.settings.announce_logins {
            return 0;
        }
        let line = format!("{name} has logged in.");
        let n = send_to_all(
            registry,
            world,
            None,
            crate::social::chat::CHAT_SYSTEM,
            "",
            &line,
        )
        .await;
        self.to_discord(discord::login_line(name));
        n
    }

    /// A Discord message into the game, as /say from "[Discord] Name".
    pub async fn relay_discord(
        &self,
        registry: &ActorRegistry,
        world: &WorldManager,
        author: &str,
        text: &str,
    ) -> usize {
        let text = cap_chars(text, self.settings.discord.max_length);
        if text.is_empty() {
            return 0;
        }
        let name = discord::game_sender(&self.settings.discord.prefix, author);
        send_to_all(registry, world, None, CHAT_SAY, &name, &text).await
    }

    /// Whether `actor_id` may say another world line at `now`.
    fn allow(&self, actor_id: u32, now: Instant) -> bool {
        let Ok(mut recent) = self.recent.lock() else {
            return true;
        };
        let q = recent.entry(actor_id).or_default();
        while q
            .front()
            .is_some_and(|t| now.duration_since(*t) >= Duration::from_secs(60))
        {
            q.pop_front();
        }
        if q.len() as u32 >= self.settings.max_per_minute.max(1) {
            return false;
        }
        q.push_back(now);
        true
    }

    fn to_discord(&self, line: String) {
        let Ok(out) = self.discord_out.lock() else {
            return;
        };
        if let Some(tx) = out.as_ref()
            && let Err(TrySendError::Full(_)) = tx.try_send(line)
        {
            tracing::warn!("world chat: the Discord queue is full; a line was dropped");
        }
    }
}

/// One chat line to every player online; `source` is the sender's session
/// (None: each recipient's own, for system lines and Discord). The sender
/// isn't sent their own line: the client already prints what it says, so
/// sending it back showed it twice. Returns how many players it went to.
async fn send_to_all(
    registry: &ActorRegistry,
    world: &WorldManager,
    source: Option<u32>,
    kind: u8,
    sender_name: &str,
    message: &str,
) -> usize {
    let name = cap_bytes(sender_name, PACKET_NAME);
    let text = cap_bytes(message, PACKET_TEXT);
    let mut n = 0;
    for s in world.all_sessions().await {
        let Some(handle) = registry.by_session(s.id).await else {
            continue;
        };
        if !handle.is_player() || handle.session_id == 0 || source == Some(handle.session_id) {
            continue;
        }
        let Some(client) = world.client(handle.session_id).await else {
            continue;
        };
        let pkt = crate::packets::send::misc::build_send_message(
            source.unwrap_or(handle.session_id),
            handle.session_id,
            kind,
            name,
            text,
        );
        client.send_bytes(pkt.to_bytes()).await;
        n += 1;
    }
    n
}

/// `s` cut to at most `max` characters.
fn cap_chars(s: &str, max: usize) -> String {
    s.chars().take(max).collect()
}

/// `s` cut to at most `max` bytes, on a character boundary.
fn cap_bytes(s: &str, max: usize) -> &str {
    if s.len() <= max {
        return s;
    }
    let mut end = max;
    while !s.is_char_boundary(end) {
        end -= 1;
    }
    &s[..end]
}

/// Discord: text both ways, the webhook and the channel poll.
pub mod discord {
    use super::*;

    /// A zero-width space: after an `@` it stops Discord reading a mention.
    const ZWSP: char = '\u{200B}';

    /// A game line as Discord text: no mention can work (`@` is broken up,
    /// and the webhook sends `allowed_mentions: none` too) and Discord's
    /// formatting characters show as typed.
    pub fn escape(text: &str) -> String {
        let mut out = String::with_capacity(text.len() + 8);
        for c in text.chars() {
            match c {
                '@' => {
                    out.push('@');
                    out.push(ZWSP);
                }
                '\\' | '*' | '_' | '~' | '`' | '|' | '>' | '<' | '[' | ']' | '#' => {
                    out.push('\\');
                    out.push(c);
                }
                c if c.is_control() => out.push(' '),
                c => out.push(c),
            }
        }
        out
    }

    /// A player's world line for Discord.
    pub fn player_line(name: &str, text: &str) -> String {
        cap_chars(
            &format!("**{}**: {}", escape(name), escape(text)),
            DISCORD_MAX,
        )
    }

    /// A login line for Discord.
    pub fn login_line(name: &str) -> String {
        format!("*{} has logged in.*", escape(name))
    }

    /// A Discord name as the game shows it: "[Discord] Name", letters,
    /// digits and a few marks only, within the packet's name field.
    pub fn game_sender(prefix: &str, author: &str) -> String {
        let clean: String = author
            .chars()
            .filter(|c| c.is_ascii_alphanumeric() || matches!(c, ' ' | '\'' | '-' | '.' | '_'))
            .collect();
        let clean = clean.split_whitespace().collect::<Vec<_>>().join(" ");
        let clean = if clean.is_empty() {
            "someone".to_string()
        } else {
            clean
        };
        let full = if prefix.is_empty() {
            clean
        } else {
            format!("{prefix} {clean}")
        };
        cap_bytes(&full, PACKET_NAME).trim_end().to_string()
    }

    /// A Discord message's text as the game shows it: mentions become plain
    /// names (`mentions` maps user ids to names), `@everyone` / `@here`
    /// lose their `@`, custom emoji become `:name:`, line breaks become
    /// " / ", and control characters go.
    pub fn from_discord(content: &str, mentions: &[(String, String)]) -> String {
        let mut out = String::with_capacity(content.len());
        let mut rest = content;
        while let Some(start) = rest.find('<') {
            out.push_str(&rest[..start]);
            let after = &rest[start..];
            match after.find('>') {
                Some(end) => {
                    let inner = &after[1..end];
                    match token(inner, mentions) {
                        Some(t) => out.push_str(&t),
                        None => out.push_str(&after[..=end]),
                    }
                    rest = &after[end + 1..];
                }
                None => {
                    out.push_str(after);
                    rest = "";
                }
            }
        }
        out.push_str(rest);
        let out = out
            .replace("@everyone", "everyone")
            .replace("@here", "here");
        let mut flat = String::with_capacity(out.len());
        for c in out.chars() {
            match c {
                '\n' => flat.push_str(" / "),
                c if c.is_control() || c == ZWSP => {}
                c => flat.push(c),
            }
        }
        flat.split(' ')
            .filter(|w| !w.is_empty())
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// `<…>` markup: a user, role or channel mention, an emoji, a time.
    fn token(inner: &str, mentions: &[(String, String)]) -> Option<String> {
        let digits = |s: &str| !s.is_empty() && s.chars().all(|c| c.is_ascii_digit());
        if let Some(id) = inner.strip_prefix("@!").or_else(|| inner.strip_prefix('@'))
            && digits(id)
        {
            let name = mentions
                .iter()
                .find(|(i, _)| i == id)
                .map(|(_, n)| n.as_str())
                .unwrap_or("someone");
            return Some(name.replace('@', ""));
        }
        if let Some(id) = inner.strip_prefix("@&")
            && digits(id)
        {
            return Some("(a role)".into());
        }
        if let Some(id) = inner.strip_prefix('#')
            && digits(id)
        {
            return Some("#channel".into());
        }
        let emoji = inner.strip_prefix("a:").or_else(|| inner.strip_prefix(':'));
        if let Some(e) = emoji
            && let Some((name, id)) = e.split_once(':')
            && digits(id)
        {
            return Some(format!(":{name}:"));
        }
        if inner.starts_with("t:") {
            return Some("(a time)".into());
        }
        None
    }

    /// The webhook's JSON for `content`.
    pub fn webhook_body(username: &str, content: &str) -> serde_json::Value {
        let mut body = serde_json::json!({
            "content": content,
            "allowed_mentions": { "parse": [] },
        });
        if !username.trim().is_empty() {
            body["username"] = serde_json::Value::String(username.trim().to_string());
        }
        body
    }

    /// A message read from the channel, ready for the game: (author, text).
    /// None for what isn't relayed: bots and webhooks (this module's own
    /// posts among them), and messages with nothing to show.
    pub fn relay_of(msg: &serde_json::Value, max_length: usize) -> Option<(String, String)> {
        if msg.get("webhook_id").is_some_and(|w| !w.is_null()) {
            return None;
        }
        let author = msg.get("author")?;
        if author.get("bot").and_then(|b| b.as_bool()) == Some(true) {
            return None;
        }
        // 0 default, 19 a reply; joins, pins and the like are other types
        let kind = msg.get("type").and_then(|t| t.as_u64()).unwrap_or(0);
        if kind != 0 && kind != 19 {
            return None;
        }
        let name = display_name(author);
        let mentions: Vec<(String, String)> = msg
            .get("mentions")
            .and_then(|m| m.as_array())
            .map(|a| {
                a.iter()
                    .filter_map(|u| Some((u.get("id")?.as_str()?.to_string(), display_name(u))))
                    .collect()
            })
            .unwrap_or_default();
        let content = msg.get("content").and_then(|c| c.as_str()).unwrap_or("");
        let mut text = from_discord(content, &mentions);
        let files = msg
            .get("attachments")
            .and_then(|a| a.as_array())
            .map_or(0, Vec::len);
        if files > 0 {
            if !text.is_empty() {
                text.push(' ');
            }
            text.push_str("(an attachment)");
        }
        let text = cap_chars(&text, max_length);
        if text.is_empty() {
            return None;
        }
        Some((name, text))
    }

    fn display_name(user: &serde_json::Value) -> String {
        user.get("global_name")
            .and_then(|n| n.as_str())
            .filter(|n| !n.is_empty())
            .or_else(|| user.get("username").and_then(|n| n.as_str()))
            .unwrap_or("someone")
            .to_string()
    }

    pub(super) fn agent() -> ureq::Agent {
        ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(20))
            .user_agent("xivlegacy-server world chat")
            .build()
    }

    /// Why a request failed, without its URL (a webhook URL is a secret).
    pub(super) fn why(e: &ureq::Error) -> String {
        match e {
            ureq::Error::Status(code, _) => format!("HTTP {code}"),
            ureq::Error::Transport(t) => format!("{:?}", t.kind()),
        }
    }

    /// Seconds Discord asks us to wait after a 429.
    fn retry_after(resp: ureq::Response) -> f64 {
        resp.into_json::<serde_json::Value>()
            .ok()
            .and_then(|v| v.get("retry_after").and_then(|r| r.as_f64()))
            .unwrap_or(5.0)
            .clamp(0.5, 120.0)
    }

    /// Game lines to the webhook, as they come, a few joined per post.
    pub(super) fn post_loop(d: &DiscordSettings, rx: std::sync::mpsc::Receiver<String>) {
        let agent = agent();
        while let Ok(first) = rx.recv() {
            let mut content = first;
            while let Ok(next) = rx.try_recv() {
                if content.len() + 1 + next.len() > DISCORD_MAX {
                    send(&agent, d, &content);
                    content = next;
                } else {
                    content.push('\n');
                    content.push_str(&next);
                }
            }
            send(&agent, d, &content);
            // well inside a webhook's limit of a few posts a second
            std::thread::sleep(Duration::from_millis(500));
        }
    }

    fn send(agent: &ureq::Agent, d: &DiscordSettings, content: &str) {
        let body = webhook_body(&d.username, content);
        for _ in 0..3 {
            match agent.post(d.webhook.trim()).send_json(body.clone()) {
                Ok(_) => return,
                Err(ureq::Error::Status(429, resp)) => {
                    std::thread::sleep(Duration::from_secs_f64(retry_after(resp)));
                }
                Err(e) => {
                    tracing::warn!(error = %why(&e), "world chat: posting to Discord failed");
                    return;
                }
            }
        }
    }

    /// Read the channel every `poll_seconds`, newest messages only (what
    /// was there before the server started is skipped), and hand each to
    /// the game.
    pub(super) fn poll_loop(
        d: &DiscordSettings,
        tx: tokio::sync::mpsc::UnboundedSender<(String, String)>,
    ) {
        let agent = agent();
        let url = format!(
            "{}/channels/{}/messages",
            d.api.trim_end_matches('/'),
            d.channel_id.trim()
        );
        let auth = format!("Bot {}", d.bot_token.trim());
        let pause = Duration::from_secs(d.poll_seconds.max(2));
        let mut after: Option<u64> = None;
        let mut started = false;
        let mut failing = false;
        loop {
            let mut req = agent.get(&url).set("Authorization", &auth);
            req = match after {
                Some(id) => req.query("after", &id.to_string()).query("limit", "50"),
                None => req.query("limit", "1"),
            };
            match req.call() {
                Ok(resp) => {
                    if failing {
                        tracing::info!("world chat: reading Discord again");
                        failing = false;
                    }
                    let msgs: Vec<serde_json::Value> = resp.into_json().unwrap_or_default();
                    let mut msgs: Vec<(u64, serde_json::Value)> = msgs
                        .into_iter()
                        .filter_map(|m| Some((m.get("id")?.as_str()?.parse().ok()?, m)))
                        .collect();
                    msgs.sort_by_key(|(id, _)| *id);
                    if let Some((id, _)) = msgs.last() {
                        after = Some(*id);
                    }
                    if started {
                        let mut relayed = 0;
                        for (_, m) in &msgs {
                            let Some(line) = relay_of(m, d.max_length) else {
                                continue;
                            };
                            if relayed >= d.max_per_poll.max(1) {
                                tracing::info!("world chat: Discord is busy; skipped a message");
                                continue;
                            }
                            relayed += 1;
                            if tx.send(line).is_err() {
                                return;
                            }
                        }
                    }
                    started = true;
                    std::thread::sleep(pause);
                }
                Err(ureq::Error::Status(429, resp)) => {
                    std::thread::sleep(Duration::from_secs_f64(retry_after(resp)));
                }
                Err(e) => {
                    if !failing {
                        tracing::warn!(
                            error = %why(&e),
                            "world chat: reading the Discord channel failed (bot token, \
                             channel id, the bot's View Channel / Read Message History \
                             permissions, Message Content intent); retrying"
                        );
                        failing = true;
                    }
                    std::thread::sleep(pause.max(Duration::from_secs(30)));
                }
            }
        }
    }
}

/// A player's /say: world-wide with the module on (`wc`), else to the
/// players around them as always.
pub async fn route_say(
    wc: Option<&WorldChat>,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &crate::database::Database,
    sender: &ActorHandle,
    sender_name: &str,
    message: &str,
) {
    use crate::social::{ChatKind, SocialEvent, SocialOutbox, dispatch_social_event};
    let mut ob = SocialOutbox::new();
    match wc {
        Some(wc) => {
            if wc.say(registry, world, sender, sender_name, message).await == Said::TooFast {
                ob.push(SocialEvent::ChatSystemToPlayer {
                    target_actor_id: sender.actor_id,
                    kind: ChatKind::SystemError,
                    message: format!(
                        "World chat: {} lines a minute at most. Wait a moment and say it again.",
                        wc.settings.max_per_minute.max(1)
                    ),
                });
            }
        }
        None => ob.push(SocialEvent::ChatBroadcast {
            source_actor_id: sender.actor_id,
            kind: ChatKind::Say,
            sender_name: sender_name.to_string(),
            message: message.to_string(),
        }),
    }
    for e in ob.drain() {
        dispatch_social_event(&e, registry, world, db).await;
    }
}

#[cfg(test)]
mod tests {
    use super::discord::*;
    use super::*;
    use crate::actor::Character;
    use crate::data::{ClientHandle, Session};
    use crate::runtime::actor_registry::ActorKindTag;
    use crate::zone::navmesh::StubNavmeshLoader;
    use crate::zone::zone::Zone;
    use common::Vector3;
    use tokio::sync::mpsc;

    /// Players (actor id = session id, name, zone), each with a client.
    async fn players(
        world: &WorldManager,
        registry: &ActorRegistry,
        list: &[(u32, &str, u32)],
    ) -> Vec<mpsc::Receiver<Vec<u8>>> {
        let mut out = Vec::new();
        for &(id, name, zone) in list {
            let mut c = Character::new(id);
            c.base.actor_name = name.to_string();
            c.base.custom_display_name = name.to_string();
            c.base.zone_id = zone;
            registry
                .insert(ActorHandle::new(id, ActorKindTag::Player, zone, id, c))
                .await;
            world
                .upsert_session(Session {
                    id,
                    current_zone_id: zone,
                    ..Default::default()
                })
                .await;
            let (tx, rx) = mpsc::channel(16);
            world.register_client(id, ClientHandle::new(id, tx)).await;
            out.push(rx);
        }
        out
    }

    /// Zone 100 with the given players standing in it, side by side.
    async fn zone_with(world: &WorldManager, ids: &[u32]) {
        let zone = Zone::new(
            100,
            "test",
            1,
            "/Area/Zone/Test",
            0,
            0,
            0,
            false,
            false,
            false,
            false,
            false,
            Some(&StubNavmeshLoader),
        );
        world.register_zone(zone).await;
        let z = world.zone(100).await.unwrap();
        let mut z = z.write().await;
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        for (i, &id) in ids.iter().enumerate() {
            z.core.add_actor(
                crate::zone::area::StoredActor {
                    actor_id: id,
                    kind: crate::zone::area::ActorKind::Player,
                    position: Vector3::new(i as f32 * 5.0, 0.0, 0.0),
                    grid: (0, 0),
                    is_alive: true,
                },
                &mut ob,
            );
        }
    }

    /// "sender|text" of a chat packet a client received (its body, 0x228
    /// bytes, ends the packet: the sender at 0, the text at 0x24).
    fn received(rx: &mut mpsc::Receiver<Vec<u8>>) -> Option<String> {
        let bytes = rx.try_recv().ok()?;
        let body = &bytes[bytes.len() - 0x228..];
        let field = |b: &[u8]| {
            let end = b.iter().position(|&c| c == 0).unwrap_or(b.len());
            String::from_utf8_lossy(&b[..end]).to_string()
        };
        Some(format!("{}|{}", field(&body[..0x20]), field(&body[0x24..])))
    }

    #[tokio::test]
    async fn say_reaches_players_in_other_zones_with_the_module_on() {
        let world = WorldManager::new();
        let registry = ActorRegistry::new();
        let mut rx = players(
            &world,
            &registry,
            &[
                (1, "Loud Talker", 100),
                (2, "Near Friend", 100),
                (3, "Far Friend", 200),
            ],
        )
        .await;
        zone_with(&world, &[1, 2]).await;
        let db = crate::database::Database::open(common::test_db::fresh_blocking())
            .await
            .unwrap();
        let me = registry.get(1).await.unwrap();

        // off: as before, only the players around the speaker
        route_say(
            None,
            &registry,
            &world,
            &db,
            &me,
            "Loud Talker",
            "hello there",
        )
        .await;
        let near = received(&mut rx[1]).expect("the player nearby hears it");
        assert!(
            near.contains("Loud Talker") && near.contains("hello there"),
            "{near}"
        );
        assert!(received(&mut rx[2]).is_none(), "nobody in another zone");
        while rx[0].try_recv().is_ok() {}

        // on: everyone, wherever they are, but not the speaker (the client
        // already prints its own line)
        let wc = WorldChat::new(Settings::default());
        route_say(
            Some(&wc),
            &registry,
            &world,
            &db,
            &me,
            "Loud Talker",
            "hello world",
        )
        .await;
        assert!(received(&mut rx[0]).is_none(), "no echo to the speaker");
        for (i, r) in rx.iter_mut().enumerate().skip(1) {
            let got = received(r).unwrap_or_else(|| panic!("player {i} heard nothing"));
            assert!(
                got.contains("Loud Talker") && got.contains("hello world"),
                "{got}"
            );
        }
    }

    #[tokio::test]
    async fn too_many_lines_are_held_back() {
        let world = WorldManager::new();
        let registry = ActorRegistry::new();
        let mut rx = players(
            &world,
            &registry,
            &[(1, "Spammer", 100), (2, "Victim", 200)],
        )
        .await;
        let me = registry.get(1).await.unwrap();
        let wc = WorldChat::new(Settings {
            max_per_minute: 2,
            ..Settings::default()
        });
        assert_eq!(
            wc.say(&registry, &world, &me, "Spammer", "1").await,
            Said::World(1)
        );
        assert_eq!(
            wc.say(&registry, &world, &me, "Spammer", "2").await,
            Said::World(1)
        );
        assert_eq!(
            wc.say(&registry, &world, &me, "Spammer", "3").await,
            Said::TooFast
        );
        let mut n = 0;
        while rx[1].try_recv().is_ok() {
            n += 1;
        }
        assert_eq!(n, 2);
        // a minute later it opens again
        let later = Instant::now() + Duration::from_secs(61);
        assert!(wc.allow(1, later));
    }

    #[tokio::test]
    async fn long_lines_are_cut() {
        let world = WorldManager::new();
        let registry = ActorRegistry::new();
        let mut rx = players(
            &world,
            &registry,
            &[(1, "Talker", 100), (2, "Listener", 200)],
        )
        .await;
        let me = registry.get(1).await.unwrap();
        let wc = WorldChat::new(Settings {
            max_length: 10,
            ..Settings::default()
        });
        wc.say(&registry, &world, &me, "Talker", "0123456789ABCDEF")
            .await;
        let got = received(&mut rx[1]).unwrap();
        assert!(got.contains("0123456789") && !got.contains('A'), "{got}");
    }

    #[tokio::test]
    async fn logins_are_announced_to_everyone() {
        let world = WorldManager::new();
        let registry = ActorRegistry::new();
        let mut rx = players(
            &world,
            &registry,
            &[(1, "Old Timer", 100), (2, "New Face", 200)],
        )
        .await;
        let wc = WorldChat::new(Settings::default());
        assert_eq!(wc.login(&registry, &world, "New Face").await, 2);
        for r in rx.iter_mut() {
            let got = received(r).unwrap();
            assert!(got.contains("New Face has logged in."), "{got}");
        }
        let quiet = WorldChat::new(Settings {
            announce_logins: false,
            ..Settings::default()
        });
        assert_eq!(quiet.login(&registry, &world, "New Face").await, 0);
        assert!(rx[0].try_recv().is_err());
    }

    #[tokio::test]
    async fn discord_messages_come_in_as_say() {
        let world = WorldManager::new();
        let registry = ActorRegistry::new();
        let mut rx = players(&world, &registry, &[(1, "Reader", 100)]).await;
        let wc = WorldChat::new(Settings::default());
        assert_eq!(
            wc.relay_discord(&registry, &world, "Moogle Fan", "kupo!")
                .await,
            1
        );
        let got = received(&mut rx[0]).unwrap();
        assert!(
            got.contains("[Discord] Moogle Fan") && got.contains("kupo!"),
            "{got}"
        );
    }

    #[test]
    fn game_lines_for_discord_cannot_ping_or_format() {
        assert_eq!(
            player_line("Hero Name", "@everyone look <@123> **bold**"),
            "**Hero Name**: @\u{200B}everyone look \\<@\u{200B}123\\> \\*\\*bold\\*\\*"
        );
        assert_eq!(login_line("A_B"), "*A\\_B has logged in.*");
        let body = webhook_body("Moghouse XIV", "hi");
        assert_eq!(body["allowed_mentions"]["parse"], serde_json::json!([]));
        assert_eq!(body["username"], "Moghouse XIV");
        assert!(webhook_body("", "hi").get("username").is_none());
        // Discord's own limit
        assert!(player_line("A", &"x".repeat(5000)).chars().count() <= 2000);
    }

    #[test]
    fn discord_text_comes_in_plain() {
        let mentions = vec![("42".to_string(), "Kupo".to_string())];
        assert_eq!(
            from_discord(
                "hey <@42> and <@!7> @everyone @here <@&9> in <#5> <:moogle:123> <a:dance:4>\nbye",
                &mentions
            ),
            "hey Kupo and someone everyone here (a role) in #channel :moogle: :dance: / bye"
        );
        assert_eq!(from_discord("1 < 2 > 0", &[]), "1 < 2 > 0");
        assert_eq!(from_discord("tab\there\u{200B}", &[]), "tabhere");
    }

    #[test]
    fn discord_names_fit_the_game() {
        assert_eq!(
            game_sender("[Discord]", "Moogle Fan"),
            "[Discord] Moogle Fan"
        );
        assert_eq!(
            game_sender("[Discord]", "@every<one>💥"),
            "[Discord] everyone"
        );
        assert_eq!(game_sender("[Discord]", "💥"), "[Discord] someone");
        let long = game_sender("[Discord]", &"a".repeat(80));
        assert!(long.len() <= 0x1F, "{long}");
        assert_eq!(game_sender("", "Name"), "Name");
    }

    #[test]
    fn only_people_are_relayed() {
        let person = serde_json::json!({
            "id": "10", "type": 0, "content": "hello <@42>",
            "author": { "id": "1", "username": "kupo", "global_name": "Kupo Nut" },
            "mentions": [{ "id": "42", "username": "mog" }],
            "attachments": [{ "id": "3" }]
        });
        assert_eq!(
            relay_of(&person, 200),
            Some(("Kupo Nut".into(), "hello mog (an attachment)".into()))
        );
        let ours = serde_json::json!({
            "id": "11", "type": 0, "content": "**Hero**: hi", "webhook_id": "77",
            "author": { "id": "77", "username": "Moghouse XIV", "bot": true }
        });
        assert_eq!(relay_of(&ours, 200), None);
        let bot = serde_json::json!({
            "id": "12", "type": 0, "content": "beep",
            "author": { "id": "8", "username": "ffxi-bridge", "bot": true }
        });
        assert_eq!(relay_of(&bot, 200), None);
        let join = serde_json::json!({
            "id": "13", "type": 7, "content": "",
            "author": { "id": "9", "username": "newbie" }
        });
        assert_eq!(relay_of(&join, 200), None);
        let long = serde_json::json!({
            "id": "14", "type": 0, "content": "x".repeat(500),
            "author": { "id": "9", "username": "talker" }
        });
        assert_eq!(relay_of(&long, 50).unwrap().1.len(), 50);
    }

    #[tokio::test]
    async fn the_status_counts_players_as_the_status_page_does() {
        use common::db::ConnCallExt;
        let db = crate::database::Database::open(common::test_db::fresh_blocking())
            .await
            .unwrap();
        assert_eq!(db.players_online().await.unwrap(), 0);
        let now = chrono::Utc::now().timestamp();
        db.conn_for_test()
            .call_db(move |c| {
                // two in the world (one zoning), one left behind by a crash
                for (acct, seen, state) in [
                    (1, now, "in_world"),
                    (2, now - 30, "zoning"),
                    (3, now - 600, "in_world"),
                ] {
                    c.execute(
                        r"INSERT INTO world_sessions (account_id, character_id, world_id,
                            zone_id, map_server, client_ip, conn_seq, started_at,
                            last_seen_at, state)
                          VALUES (:a, :a, 1, 100, '', '', 1, :t, :t, :s)",
                        common::sql::named_params! { ":a": acct, ":t": seen, ":s": state },
                    )?;
                }
                Ok(())
            })
            .await
            .unwrap();
        assert_eq!(db.players_online().await.unwrap(), 2);
    }

    #[test]
    fn discord_sides_need_their_settings() {
        let d = DiscordSettings::default();
        assert!(!d.outbound() && !d.inbound());
        let d = DiscordSettings {
            bot_token: "t".into(),
            ..DiscordSettings::default()
        };
        assert!(!d.inbound(), "a token alone reads no channel");
        assert!(d.presence_on(), "a token alone shows the bot's status");
        let d = DiscordSettings {
            presence: false,
            ..d
        };
        assert!(!d.presence_on());
        assert!(
            !DiscordSettings::default().presence_on(),
            "no token: no status"
        );
    }

    #[test]
    fn shipped_settings_parse_and_leave_discord_off() {
        let s: Settings =
            toml::from_str(include_str!("../../settings/default/worldchat.toml")).unwrap();
        assert!(s.announce_logins);
        assert!(!s.discord.outbound() && !s.discord.inbound());
        assert!(s.discord.presence && !s.discord.presence_on());
        assert_eq!(s.discord.presence_text, "{online} players online");
        let modules: toml::Value =
            toml::from_str(include_str!("../../settings/default/modules.toml")).unwrap();
        let on = modules["enabled"].as_array().unwrap();
        assert!(
            !on.iter().any(|m| m.as_str() == Some(MODULE)),
            "world chat stays off unless an operator turns it on"
        );
    }
}
