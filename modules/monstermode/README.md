# monstermode

Monster Mode: a player takes over the monster they target and plays it, its
body, level, HP, moves and all, like FFXI's Monstrosity. Fun for players and
a way to try every monster move by hand. Off by default; turn it on with

```toml
# settings/modules.toml
enabled = ["status", "monstermode"]
```

and restart the map server.

| Command | Level | Does |
| --- | --- | --- |
| `!monstermode` | GM (3) | Take over your target monster; again to let go (not mid-fight) |
| `!monstermode <class id>` | GM (3) | Tester form: become a fresh monster of that class |
| `!monstermode ok [move] [note]` / `bad [move] [note]` | GM (3) | Mark the last move (or a named one) as working or broken |

Defeat, a zone change, logging out, changing class or gear all put the
player back in their own body. A monster body earns no experience or loot,
and nothing about it is ever saved to the character.

What players do as monsters goes to `log_monster_mode` (moves used, refused
and marked; see docs/database.md), shown on the web server's reports page
at `/reports/monster-mode`. `tools/monster_mode/export_moves.py` exports it
for the status tracker.

While the module is off, `!monstermode` answers that Monster Mode isn't
enabled and isn't listed by `!help`. The levels are in
`settings/default/commands.toml`; change them in `settings/commands.toml`.
The code is Rust, compiled into the map server
(`map-server/src/runtime/monster_mode.rs`,
`map-server/src/command_processor/monster_mode.rs`); this folder only
switches it on.
