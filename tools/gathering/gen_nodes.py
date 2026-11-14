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
import csv, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(ROOT, "common", "sql", "data")
sys.path.insert(0, os.path.join(ROOT, "tools", "terrain"))

# command -> (harvest command id in the 1.23b command sheet, MiningPoint actor class)
COMMANDS = {"Mine": (22002, 1200052), "Quarry": (22006, 1200052), "Log": (22003, 1200054),
            "Harvest": (22007, 1200054), "Fish": (22004, 1200056), "Spearfish": (22008, 1200056)}
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
POINTS_PER_POOL = 3
ATTEMPTS = 3


def aetherytes():
    src = open(os.path.join(ROOT, "map-server/src/actor/aetheryte.rs"), encoding="utf8").read()
    out = {}
    for m in re.finditer(r"aetheryte_id: ([\d_]+),\s*zone_id: (\d+),\s*x: ([-\d.]+),\s*y: ([-\d.]+),\s*z: ([-\d.]+)", src):
        out[int(m.group(1).replace("_", ""))] = (int(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5)))
    return out


def place(terrain, zone, ax, ay, az, n, seed):
    """n points 45-80 yalms out from the aetheryte on level, walkable ground, 25+ yalms apart."""
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
    for p in pools:
        tid, cmd, name = int(p["template"]), p["command"], p["place"]
        if name not in PLACES:
            continue
        region, aid, grade = PLACES[name]
        grades[tid] = grade
        if only and f"{cmd}:{region}" not in only and f"{cmd}:{name}" not in only:
            continue
        if aid not in aeth:
            print(f"warning: {name}: aetheryte {aid} has no spawn", file=sys.stderr)
            continue
        zone, ax, ay, az = aeth[aid]
        harvest, cls = COMMANDS[cmd]
        pts = place(terrain, zone, ax, ay, az, POINTS_PER_POOL, tid)
        if len(pts) < POINTS_PER_POOL:
            print(f"warning: {cmd} @ {name}: only {len(pts)} spots", file=sys.stderr)
        slug = re.sub(r"[^a-z]+", "_", name.lower()).strip("_")
        for i, (x, y, z) in enumerate(pts):
            rot = round(math.atan2(ax - x, az - z), 2)
            spawns.append(f"({sid}, {cls}, '{cmd.lower()}_{slug}_{i + 1}', {zone}, '', 0, {x}, {y}, {z}, {rot}, {tid}, {harvest})")
            sid += 1
        print(f"{tid} {cmd} @ {name} ({region}, zone {zone}) grade {grade}: {len(pts)} points")

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
    head, cols, _ = rows_of(path)
    write(path, head, cols, spawns)


if __name__ == "__main__":
    main()
