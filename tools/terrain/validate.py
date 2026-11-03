#!/usr/bin/env python3
"""Check xivterrain against heights we already trust.

  * capture: monsters placed from retail 1.23b packet captures (seed 101 groups marked
    "-- capture"), whose y came from the retail server;
  * player: logged player positions (tools/world_spawns/data/height_samples_player.csv);
  * probe: grounds measured with the client (CSV with zone,x,z,ground_y,status columns, rows with
    status ok in zone 128 only), when --probe is given.

For each point it takes the floor nearest the known y and reports the difference.

Usage: validate.py [--client DIR] [--probe results.csv] [--out rows.csv]
"""

import argparse
import collections
import csv
import re
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import xivterrain  # noqa: E402

REPO = Path(__file__).resolve().parent.parent.parent
SEED = REPO / "common" / "sql" / "seed" / "101_world_monster_spawns.sql"
PLAYERS = REPO / "tools" / "world_spawns" / "data" / "height_samples_player.csv"


def capture_points():
    text = SEED.read_text()
    zone = {}
    for gid, z in re.findall(r"VALUES \((\d+), \d+, '[^']*', (?:[^,]+, ){12}(\d+)\); -- capture", text):
        zone[int(gid)] = int(z)
    for gid, x, y, z in re.findall(
            r"spawn_locations .*?VALUES \(\d+, '[^']*', (\d+), ([-\d.]+), ([-\d.]+), ([-\d.]+),", text):
        if int(gid) in zone:
            yield "capture", zone[int(gid)], float(x), float(z), float(y)


def player_points():
    for r in csv.DictReader(open(PLAYERS)):
        yield "player", int(r["zoneId"]), float(r["x"]), float(r["z"]), float(r["y"])


def probe_points(path):
    for r in csv.DictReader(open(path)):
        if r["status"] == "ok" and r["zone"] == "128":
            yield "probe", 128, float(r["x"]), float(r["z"]), float(r["ground_y"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", default=xivterrain.DEFAULT_CLIENT)
    ap.add_argument("--probe")
    ap.add_argument("--out")
    args = ap.parse_args()
    t = xivterrain.Terrain(args.client)
    pts = list(capture_points()) + list(player_points())
    if args.probe:
        pts += list(probe_points(args.probe))
    rows = []
    by_zone = collections.defaultdict(list)
    for p in pts:
        by_zone[p[1]].append(p)
    for zone in sorted(by_zone):
        if t.area(zone) is None:
            for src, zn, x, z, y in by_zone[zone]:
                rows.append(dict(source=src, zoneId=zn, x=x, z=z, y=y, ground_y="", diff="", floors=0, area="none"))
            continue
        for src, zn, x, z, y in by_zone[zone]:
            fl = t.floors(zone, x, z)
            g = t.ground_y(zone, x, z, y)
            rows.append(dict(source=src, zoneId=zn, x=x, z=z, y=y, ground_y="" if g is None else round(g, 3),
                             diff="" if g is None else round(g - y, 3), floors=len(fl), area="yes"))
        t.release(zone)
    for src in ("probe", "capture", "player"):
        rs = [r for r in rows if r["source"] == src]
        if not rs:
            continue
        hit = [abs(r["diff"]) for r in rs if r["diff"] != ""]
        noarea = sum(r["area"] == "none" for r in rs)
        print(f"{src}: {len(rs)} points, {noarea} in areas without a layout, "
              f"{len(rs) - noarea - len(hit)} with no floor")
        if hit:
            hit.sort()
            within = lambda d: sum(h <= d for h in hit)
            print(f"  |decoded - known|: median {statistics.median(hit):.3f}, "
                  f"90% {hit[int(0.9 * (len(hit) - 1))]:.3f}, max {hit[-1]:.3f}; "
                  f"within 0.5: {within(0.5)}/{len(hit)}, within 2: {within(2)}/{len(hit)}")
    if args.out:
        with open(args.out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)


if __name__ == "__main__":
    sys.exit(main())
