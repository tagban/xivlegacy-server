#!/usr/bin/env python3
"""Check or fit a layout's offset (server = layout + offset) against NPC spawn positions.

    fit_offsets.py check ZONE LAYOUT DX DY DZ          how many public spawns of ZONE stand on its floor
    fit_offsets.py fit ZONE LAYOUT DX DY DZ [RADIUS]   search DX, DZ within RADIUS (0.5 steps) around a guess

ZONE may be a file of "x y z" lines instead (for example player positions from a map server log,
which are always on a real floor), sampled down to 400 points.

A spawn "stands on the floor" when the layout has a floor within 0.6 yalm of its height (after the
offset) under it. The y offset of a candidate is the most common height difference.
"""
import math
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "terrain"))
import xivterrain  # noqa: E402

SPAWNS = HERE.parent.parent / "common" / "sql" / "data" / "server_spawn_locations.sql"
ROW = re.compile(r"\(\d+, (\d+), '[^']*', (\d+), '([^']*)', \d+, (-?[\d.]+), (-?[\d.]+), (-?[\d.]+),")


def spawns(zone):
    out = []
    for cls, z, pa, x, y, zz in ROW.findall(SPAWNS.read_text()):
        if int(z) == zone and not pa:
            out.append((float(x), float(y), float(zz)))
    return out


def score(area, pts, dx, dz, dy=None):
    res = []
    for x, y, z in pts:
        fl = area.floors(x - dx, z - dz, props=True)
        res.append([y - f for f in fl])
    if dy is None:
        c = Counter(round(r * 2) / 2 for rs in res for r in rs)
        if not c:
            return 0, 0.0
        dy = c.most_common(1)[0][0]
    n = sum(1 for rs in res if any(abs(r - dy) < 0.6 for r in rs))
    # refine dy: median of the matching residuals
    m = sorted(r for rs in res for r in rs if abs(r - dy) < 0.6)
    if m:
        dy = m[len(m) // 2]
    return n, dy


def points(arg):
    if arg.lstrip("-").isdigit():
        return spawns(int(arg))
    pts = [tuple(map(float, line.split()[:3])) for line in open(arg) if line.strip() and not line.startswith("#")]
    step = max(1, len(pts) // 400)
    return pts[::step]


def main():
    cmd, zone, layout = sys.argv[1], sys.argv[2], sys.argv[3]
    dx, dy, dz = map(float, sys.argv[4:7])
    t = xivterrain.Terrain()
    area = t.area(layout)
    pts = points(zone)
    if cmd == "check":
        n, _ = score(area, pts, dx, dz, dy)
        print(f"{layout} + ({dx}, {dy}, {dz}): {n}/{len(pts)} spawns of zone {zone} on the floor")
        return
    rad = float(sys.argv[7]) if len(sys.argv) > 7 else 6
    best = []
    k = int(rad * 2)
    for i in range(-k, k + 1):
        for j in range(-k, k + 1):
            n, fdy = score(area, pts, dx + i * 0.5, dz + j * 0.5)
            best.append((n, dx + i * 0.5, fdy, dz + j * 0.5))
    best.sort(reverse=True)
    for n, a, b, c in best[:8]:
        print(f"{n}/{len(pts)}  offset {a:.1f} {b:.2f} {c:.1f}")


if __name__ == "__main__":
    main()
