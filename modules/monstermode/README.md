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

## Monster Points

Playing as a monster earns Monster Points (currency 1000124): 15 for a kill at
even level, 3 more or less per level of difference (30 at most, none for prey
5+ levels below the body, half for the 6th+ kill of one kind in 10 minutes),
plus a point per active minute when letting go (20 at most). At most 600 a
day and 3,000 a week. The tester form (`!monstermode <class id>`) earns none.

Three monster vendors sell level 50 gear for them: Nibbles Coinwhisker (a
Qiqirn) in Ul'dah's Quicksand, Mogsley Pompomtrade (a Moogle) in Gridania's
Carline Canopy and Gobbie Grubtrader (a Goblin) in Limsa's Drowning Wench.
They spawn only while this module is on (`server_spawn_location_modules`).
Talking to one lists the goods in chat; `!mp` (everyone) shows the balance,
`!mp list` the goods and `!mp buy <number>` buys next to a vendor. The goods
and prices are in `scripts/lua/monsterpoints.lua`. Its `MP_SHOP_WINDOW`
opens the game's shop window instead, but only clients with the XIVLegacy
Monster Points patch (xivlegacy-launcher #34) have that window; any other
client crashes, so leave it off unless every player runs a patched client.

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
