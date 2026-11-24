# tools/nav: walk a test character to a spot

Three pieces:

- `nav.py` plans a route over the 1.23b client's own collision (read from your install at run time by
  `../terrain/xivterrain.py`; nothing from the game is stored in this repository, only offsets and
  spots we measured ourselves).
- The test client (xivlegacy-launcher, `tests/walk.c`) follows the route: `walkpath FILE` on its
  `XIVLEGACY_CONTROL` fifo. It steers by the player's own position and facing, read from memory
  every 20 ms, with the keyboard only (W to run, J/L to turn the camera).
- `go.py` plans, sends the route to the client, watches the client log and plans again from where a
  walk gets stuck. It prints `arrived ...` or why it stopped.

```bash
export XIV_CLIENT="/path/to/FINAL FANTASY XIV 1.23b"   # the install nav.py reads collision from
export XIVNAV_RIG=/path/to/rig                          # c<who>/xiv.fifo, c<who>/client.log, logs/map.log
python3 tools/nav/go.py 209 -86 322 --near 2            # Ul'dah: Gold Court -> Amajina & Sons
python3 tools/nav/go.py 170 34.8 -480.5 --near 3 --via -52.5 -12   # out through the Gate of Nald
```

`ZONE` is the map to plan on. A city's map includes its field and the other way round, so a route can
leave through a gate: plan a walk out of Ul'dah on 170 (Central Thanalan). `--via X Z` (repeatable)
walks through a spot first (no longer needed for long routes: the planner finds the gate itself).
`--y` picks the floor when the goal has several. The first plan in a zone builds its grid tiles
(20-30 s), and the first long route there its tile pieces too (minutes for a whole field, once);
later plans take a few seconds.

`nav.py plan ZONE SX SY SZ TX TZ` prints waypoints without walking; `nav.py floor ZONE X Z` lists the
walkable heights at a spot.

## The rig

Any XIVLegacy test rig works: a client started with `XIVLEGACY_CONTROL=<rig>/c<who>/xiv.fifo` and
its output in `<rig>/c<who>/client.log`, and the map server's log in `<rig>/logs/map.log` (go.py
takes the server's last "stand-and-mark" position as a hint for finding the player in memory).
Keep test clients silent (`XIVLEGACY_NOAUDIO=1`).

To log a client in (title, the "A Word to Our Players" box, the first character, the world), with
each step checked in the logs: `python3 tools/nav/login.py --rig RIG [--who A]`. The box focuses No;
Left only moves to Yes once the title's Return has opened it, which is the trap a blind key list falls
into.

To put the character somewhere, log out, set the database row and log in:
`currentZoneId`, `destinationZoneId` (both: the client loads the map of the destination zone; a
stale one gives you a black void with the wrong map), `positionX/Y/Z`. Don't walk right after a GM
`!warp`: the camera can come loose from the player, and W then runs one fixed way whatever J and L do.

## Offsets (zones.json)

server position = layout position + offset. Each city's town and interior layouts share one offset;
field layouts are already in server coordinates. Cities were fitted against positions our test
characters actually walked (map-server logs): with the offset applied, 94% (Ul'dah, Limsa) and 98%
(Gridania) of walked spots stand on a floor within a yalm. `fit_offsets.py` redoes the check (or the
fit) against a zone's spawns or a points file. Each layout's `checked` line says how it was checked;
field layouts no route has walked yet are marked "assumed".

## What the collision as read is missing, and the fixes

`xivterrain.Layout.collision()` reads the floor and wall triangles of the layout's own parts. Some
things a player can't walk through are not in it (market counters and stalls in Ul'dah, door frames),
and some walkways are missing (Limsa's Procession of Terns). So:

- `walked.txt`: floors where our characters stood but the layouts have none (dense trails only, from
  our own logs; Limsa and Lower La Noscea only: in Ul'dah, trails along walls opened false ways).
  Right where a character stood, walls don't block.
- `zones.json` `closed`: spots walks always stuck at (Ul'dah market counters); `doors`: gates that
  are open in game (the Gate of Nald: the town copy is opened by its DoorServer, see
  map-server/src/town_gates.rs).
- go.py remembers where walks stuck, per zone, in `$XIVNAV_CACHE/learned/<zone>.json`, and plans
  around those spots next time (a spot hit again grows from 1 to 3 yalms). They are forgotten after
  3 days, a plan never treats the spot it starts from or its goal as blocked, and `--forget` starts
  over. A stop caused by a quest event (a push trigger, a cutscene) is never learned: go.py sees the
  event in the map server's log, ends the walk and exits with status 3.
- A goal on ground cut off from the start (Gridania has banks with an invisible fence at their foot,
  so the grassy top is out of reach in the game too): go.py walks to the closest spot it can reach
  and says how far that is from the goal.
  Spots that hold up are worth moving into `closed`.
- Public NPCs (server spawn rows) block a small circle each; players can't walk through them.

## Cache

`$XIVNAV_CACHE` (default `~/.cache/xivlegacy/nav`): grid tiles per zone and settings hash, planned
paths, learned spots. Safe to delete. Tiles depend on the zone table, `walked.txt`, the NPC rows
and `VERSION` in nav.py (bump it when the grid rules change).
