# Settings

| Where | What |
| --- | --- |
| `settings/default/<name>.toml` | Shipped defaults: one machine, localhost. Tracked; don't edit them |
| `settings/<name>.toml` | Your overrides: only what differs. Not tracked, so updates never touch them |

`<name>` is `web`, `lobby`, `world`, `map` or `servers` (and a module's own, such as `worldchat` or `bugreport`). Tables in an override
are merged key by key over the defaults; anything else, such as the
`[[servers]]` list, replaces the default outright. `--config <file>` on a
service names a different override file, and `XIVLEGACY_SETTINGS` a different
settings folder.

## Hosting for players on the internet

`settings/web.toml`, `settings/lobby.toml` and `settings/world.toml`, to accept
connections from other machines (the map server stays on 127.0.0.1: only the
world server talks to it):

```toml
[server]
bind_ip = "0.0.0.0"
```

`settings/servers.toml`, the address players are handed:

```toml
[[servers]]
id          = 1
name        = "Fernehalwes"
address     = "xiv.example.com"
lan_address = "auto"
port        = 54992
```

Forward TCP 54992-54994 on your router to the host; never forward 1989.

Turn on HTTPS too, so players' passwords don't cross the internet in the clear
(and security software doesn't block sign-in). It's optional and free: a
Let's Encrypt certificate the web server fetches and renews itself, plus TCP
443 forwarded. See [docs/https.md](../docs/https.md).

## Gameplay limits

Level cap, EXP rate, bag size and the GM level of new accounts are yours to
choose. Every default is the 1.23b retail value. Each setting has a **safe**
range and a **hard** range, checked once at start-up:

- a value that isn't retail is logged at INFO (`non-retail setting: ...`);
- outside the safe range the server warns (WARN, with the reason) and uses it;
- outside the hard range the client breaks, so the server logs an ERROR and
  uses the nearest end of the range instead. A gameplay value never stops the
  server from starting.

`settings/map.toml`, for example a 30-cap event server with double EXP:

```toml
[progression]
level_cap = 30
exp_rate_percent = 200
```

| Setting | File | Retail | Default | Safe | Hard | Beyond the limits |
| --- | --- | --- | --- | --- | --- | --- |
| `[progression] level_cap` | map | 50 | 50 | 1-50 | 1-50 | The client's EXP bar and the server's level, stat and ability tables end at 50, so 50 is the most. Characters above a lowered cap keep their level and earn no EXP toward the next; GM `!setlevel` still goes to 50. |
| `[progression] exp_rate_percent` | map | 100 | 100 | 0-1000 | 0-10000 | Multiplies every EXP gain of the battle classes (kills, quests, leves, GM `!giveexp`), after rested and food bonuses, rounded up. Above 1000 (10x) one kill or quest levels a character several times; past 10000 (100x) one quest reward covers the whole 1-50 curve (1,781,150 EXP), so it's clamped. 0 = no EXP. |
| `[progression] crafting_gathering_exp_rate_percent` | map | 100 | 100 | 0-1000 | 0-10000 | The same for the crafters (carpenter to culinarian) and gatherers (miner, botanist, fisher). |
| `[storage] bag_slots` | map | 200 | 200 | 50-200 | 1-200 | Normal-bag slots that take new items. The 1.23b client crashes at every login with an item at bag slot 200 or above, so this can only be lowered. Below 50 the bag fills fast: quest rewards, purchases and gathered items that don't fit are lost. Items already past a lowered size stay. |
| `[accounts] default_gm_level` | web | 0 | 0 | 0 | 0-4 | `users.gmLevel` for accounts signed up from now on (existing accounts never change). Anything above 0 makes every new account a GM, so the server warns at every start: only for private or solo servers. 4 (administrator) is the highest level. |

Other bags (currency 320, key items 500, loot, bazaar, equipment) stay at
their retail sizes: lowering them loses crystals or quest key items, and the
client's limits past retail are unknown.

## GMs and chat commands

Players type commands in chat, starting with `!` (`!zone gridania`). What each
account may use is its GM level against `settings/commands.toml`:

| Level | Name | Gets, by default |
| --- | --- | --- |
| 0 | player | `!help`, `!gmhelp`, `!who`, `!version`; on themselves: `!pos`, `!setmusic`, `!myweather`, `!mydalamud`, `!dismount`, `!wake`, `!home`, `!zone` (open places only), `!posfix` (their own account's characters) |
| 1 | helper | the same (give helpers commands by lowering them to 1) |
| 2 | GM | moving players: `!zone`, `!home` and `!posfix` on anyone, `!camp`, `!warp`, `!gmcottage` (`!gmhome`), `!revive`, `!speed`; `!setmusic` for a zone or everyone |
| 3 | senior GM | changing characters: `!givegil`, `!giveexp`, `!setclass`, `!setlevel`, `!setjob`, `!gearset`, `!equip`, grand companies, retainers |
| 4 | administrator | `!setgm`, `!reload`, quest debugging; and any command not listed |

Below `target_others` (GM by default) a command only works on whoever typed
it. `!help` shows each player the commands they have; `!gmhelp [word]` the
same with how to type each one, a line apiece (`!gmhelp gil`: just the gil
ones).

**Making the first administrator:** the map server's console isn't limited.
With `host.sh` (or `run-all.sh`), write to its GM FIFO:

```sh
echo "setgm 4 Your Name" > logs/map-server.gm.fifo
```

After that, `!setgm <level> <name>` in game; nobody can grant a level above
their own. Levels belong to the account, so all its characters share one.

**Giving players a command:** lower it in `settings/commands.toml`, for
example to let everyone teleport to camps (not retail behavior, so off by
default):

```toml
[levels]
camp = 0
```

| Command | Does |
| --- | --- |
| `!bug <what happened>` | Everyone, with the `bugreport` module on: file a bug report with your place (and the client's screenshot and logs); see [modules/bugreport](../modules/bugreport/) |
| `!pos [name]` | Everyone, on themselves: where someone is: zone, coordinates, and the `!warp` that comes back there |
| `!setmusic <music id or name> [name \| world]` / `!setmusic list` / `!setmusic off [name \| world]` | Everyone, on themselves: music only that player hears (`!setmusic gridania`, `!setmusic 59`, `!music list`). It stays through zoning, border crossings, chocobo rides and crafting (which play their own track while they run, then come back to it) until `!setmusic off` or logout. Battle music is the client's own. GMs: with no name, everyone in the GM's zone; `world`, everyone online; a name, that player (`!setmusic off world` puts everyone back). Each player keeps it as their own pick and can `!setmusic off` |
| `!myweather <weather id \| clear \| snow \| dalamud \| off>` | Everyone: a sky only you see, until you zone or the server's weather changes |
| `!mydalamud <stage 0-7 \| hide \| off>` | Everyone: Dalamud at another size (4 small .. 7 the biggest; 1-3 draw nothing) only you see, until you zone; `off` goes back to the size your main story earns |
| `!dismount [name]` / `!wake [name]` | Everyone, on themselves: clear the server's mount state (and any rental) when it is stuck / a stuck bed or dream state |
| `!endevent [name]` | Free someone held by a conversation, cutscene or menu |
| `!zone <zone id or name> [name]` | To a zone's spawn point, or beside its aetheryte (`!zone central shroud`, `!zone 155`, `!zone mordion`). Players: themselves only, and only to the three cities, the open fields and the open-world dungeons (Mistbeard Cove, Cassiopeia Hollow, the Mun-Tuy Cellars, Nanawa Mines, Copperbell Mines); the GM Cottage, Mordion Gaol, duty, dungeon and raid copies, story copies of cities and fields, inn rooms, market wards and offices are GM-only |
| `!home [name]` | Back to the home point aetheryte, revived if fallen (as Return does). Players: themselves only |
| `!camp [camp name] [name]` | To an aetheryte camp or gate by part of its name (`!camp bearded rock`); alone, lists the camps |
| `!setgm <level> <name>` | Set the GM level of a character's account |
| `!gmgear [name]` | The Judge's set, 1.0's GM outfit (all races) |
| `!togglegm [name]` | The GM icon over your head on or off (shows from GM level 2; on by default) |
| `!jail <First Last> [cell] [reason]` / `!pardon <name>` | Hold someone in a Mordion Gaol cell (see below) / release them to their home city |
| `!goto <name>` / `!bring <name>` / `!bringall` | To someone / someone to you / everyone online to you |
| `!send <name> to <name>` / `!return [name]` | One player to another / back to where the last command moved them from |
| `!up [yalms] [name]` / `!down [yalms] [name]` | Straight up or down (5 yalms by default) |
| `!posfix <name>` | To their home city; works offline, for someone who can't log in where they are. Players: any character of their own account (log in on another character to free a stuck one), never one in Mordion Gaol |
| `!logoff <name>` / `!announce <message>` | Disconnect someone / a message to everyone online |
| `!getid` | What you have targeted: actor id, class, name, position |
| `!additem` `!delitem` `!hasitem <item id> [qty] [name]` | Items (catalog ids). `!additem <id> [qty] [hq\|+1\|+2\|+3] [name]` gives a high quality one |
| `!finditem <part of a name>` | Item ids by name (`!finditem gladius`), lowest level first |
| `!setclass <class> [name]` | Switch class (`gla`, `pgl`, `mrd`, `arc`, `lnc`, `thm`, `cnj`, `crp`, `bsm`, `arm`, `gsm`, `ltw`, `wvr`, `alc`, `cul`, `min`, `btn`, `fsh`, or the full name). In 1.0 the weapon is the class: this equips the class's own weapon, or one from the bag, or gives one for its level |
| `!setlevel <class or job> <level> [name]` | A class to level 1-50 (EXP bar empty); the client, stats and the actions it unlocks follow at once. Works on characters who are offline |
| `!maxall [level] [name]` | Every class to 50 (or `level`) |
| `!setjob <job> [name]` / `!setjob none` | Take up a job (`pld`, `war`, `mnk`, `drg`, `brd`, `whm`, `blm`): the class goes to 30 if it's lower, the soul crystal and the job's first quest are given, then the switch to the class and the job / back to the class |
| `!gearset <class or job> [level] [name]` | Give and equip a set for the class at that level (its own level by default) from the item tables: the best main hand (and shield or off-hand tool) of the class, armor and accessories everyone can wear with its stats. Ends on the job when a job is named and the soul crystal is held |
| `!equip <item id> [hq\|+1\|+2\|+3] [name]` / `!unequip <slot\|all> [name]` | Put one piece on, in its own slot (a new one if the bag has none), with no class or level check / take a piece off (`head`, `body`, `legs`, `hands`, `feet`, `waist`, `neck`, `ears`, `wrists`, `ring`, `ring2`, `offhand`, or `all`) |
| `!addkeyitem` `!delkeyitem` `!haskeyitem <id> [name]` | Key items |
| `!setgil` `!takegil <amount> [name]` / `!givegil <qty> [name]` | Gil: set it, take some / add some |
| `!addquest` `!completequest` `!delquest <quest id> [name]` | Quests |
| `!addtitle <id>` `!addeffect <status id> [seconds]` `!addallaetherytes` | Titles, status effects, every aetheryte |
| `!setweather <id>` | Weather for everyone in your zone |
| `!spawn <class id> [level] [count] [path=…] [genus=…]` / `!despawn` | Monsters around you for testing (up to 8, never respawn; `path=` tries a class path, `genus=` a family) / remove them |
| `!sethp <hp>` | Your current HP (up to your max), for testing potions and healing |
| `!kill` / `!kill all` | Defeat your target or the nearest monster / every monster within 20 yalms, as if you'd won the fight (EXP, quest and leve kills count) |
| `!leve <id> [stars]` / `!leve status` / `!leve go` / `!leve poke` / `!leve open` / `!leve camp <id>` / `!leve abandon` | Start a levequest without a card / show the running one's counts and targets / go to its nearest target (or crate, or behind the beast to follow) / poke every disguised beast nearby / open the errand crate you stand by / go to a leve's camp aetheryte / abandon the running leve |
| `!event [name] [on\|off\|auto]` | Seasonal events (see below): list them, or switch one on or off whatever the date (`auto` goes back to its dates). Kept over restarts |
| `!worldend` | (finaldays module, off by default) 1.0's Final Days: Nael van Darnus, his Imperials, Atomos and other level 70-80 monsters around you and in each city (the Bombard King only falls to /firedance). Again to end it |

With no name, `!setclass`, `!setlevel`, `!maxall`, `!setjob`, `!gearset`, `!equip` and `!unequip`
work on the player you have targeted, else on you.

Below GM level 2 (`target_others`) a command works only on whoever typed it,
and `!help` / `!gmhelp` show players their commands without the `[name]`.

The FFXI server's names work too: `!where`, `!ver`, `!raise`, `!kill <name>`,
`!release`, `!promote`, `!homepoint`, `!giveitem`, `!givekeyitem`,
`!fixspeed`, `!reloadglobal`, and `!music` for `!setmusic`.

**Chat:** leading spaces are ignored, so ` !help` is a command. Start a line
with `!!` to say a command without running it: `!!zone gridania` shows
"!zone gridania" to everyone, for telling players what to type.

### World chat

With the `worldchat` module on (off by default; [modules/worldchat](../modules/worldchat/)),
`/say` reaches everyone online in every zone, everyone sees "Name has
logged in.", and both can go to a Discord channel with that channel's
messages coming back into the game. Its settings are in
`settings/worldchat.toml` (defaults in
[`settings/default/worldchat.toml`](default/worldchat.toml)).

### Seasonal events

`settings/events.toml` lists the seasonal events and when they run, by the
server's local date. The shipped calendar repeats every year:

| Event | Name | Runs | Quests |
|---|---|---|---|
| All Saints' Wake | `allsaints` | Oct 1 - Oct 31 | Impish Impositions |
| Starlight Celebration | `starlight` | Nov 1 - Jan 16 | Winter Is Not Coming (all of it); Gone with the Snow from Dec 26 |
| Hatching-tide | `hatchingtide` | Apr 1 - Apr 30 | The Dreamer's Gospel and The Dreamer's Dilemma (one of each per adventurer, offered in all three cities); Scrambled Eggs (after a Dilemma; rings, caps and daily gifts for egg sets) |
| Moonfire Faire | `moonfire` | Jun 1 - Aug 31 | The Heat Is On (2011: fireworks and summer suits), then Bombard Backlash (2012: yukata); dance at Bombards, trade their ash |

An event's NPCs and decorations show while any of its windows is open, and
each window's quests are offered only while it is open. Each window's dates
are `MM-DD`, both days included; an end before the start runs over the new
year. To change them, copy the event's whole block (all its windows) from
`settings/default/events.toml` into your `settings/events.toml` and edit
the dates; `mode = "on"` runs it whatever the date, `"off"` never.

`!starlight`, `!moonfire`, `!halloween` (or `!allsaints`) and `!easter` (or
`!hatchingtide`) run that one event and stop every other; the reply names
any of its quests not built yet. `!event auto` puts every event back on the
calendar.

`!event starlight on` or `off` overrides the file until `!event starlight
auto`. NPCs appear or vanish around players within a minute; quest offers
change at the player's next zone change. A quest already taken stays in the
journal when the event ends, but can't be finished until its NPCs come back.

### Mordion Gaol

`!jail` holds a character in a gaol cell: they're put back there if they log
in, teleport or are moved out, can't use commands, and only /say reaches
anyone, until `!pardon`. The cells are in `settings/jail.toml`; the shipped
file has one (2, 2, 2). To add cells, stand in each one, use `!pos`, and list
them in order in your `settings/jail.toml`:

```toml
[[cells]]
x = 2.0
y = 2.0
z = 2.0

[[cells]]
x = 12.5
y = 2.0
z = -4.0
```

Where you arrive in the gaol has depended on the zone you came from (from
Gridania the stone cells, from Limsa Lominsa a dark cave), so check each cell
from a couple of places.

Names don't need typing in full: any part works (`!camp bent`, a `*` is
fine too), case and apostrophes don't matter (`!zone uldah`), several
matches are listed, and a typo gets a "did you mean". The two places the
client's auto-translate menu (Tab, [Places]) offers, Limsa Lominsa and Central
Shroud, work as well.
