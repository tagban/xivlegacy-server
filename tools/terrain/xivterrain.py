#!/usr/bin/env python3
"""Ground height from the FFXIV 1.23b client's own collision data.

Reads the user's local 1.23b install at run time (nothing from it is stored in this repo):
an area's MapLayout file places collision meshes (PHB files) in the world; ground_y casts a
vertical ray through the up-facing triangles under (x, z). Layout coordinates are server
world coordinates. The file formats are described in README.md.
Up-facing means the triangle's (b - a) x (c - a) has a positive y.

Library:
    t = Terrain("/path/to/FINAL FANTASY XIV 1.23b")
    t.ground_y(128, 151.6, 59.9)              # highest floor, or None off the mesh
    t.ground_y(128, 151.6, 59.9, near_y=45)   # floor nearest a hint height
    t.floors(128, 151.6, 59.9)                # every floor height, low to high

Command line:
    xivterrain.py [--client DIR] query ZONE X Z [NEAR_Y]
    xivterrain.py [--client DIR] batch IN.csv OUT.csv   (columns zoneId,x,z[,near_y])
    xivterrain.py [--client DIR] zones
"""

import argparse
import collections
import csv
import json
import math
import os
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZONES_SQL = REPO / "common" / "sql" / "seed" / "033_server_zones.sql"
DEFAULT_CLIENT = os.environ.get("XIV_CLIENT", "/Volumes/AppStorage/ffxiv-scratch/FINAL FANTASY XIV 1.23b")

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "xivlegacy" / "terrain_layouts.json"
CELL = 8.0  # triangle bucket size (yalms)
MIN_UP = 0.2  # a floor's normal must point at least this much up (cos of ~78 degrees)
KIND = {"Field": "fld", "Town": "twn", "Dungeon": "dun"}


def f32(word):
    return struct.unpack("<f", struct.pack("<I", word))[0]


def area_name(zone_name):
    """Server zoneName -> layout area name: 'sea0Field01' -> 'sea_s0_fld01'."""
    m = re.fullmatch(r"([a-z]{3})(\d)([A-Za-z]+)(\d+)", zone_name or "")
    if not m or m.group(3) not in KIND:
        return None
    reg, var, kind, num = m.groups()
    return f"{reg}_{reg[0]}{var}_{KIND[kind]}{int(num):02d}"


def server_zone_names(path=ZONES_SQL):
    names = {}
    if path.exists():
        for zid, name in re.findall(r"\((\d+), \d+, '([A-Za-z0-9]+)'", path.read_text()):
            names.setdefault(int(zid), name)
    return names


class Layout:
    """One MapLayout file: its resource table and the collision placements in its object graph."""

    def __init__(self, data):
        count = struct.unpack_from("<I", data, 0x24)[0]
        self.resources = collections.defaultdict(dict)  # key -> {type: DAT id}
        for i in range(count):
            o = 0x60 + 32 * i
            key = data[o:o + 16].split(b"\0")[0].decode("latin1")
            typ = data[o + 16:o + 20].split(b"\0")[0][::-1].decode("latin1")
            self.resources[key][typ] = struct.unpack_from("<I", data, o + 20)[0]
        base = data.find(b"SEDBlyb") + 0x30
        self.blob = data[base:base + struct.unpack_from("<I", data, base + 4)[0]]
        self.words = struct.unpack_from(f"<{len(self.blob) // 4}I", self.blob)
        self.classes = {}  # class record offset -> short class name
        w = self.words
        for i in range(len(w) - 4):
            if w[i + 1] == 0 and w[i + 3] == 0:
                name = self.string(w[i + 2])
                if name and "/" in name and name[0].isupper() and name.replace("/", "").replace("_", "").isalnum():
                    self.classes[4 * i] = name.split("/")[-1]

    def string(self, off):
        if not 0 < off < len(self.blob):
            return None
        end = self.blob.find(b"\0", off)
        return self.blob[off:end].decode("latin1") if 0 <= end - off < 100 else None

    def word(self, off, k):
        return self.words[off // 4 + k]

    def vec(self, off):
        return [f32(self.words[off // 4 + k]) for k in range(3)]

    def class_of(self, off):
        return self.classes.get(self.word(off, 1))

    def collision(self):
        """[(PHB DAT id, 3x4 world matrix, resource key)] for every placed collision mesh:
        attribute objects, and the models whose resource key also has a phb."""
        inst_class = {k for k, v in self.classes.items() if v == "InstanceObject"}
        out = []
        for i in range(1, len(self.words) - 16):
            if self.words[i] not in inst_class:
                continue
            o = 4 * (i - 1)
            pos = [f32(self.word(o, k)) for k in (8, 9, 10)]
            m = matrix(pos, self.vec(self.word(o, 11)), self.vec(self.word(o, 12)))
            base = self.word(o, 15)
            parts = [(base, m)]
            if self.class_of(base) == "UnitTreeObject":
                arr, n = self.word(base, 12), self.word(base, 13)
                parts = []
                for k in range(n):
                    e = arr + 0x30 * k
                    local = matrix([f32(self.word(e, j)) for j in range(3)],
                                   self.vec(self.word(e, 3)), self.vec(self.word(e, 4)))
                    parts.append((self.word(e, 6), compose(m, local)))
            for obj, mat in parts:
                c = self.class_of(obj)
                if c == "AttributeBaseObject":
                    key = self.string(self.word(obj, 9))
                elif c in ("BGPartsBaseObject", "BGChipBaseObject"):
                    key = self.string(self.word(obj, 8))  # a model with its own collision
                else:
                    continue
                rid = self.resources.get(key, {}).get("phb")
                if rid:
                    out.append((rid, mat, key))
        return out


def matrix(pos, rot, scale):
    """3x4 matrix T * Rz * Ry * Rx * S."""
    cx, sx = math.cos(rot[0]), math.sin(rot[0])
    cy, sy = math.cos(rot[1]), math.sin(rot[1])
    cz, sz = math.cos(rot[2]), math.sin(rot[2])
    r = [[cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
         [sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
         [-sy, cy * sx, cy * cx]]
    return [[r[i][0] * scale[0], r[i][1] * scale[1], r[i][2] * scale[2], pos[i]] for i in range(3)]


def compose(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) + (a[i][3] if j == 3 else 0) for j in range(4)]
            for i in range(3)]


def read_phb(data):
    """(vertices, triangles, local AABB) of a PHB collision mesh."""
    g = data.find(b"PHB.GBD")
    h = struct.unpack_from("<14I", data, g + 8)
    o_tbc, l_tbc, o_verts, n_verts = h[9], h[10], h[12], h[13]
    lo = struct.unpack_from("<3f", data, g + 0x40)
    hi = struct.unpack_from("<3f", data, g + 0x50)
    n_tris, i, end = 0, g + o_tbc, g + o_tbc + l_tbc
    while True:
        i = data.find(b"PHB.TBD", i, end)
        if i < 0:
            break
        _, _, _, n, o_list = struct.unpack_from("<5I", data, i + 8)
        if n:
            n_tris = max(n_tris, max(struct.unpack_from(f"<{n}H", data, i + o_list)) + 1)
        i += 8
    verts = [struct.unpack_from("<3f", data, g + o_verts + 12 * k) for k in range(n_verts)]
    t0 = g + o_verts - ((8 * n_tris + 0x7F) & ~0x7F)
    tris = [struct.unpack_from("<3H", data, t0 + 8 * k) for k in range(n_tris)]
    return verts, tris, (lo, hi)


class Area:
    """Collision of one layout area, transformed and bucketed lazily."""

    def __init__(self, terrain, layout):
        self.terrain = terrain
        self.placements = layout.collision()
        # Scaled primitive colliders (keys "......col_cyln04_a" etc.): tree trunks, crates, posts.
        self.props = {n for n, p in enumerate(self.placements) if p[2][6:].startswith("col_")}
        self.index = collections.defaultdict(list)  # cell -> placement numbers (by world AABB)
        self.cells = {}  # placement number -> {cell: [(ax, ay, az, bx, by, bz, cx, cy, cz)]}
        for n, (rid, m, _) in enumerate(self.placements):
            lo, hi = terrain.phb(rid)[2]
            xs, zs = [], []
            for x in (lo[0], hi[0]):
                for y in (lo[1], hi[1]):
                    for z in (lo[2], hi[2]):
                        xs.append(m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3])
                        zs.append(m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3])
            for cx in range(int(min(xs) // CELL), int(max(xs) // CELL) + 1):
                for cz in range(int(min(zs) // CELL), int(max(zs) // CELL) + 1):
                    self.index[(cx, cz)].append(n)

    def floors_of(self, n):
        if n not in self.cells:
            rid, m, _ = self.placements[n]
            verts, tris, _ = self.terrain.phb(rid)
            w = [(m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
                  m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
                  m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3]) for x, y, z in verts]
            cells = collections.defaultdict(list)
            for a, b, c in tris:
                A, B, C = w[a], w[b], w[c]
                ux, uy, uz = B[0] - A[0], B[1] - A[1], B[2] - A[2]
                vx, vy, vz = C[0] - A[0], C[1] - A[1], C[2] - A[2]
                nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
                ln = math.sqrt(nx * nx + ny * ny + nz * nz)
                if ln == 0 or ny / ln < MIN_UP:
                    continue  # walls, ceilings and degenerate triangles
                t = A + B + C
                for cx in range(int(min(A[0], B[0], C[0]) // CELL), int(max(A[0], B[0], C[0]) // CELL) + 1):
                    for cz in range(int(min(A[2], B[2], C[2]) // CELL), int(max(A[2], B[2], C[2]) // CELL) + 1):
                        cells[(cx, cz)].append(t)
            self.cells[n] = cells
        return self.cells[n]

    def floors(self, x, z, props=False):
        key = (int(x // CELL), int(z // CELL))
        out = []
        for n in self.index.get(key, ()):
            if n in self.props and not props:
                continue
            for ax, ay, az, bx, by, bz, cx, cy, cz in self.floors_of(n).get(key, ()):
                d = (bx - ax) * (cz - az) - (cx - ax) * (bz - az)
                if d == 0:
                    continue
                u = ((x - ax) * (cz - az) - (cx - ax) * (z - az)) / d
                v = ((bx - ax) * (z - az) - (x - ax) * (bz - az)) / d
                if u < -1e-6 or v < -1e-6 or u + v > 1 + 1e-6:
                    continue
                out.append(ay + u * (by - ay) + v * (cy - ay))
        out.sort()
        # The same floor often comes from several overlapping meshes.
        return [y for i, y in enumerate(out) if i == 0 or y - out[i - 1] > 0.05]


class Terrain:
    def __init__(self, client=DEFAULT_CLIENT, zone_names=None):
        self.data = Path(client) / "data"
        if not self.data.is_dir():
            raise FileNotFoundError(f"no 1.23b data folder at {self.data}")
        self.zone_names = zone_names if zone_names is not None else server_zone_names()
        self._layouts = None
        self._areas = {}
        self._phb = {}

    def dat(self, rid):
        return self.data / f"{rid >> 24:02X}/{rid >> 16 & 255:02X}/{rid >> 8 & 255:02X}/{rid & 255:02X}.DAT"

    def phb(self, rid):
        if rid not in self._phb:
            self._phb[rid] = read_phb(self.dat(rid).read_bytes())
        return self._phb[rid]

    def layouts(self):
        """Area name -> MapLayout path. Scans only the first bytes of each file (about 40 s
        cold), then remembers the answer in CACHE (area names and DAT paths only)."""
        if self._layouts is None:
            try:
                cached = json.loads(CACHE.read_text())
                if cached.get("data") == str(self.data):
                    self._layouts = {k: self.data / v for k, v in cached["layouts"].items()}
                    return self._layouts
            except (OSError, ValueError, KeyError):
                pass
            self._layouts = {}
            for path in sorted(self.data.glob("*/*/*/*.DAT")):
                with open(path, "rb") as f:
                    if f.read(21) != b"MapLayoutResourceData":
                        continue
                    head = f.read(0x20000)
                i = head.find(b"Root Folder\0")
                if i >= 0:
                    name = head[i + 12:head.find(b"\0", i + 12)].decode("latin1")
                    self._layouts.setdefault(name, path)
            try:
                CACHE.parent.mkdir(parents=True, exist_ok=True)
                CACHE.write_text(json.dumps({"data": str(self.data), "layouts": {
                    k: str(v.relative_to(self.data)) for k, v in self._layouts.items()}}, indent=1))
            except OSError:
                pass
        return self._layouts

    def area(self, zone):
        name = area_name(self.zone_names.get(zone)) if isinstance(zone, int) else zone
        if name not in self._areas:
            path = self.layouts().get(name)
            self._areas[name] = Area(self, Layout(path.read_bytes())) if path else None
        return self._areas[name]

    def release(self, zone):
        """Drop an area's meshes (they take memory) once a batch is done with it."""
        name = area_name(self.zone_names.get(zone)) if isinstance(zone, int) else zone
        self._areas.pop(name, None)
        self._phb.clear()

    def floors(self, zone, x, z, props=False):
        """Every floor height under (x, z), low to high. props=True adds the tops of primitive
        colliders (tree trunks, crates)."""
        a = self.area(zone)
        return a.floors(x, z, props) if a else []

    def ground_y(self, zone, x, z, near_y=None, props=False):
        """Highest floor under (x, z), or the one nearest near_y; None where there is none."""
        fl = self.floors(zone, x, z, props)
        if not fl:
            return None
        if near_y is None:
            return fl[-1]
        return min(fl, key=lambda y: abs(y - near_y))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--client", default=DEFAULT_CLIENT, help="1.23b install folder (or $XIV_CLIENT)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    q = sub.add_parser("query")
    q.add_argument("zone", type=int)
    q.add_argument("x", type=float)
    q.add_argument("z", type=float)
    q.add_argument("near_y", type=float, nargs="?")
    b = sub.add_parser("batch")
    b.add_argument("infile")
    b.add_argument("outfile")
    sub.add_parser("zones")
    args = ap.parse_args()
    t = Terrain(args.client)
    if args.cmd == "query":
        print("floors:", " ".join(f"{y:.3f}" for y in t.floors(args.zone, args.x, args.z)) or "none")
        print("with props:", " ".join(f"{y:.3f}" for y in t.floors(args.zone, args.x, args.z, True)) or "none")
        g = t.ground_y(args.zone, args.x, args.z, args.near_y)
        print("ground_y:", "none" if g is None else f"{g:.3f}")
    elif args.cmd == "zones":
        lay = t.layouts()
        for zid, name in sorted(t.zone_names.items()):
            a = area_name(name)
            if a:
                print(zid, name, a, lay[a].relative_to(t.data) if a in lay else "-")
    else:
        rows = list(csv.DictReader(open(args.infile)))
        by_zone = collections.defaultdict(list)
        for r in rows:
            by_zone[int(r["zoneId"])].append(r)
        for zone, rs in by_zone.items():
            for r in rs:
                hint = float(r["near_y"]) if r.get("near_y") else None
                fl = t.floors(zone, float(r["x"]), float(r["z"]))
                g = t.ground_y(zone, float(r["x"]), float(r["z"]), hint)
                r["ground_y"] = "" if g is None else f"{g:.3f}"
                r["floors"] = len(fl)
            t.release(zone)
        with open(args.outfile, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else ["zoneId", "x", "z"])
            w.writeheader()
            w.writerows(rows)


if __name__ == "__main__":
    sys.exit(main())
