# XIVLegacy Server design

How XIVLegacy Server is being rebuilt from its Garlemald starting point into a
game server you can host for real players: one authority for who is online,
optional modules, a database with enforced relationships, and a target of
**100 players online at once**. It follows the shape of LandSandBoat, the
FFXI server, where that fits FFXIV 1.23b.

The rebuild is incremental. The game stays playable at every step: tutorials,
combat, quests and monsters keep working while the core changes underneath.
Fixes that also apply to Garlemald still go upstream.

## Where we start

Garlemald plays, but its core lacks what hosting needs:

| Area | Today | Problem |
| --- | --- | --- |
| Sessions | In memory only; the `server_sessions` table is never written | No reliable online count, no one-login-per-account rule, reconnects and crashes leave ghosts |
| Character routing | Spread across the world and map servers | No single place that knows which character is in which zone on which map server |
| Settings | Tracked files in `configs/` | Hosting changes (public address, binds) would end up in the repository |
| Database | SQLite only (WAL, foreign keys switched on), 73 tables, none declaring a foreign key | Rows can point at rows that don't exist; one writer process at a time |
| Monsters | Family, pool, group, spawn and drop tables (`server_drop_lists`) | Drop rates are rule-based (ZAM lists no rates), no notorious monsters, skill lists can hold one skill each |
| Extensions | Edit the core | No way to add a feature (a status page, a Discord bridge) without touching core code |

## Services

| Service | Port | Owns |
| --- | --- | --- |
| **connect** (today: web + lobby) | 54993, 54994 | Accounts, sign-in, character list and creation, the hand-off to a world |
| **world** | 54992 | Sessions and the character registry; routing each character to the map server running its zone; anything that crosses zones (chat, tells, parties, linkshells, friend lists) |
| **map** | 1989, internal only | The game world: zones, actors, combat, scripts. One process runs every zone today; zones can be split across several map processes later |

Players connect only to connect and world. The world server is the authority:
a map server never decides on its own who is online.

## Sessions

One table, written only by the world server, is the single source of truth for
who is in the game:

```sql
sessions (
  account_id    INTEGER NOT NULL REFERENCES accounts(id),
  character_id  INTEGER NOT NULL REFERENCES characters(id),
  world_id      INTEGER NOT NULL,
  zone_id       INTEGER NOT NULL,
  map_server    TEXT    NOT NULL,     -- which map process runs the zone
  client_ip     TEXT    NOT NULL,
  started_at    INTEGER NOT NULL,     -- unix seconds
  last_seen_at  INTEGER NOT NULL,     -- heartbeat
  state         TEXT    NOT NULL,     -- 'connecting' | 'in_world' | 'zoning' | 'linkdead'
  PRIMARY KEY (account_id)            -- one session per account
)
```

Lifecycle:

1. **Sign-in:** connect checks there is no live session for the account. If
   there is one, it is ended first (or sign-in is refused, by setting).
2. **World entry:** world inserts the row as `connecting`, then `in_world` once
   the map server confirms the character loaded.
3. **Zoning:** `zoning`, then the new zone and map server.
4. **Disconnect:** the row becomes `linkdead`. If the player returns within a
   grace period (default 60 s), the session resumes where it was. After that,
   the character is saved and the row is deleted.
5. **Heartbeat:** map servers report their live characters every 10 s. Rows
   not seen for 60 s are treated as disconnects, so a crashed map server
   cannot leave ghosts.
6. **Boot:** world clears every row; nobody is online when it starts.

`characters.last_active_at` is stamped on world entry and on logout. Online
counts and "recently active" lists then become simple queries, with no game
state involved.

## Character routing

`zones.map_server` says which map process runs each zone. World routes every
packet for a character by `sessions.zone_id → zones.map_server`. Moving a zone
to another process is a configuration change, not a code change.

## Modules

Optional features load from a list, like LandSandBoat's modules, so the core
stays small and operators choose what runs.

```
modules/
  status/
    module.toml      # name, version, description, which hooks it uses
    status.lua       # Lua hooks (optional)
    sql/001_*.sql    # its own tables and migrations (optional)
settings/modules.toml   # enabled = ["status", ...]
```

- **Lua modules** run in the map server's existing Lua runtime and hook game
  events: `on_login`, `on_logout`, `on_zone_in`, `on_mob_death`, `on_tick`, GM
  commands.
- **Rust modules** are compiled in behind Cargo features, with no dynamic
  loading, and add things Lua can't: HTTP routes on the web service, background
  tasks, outside connections such as a Discord bridge.
- **SQL** in a module goes through the same migration runner, in its own
  namespace (`module_status_*` tables).

First modules:

| Module | Does |
| --- | --- |
| `status` | `GET /status`: players online and the most recently active characters with their starting city (Limsa Lominsa, Gridania, Ul'dah), for websites such as moghouse.cc. The same JSON shape as the FFXI exporter, so one WordPress plugin reads both |
| `discord` (later) | Logins and announcements to a Discord channel |

## Settings

```
settings/default/*.toml   # shipped defaults, tracked
settings/*.toml           # the operator's overrides, not tracked (.gitignore)
```

An override file holds only what differs. A host's public address,
`lan_address`, bind addresses and passwords never sit in tracked files. This
replaces the separate config folder that hosting uses today.

## Database

- **Two backends.** SQLite is the default: one file, nothing to install, right
  for a single machine. MariaDB is optional, for hosting, several processes
  writing at once, and proper backups. The server talks to the database through
  one layer, so game code doesn't care which is in use.
- **Foreign keys declared.** SQLite already runs with `foreign_keys = ON`, but
  no table declares a key, so nothing is checked. Every relationship gets a
  declared key, enforced on both backends.
- **Migrations per backend.** The same numbered migration in SQLite and MariaDB
  dialects, run at start-up and recorded in `schema_migrations`, as today.
- **dbtool**, as in LandSandBoat: `migrate`, `status`, `backup`, `restore`,
  `import` (data from a Garlemald database).
- **Writes off the game loop.** Position and play time are written in batches
  every 30 s, and immediately at logout and zone change. Combat never waits on
  the database.

## NPCs, notorious monsters and monsters

The current tables become a relational model with enforced keys. The game data
moves over unchanged; the new parts are drops, notorious monsters and saved
spawn state.

```
mob_families   (family_id PK, name, size, speed, kindred, base stats)        -- today: server_battlenpc_genus
  └ mob_pools  (pool_id PK, family_id FK, actor_class_id FK, name, job,
                aggro, link, immunity, skill_list_id FK, spell_list_id FK)   -- today: server_battlenpc_pools
     └ mob_groups (group_id PK, pool_id FK, zone_id FK, min_level, max_level,
                   hp, mp, respawn_seconds, drop_list_id FK, spawn_type,
                   private_area, script)                                     -- today: server_battlenpc_groups
        └ mob_spawn_points (spawn_id PK, group_id FK, x, y, z, rotation,
                            display_name)                                    -- today: server_battlenpc_spawn_locations

mob_skill_lists (skill_list_id PK, name)
  └ mob_skill_list_entries (skill_list_id FK, skill_id, PK both)             -- fixes: one skill per list today
mob_spell_lists / mob_spell_list_entries                                     -- same shape
mob_mods (scope: family | pool | group | spawn, scope_id, mod_id, value)    -- today: three separate mod tables

drop_lists (drop_list_id PK, name)
  └ drop_list_items (drop_list_id FK, item_id FK, rate_per_10000,
                     drop_type: normal | rare | steal, slot_group)           -- new: groups reference drops nowhere today

notorious_monsters (nm_id PK, group_id FK, spawn_rule, window_min_s,
                    window_max_s, placeholder_group_id FK NULL,
                    placeholder_chance_per_10000, pop_item_id FK NULL,
                    conditions JSON: weather, time of day, moon)             -- new
mob_spawn_state (spawn_id FK PK, respawn_at, nm_killed_at)                   -- new: windows survive restarts

npcs (npc_id PK, actor_class_id FK, unique_id, script, display_name)        -- today: server_spawn_locations
  └ npc_spawn_points (npc_id FK, zone_id FK, private_area, x, y, z,
                      rotation, state, animation)
```

Spawn rules for notorious monsters:

| Rule | Means |
| --- | --- |
| `window` | Appears at a random time between `window_min_s` and `window_max_s` after its last death |
| `placeholder` | When the placeholder group's monster dies, a `placeholder_chance` roll replaces its next spawn with the NM |
| `pop_item` | Appears when a player trades the item at its spawn point |
| `conditions` | Combined with any of the above: only in this weather, at this time of day, in this moon phase |

`mob_spawn_state.nm_killed_at` is saved when an NM dies, so a server restart
neither resets its window nor spawns it early.

Migration: a numbered migration creates the new tables, copies the current rows
in, and keeps compatibility views under the old names until the code has moved
over. The world monster generator (`tools/world_spawns`) writes the new tables.

## 100 players

What one host has to handle, and how:

| Load | At 100 players | How |
| --- | --- | --- |
| Map simulation | 100 characters plus about 3,200 monsters and 1,300 NPCs, ticking at 10 Hz per zone | One map process with a task per zone; zones without players tick slowly. Today the idle cost of all monsters is about 5% of one core |
| Updates to clients | Each move goes to the players within 100 yalms, not the whole zone | Streaming by distance (in place), with removal past 130 yalms |
| Database | About 100 writes per 30 s in batches, plus logins and saves | Batched writes off the game loop; SQLite in WAL mode handles this; MariaDB for more processes |
| Network | Estimated 5–20 KB/s per player, to be measured | A home upload of 10 Mbit/s or more should fit 100 players |
| Memory | A few hundred MB | Measured, not guessed: see below |

Verification: a headless load-test client that signs in N bots, walks them and
fights, and reports tick time, packet rate and database latency. It runs at 25,
50, 100 and 150 bots before anything is called ready. The map server reports
tick time and players online on a metrics endpoint.

## Running it

- A Docker image and compose file, as LandSandBoat has, plus the native binaries.
- CI: format, clippy, tests, the Lua walkthroughs, a smoke boot of all services.
- Backups: `dbtool backup` on a schedule; MariaDB dumps or SQLite online backups.
- Logs per service with rotation; the metrics endpoint above.

## Order of work

| Phase | Work | Done when |
| --- | --- | --- |
| 0 ✅ | Rename to XIVLegacy Server; settings defaults and overrides | Hosting needs no edits to tracked files |
| 1 ✅ | Sessions table and lifecycle; `last_active_at`; the module loader; the `status` module | Online count and recent players are correct across logins, crashes and restarts |
| 2 | Database layer, foreign keys, the NPC, monster, drop and notorious-monster schema with migration | The game runs on the new tables; drops and NMs work |
| 3 | World as the authority: routing by `zones.map_server`, cross-zone chat, tells and parties through world | Two map processes can share the zones |
| 4 | MariaDB backend and `dbtool` | The same tests pass on both databases |
| 5 | Load-test client and metrics | 100 bots hold a steady tick |
| 6 | Docker, CI and backups | A host can deploy and update it from the docs |

## Progress notes

**Phases 0 and 1 (October 2026).** Settings, sessions, modules and the
`status` module are in, tested with the 1.23b client: a login shows up in
`GET /status` and in `world_sessions`, a disconnect removes the row and stamps
`characters.lastActiveAt`, and a killed world server's rows are cleared when it
starts again. Where it differs from the plan above:

- The table is `world_sessions` (`sessions` already holds web sign-in tokens),
  with a `conn_seq` column so a stale disconnect can't end a newer connection.
- Map servers send no session-begin confirmation (the 2010 client breaks if
  they do), so a session becomes `in_world` with the first packet its map
  server sends the player.
- There is no `linkdead` grace period yet: a disconnect ends the session, as
  the map server ends the character. Heartbeats come from the world server
  (every 30 s for the players connected to it) rather than from map servers;
  `GET /status` counts rows seen in the last 90 s.
- `zone_id` follows zone changes that move a player between map servers; with
  one map server it keeps the zone the player entered the world in, until
  phase 3 routes zone changes through the world server.

## Relationship to Garlemald

XIVLegacy Server started as a fork of
[Garlemald Server](https://github.com/swstegall/Garlemald-Server) (AGPL-3.0),
itself a port of Project Meteor Server. It keeps the AGPL-3.0 license and the
history. Fixes that apply to Garlemald as it stands are still offered upstream
as pull requests.
