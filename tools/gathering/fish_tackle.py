#!/usr/bin/env python3
"""Write common/sql/data/gamedata_fishing_tackle.sql: which bait or lure each
fish takes, from ZAM's 1.0 item pages (the "Fished From" tables: one row per
catch with the tackle used).

Usage: fish_tackle.py <ZAM cache item dir> <repo root>

The cache is the Wayback copy of ZAM's 1.0 database the reference site uses
(see tools/zam_fetch.py in tagban/xivlegacy-reference); it is not in this
repo. Only facts are taken (item id, tackle name); no page text.
"""
import html
import os
import re
import sys


def tackle_ids(items_sql):
    """Bait (kind 6112) and lure (kind 6113) ids by name, from gamedata_items."""
    ids = {}
    row = re.compile(r"^\((\d+), '((?:[^']|'')*)', '[^']*', '[^']*', '[^']*', \d+, \d+, \d+, \d+, \d+, \d+, \d+, \d+, \d+, (\d+),", re.M)
    for m in row.finditer(items_sql):
        if m[3] in ("6112", "6113"):
            ids[m[2].replace("''", "'")] = int(m[1])
    return ids


def fished_from(cache):
    """(fish id, tackle name) pairs from every cached item page."""
    pairs = set()
    for f in sorted(os.listdir(cache)):
        if not f.endswith(".html"):
            continue
        t = open(os.path.join(cache, f), encoding="utf-8", errors="replace").read()
        i = t.find('id="Fished_From_t"')
        if i < 0:
            continue
        tab = t[i:t.find("</table>", i)]
        hdr = [re.sub(r"<[^>]+>", "", h).strip() for h in re.findall(r"<th[^>]*>(.*?)</th>", tab, re.S)]
        if "Tackle" not in hdr:
            continue
        col = hdr.index("Tackle")
        for row in re.findall(r"<tr[^>]*>(.*?)</tr>", tab, re.S):
            tds = re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)
            if len(tds) <= col:
                continue
            name = html.unescape(re.sub(r"<[^>]+>", " ", tds[col])).strip()
            if name:
                pairs.add((int(f[:-5]), name))
    return pairs


def main():
    cache, root = sys.argv[1], sys.argv[2]
    items_sql = open(os.path.join(root, "common/sql/data/gamedata_items.sql"), encoding="utf-8").read()
    ids = tackle_ids(items_sql)
    rows = sorted({(fish, ids[name]) for fish, name in fished_from(cache) if name in ids})
    unknown = sorted({name for _, name in fished_from(cache) if name not in ids})
    if unknown:
        print("tackle names not in gamedata_items:", unknown, file=sys.stderr)
    out = os.path.join(root, "common/sql/data/gamedata_fishing_tackle.sql")
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"-- gamedata_fishing_tackle: game data, {len(rows)} rows. Reloaded whole when this file changes.\n")
        f.write("-- Which bait or lure each fish takes, from ZAM's 1.0 catch records (tools/gathering/fish_tackle.py).\n")
        f.write("-- A fish with no rows here takes any tackle (nothing was recorded for it).\n")
        f.write("SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n")
        f.write("DELETE FROM `gamedata_fishing_tackle`;\n")
        f.write("INSERT INTO `gamedata_fishing_tackle` (`itemCatalogId`, `tackleCatalogId`) VALUES\n")
        f.write(",\n".join(f"({a}, {b})" for a, b in rows) + ";\n")
    print(len(rows), "rows ->", out)


if __name__ == "__main__":
    main()
