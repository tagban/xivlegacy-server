#!/usr/bin/env python3
"""Walk a test character to (X, Z): plan with nav.py, walk with the test client's walkpath command,
plan again from where it stopped if it gets stuck. Prints "arrived ..." or why it stopped.

    go.py ZONE X Z [--y Y] [--near 1.5] [--via X Z]... [--rig DIR] [--who A] [--forget]

Exit status: 0 arrived; 1 stopped (the last line says why); 3 a quest event or cutscene took over on
the way (a push trigger, a zone-in scene): the walk ends there and the spot is not learned as stuck.

A rig is the folder layout every XIVLegacy test rig uses: c<who>/xiv.fifo (the client's
XIVLEGACY_CONTROL fifo), c<who>/client.log (its output) and logs/map.log (the map server's log,
for the server's last position of the player). The client must be a test build with walk.c
(tests/walk.c in xivlegacy-launcher). ZONE is the zone whose map to plan on (a city's zone
includes its field and the other way round, so a route may go out through a gate).
"""
import argparse
import json
import math
import os
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import nav  # noqa: E402

WALK = re.compile(r"\[walk\] (arrived|stuck|lost|stopped)(?::| at) ?(-?[\d.]+)? ?(-?[\d.]+)? ?(-?[\d.]+)?")
AT = re.compile(r"\[walk\] at (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)")
MARK = re.compile(r"stand-and-mark player position actor=\d+ x=(\S+) y=(\S+) z=(\S+)")
# an event that holds the player (a push trigger, talk, a notice scene); event_type 0 is a command
EVENT = re.compile(r"RunEventFunction .*? event=(\S+) .*?event_type=([1-9])")
LEARN_DAYS = 3  # stuck spots learned from walks are forgotten after this long (a mob, a door shut then)


class Rig:
    def __init__(self, root, who):
        self.root = Path(root)
        self.fifo = self.root / f"c{who}" / "xiv.fifo"
        self.log = self.root / f"c{who}" / "client.log"
        self.map = self.root / "logs" / "map.log"

    def send(self, line):
        with open(self.fifo, "w") as f:
            f.write(line + "\n")

    def size(self):
        return self.log.stat().st_size

    def since(self, off):
        with open(self.log, "rb") as f:
            f.seek(off)
            return f.read().decode("latin1", "replace")

    def map_size(self):
        return self.map.stat().st_size

    def map_since(self, off):
        with open(self.map, "rb") as f:
            f.seek(off)
            return f.read().decode("latin1", "replace")

    def server_pos(self):
        """the server's last position for the player (the hint for finding it in memory)"""
        with open(self.map, "rb") as f:
            f.seek(max(0, self.map.stat().st_size - 4_000_000))
            tail = f.read().decode("latin1", "replace")
        m = None
        for m in MARK.finditer(tail):
            pass
        return tuple(float(v) for v in m.groups()) if m else None

    def where(self, timeout=10):
        off = self.size()
        hint = self.server_pos()
        self.send("walkwhere" + (f" near {hint[0]:.2f} {hint[2]:.2f} {hint[1]:.2f}" if hint else ""))
        end = time.time() + timeout
        while time.time() < end:
            m = AT.search(self.since(off))
            if m:
                return tuple(float(v) for v in m.groups())
            time.sleep(0.2)
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("zone", type=int)
    ap.add_argument("x", type=float)
    ap.add_argument("z", type=float)
    ap.add_argument("--y", type=float, help="the goal's height when it has several floors")
    ap.add_argument("--near", type=float, default=1.5, help="arrived within this many yalms")
    ap.add_argument("--radius", type=float, default=0.6, help="the walker's radius for planning")
    ap.add_argument("--rig", default=os.environ.get("XIVNAV_RIG"), help="the rig folder (or $XIVNAV_RIG)")
    ap.add_argument("--who", default="A", help="which client of the rig (c<who>/)")
    ap.add_argument("--tries", type=int, default=8, help="plans before giving up")
    ap.add_argument("--client", help="1.23b install (default $XIV_CLIENT)")
    ap.add_argument("--via", type=float, nargs=2, action="append", default=[], metavar=("X", "Z"),
                    help="walk through this spot first (repeat for several)")
    ap.add_argument("--forget", action="store_true", help="drop the spots earlier walks got stuck at in this zone")
    a = ap.parse_args()
    if not a.rig:
        sys.exit("go.py: --rig DIR (or XIVNAV_RIG) is needed")
    rig = Rig(a.rig, a.who)
    world = nav.World(a.zone, a.client, a.radius)
    # spots earlier walks got stuck at (walls the collision data doesn't have): kept per zone in the cache
    learned_file = nav.CACHE / "learned" / f"{a.zone}.json"
    learned = [] if a.forget or not learned_file.exists() else json.loads(learned_file.read_text())
    now = time.time()
    # older files have no time stamp: count them as learned now
    learned = [s if len(s) > 3 else s + [now] for s in learned]
    learned = [s for s in learned if now - s[3] < LEARN_DAYS * 86400]
    for x, z, r, _ in learned:
        world.block(x, z, r)
    paths = nav.CACHE / "paths"
    paths.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    rig.send("key Escape")  # no chat line or menu in the way
    time.sleep(0.5)
    goals = [(x, None, z, 2.0) for x, z in a.via] + [(a.x, a.y, a.z, a.near)]
    plans = 0
    for gx, gy, gz, near in goals:
        why, n = walk_to(rig, world, (gx, gy, gz), near, a.tries, learned, learned_file, paths, plans)
        plans += n
        if why:
            break
    pos = rig.where() or (float("nan"),) * 3
    d = math.hypot(pos[0] - a.x, pos[2] - a.z)
    took = time.time() - t0
    if why and why.startswith("event"):
        print(f"{why} at {pos[0]:.1f} {pos[1]:.1f} {pos[2]:.1f}, {d:.1f} from the goal, after {took:.0f} s and {plans} plan(s)")
        return 3
    if d <= a.near + 0.5:
        print(f"arrived at {pos[0]:.1f} {pos[1]:.1f} {pos[2]:.1f} ({d:.1f} from the goal) in {took:.0f} s, {plans} plan(s)")
        return 0
    print(f"stopped at {pos[0]:.1f} {pos[1]:.1f} {pos[2]:.1f}, {d:.1f} from the goal, after {took:.0f} s and {plans} plan(s)"
          + (f": {why}" if why else ""))
    return 1


def walk_to(rig, world, goal, near, tries, learned, learned_file, paths, plans):
    """plan and walk to goal (x, y or None, z) within `near`, planning again where a walk sticks;
    (None, plans made) when there, else (why it stopped, plans made)"""
    for attempt in range(1, tries + 1):
        pos = rig.where()
        if pos is None:
            return "the client can't find the player (logged in? a walk.c build?)", attempt - 1
        if math.hypot(pos[0] - goal[0], pos[2] - goal[2]) <= near:
            return None, attempt - 1
        n = plans + attempt
        tp = time.time()
        walled = None
        try:
            pts = world.plan(pos, goal, near)
        except nav.NoPath as e:
            if not e.walled or not e.partial or e.gap is None:
                return str(e), attempt - 1
            # the goal stands on ground cut off from here (a fenced bank, a ledge): walk to the
            # closest spot that can be reached and say so
            cx, cy, cz = e.partial[-1]
            if math.hypot(pos[0] - cx, pos[2] - cz) < 1.0:
                return (f"the goal is cut off from here (a wall, fence or ledge in the collision); "
                        f"this is the closest spot, {e.gap:.1f} yalms from it"), attempt - 1
            try:
                pts = world.plan(pos, (cx, cy, cz), 1.0)
            except (nav.NoPath, RuntimeError) as e2:
                return str(e2), attempt - 1
            walled = e.gap
        except RuntimeError as e:
            return str(e), attempt - 1
        pts[0] = pos
        if nav.length(pts) < 1.0:
            return None, attempt - 1  # already as close as the map allows (the goal spot itself is blocked)
        file = paths / f"go-{os.getpid()}-{n}.txt"
        file.write_text("".join(f"{x:.2f} {y:.2f} {z:.2f}\n" for x, y, z in pts))
        marks = ", ".join(f"{m['name']}" for m in world.marks(pts))
        print(f"plan {n}: {len(pts)} points, {nav.length(pts):.0f} yalms to {goal[0]:.1f} {goal[2]:.1f} in "
              f"{time.time() - tp:.1f} s" + (f" (passes {marks})" if marks else ""), flush=True)
        off = rig.size()
        moff = rig.map_size()
        rig.send(f"walkpath {file} {min(near, 1.0)}")
        limit = time.time() + 60 + nav.length(pts) / 3.0
        result = None
        while time.time() < limit:
            time.sleep(0.5)
            m = WALK.search(rig.since(off))
            if m:
                result = m
                break
        if result is None:
            rig.send("walkstop")
            time.sleep(1)
            print(f"plan {n}: no word from the walker in time; stopped it", flush=True)
            continue
        kind = result.group(1)
        ev = EVENT.search(rig.map_since(moff))
        if ev:
            # a trigger or scene holds the character: not an obstacle, so nothing is learned
            rig.send("walkstop")
            return f"event {ev.group(1)} (a quest trigger or cutscene) took over", attempt
        if walled is not None and kind == "arrived":
            return (f"the goal is cut off from here (a wall, fence or ledge in the collision); "
                    f"walked to the closest spot, {walled:.1f} yalms from it"), attempt
        if kind == "arrived":
            continue  # the top of the loop checks the goal itself
        if kind == "lost":
            return "the client lost the player (a zone change that didn't come back?)", attempt
        # stuck or stopped: keep the next plan away from where it stuck, plan again
        if result.group(2):
            sx, sz = float(result.group(2)), float(result.group(4))
            # block the spot just ahead of where it stuck (the obstacle), not under its feet
            best = min(range(len(pts)), key=lambda i: math.hypot(pts[i][0] - sx, pts[i][2] - sz))
            ahead = pts[min(best + 1, len(pts) - 1)]
            dx, dz = ahead[0] - sx, ahead[2] - sz
            d = math.hypot(dx, dz) or 1.0
            # stuck near the same place again: the obstacle is bigger than the last circle
            again = sum(1 for x, z, r, _ in learned if math.hypot(x - sx, z - sz) <= r + 2.5)
            spot = [round(sx + dx / d * 1.5, 2), round(sz + dz / d * 1.5, 2), min(1.0 + again, 3.0), round(time.time())]
            world.block(*spot[:3])
            learned.append(spot)
            learned_file.parent.mkdir(parents=True, exist_ok=True)
            learned_file.write_text(json.dumps(learned))
            print(f"plan {n}: {kind} at {sx:.1f} {sz:.1f}; planning around it", flush=True)
    pos = rig.where()
    if pos and math.hypot(pos[0] - goal[0], pos[2] - goal[2]) <= near:
        return None, tries
    return f"no way through after {tries} plans", tries

if __name__ == "__main__":
    sys.exit(main())
