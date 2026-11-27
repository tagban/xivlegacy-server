#!/usr/bin/env python3
"""Walking routes for test characters, planned over the 1.23b client's own collision.

The world of a zone is one or more layouts (MapLayout + PHB collision, read at run time by
../terrain/xivterrain.py from the user's install), each moved into the server's frame by an offset
(zones.json: server = layout + offset). A city is its town layout plus its interiors, sharing one
offset; its field joins it so a route can leave through a gate. The walkable map is a 0.5-yalm grid
with several floor levels per cell:

- a floor is an up-facing collision triangle under the cell's centre;
- a wall is a steep triangle; a floor level is blocked when a wall rises in the cell between a step
  (STEP) and head height (HEAD) above it, or when another floor hangs within head height over it;
- neighbours connect when their floors differ by at most STEP; diagonals don't cut corners;
- the walker's radius: every cell within it must have a floor near the same height, and a path
  near walls costs more, so routes keep to the middle of streets and doorways;
- public NPC spawns (common/sql/data/server_spawn_locations.sql) block a small circle each, map
  objects (door spawns stand in their doorways) excepted;
- zones.json can open doors (remove walls in a circle) and close spots; walked.txt adds floors where
  players have walked but the layout has no collision (our own test logs).

The grid is built in 32-yalm tiles when first needed and cached outside the repository
($XIVNAV_CACHE, default ~/.cache/xivlegacy/nav). A* finds the path; it is then pulled tight
(straight lines wherever the grid says the walker fits) into waypoints.

Long routes (over LONG_FROM yalms, or a short one the fine search runs out of budget on, such as a
city to its field through one gate far off) are planned in two steps. Each tile is split into its
pieces (cells that join up inside the tile) and the crossings between pieces of neighbouring tiles
are found (both cached); a search over those crossings gives a corridor, and the fine search then
walks it leg by leg, each leg inside one piece. No gate list is needed: the crossings find the gate.
A route whose goal can't be reached at all ends in NoPath with `walled` set and the way to the
closest spot (go.py walks there and says so).

    nav.py plan ZONE SX SY SZ TX TZ [--radius R] [--out FILE]   waypoints "x y z", one a line
    nav.py floor ZONE X Z                                        the walkable levels there
    nav.py zones                                                 the zone table
    nav.py check ZONE FILE                                       how many "x y z" points stand on a floor
"""
import argparse
import hashlib
import heapq
import json
import math
import os
import pickle
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "terrain"))
import xivterrain  # noqa: E402

LONG_FROM = 150.0  # yalms: longer routes are planned as a corridor of tile pieces first
VERSION = 5  # bump when the grid rules change (old cache tiles are then ignored)
G = 0.5  # cell size, yalms
TILE = 64  # cells a tile side (32 yalms)
STEP = 0.6  # highest step between neighbouring cells
HEAD = 1.8  # a wall or floor this close above a floor blocks it
FLOOR_UP = 0.45  # a floor's normal points at least this much up (about 63 degrees)
WALL_UP = 0.7  # steeper than this (45 degrees) is a wall
MERGE = 0.3  # floors closer than this in one cell are one
NPC_R = 0.6  # an NPC blocks this far around its spawn
CACHE = Path(os.environ.get("XIVNAV_CACHE") or Path.home() / ".cache" / "xivlegacy" / "nav")
N8 = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]


def load_table():
    return json.loads((HERE / "zones.json").read_text())


def load_walked():
    """zone -> [(x, y, z)]: spots our test characters stood on where the layouts have no floor"""
    out = {}
    path = HERE / "walked.txt"
    if path.exists():
        for line in path.read_text().splitlines():
            if line.strip() and not line.startswith("#"):
                z, x, y, zz = line.split()[:4]
                out.setdefault(int(z), []).append((float(x), float(y), float(zz)))
    return out


def load_npcs():
    """zone -> [(x, y, z)]: public NPC spawns (server data); a player can't walk through them.
    Map objects (/Chara/Npc/MapObj/: guild and shop doors, which open as a player walks up, and
    pieces that only show or hide) are left out: a door spawn stands in its doorway."""
    out = {}
    data = HERE.parent.parent / "common" / "sql" / "data"
    path = data / "server_spawn_locations.sql"
    row = re.compile(r"\(\d+, (\d+), '[^']*', (\d+), '', \d+, (-?[\d.]+), (-?[\d.]+), (-?[\d.]+),")
    mapobj = set()
    classes = data / "gamedata_actor_class.sql"
    if classes.exists():
        mapobj = set(re.findall(r"^\((\d+), '/Chara/Npc/MapObj/", classes.read_text(errors="replace"), re.M))
    if path.exists():
        for c, z, x, y, zz in row.findall(path.read_text()):
            if c not in mapobj:
                out.setdefault(int(z), []).append((float(x), float(y), float(zz)))
    return out


def clip(poly, axis, value, keep_greater):
    """Sutherland-Hodgman: clip a polygon of (x, y, z) to one side of x or z = value"""
    out = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ina = (a[axis] >= value) if keep_greater else (a[axis] <= value)
        inb = (b[axis] >= value) if keep_greater else (b[axis] <= value)
        if ina:
            out.append(a)
        if ina != inb:
            t = (value - a[axis]) / (b[axis] - a[axis])
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])))
    return out


class World:
    """The walkable grid of one zone (its layouts, offsets and fixes from zones.json)."""

    def __init__(self, zone, client=None, radius=0.6):
        table = load_table()
        self.zone = zone
        spec = table["zones"].get(str(zone))
        if spec is None:
            raise SystemExit(f"zone {zone} is not in zones.json")
        self.name = spec.get("name", str(zone))
        self.terrain = xivterrain.Terrain(client or xivterrain.DEFAULT_CLIENT)
        self.layouts = []  # (name, area, offset)
        for name in spec["layouts"]:
            off = table["layouts"].get(name, {}).get("offset", [0.0, 0.0, 0.0])
            area = self.terrain.area(name)
            if area is None:
                raise SystemExit(f"layout {name} not found in the install")
            self.layouts.append((name, area, tuple(off)))
        self.doors = [d for d in table.get("doors", []) if zone in d["zones"]]
        self.closed = [d for d in table.get("closed", []) if zone in d["zones"]]
        self.lines = [d for d in table.get("zone_lines", []) if zone in d["zones"]]
        same = spec.get("same_map", [zone])
        walked = load_walked()
        self.walked = [p for z in same for p in walked.get(z, [])]
        self.npcs = [p for z in same for p in load_npcs().get(z, [])]
        self.radius = radius
        key = json.dumps([VERSION, [(n, o) for n, _, o in self.layouts], self.doors, self.closed, len(self.walked),
                          sum(x + y + z for x, y, z in self.walked), len(self.npcs), sum(x + z for x, y, z in self.npcs)],
                         sort_keys=True)
        self.cache = CACHE / f"{zone}-{hashlib.sha1(key.encode()).hexdigest()[:12]}"
        self.tiles = {}
        self.world_tris = {}  # (layout index, placement) -> [(A, B, C, ny)]
        self.clear_memo = {}
        self.blocked = set()  # cells kept out of plans for now (where a walk got stuck)
        self.free = set()  # blocked cells let through for this plan (where it starts and ends)

    # --- building tiles -------------------------------------------------------------------
    def _tris(self, li, n):
        k = (li, n)
        if k not in self.world_tris:
            _, area, (ox, oy, oz) = self.layouts[li]
            rid, m, _ = area.placements[n]
            verts, tris, _ = self.terrain.phb(rid)
            w = [(m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3] + ox,
                  m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3] + oy,
                  m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3] + oz) for x, y, z in verts]
            out = []
            for a, b, c in tris:
                A, B, C = w[a], w[b], w[c]
                ux, uy, uz = B[0] - A[0], B[1] - A[1], B[2] - A[2]
                vx, vy, vz = C[0] - A[0], C[1] - A[1], C[2] - A[2]
                nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
                ln = math.sqrt(nx * nx + ny * ny + nz * nz)
                if ln > 0:
                    out.append((A, B, C, ny / ln))
            self.world_tris[k] = out
        return self.world_tris[k]

    def _build(self, tx, tz):
        x0, z0 = tx * TILE * G, tz * TILE * G
        x1, z1 = x0 + TILE * G, z0 + TILE * G
        floors = {}
        walls = {}
        for li, (_, area, (ox, oy, oz)) in enumerate(self.layouts):
            cand = set()
            for cx in range(int((x0 - ox) // xivterrain.CELL), int((x1 - ox) // xivterrain.CELL) + 1):
                for cz in range(int((z0 - oz) // xivterrain.CELL), int((z1 - oz) // xivterrain.CELL) + 1):
                    cand.update(area.index.get((cx, cz), ()))
            for n in cand:
                for A, B, C, ny in self._tris(li, n):
                    lx, hx = min(A[0], B[0], C[0]), max(A[0], B[0], C[0])
                    lz, hz = min(A[2], B[2], C[2]), max(A[2], B[2], C[2])
                    if hx < x0 or lx > x1 or hz < z0 or lz > z1:
                        continue
                    i0, i1 = max(0, int((lx - x0) // G)), min(TILE - 1, int((hx - x0) // G))
                    j0, j1 = max(0, int((lz - z0) // G)), min(TILE - 1, int((hz - z0) // G))
                    up = abs(ny)
                    if ny >= FLOOR_UP:
                        d = (B[0] - A[0]) * (C[2] - A[2]) - (C[0] - A[0]) * (B[2] - A[2])
                        if d != 0:
                            for i in range(i0, i1 + 1):
                                x = x0 + (i + 0.5) * G
                                for j in range(j0, j1 + 1):
                                    z = z0 + (j + 0.5) * G
                                    u = ((x - A[0]) * (C[2] - A[2]) - (C[0] - A[0]) * (z - A[2])) / d
                                    v = ((B[0] - A[0]) * (z - A[2]) - (x - A[0]) * (B[2] - A[2])) / d
                                    if u >= -1e-6 and v >= -1e-6 and u + v <= 1 + 1e-6:
                                        floors.setdefault((i, j), []).append(A[1] + u * (B[1] - A[1]) + v * (C[1] - A[1]))
                    if up < WALL_UP:
                        tri = [A, B, C]
                        for i in range(i0, i1 + 1):
                            cx0 = x0 + i * G
                            pi = clip(clip(tri, 0, cx0, True), 0, cx0 + G, False)
                            if not pi:
                                continue
                            for j in range(j0, j1 + 1):
                                cz0 = z0 + j * G
                                pj = clip(clip(pi, 2, cz0, True), 2, cz0 + G, False)
                                if pj:
                                    ys = [p[1] for p in pj]
                                    walls.setdefault((i, j), []).append((min(ys), max(ys)))
        # floors where players walked but the layouts have none; right where they stood, no walls
        stood = {}
        for x, y, z in self.walked:
            if x0 - 1 <= x < x1 + 1 and z0 - 1 <= z < z1 + 1:
                for i in range(int((x - 0.5 - x0) // G), int((x + 0.5 - x0) // G) + 1):
                    for j in range(int((z - 0.5 - z0) // G), int((z + 0.5 - z0) // G) + 1):
                        stood.setdefault((i, j), []).append(y)
                for i in range(int((x - 0.9 - x0) // G), int((x + 0.9 - x0) // G) + 1):
                    for j in range(int((z - 0.9 - z0) // G), int((z + 0.9 - z0) // G) + 1):
                        if 0 <= i < TILE and 0 <= j < TILE:
                            fl = floors.setdefault((i, j), [])
                            if not any(abs(f - y) < 1.0 for f in fl):
                                fl.append(y)
        # opened doors: no walls in the circle; closed spots: no floor
        for d in self.doors:
            for (i, j) in list(walls):
                x, z = x0 + (i + 0.5) * G, z0 + (j + 0.5) * G
                if (x - d["x"]) ** 2 + (z - d["z"]) ** 2 <= d["r"] ** 2:
                    lo, hi = d.get("y", [-1e9, 1e9])
                    walls[(i, j)] = [w for w in walls[(i, j)] if w[1] < lo or w[0] > hi]
        levels = {}
        for c, fl in floors.items():
            x, z = x0 + (c[0] + 0.5) * G, z0 + (c[1] + 0.5) * G
            if any((x - d["x"]) ** 2 + (z - d["z"]) ** 2 <= d["r"] ** 2 for d in self.closed):
                continue
            fl.sort()
            merged = []
            for f in fl:
                if merged and f - merged[-1] <= MERGE:
                    merged[-1] = f
                else:
                    merged.append(f)
            ws = walls.get(c, ())
            near = [ny for nx, ny, nz in self.npcs if (x - nx) ** 2 + (z - nz) ** 2 <= NPC_R * NPC_R]
            ok = []
            for k, f in enumerate(merged):
                if k + 1 < len(merged) and merged[k + 1] - f < HEAD:
                    continue  # something hangs over it
                if any(lo < f + HEAD and hi > f + STEP for lo, hi in ws) and not any(abs(f - y) < 1.0 for y in stood.get(c, ())):
                    continue
                if any(-HEAD < ny - f < HEAD for ny in near):
                    continue  # an NPC stands there
                ok.append(round(f, 2))
            if ok:
                levels[c[0] * TILE + c[1]] = ok
        return levels

    def tile(self, tx, tz):
        k = (tx, tz)
        if k not in self.tiles:
            path = self.cache / f"{tx}_{tz}.pkl"
            try:
                self.tiles[k] = pickle.loads(path.read_bytes())
            except (OSError, pickle.PickleError, EOFError):
                self.tiles[k] = self._build(tx, tz)
                try:
                    self.cache.mkdir(parents=True, exist_ok=True)
                    tmp = path.with_suffix(".tmp")
                    tmp.write_bytes(pickle.dumps(self.tiles[k], protocol=4))
                    tmp.replace(path)
                except OSError:
                    pass
        return self.tiles[k]

    # --- queries --------------------------------------------------------------------------
    def levels(self, ci, cj):
        t = self.tile(ci // TILE, cj // TILE)
        return t.get((ci % TILE) * TILE + (cj % TILE), ())

    def level_near(self, ci, cj, y, tol=STEP):
        best = None
        for f in self.levels(ci, cj):
            if abs(f - y) <= tol and (best is None or abs(f - y) < abs(best - y)):
                best = f
        return best

    def clear(self, ci, cj, y, r):
        """every cell within r yalms has a floor near y"""
        k = (ci, cj, y, r)
        v = self.clear_memo.get(k)
        if v is None:
            n = int(math.ceil(r / G))
            v = True
            for di in range(-n, n + 1):
                for dj in range(-n, n + 1):
                    if (di or dj) and (di * di + dj * dj) * G * G <= r * r + 1e-6:
                        if self.level_near(ci + di, cj + dj, y, STEP + 0.25 * max(abs(di), abs(dj))) is None:
                            v = False
                            break
                if not v:
                    break
            self.clear_memo[k] = v
        return v

    def cell(self, x, z):
        return int(math.floor(x / G)), int(math.floor(z / G))

    def centre(self, ci, cj):
        return (ci + 0.5) * G, (cj + 0.5) * G

    def snap(self, x, y, z, search=6.0):
        """the walkable cell and level nearest (x, y, z) (y None: the highest)"""
        ci, cj = self.cell(x, z)
        n = int(search / G)
        best = None
        for ring in range(n + 1):
            for di in range(-ring, ring + 1):
                for dj in range(-ring, ring + 1):
                    if max(abs(di), abs(dj)) != ring:
                        continue
                    for f in self.levels(ci + di, cj + dj):
                        if not self.clear(ci + di, cj + dj, f, min(self.radius, 0.5)):
                            continue
                        dy = 0 if y is None else abs(f - y)
                        if y is not None and dy > 3.0:
                            continue
                        score = math.hypot(di, dj) * G + dy - (f * 1e-3 if y is None else 0)
                        if best is None or score < best[0]:
                            best = (score, (ci + di, cj + dj, f))
            if best and ring * G > best[0] + 1:
                break
        return best[1] if best else None

    # --- planning -------------------------------------------------------------------------
    def plan(self, start, goal, near=1.5, max_nodes=300000, corridor=True, pulled=True):
        """[(x, y, z)] from start (x, y, z) to within `near` yalms of goal (x, y or None, z), or raise
        NoPath with the way to the closest spot"""
        s = self.snap(*start)
        if s is None:
            raise RuntimeError(f"no walkable floor near the start {start}")
        g = self.snap(goal[0], goal[1], goal[2], 8.0)
        if g is None:
            raise RuntimeError(f"no walkable floor near the goal {goal}")
        gi, gj = g[0], g[1]
        if corridor:
            self.free_ends(s, goal, near)
        soft = self.radius + 0.75
        # search inside an ellipse around start and goal: a detour of 1.5 x the straight line + 150 yalms
        span = math.hypot(s[0] - gi, s[1] - gj)
        reach = 1.5 * span + 150.0 / G
        # a greedier search on long routes (a field crossing): a little longer path, far fewer cells
        weight = 1.2 + min(0.8, span * G / 500.0)
        if corridor and span * G > LONG_FROM:
            return self.long(start, goal, near)
        openq = [(0.0, 0.0, s)]
        came = {s: None}
        cost = {s: 0.0}
        gy = goal[1]

        def off(ci, cj, y):
            # how far a cell is from the goal, in cells; a goal with a height counts the climb too, so
            # the closest spot to a counter on an upper floor is not the floor right under it
            h = math.hypot(ci - gi, cj - gj)
            return h if gy is None or abs(y - gy) < 1.5 else h + abs(y - gy) / G

        best = (off(*s), s)
        found = None
        nodes = 0
        while openq:
            _, c0, cur = heapq.heappop(openq)
            if c0 > cost.get(cur, 1e18):
                continue
            nodes += 1
            if nodes > max_nodes:
                break
            ci, cj, y = cur
            if math.hypot(ci - gi, cj - gj) * G <= near and (gy is None or abs(y - gy) < 1.5):
                found = cur
                break
            h = off(ci, cj, y)
            if h < best[0]:
                best = (h, cur)
            for di, dj, step in N8:
                ni, nj = ci + di, cj + dj
                if di and dj:
                    # no cutting corners
                    if self.level_near(ci + di, cj, y) is None or self.level_near(ci, cj + dj, y) is None:
                        continue
                if self.is_blocked((ni, nj)) or math.hypot(ni - s[0], nj - s[1]) + math.hypot(ni - gi, nj - gj) > reach:
                    continue
                for f in self.levels(ni, nj):
                    if abs(f - y) > STEP:
                        continue
                    if not self.clear(ni, nj, f, self.radius):
                        continue
                    nc = c0 + step * (1.0 if self.clear(ni, nj, f, soft) else 2.5) + abs(f - y) * 0.5
                    st = (ni, nj, f)
                    if nc < cost.get(st, 1e18):
                        cost[st] = nc
                        came[st] = cur
                        heapq.heappush(openq, (nc + weight * math.hypot(ni - gi, nj - gj), nc, st))
        end = found or best[1]
        path = []
        c = end
        while c:
            path.append(c)
            c = came[c]
        path.reverse()
        pts = [(*self.centre(ci, cj), y) for ci, cj, y in path]
        pts = [(x, y, z) for x, z, y in pts]
        if not found and nodes > max_nodes and corridor:
            # out of budget (a short way as the crow flies, a long way round): the corridor search
            return self.long(start, goal, near)
        if not found:
            x, y, z = pts[-1]
            raise NoPath(f"no path ({nodes} cells searched); closest {x:.1f} {y:.1f} {z:.1f}, "
                         f"{best[0] * G:.1f} yalms from the goal", pts, walled=nodes <= max_nodes, gap=best[0] * G)
        return self.pull(pts) if pulled else pts

    # --- long routes: pieces of tiles and the crossings between them ------------------------
    def moves(self, ci, cj, y, inside=None):
        """the walker's moves from (ci, cj) at level y: (ni, nj, f, step); `inside` keeps them to one tile"""
        for di, dj, step in N8:
            ni, nj = ci + di, cj + dj
            if inside and (ni // TILE, nj // TILE) != inside:
                continue
            if di and dj and (self.level_near(ci + di, cj, y) is None or self.level_near(ci, cj + dj, y) is None):
                continue
            for f in self.levels(ni, nj):
                if abs(f - y) <= STEP and self.clear(ni, nj, f, self.radius):
                    yield ni, nj, f, step

    def pieces(self, tx, tz):
        """{(ci, cj, f): piece number}: the tile's walkable cells, grouped by what joins up inside it"""
        k = ("pieces", tx, tz)
        if k in self.tiles:
            return self.tiles[k]
        path = self.cache / f"{tx}_{tz}.pieces-{self.radius}.pkl"
        try:
            out = pickle.loads(path.read_bytes())
        except (OSError, pickle.PickleError, EOFError):
            out = {}
            n = 0
            for idx, fl in self.tile(tx, tz).items():
                ci, cj = tx * TILE + idx // TILE, tz * TILE + idx % TILE
                for f in fl:
                    if (ci, cj, f) in out or not self.clear(ci, cj, f, self.radius):
                        continue
                    out[(ci, cj, f)] = n
                    todo = [(ci, cj, f)]
                    while todo:
                        c = todo.pop()
                        for ni, nj, g, _ in self.moves(*c, inside=(tx, tz)):
                            if (ni, nj, g) not in out:
                                out[(ni, nj, g)] = n
                                todo.append((ni, nj, g))
                    n += 1
            try:
                self.cache.mkdir(parents=True, exist_ok=True)
                tmp = path.with_suffix(".tmp")
                tmp.write_bytes(pickle.dumps(out, protocol=4))
                tmp.replace(path)
            except OSError:
                pass
        self.tiles[k] = out
        return out

    def piece_of(self, node):
        return (node[0] // TILE, node[1] // TILE, self.pieces(node[0] // TILE, node[1] // TILE).get(node))

    def crossings(self, tx, tz):
        """{piece: [(here, there)]}: where the walker steps from a piece of this tile into a neighbour
        tile; one crossing for each run of side-by-side border cells (and one every 8 cells of a long run)"""
        k = ("cross", tx, tz)
        if k in self.tiles:
            return self.tiles[k]
        mine = self.pieces(tx, tz)
        runs = {}  # (my piece, their piece, side) -> [(here, there)] along the border
        for (ci, cj, f), p in mine.items():
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ni, nj = ci + di, cj + dj
                if (ni // TILE, nj // TILE) == (tx, tz):
                    continue
                for g in self.levels(ni, nj):
                    if abs(g - f) <= STEP and self.clear(ni, nj, g, self.radius):
                        q = self.piece_of((ni, nj, g))
                        if q[2] is not None:
                            runs.setdefault(((tx, tz, p), q, (di, dj)), []).append(((ci, cj, f), (ni, nj, g)))
        out = {}
        for (p, q, side), pairs in runs.items():
            along = 1 if side[0] else 0  # the border runs along j for an east/west side
            pairs.sort(key=lambda ab: ab[0][along])
            run = [pairs[0]]
            for ab in pairs[1:] + [None]:
                if ab is not None and ab[0][along] - run[-1][0][along] <= 1 and len(run) < 8:
                    run.append(ab)
                    continue
                out.setdefault(p, []).append(run[len(run) // 2])
                run = [ab]
        self.tiles[k] = out
        return out

    def goal_cells(self, goal, near):
        """every walkable cell within `near` of goal (x, y or None, z), at a matching height; else the
        nearest walkable one"""
        gx, gy, gz = goal
        ci, cj = self.cell(gx, gz)
        n = int(math.ceil(near / G))
        out = []
        for di in range(-n, n + 1):
            for dj in range(-n, n + 1):
                x, z = self.centre(ci + di, cj + dj)
                if math.hypot(x - gx, z - gz) > near:
                    continue
                for f in self.levels(ci + di, cj + dj):
                    if (gy is None or abs(f - gy) < 1.5) and self.piece_of((ci + di, cj + dj, f))[2] is not None:
                        out.append((ci + di, cj + dj, f))
        if not out:
            g = self.snap(gx, gy, gz, 8.0)
            if g is not None and self.piece_of(g)[2] is not None:
                out.append(g)
        return out

    def corridor(self, s, goals, max_nodes=200000, avoid=()):
        """[s, crossings..., one of goals]: cells (ci, cj, f) to walk through, from a search over tile
        pieces and the crossings between them (each leg between two of them stays inside one piece)"""
        ends = {}
        for g in goals:
            ends.setdefault(self.piece_of(g), []).append(g)
        goals = set(goals)
        gi = sum(g[0] for g in goals) / len(goals)
        gj = sum(g[1] for g in goals) / len(goals)
        span = math.hypot(s[0] - gi, s[1] - gj)
        reach = 2.0 * span + 400.0 / G
        openq = [(0.0, 0.0, s)]
        came, cost = {s: None}, {s: 0.0}
        best = (span, s)
        nodes = 0
        end = None
        while openq:
            _, c0, cur = heapq.heappop(openq)
            if c0 > cost.get(cur, 1e18):
                continue
            if cur in goals:
                end = cur
                break
            nodes += 1
            if nodes > max_nodes:
                break
            h = math.hypot(cur[0] - gi, cur[1] - gj)
            if h < best[0]:
                best = (h, cur)
            p = self.piece_of(cur)
            nxt = list(ends.get(p, ()))
            for here, there in self.crossings(p[0], p[1]).get(p, ()):
                if here == cur:
                    nxt.append(there)
                elif (cur, here) not in avoid:
                    nxt.append(here)
            for n in nxt:
                if (cur, n) in avoid or math.hypot(n[0] - s[0], n[1] - s[1]) + math.hypot(n[0] - gi, n[1] - gj) > reach:
                    continue
                nc = c0 + math.hypot(n[0] - cur[0], n[1] - cur[1]) * 1.1 + abs(n[2] - cur[2]) * 0.5
                if nc < cost.get(n, 1e18):
                    cost[n] = nc
                    came[n] = cur
                    heapq.heappush(openq, (nc + 1.2 * math.hypot(n[0] - gi, n[1] - gj), nc, n))
        out = []
        c = end or best[1]
        while c:
            out.append(c)
            c = came[c]
        out.reverse()
        if end is None:
            x, z = self.centre(out[-1][0], out[-1][1])
            raise NoPath(f"no way through ({nodes} crossings searched); closest {x:.1f} {out[-1][2]:.1f} {z:.1f}, "
                         f"{best[0] * G:.1f} yalms from the goal", [(self.centre(a, b)[0], f, self.centre(a, b)[1]) for a, b, f in out],
                         walled=nodes <= max_nodes, gap=best[0] * G)
        return out

    def long(self, start, goal, near=1.5):
        """a long route (a field crossing, a city to its field): a corridor of tile pieces, then the
        fine search leg by leg along it"""
        s = self.snap(*start)
        if s is None or self.piece_of(s)[2] is None:
            raise RuntimeError(f"no walkable floor near the start {start}")
        self.free_ends(s, goal, near)
        goals = self.goal_cells(goal, max(near, 0.75))
        if not goals:
            raise RuntimeError(f"no walkable floor near the goal {goal}")
        avoid = set()
        for _ in range(8):
            cells = self.corridor(s, goals, avoid=avoid)
            pts = []
            bad = None
            for a, b in zip(cells, cells[1:]):
                pa = (self.centre(a[0], a[1])[0], a[2], self.centre(a[0], a[1])[1])
                pb = (self.centre(b[0], b[1])[0], b[2], self.centre(b[0], b[1])[1])
                if self.piece_of(a) != self.piece_of(b):
                    leg = [pa, pb]  # a crossing: side-by-side cells
                else:
                    try:
                        leg = self.fine(pa, pb, 0.5)
                    except NoPath:
                        bad = (a, b)  # a spot blocked since (where a walk stuck) cuts this piece
                        break
                pts += leg if not pts else leg[1:]
            if bad is None:
                return self.pull(pts)
            avoid.add(bad)
        raise NoPath("no way through: the corridor keeps meeting blocked spots", pts)

    def fine(self, start, goal, near):
        """the fine search alone, unpulled (a leg of a long route)"""
        pts = self.plan(start, goal, near, max_nodes=60000, corridor=False, pulled=False)
        return pts

    def trace(self, a, b):
        """walk the grid straight from a (x, y, z) toward b's x, z: the floor height reached, or None"""
        d = math.hypot(b[0] - a[0], b[2] - a[2])
        n = max(1, int(d / (G * 0.5)))
        y = a[1]
        prev = self.cell(a[0], a[2])
        for k in range(1, n + 1):
            t = k / n
            x, z = a[0] + t * (b[0] - a[0]), a[2] + t * (b[2] - a[2])
            c = self.cell(x, z)
            if c == prev:
                continue
            if c[0] != prev[0] and c[1] != prev[1]:
                # a diagonal step: both side cells must be open
                if self.level_near(c[0], prev[1], y) is None or self.level_near(prev[0], c[1], y) is None:
                    return None
            f = self.level_near(c[0], c[1], y)
            if f is None or self.is_blocked(c) or not self.clear(c[0], c[1], f, self.radius) or not self.clear(c[0], c[1], f, self.radius + 0.25):
                return None
            y, prev = f, c
        return y

    def line_ok(self, a, b):
        """can the walker go straight from a to b (each (x, y, z)) on the grid?"""
        y = self.trace(a, b)
        return y is not None and abs(y - b[1]) < 1.0

    def pull(self, pts, reach=40.0):
        """straight lines over the grid path wherever they fit"""
        out = [pts[0]]
        i = 0
        while i < len(pts) - 1:
            j = len(pts) - 1
            while j > i + 1 and (math.hypot(pts[j][0] - pts[i][0], pts[j][2] - pts[i][2]) > reach or not self.line_ok(pts[i], pts[j])):
                j -= 1
            out.append(pts[j])
            i = j
        return out

    def is_blocked(self, c):
        return c in self.blocked and c not in self.free

    def free_ends(self, s, goal, near):
        """a blocked spot never covers where the walker stands (it is standing there) or the goal itself"""
        self.free = set()
        for (ci, cj), r in ((s[:2], 2.0), (self.cell(goal[0], goal[2]), near + 0.5)):
            n = int(math.ceil(r / G))
            for di in range(-n, n + 1):
                for dj in range(-n, n + 1):
                    if (di * di + dj * dj) * G * G <= r * r and (ci + di, cj + dj) in self.blocked:
                        self.free.add((ci + di, cj + dj))

    def block(self, x, z, r):
        """keep plans out of a circle (a spot a walk got stuck at)"""
        ci, cj = self.cell(x, z)
        n = int(math.ceil(r / G))
        for di in range(-n, n + 1):
            for dj in range(-n, n + 1):
                if (di * di + dj * dj) * G * G <= r * r:
                    self.blocked.add((ci + di, cj + dj))

    def marks(self, pts):
        """the doors and zone lines a path passes"""
        out = []
        for d in self.doors + self.lines:
            for x, y, z in pts:
                if math.hypot(x - d["x"], z - d["z"]) <= d.get("r", 4) + 2:
                    out.append(d)
                    break
        return out


class NoPath(RuntimeError):
    """no way to the goal; `partial` is the way to the closest spot, `walled` says every spot reachable
    from the start was searched (the goal is cut off, not just far), `gap` how far that spot is from it"""

    def __init__(self, msg, partial, walled=False, gap=None):
        super().__init__(msg)
        self.partial = partial
        self.walled = walled
        self.gap = gap


def length(pts):
    return sum(math.hypot(b[0] - a[0], b[2] - a[2]) for a, b in zip(pts, pts[1:]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--client", help="1.23b install (default $XIV_CLIENT)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan")
    p.add_argument("zone", type=int)
    p.add_argument("coords", type=float, nargs=5, metavar="SX SY SZ TX TZ")
    p.add_argument("--ty", type=float, help="the goal's height, when it has several floors")
    p.add_argument("--radius", type=float, default=0.6, help="the walker's radius (yalms)")
    p.add_argument("--near", type=float, default=1.5, help="how close to the goal is there (yalms)")
    p.add_argument("--out")
    p.add_argument("--partial", action="store_true", help="on no path, write the way to the closest spot")
    f = sub.add_parser("floor")
    f.add_argument("zone", type=int)
    f.add_argument("x", type=float)
    f.add_argument("z", type=float)
    sub.add_parser("zones")
    c = sub.add_parser("check")
    c.add_argument("zone", type=int)
    c.add_argument("file")
    a = ap.parse_args()
    if a.cmd == "zones":
        t = load_table()
        for z, s in sorted(t["zones"].items(), key=lambda kv: int(kv[0])):
            offs = ", ".join(f"{n} {tuple(t['layouts'].get(n, {}).get('offset', [0, 0, 0]))}" for n in s["layouts"])
            print(f"{z:>4} {s.get('name', '')}: {offs}")
        return
    w = World(a.zone, a.client, getattr(a, "radius", 0.6))
    if a.cmd == "floor":
        ci, cj = w.cell(a.x, a.z)
        print(f"zone {a.zone} ({a.x}, {a.z}): walkable floors {list(w.levels(ci, cj))}")
        return
    if a.cmd == "check":
        pts = [tuple(map(float, l.split()[:3])) for l in open(a.file) if l.strip() and not l.startswith("#")]
        ok = sum(1 for x, y, z in pts if w.level_near(*w.cell(x, z), y, 1.0) is not None)
        print(f"{ok}/{len(pts)} points on a walkable floor of zone {a.zone}")
        return
    sx, sy, sz, tx, tz = a.coords
    try:
        pts = w.plan((sx, sy, sz), (tx, a.ty, tz), a.near)
        status = "ok"
    except NoPath as e:
        print(f"# {e}", file=sys.stderr)
        if not a.partial:
            sys.exit(2)
        pts, status = w.pull(e.partial), "partial"
    lines = [f"# zone {a.zone} {w.name}: {len(pts)} points, {length(pts):.0f} yalms ({status})"]
    for m in w.marks(pts):
        lines.append(f"# passes {m.get('kind', 'door')} {m['name']} at {m['x']} {m['z']}")
    lines += [f"{x:.2f} {y:.2f} {z:.2f}" for x, y, z in pts]
    text = "\n".join(lines) + "\n"
    if a.out:
        Path(a.out).write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
