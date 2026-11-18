# Settings

| Where | What |
| --- | --- |
| `settings/default/<name>.toml` | Shipped defaults: one machine, localhost. Tracked; don't edit them |
| `settings/<name>.toml` | Your overrides: only what differs. Not tracked, so updates never touch them |

`<name>` is `web`, `lobby`, `world`, `map` or `servers`. Tables in an override
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

## GMs and chat commands

Players type commands in chat, starting with `!` (`!zone gridania`). What each
account may use is its GM level against `settings/commands.toml`:

| Level | Name | Gets, by default |
| --- | --- | --- |
| 0 | player | `!help`, `!gmhelp`, `!who`, `!version` |
| 1 | helper | the same (give helpers commands by lowering them to 1) |
| 2 | GM | moving players: `!zone`, `!camp`, `!warp`, `!home`, `!revive`, `!speed` |
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
| `!pos [name]` | Where someone is: zone, coordinates, and the `!warp` that comes back there |
| `!endevent [name]` | Free someone held by a conversation, cutscene or menu |
| `!zone <zone id or name> [name]` | To a zone's spawn point, or beside its aetheryte (`!zone central shroud`, `!zone 155`, `!zone mordion`) |
| `!camp [camp name] [name]` | To an aetheryte camp or gate by part of its name (`!camp bearded rock`); alone, lists the camps |
| `!setgm <level> <name>` | Set the GM level of a character's account |
| `!gmgear [name]` | The Judge's set, 1.0's GM outfit (all races) |
| `!togglegm [name]` | The GM icon over your head on or off (shows from GM level 2; on by default) |
| `!jail <First Last> [cell] [reason]` / `!pardon <name>` | Hold someone in a Mordion Gaol cell (see below) / release them to their home city |
| `!goto <name>` / `!bring <name>` / `!bringall` | To someone / someone to you / everyone online to you |
| `!send <name> to <name>` / `!return [name]` | One player to another / back to where the last command moved them from |
| `!up [yalms] [name]` / `!down [yalms] [name]` | Straight up or down (5 yalms by default) |
| `!posfix <name>` | To their home city; works offline, for someone who can't log in where they are |
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
| `!setmusic <id> [name]` / `!setweather <id>` | Music for someone / weather for your zone |
| `!spawn <class id> [level] [count] [path=…] [genus=…]` / `!despawn` | Monsters around you for testing (up to 8, never respawn; `path=` tries a class path, `genus=` a family) / remove them |
| `!sethp <hp>` | Your current HP (up to your max), for testing potions and healing |
| `!kill` / `!kill all` | Defeat your target or the nearest monster / every monster within 20 yalms, as if you'd won the fight (EXP, quest and leve kills count) |
| `!event [name] [on\|off\|auto]` | Seasonal events (see below): list them, or switch one on or off whatever the date (`auto` goes back to its dates). Kept over restarts |
| `!worldend` | (finaldays module, off by default) 1.0's Final Days: Nael van Darnus, his Imperials, Atomos and other level 70-80 monsters around you and in each city (the Bombard King only falls to /firedance). Again to end it |

With no name, `!setclass`, `!setlevel`, `!maxall`, `!setjob`, `!gearset`, `!equip` and `!unequip`
work on the player you have targeted, else on you.

The FFXI server's names work too: `!where`, `!ver`, `!raise`, `!kill <name>`,
`!release`, `!promote`, `!homepoint`, `!giveitem`, `!givekeyitem`,
`!fixspeed`, `!reloadglobal`.

**Chat:** leading spaces are ignored, so ` !help` is a command. Start a line
with `!!` to say a command without running it: `!!zone gridania` shows
"!zone gridania" to everyone, for telling players what to type.

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
