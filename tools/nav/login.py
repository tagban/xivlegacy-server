#!/usr/bin/env python3
"""Log a test client in: title -> "A Word to Our Players" (Yes) -> character list -> the world.

    login.py [--rig DIR] [--who A] [--timeout 180]

For any XIVLegacy test rig (c<who>/xiv.fifo, c<who>/client.log, logs/map.log; see go.py), with the
client started and on its way to (or at) the title screen. Prints "logged in" (exit 0) or where it
got stuck (exit 1).

The notice box before the lobby has Yes and No with No focused; Left moves to Yes. The box only
opens after the title screen's Return, so Left must come after that Return: a Left sent at the title
does nothing and the next Return answers No. Each step is checked in the logs before the next:
the title menu's form in the client log, the lobby connection (only made after Yes), and the map
server's zone-in.
"""
import argparse
import os
import re
import sys
import time
from pathlib import Path

TITLE = "BootupMenu.en.form"
LOBBY = re.compile(r"ws2: lobby\S* -> ")
ZONE_IN = "zone-in-complete"


class Rig:
    def __init__(self, root, who):
        self.root = Path(root)
        self.fifo = self.root / f"c{who}" / "xiv.fifo"
        self.log = self.root / f"c{who}" / "client.log"
        self.map = self.root / "logs" / "map.log"

    def key(self, name, wait):
        with open(self.fifo, "w") as f:
            f.write(f"key {name}\n")
        time.sleep(wait)

    def text(self, path):
        try:
            return path.read_bytes().decode("latin1", "replace")
        except OSError:
            return ""


def wait_for(test, timeout, step=1.0):
    end = time.time() + timeout
    while time.time() < end:
        if test():
            return True
        time.sleep(step)
    return test()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rig", default=os.environ.get("XIVNAV_RIG"), help="the rig folder (or $XIVNAV_RIG)")
    ap.add_argument("--who", default="A", help="which client of the rig (c<who>/)")
    ap.add_argument("--timeout", type=float, default=180, help="seconds to wait for the title screen")
    a = ap.parse_args()
    if not a.rig:
        sys.exit("login.py: --rig DIR (or XIVNAV_RIG) is needed")
    rig = Rig(a.rig, a.who)
    if not rig.fifo.exists():
        sys.exit(f"login.py: no control fifo at {rig.fifo}")
    zone_ins = rig.text(rig.map).count(ZONE_IN)

    # 1. the title screen: its menu form is read when it opens; give it a moment to take keys
    if not wait_for(lambda: TITLE in rig.text(rig.log), a.timeout, 2.0):
        print(f"login failed: no title screen after {a.timeout:.0f} s (is the client running?)")
        return 1
    time.sleep(8)

    # 2. leave the title, then Yes in the notice box; the lobby connection proves it was Yes
    for attempt in range(3):
        lobby = len(LOBBY.findall(rig.text(rig.log)))
        rig.key("Return", 6)  # title -> the notice box
        rig.key("Left", 1)  # No -> Yes
        rig.key("Return", 2)
        if wait_for(lambda: len(LOBBY.findall(rig.text(rig.log))) > lobby, 15):
            break
        if rig.text(rig.map).count(ZONE_IN) > zone_ins:
            print("logged in")
            return 0
    else:
        print("login failed: the game never reached the lobby (the notice box answered No, or the lobby "
              "server isn't up)")
        return 1

    # 3. the character list: Return picks the first character, Return again confirms
    time.sleep(8)
    for attempt in range(4):
        rig.key("Return", 3)
        rig.key("Return", 2)
        if wait_for(lambda: rig.text(rig.map).count(ZONE_IN) > zone_ins, 45):
            time.sleep(5)
            print("logged in")
            return 0
    print("login failed: reached the lobby but never zoned in (if the character was placed by database, "
          "set destinationZoneId as well as currentZoneId)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
