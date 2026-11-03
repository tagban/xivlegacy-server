#!/usr/bin/env python3
"""Ground heights for the map-derived monster spawns of seed 101, from the client's collision.

Reads the planned points written by `tools/world_spawns/generate.py --points` and writes
`tools/world_spawns/data/ground_heights.csv` (zoneId, x, z, y, moved_x, moved_z), which
generate.py then uses instead of its blended heights.

For each point:
  1. the highest floor under it (tree trunks and crates ignored);
  2. no floor (map-coordinate error put it off the ground): move it to the nearest floor within
     MOVE_RADIUS yalms, preferring the side toward its camp's center;
  3. still none: put it 1.5 yalms from the nearest placed spawn of the same camp;
  4. still none: leave it out (generate.py keeps the blended height).

Usage: spawn_heights.py planned.csv [--client DIR] [--out ground_heights.csv]
"""

import argparse
import collections
import csv
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import xivterrain  # noqa: E402

REPO = Path(__file__).resolve().parent.parent.parent
OUT = REPO / "tools" / "world_spawns" / "data" / "ground_heights.csv"
MOVE_RADIUS = 40.0
STEP = 2.0
DIRECTIONS = 24
BESIDE = 1.5


def nearest_floor(t, zone, x, z, toward):
    """(x, z, y) of the closest floor within MOVE_RADIUS, ties broken toward `toward`."""
    r = STEP
    while r <= MOVE_RADIUS:
        hits = []
        for k in range(DIRECTIONS):
            a = 2 * math.pi * k / DIRECTIONS
            px, pz = x + r * math.cos(a), z + r * math.sin(a)
            y = t.ground_y(zone, px, pz)
            if y is not None:
                hits.append(((px - toward[0]) ** 2 + (pz - toward[1]) ** 2, px, pz, y))
        if hits:
            _, px, pz, y = min(hits)
            return px, pz, y
        r += STEP
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("planned")
    ap.add_argument("--client", default=xivterrain.DEFAULT_CLIENT)
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    t = xivterrain.Terrain(args.client)
    pts = [(int(r["zoneId"]), float(r["x"]), float(r["z"]), int(r["groupId"])) for r in csv.DictReader(open(args.planned))]
    camp = collections.defaultdict(list)
    for zone, x, z, gid in pts:
        camp[gid].append((x, z))
    center = {g: (sum(p[0] for p in v) / len(v), sum(p[1] for p in v) / len(v)) for g, v in camp.items()}

    result = {}  # index -> (y, moved x or None, moved z or None)
    how = collections.Counter()
    per_zone = collections.defaultdict(collections.Counter)
    by_zone = collections.defaultdict(list)
    for i, p in enumerate(pts):
        by_zone[p[0]].append(i)
    for zone in sorted(by_zone):
        idx = by_zone[zone]
        for i in idx:
            _, x, z, gid = pts[i]
            y = t.ground_y(zone, x, z)
            if y is not None:
                result[i] = (y, None, None)
                per_zone[zone]["floor"] += 1
                continue
            m = nearest_floor(t, zone, x, z, center[gid])
            if m:
                result[i] = (m[2], m[0], m[1])
                per_zone[zone]["moved"] += 1
        for i in idx:
            if i in result:
                continue
            _, x, z, gid = pts[i]
            mates = [(pts[j][1] - x) ** 2 + (pts[j][2] - z) ** 2 for j in idx if j in result and pts[j][3] == gid]
            if not mates:
                per_zone[zone]["none"] += 1
                continue
            j = min((j for j in idx if j in result and pts[j][3] == gid),
                    key=lambda j: (pts[j][1] - x) ** 2 + (pts[j][2] - z) ** 2)
            my, mx, mz = result[j]
            bx = (pts[j][1] if mx is None else mx)
            bz = (pts[j][2] if mz is None else mz)
            a = 2 * math.pi * (i % DIRECTIONS) / DIRECTIONS
            nx, nz = bx + BESIDE * math.cos(a), bz + BESIDE * math.sin(a)
            y = t.ground_y(zone, nx, nz)
            result[i] = (my if y is None else y, nx, nz)
            per_zone[zone]["beside camp"] += 1
        t.release(zone)

    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["zoneId", "x", "z", "y", "moved_x", "moved_z"])
        for i, (zone, x, z, gid) in enumerate(pts):
            if i in result:
                y, mx, mz = result[i]
                w.writerow([zone, f"{x:.4f}", f"{z:.4f}", f"{y:.3f}",
                            "" if mx is None else f"{mx:.3f}", "" if mz is None else f"{mz:.3f}"])
    for zone in sorted(per_zone):
        how.update(per_zone[zone])
        print(zone, t.zone_names.get(zone), dict(per_zone[zone]))
    print("total", sum(how.values()), dict(how))


if __name__ == "__main__":
    sys.exit(main())
