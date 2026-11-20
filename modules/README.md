# Modules

Optional features outside the core game: quality-of-life additions, tools for
operators, integrations. The core stays as close to the 2010 game as we can
make it; anything that isn't retail behavior belongs in a module that a server
operator chooses to run.

```
modules/<name>/module.toml   name, version, description, hooks
modules/<name>/<name>.lua    Lua hooks (optional)
modules/<name>/sql/*.sql     the module's own tables (optional)
settings/modules.toml        enabled = ["status", ...]
```

Turn modules on in `settings/modules.toml` (the list replaces the default one)
and restart. A module listed there that can't be loaded stops the server from
starting, so a typo never quietly switches a feature off.

| Module | Default | Does |
| --- | --- | --- |
| [status](status/) | on | `GET /status`: players online and recently active characters, for websites |
| [welcome](welcome/) | off | A welcome message when a player enters the world; an example to copy |
| [finaldays](finaldays/) | off | GM event commands recreating the end of 1.0 (`!worldend`) |
| [bugreport](bugreport/) | off | `!bug` and the client's bug-report key: player bug reports with place, screenshot and logs, published to a private GitHub repository and Discord |
| [worldchat](worldchat/) | off | `/say` to everyone online in every zone, login lines, and a Discord channel bridge both ways |
| [monstermode](monstermode/) | off | `!monstermode`: players take over the monster they target and fight as it (Monster Mode) |

## Lua hooks

The map server calls these in each enabled module's `<name>.lua`, after the
game's own scripts, with the same `player` object as `scripts/lua/player.lua`.
List the ones a module defines under `hooks` in its module.toml.

| Hook | When |
| --- | --- |
| `on_login(player)` | The player has entered the world (after player.lua's onLogin) |
| `on_zone_in(player)` | The player has arrived in a zone after a zone change |
| `on_logout(player)` | The player's session is ending (what it queues isn't applied) |

## SQL

Files in `sql/` run once each, in name order, when a service opens the
database, and are recorded in `schema_migrations` as `module/<name>/<file>`.
Name the module's tables `module_<name>_*` so they never collide with the
game's.

## Modules in Rust

A module that needs more than Lua (a web route, a background task, a
connection to another service such as Discord) is compiled into its service
and only switched on here; `status` is one.
