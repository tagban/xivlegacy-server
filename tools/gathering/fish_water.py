#!/usr/bin/env python3
"""Find fishing spots in the 1.23b client's own collision data.

    python3 -I tools/gathering/fish_water.py [--client DIR] PLACE [PLACE ...]

The client opens the fishing window at any fishing point, dry ground too, so where a point
stands at water is our rule. The hand-checked spots of FISH_SPOTS (gen_nodes.py) all stand
on, or wade in, one of the layouts' water meshes: the La Noscea sea plane ("f0_s"), lakes
("lak_", "c0_l"), river and swamp surfaces ("ris0", "rif_", "rif0", "sw0_", "swf0"), the
Thanalan pools ("mi_h", "mizu") and the Coerthas flats ("fla0", "fla1"); the dungeons' are
"la_h" and "p0_w". The mesh names are the part after the 6-character hash and the area code.
A spot is a level floor (3 of 4 sides within 2
yalms of it, nothing solid 0.3-6 yalms over it) with one of those surfaces from 2.6
yalms under its feet to 1.8 over them, at the point or 3 yalms around it.

The finder only proposes; gen_nodes.py says which spots were also walked to in the client.
Prints, per place, candidates as
(x, y, z, water_x, water_z): nearest the camp's aetheryte (or the dungeon's middle)
first, 25+ yalms apart and POOL_GAP+ yalms from the points already placed.
"""
import collections, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "tools", "terrain"))
import xivterrain as X  # noqa: E402

SURFACES = {"f0_s", "c0_l", "lak_", "ris0", "rif0", "rif_", "sw0_", "swf0", "mi_h", "mizu", "fla0", "fla1",
            "la_h", "p0_w"}
# Water surfaces the player passes through (not a floor to stand on).
NOT_FLOOR = {"ris0", "rif0", "rif_", "sw0_", "swf0", "c0_l", "mizu"}


def kind(key):
    """Mesh name of a collision resource key: '0fhVbGr0f5_ris0' -> 'ris0'."""
    return key[11:]


def floors(area, x, z):
    """[(height, mesh name)] of every floor under (x, z)."""
    cell = (int(x // X.CELL), int(z // X.CELL))
    out = []
    for n in area.index.get(cell, ()):
        if n in area.props:
            continue
        name = kind(area.placements[n][2])
        for ax, ay, az, bx, by, bz, cx, cy, cz in area.floors_of(n).get(cell, ()):
            d = (bx - ax) * (cz - az) - (cx - ax) * (bz - az)
            if d == 0:
                continue
            u = ((x - ax) * (cz - az) - (cx - ax) * (z - az)) / d
            v = ((bx - ax) * (z - az) - (x - ax) * (bz - az)) / d
            if u < -1e-6 or v < -1e-6 or u + v > 1 + 1e-6:
                continue
            out.append((ay + u * (by - ay) + v * (cy - ay), name))
    return sorted(out)


class Finder:
    def __init__(self, terrain, zone, offset=(0.0, 0.0, 0.0)):
        """offset: server = layout + offset (dungeons; tools/terrain/README.md)."""
        self.area = terrain.area(zone)
        self.off = offset

    def at(self, x, z):
        ox, oy, oz = self.off
        return [(h + oy, k) for h, k in floors(self.area, x - ox, z - oz)] if self.area else []

    def stand(self, x, z, near_y=None, ylim=40.0):
        """Height a fisher can stand at (x, z) by known water, or None."""
        here = self.at(x, z)
        if not here:
            return None
        wet = [h for h, k in here if k in SURFACES]
        for dx, dz in ((3, 0), (-3, 0), (0, 3), (0, -3)):
            wet += [h for h, k in self.at(x + dx, z + dz) if k in SURFACES]
        for h, k in reversed(here):
            if k in NOT_FLOOR or (near_y is not None and abs(h - near_y) > ylim):
                continue
            if any(h + 0.3 < u < h + 6 and kk not in NOT_FLOOR for u, kk in here):
                continue  # under a ledge or a roof
            if not any(-2.6 <= w - h <= 1.8 for w in wet):
                continue
            level = 0
            for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                f = self.at(x + dx, z + dz)
                if f and abs(min((u for u, _ in f), key=lambda u: abs(u - h)) - h) <= 2.0:
                    level += 1
            if level >= 3:
                return round(h, 2)
        return None

    def facing(self, x, z, y):
        """A point 20 yalms out over the water, for the point's rotation."""
        best, score = (x + 20, z), -1
        for i in range(8):
            a = i * math.pi / 4
            s = sum(1 for r in (4, 8, 12) for h, k in self.at(x + r * math.cos(a), z + r * math.sin(a))
                    if k in SURFACES and abs(h - y) < 4)
            if s > score:
                best, score = (round(x + 20 * math.cos(a), 1), round(z + 20 * math.sin(a), 1)), s
        return best

    def scan(self, cx, cz, radius, step=3.0, near_y=None, ylim=40.0):
        """[(distance, x, y, z)] of every spot within radius of (cx, cz)."""
        out, n = [], int(radius / step)
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                x, z = cx + i * step, cz + j * step
                d = math.hypot(x - cx, z - cz)
                if d > radius:
                    continue
                y = self.stand(x, z, near_y, ylim)
                if y is not None:
                    out.append((d, round(x, 2), y, round(z, 2)))
        return sorted(out)

    def middle(self):
        """Middle (server x, z) and half-diagonal of the area's floors."""
        xs = [c[0] * X.CELL for c in self.area.index]
        zs = [c[1] * X.CELL for c in self.area.index]
        half = max(max(xs) - min(xs), max(zs) - min(zs)) / 2 * 1.42
        return (min(xs) + max(xs)) / 2 + self.off[0], (min(zs) + max(zs)) / 2 + self.off[2], half


def pick(spots, n, taken, gap=25.0, pool_gap=20.0):
    """Up to n spots, nearest first, gap apart and pool_gap from the taken points."""
    got = []
    for _, x, y, z in spots:
        if any(math.hypot(x - px, z - pz) < pool_gap for px, _, pz in taken):
            continue
        if all(math.hypot(x - px, z - pz) >= gap for px, _, pz in got):
            got.append((x, y, z))
        if len(got) == n:
            break
    return got


def main():
    import gen_nodes as G
    args = [a for a in sys.argv[1:]]
    client = os.environ.get("XIV_CLIENT", X.DEFAULT_CLIENT)
    if "--client" in args:
        i = args.index("--client")
        client = args[i + 1]
        del args[i:i + 2]
    terrain = X.Terrain(client)
    aeth = G.aetherytes()
    taken = collections.defaultdict(list)
    for zone, x, y, z in G.placed_points():
        taken[zone].append((x, y, z))
    for name in args:
        if name in G.DUNGEON_PLACES:
            zone, offset = G.DUNGEON_PLACES[name]
            f = Finder(terrain, zone, offset)
            cx, cz, radius = f.middle()
            spots = f.scan(cx, cz, radius)
        else:
            zone, ax, ay, az = aeth[G.PLACES[name][1]]
            f = Finder(terrain, zone)
            spots = f.scan(ax, az, 700, step=4, near_y=ay, ylim=150)
        got = pick(spots, 4, taken[zone])
        taken[zone] += got
        print(f"{name} (zone {zone}): {len(spots)} spots")
        for x, y, z in got:
            print("   ", (x, y, z) + f.facing(x, z, y))
        terrain.release(zone)


if __name__ == "__main__":
    main()
