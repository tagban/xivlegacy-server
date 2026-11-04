# Database

All four servers share one MariaDB database. MariaDB 10.6 or newer works; CI
runs 11.4 and development uses 12.3.

## Set up MariaDB

Install MariaDB (`brew install mariadb`, `apt install mariadb-server`, or the
Windows installer), start it, then make an account and a database for the
servers:

```sql
CREATE USER 'xivlegacy'@'localhost' IDENTIFIED BY 'choose-a-password';
CREATE USER 'xivlegacy'@'127.0.0.1' IDENTIFIED BY 'choose-a-password';
GRANT ALL PRIVILEGES ON `xivlegacy%`.* TO 'xivlegacy'@'localhost';
GRANT ALL PRIVILEGES ON `xivlegacy%`.* TO 'xivlegacy'@'127.0.0.1';
```

The grant on `xivlegacy%` lets the servers create their database on first
boot, and lets the tests make their throwaway `xivlegacy_t_*` databases. If
you would rather create the database yourself and grant only on it, the
servers use it as they find it.

Tell the servers where it is, in your own `settings/<name>.toml` for each
server (or once, for all four, in the environment):

```toml
[database]
url = "mysql://xivlegacy:choose-a-password@127.0.0.1:3306/xivlegacy"
```

```sh
export XIVLEGACY_DB_URL='mysql://xivlegacy:choose-a-password@127.0.0.1:3306/xivlegacy'
```

`XIVLEGACY_DB_URL` wins over the settings files, and `--db-url` on a server's
command line wins over both. Logs show the URL with the password hidden.

## What the servers do at boot

Each server runs the same setup pass under a MariaDB named lock, so four
servers starting together take turns:

1. **Empty database:** apply the baseline schema, `common/sql/schema.sql`.
2. **Game data:** every file in `common/sql/data/` holds one table's rows
   (items, zones, spawns, monsters, quests, status effects). A file whose text
   changed since it was last loaded is reloaded whole, in a transaction.
   `static_data_versions` records each file's checksum.
3. **Migrations:** each file in `common/sql/migrations/` (`NNN_name.sql`) runs
   once, in name order, and is recorded with its checksum in
   `schema_migrations`. A migration that was changed after it ran stops the
   boot with an error naming it: fix it with a new migration instead.
4. **Modules:** the enabled modules' SQL, as before.

All of this SQL is bundled into the server binaries, so a server needs no
files beside it to set up its database.

## Changing the database

- **Change game data** (an item, a spawn, a monster's level): edit the row in
  `common/sql/data/<table>.sql`. It reloads on the next boot. Don't change
  game-data tables from code or by hand on a live server; the next reload puts
  the file's rows back.
- **Change a table** (add a column, a key, a new table) or fix player data:
  add the next numbered file to `common/sql/migrations/`. Never edit one that
  has shipped.

### GM edits to game data

A few GM commands write game-data tables on the running server: saving a
spawn (`server_battlenpc_pools`, `server_battlenpc_groups`,
`server_battlenpc_spawn_locations`) and moving an NPC's or monster's spawn
point (`server_spawn_locations`, `server_battlenpc_spawn_locations`). Those edits
last until that table's data file next changes, when the reload puts the
file's rows back. To keep them, write the live table back to its file and
commit it:

```sh
python3 -I tools/mariadb/export_data.py server_spawn_locations -u xivlegacy -p xivlegacy
git diff common/sql/data/server_spawn_locations.sql
```

The export has the bundled files' exact form, so the diff shows only the rows
that changed.

Every connection runs with `sql_mode` set to
`ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,...`
(see `common/src/sql.rs`). Write standard SQL: `"name"` quotes an
identifier, `'text'` is a string, `||` joins strings, a value that doesn't fit
its column is an error rather than a silent truncation, and an explicit id of 0
is stored as 0.

## Moving a server from SQLite

Servers before this change kept everything in `./data/garlemald.db`. To move a
server's accounts and characters across:

1. Stop the servers and back up `data/` (the `.db`, `-wal` and `-shm` files).
2. Boot the new servers once against the empty MariaDB database so they set
   it up, then stop them.
3. Export the player tables and load them:

   ```sh
   python3 -I tools/mariadb/sqlite_to_mariadb.py import data/garlemald.db > players.sql
   mariadb -u xivlegacy -p xivlegacy < players.sql
   ```

   The export covers accounts, sessions, characters and everything under them
   (inventories, equipment, hotbars, quests, leves, linkshells, retainers,
   status effects). Game data comes from the bundled files, not the old
   database.
4. Start the servers.

## Activity logs and reports

Migration 002 adds tables that record what happens to characters. The servers
only ever insert into them; nothing in the game reads them back, and a log
write that fails is logged as a warning without stopping the change it
describes. Every row has `at` (unix seconds, UTC) and is indexed by
character and time.

| Table | One row per | Written by |
| --- | --- | --- |
| `log_sessions` | login, zone change, logout | world server |
| `log_items` | item gained or lost (`quantity` is the change) | map server: add, remove, stack size |
| `log_gil` | gil change, with the balance after | map server |
| `log_progress` | exp, level, class or job change | map server |
| `log_quests` | quest accepted, step, completed, removed; leve accepted, completed, abandoned, removed | map server |
| `log_gm` | GM command run (character 0 = the console) | map server |
| `log_combat` | kill, death, damage, heal | not yet written |
| `log_trades` | trade, bazaar or retainer sale | not yet written |

The web server shows them to GMs at `/reports` (the day, week or month at a
glance) and `/reports/character?name=` (one character's history, newest
first). Sign in there with an account whose `users.gmLevel` is at least
`[reports] gm_level` in `settings/web.toml` (default 1). Anything else is a
SQL query away, for example the items a character lost this week:

```sql
SELECT FROM_UNIXTIME(l.at), i.name, l.quantity, l.reason
FROM log_items l LEFT JOIN gamedata_items i ON i.catalogID = l.itemId
WHERE l.characterId = 1 AND l.quantity < 0 AND l.at > UNIX_TIMESTAMP() - 7 * 86400
ORDER BY l.at DESC;
```

The tables grow without limit. Old rows can go whenever you like, for
example `DELETE FROM log_progress WHERE at < UNIX_TIMESTAMP() - 180 * 86400`.

## Backups

```sh
mariadb-dump --single-transaction -u xivlegacy -p xivlegacy > xivlegacy-$(date +%F).sql
```

restores with `mariadb -u xivlegacy -p xivlegacy < xivlegacy-<date>.sql`.

## Tests

Tests that need a database get their own (`common::test_db::fresh`), copied
from a template database built once from the bundled SQL and kept between runs
(`xivlegacy_tpl_<checksum>`). Copying 75 tables is slow, so a test process
keeps the copies it made: when the last connection to one closes, the next
test gets it back emptied to the template's contents. A test process drops its
databases when it exits; databases left by a crashed run are dropped by the
next one.

The tests find the MariaDB server in `XIVLEGACY_TEST_DB_URL`
(`mysql://user:password@host:port/`, no database name), else in the
`XIV_DB_ADMIN_URL=` line of `~/.config/xivlegacy/db.env`.

## Regenerating the baseline

`tools/mariadb/sqlite_to_mariadb.py` made `schema.sql` and `data/` from the
last SQLite seeds (001-298, develop 5f32a3e). It is kept for the import above
and for reference; new work goes in `data/` and `migrations/` directly.
