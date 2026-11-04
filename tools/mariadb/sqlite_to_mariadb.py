#!/usr/bin/env python3
"""Convert a fully migrated XIVLegacy SQLite database into the MariaDB baseline.

Writes:
  <out>/schema.sql          every table (game data and player data), InnoDB utf8mb4
  <out>/data/<table>.sql    the rows of each game-data table, one file per table

Game-data tables are the ones the server ships rows for (gamedata_*, server_*
spawn/battle/zone tables, support desk text). Player tables ship empty.

Type mapping follows SQLite's affinity rules, checked against the data:
  INT affinity      -> BIGINT (rusqlite reads every integer as i64)
  REAL affinity     -> DOUBLE
  TEXT affinity     -> VARCHAR(255) when a key or index covers it, else TEXT
                       (MEDIUMTEXT when a value is longer than TEXT holds)
  BLOB / no type    -> MEDIUMBLOB, or the type the data actually holds
A lone INTEGER PRIMARY KEY named id, or marked AUTOINCREMENT, numbers new
rows itself in SQLite, so it becomes AUTO_INCREMENT.

Usage:
  python3 -I sqlite_to_mariadb.py <sqlite.db> <out dir>
      Regenerate the baseline (schema.sql + data/) from a migrated database.
  python3 -I sqlite_to_mariadb.py import <server sqlite.db> > players.sql
      Write the player tables of a running server's SQLite database (accounts,
      characters, inventories, quests, linkshells, retainers) as INSERTs for a
      MariaDB database the servers have already set up. Load it with
      `mariadb <database> < players.sql` while the servers are stopped.
"""

import os
import re
import sqlite3
import sys

SKIP = {"sqlite_sequence", "schema_migrations"}

# Tables that hold player or runtime state even though a name prefix
# suggests otherwise. Everything else with rows in a fresh database, and
# every gamedata_* / server_battlenpc_* table, is game data.
PLAYER_PREFIXES = ("characters", "users", "sessions", "world_sessions", "server_sessions",
                   "reserved_names", "supportdesk_tickets")
PLAYER_TABLES = {"server_items", "server_items_dealing", "server_items_modifiers",
                 "server_linkshells"}
DATA_PREFIXES = ("gamedata_", "server_battlenpc_", "server_battle_", "server_zones",
                 "server_spawn", "server_statuseffects", "server_seamless", "server_eventnpc",
                 "server_gather", "server_retainers", "supportdesk_faqs", "supportdesk_issues")

TEXT_MAX = 65535
BATCH = 500


def q(name):
    return "`" + name.replace("`", "``") + "`"


def is_player_table(name):
    return name in PLAYER_TABLES or name.startswith(PLAYER_PREFIXES)


def is_data_table(name, rows):
    if is_player_table(name):
        return False
    return name.startswith(DATA_PREFIXES) or rows > 0


def affinity(decl):
    d = (decl or "").upper()
    if "INT" in d:
        return "INT"
    if any(k in d for k in ("CHAR", "CLOB", "TEXT")):
        return "TEXT"
    if "BLOB" in d or d == "":
        return "BLOB"
    if any(k in d for k in ("REAL", "FLOA", "DOUB")):
        return "REAL"
    return "NUMERIC"


def lit(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        r = repr(v)
        if r in ("inf", "-inf", "nan"):
            raise ValueError(f"unrepresentable float {r}")
        return r
    if isinstance(v, bytes):
        return "X'" + v.hex() + "'" if v else "''"
    s = str(v).replace("\\", "\\\\").replace("'", "''").replace("\0", "\\0")
    return "'" + s + "'"


def default_clause(raw, kind):
    if raw is None:
        return ""
    r = raw.strip()
    up = r.upper()
    if up in ("CURRENT_TIMESTAMP", "(CURRENT_TIMESTAMP)", "(DATETIME('NOW'))", "DATETIME('NOW')"):
        return " DEFAULT (UTC_TIMESTAMP())"
    if up in ("(STRFTIME('%S','NOW'))", "STRFTIME('%S','NOW')", "(UNIXEPOCH())", "UNIXEPOCH()"):
        return " DEFAULT (UNIX_TIMESTAMP())"
    if up == "NULL":
        return " DEFAULT NULL"
    # strip one layer of parentheses and quotes
    while r.startswith("(") and r.endswith(")"):
        r = r[1:-1].strip()
    m = re.fullmatch(r"'(.*)'", r, re.S) or re.fullmatch(r'"(.*)"', r, re.S)
    inner = m.group(1).replace("''", "'") if m else r
    if kind in ("BIGINT", "DOUBLE"):
        try:
            float(inner)
            return " DEFAULT " + inner
        except ValueError:
            raise ValueError(f"non-numeric default {raw!r} on numeric column")
    if kind.endswith("TEXT") or kind.endswith("BLOB"):
        return " DEFAULT " + lit(inner)
    return " DEFAULT " + lit(inner)


def column_kind(con, table, col, decl, indexed):
    aff = affinity(decl)
    rows = con.execute(
        f'SELECT typeof("{col}") t, count(*), max(length("{col}")) FROM "{table}" '
        f'WHERE "{col}" IS NOT NULL GROUP BY t').fetchall()
    types = {t: (n, ln or 0) for t, n, ln in rows}
    maxlen = max((ln for _, ln in types.values()), default=0)
    if aff == "INT" or (aff in ("NUMERIC", "BLOB") and set(types) <= {"integer"} and types):
        bad = set(types) - {"integer"}
        if bad:
            raise ValueError(f"{table}.{col}: INT column holds {bad}")
        return "BIGINT"
    if aff == "REAL" or (aff in ("NUMERIC", "BLOB") and types and set(types) <= {"integer", "real"}):
        bad = set(types) - {"integer", "real"}
        if bad:
            raise ValueError(f"{table}.{col}: REAL column holds {bad}")
        return "DOUBLE"
    if aff == "NUMERIC" and not types:
        return "DOUBLE"
    if aff == "TEXT" or "text" in types:
        if "blob" in types:
            raise ValueError(f"{table}.{col}: TEXT column holds blobs")
        if indexed:
            if maxlen > 255:
                raise ValueError(f"{table}.{col}: indexed text longer than 255")
            return "VARCHAR(255)"
        return "MEDIUMTEXT" if maxlen * 4 > TEXT_MAX else "TEXT"
    return "LONGBLOB" if maxlen > 16 * 1024 * 1024 - 1 else "MEDIUMBLOB"


def convert(src, out):
    con = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    os.makedirs(os.path.join(out, "data"), exist_ok=True)
    tables = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    schema = [
        "-- XIVLegacy MariaDB baseline schema. Generated by tools/mariadb/sqlite_to_mariadb.py",
        "-- from the SQLite seeds 001-298 (develop 5f32a3e). Change tables through sql/migrations/;",
        "-- change game data by editing sql/data/<table>.sql.",
        "",
        "SET NAMES utf8mb4;",
        "",
    ]
    data_tables = []
    for t in tables:
        if t in SKIP:
            continue
        cols = con.execute(f'PRAGMA table_info("{t}")').fetchall()
        pk = [c[1] for c in sorted((c for c in cols if c[5] > 0), key=lambda c: c[5])]
        idx = con.execute(f'PRAGMA index_list("{t}")').fetchall()
        indexed_cols = set(pk)
        index_defs = []
        for _, iname, unique, origin, partial in idx:
            if origin == "pk":
                continue
            if partial:
                raise ValueError(f"{t}: partial index {iname} has no MariaDB form")
            icols = [r[2] for r in con.execute(f'PRAGMA index_info("{iname}")').fetchall()]
            if None in icols:
                raise ValueError(f"{t}: expression index {iname}")
            indexed_cols.update(icols)
            nm = iname if not iname.startswith("sqlite_autoindex") else f"uq_{t}_{'_'.join(icols)}"
            index_defs.append((bool(unique), nm[:64], icols))
        sql = con.execute("SELECT sql FROM sqlite_master WHERE name=?", (t,)).fetchone()[0] or ""
        # SQLite numbers new rows itself for any lone INTEGER PRIMARY KEY.
        # Keep that only where it is meant: an AUTOINCREMENT column or a
        # table's own `id`. A per-character table keyed on characterId gets
        # its key from the caller, so it stays a plain key.
        pk_decl = next((c[2] for c in cols if pk and c[1] == pk[0]), "").upper()
        rowid_pk = (len(pk) == 1 and pk_decl == "INTEGER"
                    and (pk[0].lower() == "id" or "AUTOINCREMENT" in sql.upper()))
        lines = []
        for cid, name, decl, notnull, dflt, pkpos in cols:
            kind = column_kind(con, t, name, decl, name in indexed_cols)
            line = f"    {q(name)} {kind}"
            if notnull or pkpos:
                line += " NOT NULL"
            if rowid_pk and pkpos:
                line += " AUTO_INCREMENT"
            elif dflt is not None:
                line += default_clause(dflt, kind)
            lines.append(line)
        if pk:
            lines.append(f"    PRIMARY KEY ({', '.join(q(c) for c in pk)})")
        for unique, nm, icols in index_defs:
            lines.append(f"    {'UNIQUE KEY' if unique else 'KEY'} {q(nm)} ({', '.join(q(c) for c in icols)})")
        if not pk:
            schema.append(f"-- {t}: no primary key in SQLite")
        schema.append(f"CREATE TABLE IF NOT EXISTS {q(t)} (\n" + ",\n".join(lines) +
                      "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;\n")

        n = con.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0]
        if not is_data_table(t, n):
            continue
        data_tables.append(t)
        names = [c[1] for c in cols]
        order = ", ".join(f'"{c}"' for c in (pk or names))
        with open(os.path.join(out, "data", f"{t}.sql"), "w", encoding="utf-8") as f:
            f.write(f"-- {t}: game data, {n} rows. Reloaded whole when this file changes.\n")
            f.write("SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n")
            f.write(f"DELETE FROM {q(t)};\n")
            cur = con.execute(f'SELECT {", ".join(chr(34) + c + chr(34) for c in names)} FROM "{t}" ORDER BY {order}')
            head = f"INSERT INTO {q(t)} ({', '.join(q(c) for c in names)}) VALUES\n"
            while True:
                batch = cur.fetchmany(BATCH)
                if not batch:
                    break
                f.write(head + ",\n".join("(" + ", ".join(lit(v) for v in r) + ")" for r in batch) + ";\n")
    with open(os.path.join(out, "schema.sql"), "w", encoding="utf-8") as f:
        f.write("\n".join(schema))
    print(f"{len(tables) - len(SKIP & set(tables))} tables, {len(data_tables)} game-data files")


def export_players(src, out=sys.stdout):
    """Player tables of a live SQLite database as one MariaDB load script."""
    con = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    tables = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    out.write("-- XIVLegacy player data exported from SQLite by tools/mariadb/sqlite_to_mariadb.py\n")
    out.write("SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,"
              "NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n")
    out.write("SET FOREIGN_KEY_CHECKS = 0;\nSTART TRANSACTION;\n")
    total = 0
    for t in tables:
        if t in SKIP or not is_player_table(t):
            continue
        n = con.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0]
        cols = [c[1] for c in con.execute(f'PRAGMA table_info("{t}")').fetchall()]
        out.write(f"DELETE FROM {q(t)};\n")
        if n == 0:
            continue
        head = f"INSERT INTO {q(t)} ({', '.join(q(c) for c in cols)}) VALUES\n"
        cur = con.execute(f'SELECT {", ".join(chr(34) + c + chr(34) for c in cols)} FROM "{t}"')
        while True:
            batch = cur.fetchmany(BATCH)
            if not batch:
                break
            out.write(head + ",\n".join("(" + ", ".join(lit(v) for v in r) + ")" for r in batch) + ";\n")
        total += n
        print(f"{t}: {n} rows", file=sys.stderr)
    out.write("COMMIT;\nSET FOREIGN_KEY_CHECKS = 1;\n")
    print(f"{total} player rows", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "import":
        export_players(sys.argv[2])
    elif len(sys.argv) == 3:
        convert(sys.argv[1], sys.argv[2])
    else:
        sys.exit(__doc__)
