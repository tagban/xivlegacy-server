# XIVLegacy Server

[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0--or--later-blue.svg)](LICENSE.md)
[![Rust](https://img.shields.io/badge/rust-1.95-orange.svg)](rust-toolchain.toml)
[![Discord](https://img.shields.io/badge/Discord-join%20us-5865F2?logo=discord&logoColor=white)](https://discord.gg/D9k3khqvy8)

A server for **FINAL FANTASY XIV v1.23b**, the final patch of the original
1.0 release (not *A Realm Reborn*), written in Rust.

**Community:** questions, testing and news on the [XIVLegacy Discord](https://discord.gg/D9k3khqvy8).

**A passion project.** XIVLegacy preserves FINAL FANTASY XIV as it was in 1.0 so people can walk through it again — and seeing the original up close may help explain why Square Enix rebuilt it as *A Realm Reborn*. If you enjoy old Eorzea, please play the game today: FINAL FANTASY XIV has a [free trial](https://freetrial.finalfantasyxiv.com/) with no time limit.

**Where it comes from.** XIVLegacy Server is derived from the original
community server work: it is a fork of
[Garlemald Server](https://github.com/swstegall/Garlemald-Server) by Samuel
Stegall, itself a Rust port of
[Project Meteor Server](https://bitbucket.org/Ioncannon/project-meteor-server/).
The lobby, world and map services, the 1.x wire protocol, the Blowfish-keyed
session handshake and the Lua content system come from there, under the same
AGPL-3.0 license, and fixes that apply to Garlemald are still offered
upstream.

**Where it's going.** Two goals, kept apart on purpose:

- **Retail accuracy in the core.** The game should behave the way 1.23b did in
  2012: its quests, combat, monsters, drops, notorious monsters and economy.
  When the core and retail disagree, the core is wrong.
- **Quality of life in modules.** Anything that isn't retail behavior (a
  welcome message, a status page for your website, a Discord bridge, faster
  travel, conveniences for a small community) goes in an optional
  [module](modules/README.md) that each server operator chooses to turn on.

Underneath, it is being rebuilt into a server you can host for real players:
one authority for who is online, settings that never touch tracked files, a
database with enforced relationships, and a target of 100 players at once. See
[docs/DESIGN.md](docs/DESIGN.md) for the plan and its progress.

Players connect with the
[XIVLegacy launcher](https://github.com/tagban/xivlegacy-launcher) (Windows and
macOS), which sets up the 1.23b client from the original disc and patches and
joins a server. Only a client reporting version `2012.09.19.0001` can connect.

## Highlights

- Four services in one Cargo workspace (`web-server`, `lobby-server`,
  `world-server`, `map-server`) sharing a `common` crate for protocol, packet
  log, database, settings and modules
- Compatible with the 1.23b client byte for byte: TCP + Blowfish framing, 1.x
  opcodes, actor spawn fields, and the Director / ContentArea / PrivateArea /
  Zone / Weather state machines
- **1,142 Lua scripts** (quests, directors, shops, aetherytes, populace,
  commands) run by [`mlua`](https://github.com/mlua-rs/mlua) 5.4, with a
  coroutine scheduler for the upstream `_WAIT_TIME` / `_WAIT_SIGNAL` idioms
- **MariaDB** shared by all four servers: the schema and game data are laid
  down on first boot, game data reloads when its file changes, and numbered
  migrations are tracked in `schema_migrations` ([docs/database.md](docs/database.md))
- **Sessions:** the world server keeps `world_sessions`, the one record of who
  is in the game (one character per account), cleared at start-up and
  refreshed every 30 s so a crash never leaves ghosts
- **Settings:** shipped defaults in `settings/default/`, your changes in
  `settings/*.toml`, never in tracked files
- **Modules:** optional features with Lua hooks and their own tables; `status`
  serves players online and recent characters as JSON for websites
- **GM levels and chat commands:** `!zone`, `!camp`, `!warp` and more, each
  given to a GM level (player to administrator) in `settings/commands.toml`;
  see [settings/README.md](settings/README.md#gms-and-chat-commands)

## Project status

Account flow, character creation and selection, zones, NPC and monster
spawns, chat, movement, guildleves and status effects work end to end with the
1.23b client. Combat formulas, stat recalculation, levels and experience, and
the quest reward pipeline are partly done. The rebuild's phases (sessions,
modules, the relational monster/drop/NM schema, MariaDB, load testing) are
tracked in [docs/DESIGN.md](docs/DESIGN.md).

## Architecture

```
         ┌──────────────┐     signup / login (HTTP)
Client ─►│  web-server  │───┐
         │  :54993      │   │
         └──────────────┘   │ session token
                            ▼
         ┌──────────────┐ character list,
Client ─►│ lobby-server │ world handoff
         │  :54994      │
         └──────┬───────┘
                │ world handoff
                ▼
         ┌──────────────┐     zone-in
Client ─►│ world-server │─┐
         │  :54992      │ │
         └──────────────┘ │
                          ▼
         ┌──────────────┐   actors, AI,
Client ─►│  map-server  │   Lua directors,
         │  :1989       │   navmesh, combat
         └──────────────┘
                ▲
                │  shared MariaDB database (xivlegacy)
                │  shared Lua script root (./scripts/lua/)
                ▼
         ┌──────────────┐
         │  common/     │   protocol · packet log · db · lua bindings
         └──────────────┘
```

## Quick start

Requires Rust 1.95 (pinned in `rust-toolchain.toml`; `rustup` installs
it automatically on first build) and a MariaDB server with an account for the
servers: see [docs/database.md](docs/database.md) for the two-minute setup.

```sh
# Build every workspace member once, then launch the full stack.
# Per-server logs land in ./logs/{lobby,world,map,web}.log, and
# Ctrl-C propagates a clean shutdown to every child.
./scripts/run-all.sh
```

Individual services can be started on their own for debugging:

```sh
./scripts/run-web.sh     # HTTP signup/login on :54993
./scripts/run-lobby.sh   # Lobby / character-list on :54994
./scripts/run-world.sh   # World handoff on :54992
./scripts/run-map.sh     # Map / zone / AI on :1989
```

Windows hosts have `.cmd` equivalents of every script in the same
directory.

On a fresh checkout the first run creates the `xivlegacy` database, lays
down the bundled schema and game data, and boots the stack on localhost. Add `127.0.0.1` as a server in the
[XIVLegacy launcher](https://github.com/tagban/xivlegacy-launcher), then use
Create Account and Join.

## Settings

Each service reads `settings/default/<name>.toml` (shipped, don't edit) with
your overrides from `settings/<name>.toml` on top, holding only what differs.
See [settings/README.md](settings/README.md), including what to change to host
for players on the internet.

| Service | Settings | Default bind | Does |
|---|---|---|---|
| `web-server` | `web` | `127.0.0.1:54993` | Sign-up and sign-in; the `status` module's `GET /status` |
| `lobby-server` | `lobby` | `127.0.0.1:54994` | Character list and the hand-off to a world |
| `world-server` | `world` | `127.0.0.1:54992` | Sessions, routing to the map server, cross-zone chat, parties, linkshells |
| `map-server` | `map` | `127.0.0.1:1989` | Zones, actors, combat, AI and the Lua scripts |

The worlds shown at character select are `servers`, and the enabled modules
`modules`. `--config <file>` on a service names a different override file.

## Modules

Turn optional features on in `settings/modules.toml`:

```toml
enabled = ["status", "welcome"]
```

| Module | Default | Does |
|---|---|---|
| [status](modules/status/) | on | `GET /status`: players online and recently active characters with their starting city, for websites such as moghouse.cc |
| [welcome](modules/welcome/) | off | A welcome message as players enter the world; an example to copy |

Writing one: [modules/README.md](modules/README.md).

## Layout

```
xivlegacy-server/
├── common/            # Protocol, packet log, db, settings, modules (shared crate)
├── lobby-server/      # Lobby / character list binary
├── world-server/      # World registration / handoff binary
├── map-server/        # Zone / actor / AI / Lua host binary
├── web-server/        # axum HTTP signup + login binary
├── settings/          # default/: shipped settings; your overrides beside them
├── modules/           # Optional features (status, welcome, ...)
├── scripts/
│   ├── run-*.sh       # Build + launch helpers (bash and .cmd variants)
│   └── lua/           # 1,142 upstream Lua scripts — quests, directors, shops, ...
├── data-backups/      # Zip snapshots of known-good save states
└── logs/              # Per-server log files
```

## Documentation

New contributor? These docs take you from zero to running the stack to opening a
pull request:

- **[Contributing guide](CONTRIBUTING.md)** — request access, pick an issue, fork,
  and open a PR (start here).
- **[Architecture](docs/architecture.md)** — what each binary owns, how the
  servers talk to each other, and the client wire protocol.
- **[Lua runtime](docs/lua-runtime.md)** — the `map-server` content engine:
  scripts, the coroutine scheduler, the hook surface, and the command pipeline.
- **[Combat formulas](docs/combat.md)** — every hit, damage, stat and tick
  formula, where it lives in the code and where its numbers came from.
- **[Developer environment](docs/dev-environment.md)** — build/run, ports,
  `RUST_LOG` and packet-log toggles, and resetting save state.
- **[Working an issue with an AI agent](docs/agents.md)** — Claude / OpenAI setup;
  the in-repo [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) tell the agent
  the house rules.
- **[Releasing](docs/RELEASING.md)** — the `develop` → `main` branching model and
  release automation.

## Contributing

Issues and pull requests are welcome on
[tagban/xivlegacy-server](https://github.com/tagban/xivlegacy-server). Keep CI
green (`fmt` / `clippy` / `build` / `test`). Fixes that also apply to Garlemald
are worth offering upstream too.

## Attribution and licensing

XIVLegacy Server is a fork of
[Garlemald Server](https://github.com/swstegall/Garlemald-Server), which stands
on the shoulders of
[Project Meteor Server](https://bitbucket.org/Ioncannon/project-meteor-server/)
and [Seventh Umbral](https://github.com/Meteor-Project/SeventhUmbral)
for the FFXIV 1.x side, and of
[LandSandBoat](https://github.com/LandSandBoat/server) (and its
**DarkStar Project** ancestor) for the FFXI-inherited portions of the
combat, mob-AI, enmity, skillchain, status-effect, and mod-shelf
subsystems that 1.x carried forward from FFXI. Additional
indebtedness goes to the broader FFXIV 1.0 preservation community —
the FFXIV Classic wiki, the Project Meteor Discord, the Mirke
Menagerie archive, Gamer Escape, and the many packet-capture and
spreadsheet contributors whose work made the port feasible. See
[`NOTICE.md`](NOTICE.md) for the full attribution list (including the
GPL-3 → AGPL-3 combined-work rules that apply to any verbatim
LandSandBoat translations) and [`LICENSE.md`](LICENSE.md) for the full
terms of the **GNU Affero General Public License, version 3 or later**,
under which this project is distributed.

## Related projects

- **[XIVLegacy launcher](https://github.com/tagban/xivlegacy-launcher)**: the
  client for Windows and macOS, a native build of the 1.23b client with an
  installer for the game files.
- **[meteor-decomp](https://github.com/swstegall/meteor-decomp)**: a
  clean-room decompilation of the 1.23b client, the ground truth for the wire
  protocol.
