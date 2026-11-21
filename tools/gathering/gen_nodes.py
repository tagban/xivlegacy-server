#!/usr/bin/env python3
"""Place gathering points in the world for the 1.x node pools.

    python3 -I tools/gathering/gen_nodes.py [--client DIR] [--only Mine:Thanalan ...]

The node pools (gamedata_gather_nodes 2000-2113 + their drops) come from the mozk-tabetai 1.x
database: one pool per (gathering command, place). `mozk_places.csv` keeps which command and
place each pool is (the comments of the original seed). No 1.0 source gives where the points
stood, so each pool's points go around the aetheryte of its place (AETHERYTE_SPAWNS in
map-server/src/actor/aetheryte.rs), on the client's own ground (tools/terrain). The pool's
grade comes from its camp's leve level (PLACES); attempts per visit are ATTEMPTS.

Rewrites, in common/sql/data:
  gamedata_gather_nodes       grade + attempts of each placed pool (other rows untouched)
  server_gather_node_spawns   POINTS_PER_POOL points per placed pool
"""
import collections, csv, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(ROOT, "common", "sql", "data")
sys.path.insert(0, os.path.join(ROOT, "tools", "terrain"))

# command -> (harvest command id in the 1.23b command sheet, MiningPoint actor class).
# 1.23b retired Quarry, Harvest and Spearfish: the command sheet leaves 22006-22008 without
# text ("****") and HarvestJudge only loads the Mining, Felling and Fishing widgets. Their
# pools hold recipe materials found in no other pool, so their points are gathered with the
# 1.23b command of the same hand: Quarry -> Mine, Harvest -> Log, Spearfish -> Fish.
COMMANDS = {"Mine": (22002, 1200052), "Quarry": (22002, 1200052), "Log": (22003, 1200054),
            "Harvest": (22003, 1200054), "Fish": (22004, 1200056), "Spearfish": (22004, 1200056)}
# Points of different pools stay at least this far apart, so the push circle a player stands
# in names one pool.
POOL_GAP = 20
# Spots the client sweep could not walk up to (rocks/trees the collision terrain
# does not have): (zone, x, z). place() keeps BLOCKED_GAP yalms away from them.
BLOCKED = [
    (130, 1177.28, -939.18), (154, 765.55, 1080.95), (172, -1261.04, -160.76),
    (143, 204.56, -204.2), (143, 163.69, -241.0), (150, -127.93, -586.5),
    (172, -1365.59, -164.41), (171, 1246.11, -489.41), (172, -918.98, 364.69),
]
BLOCKED_GAP = 8
# place -> (region, aetheryte id, grade). Grades per camp from Gamer Escape 1.0 item pages (2010-12;
# grade 1 = levels 1-10 ... grade 5 = 41-50): one camp per grade in each starting region.
PLACES = {
    "Bearded Rock": ("La Noscea", 1280002, 1), "Skull Valley": ("La Noscea", 1280003, 2),
    "Bloodshore": ("La Noscea", 1280005, 3), "Cedarwood": ("La Noscea", 1280007, 4),
    "Iron Lake": ("La Noscea", 1280006, 5), "Bald Knoll": ("La Noscea", 1280004, 5),
    "Bentbranch": ("The Black Shroud", 1280062, 1), "Emerald Moss": ("The Black Shroud", 1280064, 2),
    "Tranquil Paths": ("The Black Shroud", 1280065, 3), "Humblehearth": ("The Black Shroud", 1280067, 4),
    "Nine Ivies": ("The Black Shroud", 1280063, 5), "Treespeak": ("The Black Shroud", 1280073, 5),
    "Black Brush": ("Thanalan", 1280032, 1), "Drybone": ("Thanalan", 1280033, 2),
    "Horizon's Edge": ("Thanalan", 1280034, 3), "Nophica's Wells": ("Thanalan", 1280042, 4),
    "Nanawa Mines": ("Thanalan", 1280052, 5), "Halatali": ("Thanalan", 1280039, 5),
    "Broken Water": ("Thanalan", 1280036, 5),
    "Dragonhead": ("Coerthas", 1280092, 5), "The Fields of Glory": ("Coerthas", 1280094, 4),
    "Riversmeet": ("Coerthas", 1280096, 5),
}
# Camps with no 1.x pool of their own whose leves need points: (region, aetheryte id, grade,
# camp whose pools they reuse, commands). Crimson Bark's fieldcraft leves are level 20 (grade 2).
REUSE = {"Crimson Bark": ("The Black Shroud", 1280066, 2, "Emerald Moss", ["Mine", "Log"])}
# Hand-picked points where tools/terrain has no ground (zone 176 has no layout it can read):
# near the Min200 quest points at Nanawa Mines, which stand at y 168.
HAND_SPOTS = {("Mine", "Nanawa Mines"): [(58.0, 168.0, -1232.0), (118.0, 168.0, -1272.0), (60.0, 168.0, -1292.0)]}
POINTS_PER_POOL = 3
ATTEMPTS = 3
# Fishing spots, hand-picked per camp: a dry standing point on the shore and the water it faces,
# (x, y, z, water_x, water_z). The camps' first spots were checked by hand in the 1.23b client;
# candidates came from the client's own water (La Noscea's sea plane at y=0, the `attr_*_w`
# river/pond surfaces in the layouts).
FISH_SPOTS = {
    "Bearded Rock": [(-213.67, 0.51, 19.27, -457.3, 74.0)],
    "Cedarwood": [(772.0, 2.03, 9.0, 961.5, 19.2)],
    "Bald Knoll": [(-1973.77, -0.25, -1234.35, -2064.1, -1096.0)],
    "Skull Valley": [(-1080.0, 1.5, -706.1, -1168.1, -291.4)],
    "Bloodshore": [(1303.3, 1.5, -890.4, 1483.3, -852.1)],
    "Iron Lake": [(-64.0, 62.85, -1949.9, 150.2, -1639.0), (-22.5, 63.75, -1942.6, 233.2, -1624.4)],
    "Emerald Moss": [(-1381.3, 28.1, -1953.3, -1710.6, -2146.6), (-1377.3, 28.1, -1993.3, -1702.6, -2226.6), (-1426.7, 28.1, -1954.7, -1801.4, -2149.4)],
    "Nine Ivies": [(1605.1, 15.91, -745.1, 1508.2, -628.2)],
    "Tranquil Paths": [(-1551.4, -12.3, -626.24, -1536.8, -702.0)],
    "Humblehearth": [(-135.3, -3.74, -446.2, -176.5, -349.2)],
    "Halatali": [(1659.3, 258.5, -254.3, 1719.6, -275.6)],
    "Horizon's Edge": [(-1092.7, 58.4, -65.7, -871.5, 14.2), (-1154.5, 58.4, 123.7, -995.1, 393.0)],
    "Nophica's Wells": [(-834.6, 90.4, 324.3, -804.2, 273.4), (-1019.3, 90.4, 321.6, -1173.6, 268.0)],
    "The Fields of Glory": [(2117.3, 121.65, 405.3, 2733.8, 43.1), (2053.3, 121.65, 277.3, 2605.8, -212.9), (2117.3, 121.65, 341.3, 2733.8, -84.9)],
    "Bentbranch": [(332.0, -1.01, -451.93, 317.9, -437.8), (360.0, 0.87, -451.93, 380.0, -451.9)],
    "Cassiopeia Hollow": [(1364.0, -61.6, -1029.0, 1349.9, -1043.1), (1298.0, -68.72, -687.0, 1318.0, -687.0)],
    "Drybone": [(1026.9, 251.0, -272.2, 1026.9, -252.2), (1006.9, 251.01, -264.2, 1026.9, -264.2)],
    "Mistbeard Cove": [(-2245.0, 31.61, -1594.0, -2259.1, -1579.9), (-2248.0, 45.71, -1558.0, -2262.1, -1543.9)],
    "The Mun Tuy Cellars": [(-848.0, -32.11, -2162.0, -828.0, -2162.0)],
    "The Tam Tara Deepcroft": [(173.0, -36.1, -92.0, 158.9, -77.9)],
    "Gridania": [(-84.3, 16.76, -1475.8, -104.3, -1475.8)],
    "Ul'dah": [(-177.44, 229.0, 236.03, -163.3, 221.9)],
    "Limsa Lominsa": [(-640.0, 1.0, 405.0, -654.1, 419.1), (-586.0, 0.26, 375.0, -566.0, 375.0)],
    "Riversmeet": [(-1952.0, 251.85, 0.0, -2143.6, 194.7), (-1888.0, 251.85, 192.0, -2015.6, 578.7), (-2080.0, 267.85, 64.0, -2399.6, 322.7)],
}
# Spearfishing pools (folded into Fish): spots of their own, POOL_GAP+ from the Fish spots.
# These, and the FISH_SPOTS of Bentbranch, Drybone, the dungeons and Limsa Lominsa, came
# from fish_water.py: a level floor standing at one of the client's water meshes, 20+ yalms
# from other pools (Gridania's and Ul'dah's were found by hand, see TOWN_PLACES). All of
# them were walked to in the 1.23b client from dry ground 4-15 yalms away and fished as a
# Fisher (client test 2026-11-21: each gave its own pool's fish and Fisher EXP), except
# Limsa Lominsa's, where the character logged in on the point. Mistbeard Cove's stand on
# ledges over the sea, which its layout does not carry. The fishing window opens at any
# fishing point, dry ground too, so the water rule is ours. Skull Valley has one: its
# other sea-shore spots sink to the undecoded sea bed.
SPEAR_SPOTS = {
    "Bearded Rock": [(-46.03, 1.9, 216.53, -26.0, 216.5), (-302.03, 1.66, -87.47, -282.0, -87.5)],
    "Bentbranch": [(316.0, -4.0, -439.93, 330.1, -454.1), (428.0, -0.7, -455.93, 448.0, -455.9)],
    "Bloodshore": [(1263.29, 0.24, -824.69, 1283.3, -824.7), (1263.29, 0.23, -768.69, 1283.3, -768.7)],
    "Cedarwood": [(778.47, 1.57, 54.8, 798.5, 54.8), (742.47, 0.94, 102.8, 762.5, 102.8)],
    "Drybone": [(1342.9, 258.86, -144.2, 1357.0, -130.1), (1198.9, 258.92, -136.2, 1218.9, -136.2)],
    "Emerald Moss": [(-1402.3, 28.0, -1953.3, -1382.3, -1953.3), (-1377.3, 28.0, -2014.3, -1377.3, -1994.3)],
    "Halatali": [(1668.3, 258.73, -272.3, 1668.3, -252.3), (1710.3, 259.12, -200.3, 1730.3, -200.3)],
    "Horizon's Edge": [(-1145.5, 58.68, 141.7, -1159.6, 127.6), (-1074.7, 58.15, -56.7, -1094.7, -56.7)],
    "Humblehearth": [(-117.3, -5.92, -437.2, -117.3, -417.2), (-108.3, -6.2, -413.2, -88.3, -413.2)],
    "Iron Lake": [(-40.5, 63.95, -1951.6, -20.5, -1951.6), (-31.5, 63.41, -1924.6, -45.6, -1910.5)],
    "Nine Ivies": [(1596.1, 15.2, -763.1, 1610.2, -777.2), (1596.1, 14.93, -727.1, 1582.0, -713.0)],
    "Nophica's Wells": [(-825.6, 91.04, 306.3, -825.6, 326.3), (-1037.3, 90.19, 312.6, -1017.3, 312.6)],
    "Skull Valley": [(-1059.88, 0.31, -596.79, -1039.9, -596.8)],
    "The Fields of Glory": [(2112.78, 120.34, 311.55, 2132.8, 311.6), (2128.78, 121.9, 299.55, 2148.8, 299.6)],
    "Tranquil Paths": [(-1560.4, -14.87, -644.24, -1546.3, -630.1), (-1584.4, -15.09, -635.24, -1604.4, -635.2)],
}
# Fish pools of the open dungeons: place -> (zone, layout offset). Their spots are in
# FISH_SPOTS; the pools keep their own grade.
DUNGEON_PLACES = {
    "Mistbeard Cove": (131, (-1730.0, 4.0, -1599.0)),
    "Cassiopeia Hollow": (132, (1184.0, -19.9, -767.0)),
    "The Mun Tuy Cellars": (157, (-864.0, -24.0, -2208.0)),
    "The Tam Tara Deepcroft": (158, (224.0, -35.9, -97.0)),
}
# Fish pools of the towns: place -> (zone, layout zone, layout offset, (x, z, radius) to search).
# Zone 230 (Limsa Lominsa's lower decks) stands on zone 133's layout moved by (-448, 0, 192):
# there 96 of the zone's NPC spawns stand on the layout's floors. Zone 209 (Ul'dah's
# lower city) stands on wil_w0_twn01 moved by (-96, 188, 160), as zone 175 does.
# Gridania's layout fits neither of its zones (layout None): its spot, by the mill pond
# west of the Whistling Miller, and Ul'dah's, at a fountain basin, were found by walking in
# the client and reading the position the server logged. The spots are in FISH_SPOTS; the
# pools keep their own grade.
TOWN_PLACES = {
    "Limsa Lominsa": (230, 133, (-448.0, 0.0, 192.0), (-610.0, 390.0, 80.0)),
    "Ul'dah": (209, 175, (-96.0, 188.0, 160.0), (-150.0, 200.0, 120.0)),
    "Gridania": (206, None, None, None),
}
# No Fish point: Black Brush, Broken Water and Dragonhead. No water mesh is in reach of the
# camps, and a look in the client (2026-11-21) found none at either Thanalan camp nor at
# Black Brush's "a0_w" basins by the Ul'dah gate; Dragonhead's flat "b2_w" squares are
# stone floors. Their fish all come from other pools.
# The Mun Tuy Cellars and The Tam Tara Deepcroft have one point each: the client shows no
# open water there (their "p0_w" meshes are puddles), but the pools need a point.


def aetherytes():
    src = open(os.path.join(ROOT, "map-server/src/actor/aetheryte.rs"), encoding="utf8").read()
    out = {}
    for m in re.finditer(r"aetheryte_id: ([\d_]+),\s*zone_id: (\d+),\s*x: ([-\d.]+),\s*y: ([-\d.]+),\s*z: ([-\d.]+)", src):
        out[int(m.group(1).replace("_", ""))] = (int(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5)))
    return out


def placed_points():
    """(zone, x, y, z) of every point in server_gather_node_spawns.sql."""
    text = open(os.path.join(DATA, "server_gather_node_spawns.sql"), encoding="utf8").read()
    return [(int(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))) for m in re.finditer(
        r"^\(\d+, \d+, '[^']*', (\d+), '[^']*', -?\d+, ([-\d.]+), ([-\d.]+), ([-\d.]+),", text, re.M)]


def place(terrain, zone, ax, ay, az, n, seed, taken=()):
    """n points 45-80 yalms out from the aetheryte on level, walkable ground, 25+ yalms apart
    and POOL_GAP+ yalms from the `taken` points of other pools."""
    got = []
    for ring in (55, 70, 45, 80):
        for step in range(24):
            ang = math.radians(seed * 37 + step * 15)
            x, z = ax + ring * math.cos(ang), az + ring * math.sin(ang)
            y = terrain.ground_y(zone, x, z, near_y=ay)
            if y is None or abs(y - ay) > 12:
                continue
            around = [terrain.ground_y(zone, x + dx, z + dz, near_y=y) for dx, dz in ((2, 0), (-2, 0), (0, 2), (0, -2))]
            if any(a is None or abs(a - y) > 1.5 for a in around):
                continue
            if any(math.hypot(x - px, z - pz) < POOL_GAP for px, _, pz in taken):
                continue
            if any(bz == zone and math.hypot(x - bx, z - bzz) < BLOCKED_GAP for bz, bx, bzz in BLOCKED):
                continue
            if all(math.hypot(x - px, z - pz) > 25 for px, _, pz in got):
                got.append((round(x, 2), round(y, 2), round(z, 2)))
            if len(got) == n:
                return got
    return got


def rows_of(path):
    text = open(path, encoding="utf8").read()
    head, _, _ = text.partition("INSERT INTO")
    cols = re.search(r"INSERT INTO `\w+` \([^)]*\)", text).group(0)
    return head, cols, re.findall(r"^\(.*\)", text, re.M)


def write(path, head, cols, rows):
    head = re.sub(r"\d+ rows", f"{len(rows)} rows", head)
    open(path, "w", encoding="utf8").write(head + cols + " VALUES\n" + ",\n".join(rows) + ";\n")


def main():
    only = [a for a in sys.argv[1:] if ":" in a]
    client = os.environ.get("XIV_CLIENT", "/Volumes/AppStorage/ffxiv-scratch/FINAL FANTASY XIV 1.23b")
    if "--client" in sys.argv:
        client = sys.argv[sys.argv.index("--client") + 1]
    from xivterrain import Terrain
    terrain = Terrain(client)
    aeth = aetherytes()
    pools = list(csv.DictReader(open(os.path.join(HERE, "mozk_places.csv"), encoding="utf8")))
    grades, spawns, sid = {}, [], 100
    taken = collections.defaultdict(list)  # zone -> points placed so far
    for name, spots in list(FISH_SPOTS.items()) + list(SPEAR_SPOTS.items()):
        own = DUNGEON_PLACES.get(name) or TOWN_PLACES.get(name)
        if own:  # hand-picked water spots come first
            taken[own[0]] += [(x, y, z) for x, y, z, _, _ in spots]
        elif name in PLACES and PLACES[name][1] in aeth:
            taken[aeth[PLACES[name][1]][0]] += [(x, y, z) for x, y, z, _, _ in spots]
    for p in pools:
        tid, cmd, name = int(p["template"]), p["command"], p["place"]
        if name in DUNGEON_PLACES and cmd == "Fish":
            region, zone, grade, ax, ay, az = "dungeon", DUNGEON_PLACES[name][0], "own", 0.0, 0.0, 0.0
        elif name in TOWN_PLACES and cmd == "Fish":
            region, zone, grade, ax, ay, az = "town", TOWN_PLACES[name][0], "own", 0.0, 0.0, 0.0
        elif name in PLACES:
            region, aid, grade = PLACES[name]
            grades[tid] = grade
            if aid not in aeth:
                print(f"warning: {name}: aetheryte {aid} has no spawn", file=sys.stderr)
                continue
            zone, ax, ay, az = aeth[aid]
        else:
            continue
        if only and f"{cmd}:{region}" not in only and f"{cmd}:{name}" not in only:
            continue
        harvest, cls = COMMANDS[cmd]
        if cmd in ("Fish", "Spearfish"):
            spots = (FISH_SPOTS if cmd == "Fish" else SPEAR_SPOTS).get(name, [])
            pts = [(x, y, z) for x, y, z, _, _ in spots]
            faces = [(wx, wz) for _, _, _, wx, wz in spots]
        else:
            pts = HAND_SPOTS.get((cmd, name)) or place(terrain, zone, ax, ay, az, POINTS_PER_POOL, tid, taken[zone])
            faces = [(ax, az)] * len(pts)
        if cmd not in ("Fish", "Spearfish"):
            taken[zone] += pts
        if len(pts) < (1 if cmd in ("Fish", "Spearfish") else POINTS_PER_POOL):
            print(f"warning: {cmd} @ {name}: only {len(pts)} spots", file=sys.stderr)
        slug = re.sub(r"[^a-z]+", "_", name.lower()).strip("_")
        for i, (x, y, z) in enumerate(pts):
            fx, fz = faces[i]
            rot = round(math.atan2(fx - x, fz - z), 2)
            spawns.append(f"({sid}, {cls}, '{cmd.lower()}_{slug}_{i + 1}', {zone}, '', 0, {x}, {y}, {z}, {rot}, {tid}, {harvest})")
            sid += 1
        print(f"{tid} {cmd} @ {name} ({region}, zone {zone}) grade {grade}: {len(pts)} points")

    tids = {(p["command"], p["place"]): int(p["template"]) for p in pools}
    for name, (region, aid, grade, src, cmds) in REUSE.items():
        if aid not in aeth:
            print(f"warning: {name}: aetheryte {aid} has no spawn", file=sys.stderr)
            continue
        zone, ax, ay, az = aeth[aid]
        slug = re.sub(r"[^a-z]+", "_", name.lower()).strip("_")
        for cmd in cmds:
            tid = tids[(cmd, src)]
            harvest, cls = COMMANDS[cmd]
            pts = place(terrain, zone, ax, ay, az, POINTS_PER_POOL, tid + aid % 97, taken[zone])
            taken[zone] += pts
            for i, (x, y, z) in enumerate(pts):
                rot = round(math.atan2(ax - x, az - z), 2)
                spawns.append(f"({sid}, {cls}, '{cmd.lower()}_{slug}_{i + 1}', {zone}, '', 0, {x}, {y}, {z}, {rot}, {tid}, {harvest})")
                sid += 1
            print(f"{tid} {cmd} @ {name} (reuses {src}, zone {zone}): {len(pts)} points")

    path = os.path.join(DATA, "gamedata_gather_nodes.sql")
    head, cols, rows = rows_of(path)
    out = []
    for r in rows:
        f = r[1:-1].split(", ")
        tid = int(f[0])
        if tid in grades:
            f[1], f[2] = str(grades[tid]), str(ATTEMPTS)
        out.append("(" + ", ".join(f) + ")")
    write(path, head, cols, out)
    path = os.path.join(DATA, "server_gather_node_spawns.sql")
    head, cols, old = rows_of(path)
    # Quest-only points (ids 9000+) are hand-made rows of their quests: keep them.
    write(path, head, cols, spawns + [r for r in old if int(r[1:].split(",")[0]) >= 9000])


if __name__ == "__main__":
    main()
