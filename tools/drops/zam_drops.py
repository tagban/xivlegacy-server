#!/usr/bin/env python3
"""Write common/sql/data/server_drop_lists.sql: what each monster can drop.

Usage: zam_drops.py <parsed.json> <repo root>

<parsed.json> is the parsed copy of ZAM's 1.0 database that the reference site
builds (tools/zam_parse.py in tagban/xivlegacy-reference, over the Wayback
cache); it is not in this repo. Only facts are taken: which monster (ZAM's mob
id = the actor class id) lists which item (ZAM's item id = the catalog id), and
the shard count ZAM shows beside a shard. No page text.

ZAM records no drop rates. Every rate here comes from the rule in RULES, by the
item's ZAM category, and is marked as such in the file header. Each list's id
is the monster's actor class id: a monster whose group has dropListId 0 uses
the list with its own class id.

Rows ZAM restricts to one class (quest items for a class quest, a fisher's
catch) are skipped: they belong to quests, not to every kill.
"""
import json
import os
import re
import sys

# category -> (chance per 10000, rarity 0 common / 1 uncommon / 2 rare,
#              HQ chance per 10000)
RULES = {
    "shard": (3000, 0, 0),
    "crystal": (500, 1, 0),
    "cluster": (100, 2, 0),
    "Gemstone": (200, 2, 0),
    "Beastcoin": (800, 1, 0),
}
DEFAULT_RULE = (1000, 0, 100)


def known_ids(path, table_re):
    ids = set()
    for line in open(path, encoding="utf-8"):
        m = table_re.match(line)
        if m:
            ids.add(int(m[1]))
    return ids


def rule_for(name, category):
    low = name.lower()
    if category == "Crystal":
        if low.endswith("shard"):
            return RULES["shard"]
        if low.endswith("cluster"):
            return RULES["cluster"]
        return RULES["crystal"]
    return RULES.get(category, DEFAULT_RULE)


def main():
    parsed, root = sys.argv[1], sys.argv[2]
    data = os.path.join(root, "common", "sql", "data")
    items = known_ids(os.path.join(data, "gamedata_items.sql"), re.compile(r"^\((\d+), "))
    classes = known_ids(
        os.path.join(data, "gamedata_actor_class.sql"), re.compile(r"^\((\d+), ")
    )
    mobs = json.load(open(parsed, encoding="utf-8"))["mob"]
    rows = []
    skipped = {"class only": 0, "unknown item": 0, "unknown monster": 0}
    for mob_id, mob in sorted(mobs.items(), key=lambda kv: int(kv[0])):
        table = (mob.get("tabs") or {}).get("Drops")
        if not table:
            continue
        if int(mob_id) not in classes:
            skipped["unknown monster"] += 1
            continue
        seen = set()
        for name_cell, cat_cell, rank_cell, class_cell in table["rows"]:
            label, item_id = name_cell
            if item_id is None or item_id in seen:
                continue
            if (class_cell[0] or "All") != "All" or (rank_cell[0] or "") != "":
                skipped["class only"] += 1
                continue
            if item_id not in items:
                skipped["unknown item"] += 1
                continue
            seen.add(item_id)
            # ZAM shows a shard's count before its name ("6 6 6 6 6 Earth
            # Shard"): one count per rank column, all the same.
            counts = re.match(r"^((?:\d+ )+)", label)
            qty = int(counts[1].split()[0]) if counts else 1
            name = label[counts.end():] if counts else label
            chance, rarity, hq = rule_for(name, cat_cell[0] or "")
            rows.append((int(mob_id), item_id, 1, max(qty, 1), chance, rarity, hq))

    out = os.path.join(data, "server_drop_lists.sql")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            f"-- server_drop_lists: game data, {len(rows)} rows. Reloaded whole when this file changes.\n"
            "-- What each monster can drop (dropListId = the monster's actor class id, used when\n"
            "-- its group's dropListId is 0). Which monster drops which item is from ZAM's 1.0\n"
            "-- monster pages (tools/drops/zam_drops.py). ZAM has no rates: chance, rarity and\n"
            "-- hqChance follow the rule in that tool, by item category, not retail data.\n"
            "-- chance and hqChance are per 10000; rarity 0 common, 1 uncommon, 2 rare.\n"
            "SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n"
            "DELETE FROM `server_drop_lists`;\n"
            "INSERT INTO `server_drop_lists` (`dropListId`, `itemId`, `quantityMin`, `quantityMax`, `chance`, `rarity`, `hqChance`) VALUES\n"
        )
        f.write(",\n".join("(%d, %d, %d, %d, %d, %d, %d)" % r for r in rows))
        f.write(";\n")
    lists = len({r[0] for r in rows})
    print(f"{out}: {len(rows)} rows in {lists} lists; skipped {skipped}")


if __name__ == "__main__":
    main()
