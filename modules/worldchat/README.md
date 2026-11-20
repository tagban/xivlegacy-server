# worldchat

World chat for small servers, where players are spread thin over many zones.

- **`/say` reaches everyone online**, in every zone, shown as ordinary say
  with the speaker's name. `/shout`, `/yell`, linkshell, party and tells are
  unchanged.
- **Logins:** everyone online sees "Name has logged in." (`announce_logins`).
- **Discord, both ways (optional):** world chat and login lines go to a
  Discord channel, and what people write in that channel comes into the game
  as say from "[Discord] Name".

Off by default: the core stays 1.0's local `/say`.

**Limits.** A character may say `max_per_minute` world lines a minute (12);
past that they're told to wait and the line goes nowhere. Lines are cut to
`max_length` characters (300), and the client's own packet limits still
apply. A character in Mordion Gaol keeps ordinary local `/say` and gets no
login line. Commands (`!…`) are never chat, and `!!` lines are said as typed.

## Turning it on

1. `settings/modules.toml`: add `"worldchat"` to `enabled`, for example
   `enabled = ["status", "worldchat"]` (the list replaces the default one).
2. Restart the map server.

That's all for world chat and login lines. Other settings are in
[`settings/default/worldchat.toml`](../../settings/default/worldchat.toml);
put what you change in `settings/worldchat.toml`.

## Discord

The map server talks to Discord itself; nothing else needs to run. Each
direction is off until its settings are filled in, so you can have either
one alone.

### Game to Discord: a webhook

1. In Discord, the channel's settings, **Integrations**, **Webhooks**,
   **New Webhook**; name it (for example after your world) and **Copy
   Webhook URL**.
2. Give it to the map server, preferably in its environment:

   ```sh
   XIVLEGACY_WORLDCHAT_DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
   ```

   or as `webhook` under `[discord]` in `settings/worldchat.toml` (that file
   is not tracked by git).

Lines are posted as `**Name**: text`, a few joined per post when chat is
busy; logins as `*Name has logged in.*`. Nothing a player writes can ping
anyone: every `@` is broken up and the webhook sends `allowed_mentions: none`.
Discord's formatting characters show as typed. If Discord is slow or down,
up to `queue` lines wait (100); newer ones are then dropped, and the game is
never held up.

### Discord to game: a bot reading the channel

The server reads the channel every `poll_seconds` (5) with Discord's REST
API; it doesn't connect to Discord's gateway.

1. <https://discord.com/developers/applications>, **New Application**; under
   **Bot**, **Reset Token** and copy it, and switch on **Message Content
   Intent** (without it Discord sends the server empty messages).
2. Invite the bot to your Discord server (**OAuth2**, **URL Generator**,
   scope `bot`, permissions **View Channels** and **Read Message History**;
   it never posts, so it needs no Send Messages).
3. The channel id: Discord's **Settings**, **Advanced**, **Developer
   Mode** on, then right-click the channel, **Copy Channel ID**.
4. Settings:

   ```sh
   XIVLEGACY_WORLDCHAT_DISCORD_BOT_TOKEN=...
   ```

   ```toml
   # settings/worldchat.toml
   [discord]
   channel_id = "123456789012345678"
   ```

Only messages written after the map server started come in. Messages from
bots and webhooks (the server's own posts among them) are skipped, so nothing
echoes. Mentions become plain names, `@everyone` / `@here` lose their `@`,
custom emoji show as `:name:`, line breaks as ` / `, an attachment as
"(an attachment)". Each message is cut to `max_length` characters (200), at
most `max_per_poll` messages (5) come in per read, and Discord names keep
only letters, digits, spaces and `' - . _` (the game's name field is 31
bytes, prefix included).

A failed read is logged once (without the token) and retried every 30
seconds: check the token, the channel id, the bot's permissions in that
channel and the Message Content intent.

### Using the bot you already have

If a bot already bridges another game's chat (an FFXI server's, say), you
can reuse it instead of making a new one: give its token as
`XIVLEGACY_WORLDCHAT_DISCORD_BOT_TOKEN`, make sure it can see the new
channel (View Channels, Read Message History) and that its application has
the Message Content intent on, and set `channel_id` to the new channel. This
server only reads with the token over REST, so it doesn't disturb that bot's
own gateway connection. Use a webhook of the new channel for the other
direction, and keep world chat in its own channel: the other bridge's posts
are skipped here as bot messages, but a shared channel would mix both games.

Keep tokens and webhook URLs out of git and out of chat logs: anyone who has
the webhook URL can post in the channel, and anyone with the bot token can
act as the bot. The server never logs either.
