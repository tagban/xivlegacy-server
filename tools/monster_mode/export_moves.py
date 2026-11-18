#!/usr/bin/env python3
"""Print what players found out about monster moves in Monster Mode, as JSON.

Reads `log_monster_mode` (migration 013) through the `mariadb` client and
prints one object per move that was used, refused or marked:

    [{"id": 23122, "used": 4, "refused": 1, "ok": 1, "bad": 0,
      "last": "hit", "last_at": 1763437213, "note": "hits hard"}, ...]

`last` is the newest result (hit, miss, heal, status, no_effect, or
"refused 32546" with the client line), `note` the newest note on a mark.
The status tracker reads this for its "Played" column on the monster
moves tab.

Everything after the options goes to the `mariadb` client as is (account,
password, host, database), the same as tools/mariadb/export_data.py:

    python3 -I tools/monster_mode/export_moves.py -u xivlegacy -p xivlegacy > played.json
"""

import json
import subprocess
import sys

SQL = r"""
SELECT l.actionId,
       SUM(l.event = 'move'), SUM(l.event = 'refused'),
       SUM(l.event = 'verdict' AND l.outcome = 'ok'),
       SUM(l.event = 'verdict' AND l.outcome = 'bad'),
       MAX(IF(l.event IN ('move', 'refused'), l.at, 0)),
       COALESCE((SELECT IF(x.event = 'refused', CONCAT('refused ', x.textId), x.outcome)
                   FROM log_monster_mode x
                  WHERE x.actionId = l.actionId AND x.event IN ('move', 'refused')
                  ORDER BY x.at DESC, x.id DESC LIMIT 1), ''),
       COALESCE((SELECT REPLACE(REPLACE(x.note, '\t', ' '), '\n', ' ') FROM log_monster_mode x
                  WHERE x.actionId = l.actionId AND x.event = 'verdict' AND x.note <> ''
                  ORDER BY x.at DESC, x.id DESC LIMIT 1), '')
  FROM log_monster_mode l
 WHERE l.actionId > 0
 GROUP BY l.actionId
 ORDER BY l.actionId
"""

KEYS = ("id", "used", "refused", "ok", "bad", "last_at", "last", "note")


def parse(tsv: str) -> list:
    """Rows of the `mariadb -N -B` output as move objects."""
    moves = []
    for line in tsv.splitlines():
        if not line.strip():
            continue
        cells = line.split("\t")
        cells += [""] * (len(KEYS) - len(cells))
        row = dict(zip(KEYS, cells))
        for k in ("id", "used", "refused", "ok", "bad", "last_at"):
            row[k] = int(row[k] or 0) if row[k] != "NULL" else 0
        moves.append(row)
    return moves


def main(argv: list) -> int:
    if "--help" in argv:
        print(__doc__)
        return 0
    out = subprocess.run(
        ["mariadb", "-N", "-B", *argv, "-e", SQL],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    json.dump(parse(out), sys.stdout, indent=1)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
