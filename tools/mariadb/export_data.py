#!/usr/bin/env python3
"""Write a live game-data table back to its file in common/sql/data/.

GM commands that place or move spawns (!spawn save, !setpos on an NPC) write
game-data tables on the running server. The next time that table's data file
changes, the server reloads the file and those edits are gone. Export the
table into its file and commit it to keep them:

    python3 -I tools/mariadb/export_data.py server_spawn_locations -u xivlegacy -p xivlegacy

Everything after the table name goes to the `mariadb` client as is, so give
it the account, password prompt and database name the way you would there
(or rely on ~/.my.cnf). `--stdout` prints the file instead of writing it.

The output has the same form as the bundled files (rows in primary-key order,
500 per INSERT), so `git diff` shows only the rows that changed.
"""

import json
import os
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sqlite_to_mariadb import BATCH, lit, q  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FLOAT_TYPES = {"double", "float", "decimal", "real"}


def query(client_args, sql):
    out = subprocess.run(
        ["mariadb", "--batch", "--raw", "--skip-column-names", *client_args, "-e", sql],
        check=True, capture_output=True, text=True,
    ).stdout
    return [line for line in out.split("\n") if line]


def main(argv):
    to_stdout = "--stdout" in argv
    argv = [a for a in argv if a != "--stdout"]
    if not argv:
        sys.exit(__doc__)
    table, client = argv[0], argv[1:]
    path = os.path.join(ROOT, "common", "sql", "data", f"{table}.sql")
    if not to_stdout and not os.path.exists(path):
        sys.exit(f"{table} has no data file ({path}): only game-data tables are exported")
    if not table.replace("_", "").isalnum():
        sys.exit(f"not a table name: {table}")

    cols = [line.split("\t") for line in query(client, (
        "SELECT column_name, data_type FROM information_schema.columns "
        f"WHERE table_schema = DATABASE() AND table_name = '{table}' ORDER BY ordinal_position"))]
    if not cols:
        sys.exit(f"no table {table} in that database")
    pk = [line for line in query(client, (
        "SELECT column_name FROM information_schema.key_column_usage "
        f"WHERE table_schema = DATABASE() AND table_name = '{table}' AND constraint_name = 'PRIMARY' "
        "ORDER BY ordinal_position"))]
    names = [c[0] for c in cols]
    floats = [c[1].lower() in FLOAT_TYPES for c in cols]
    order = ", ".join(q(c) for c in (pk or names))
    rows = query(client, f"SELECT JSON_ARRAY({', '.join(q(c) for c in names)}) FROM {q(table)} ORDER BY {order}")

    def value(v, is_float):
        if is_float and isinstance(v, (int, float)) and not isinstance(v, bool):
            return float(v)
        return v

    out = [f"-- {table}: game data, {len(rows)} rows. Reloaded whole when this file changes.\n",
           "SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n",
           f"DELETE FROM {q(table)};\n"]
    head = f"INSERT INTO {q(table)} ({', '.join(q(c) for c in names)}) VALUES\n"
    for i in range(0, len(rows), BATCH):
        batch = [json.loads(r) for r in rows[i:i + BATCH]]
        out.append(head + ",\n".join(
            "(" + ", ".join(lit(value(v, f)) for v, f in zip(r, floats)) + ")" for r in batch) + ";\n")
    text = "".join(out)
    if to_stdout:
        sys.stdout.write(text)
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{table}: {len(rows)} rows written to {os.path.relpath(path, ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
