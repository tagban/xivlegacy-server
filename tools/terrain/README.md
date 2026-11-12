# Terrain heights from the 1.23b client

`xivterrain.py` answers "how high is the ground at (zone, x, z)?" from the collision meshes in
the user's own FFXIV 1.23b install, read at run time. No Square Enix files or bytes are stored
in this repository; only derived numbers (such as `tools/world_spawns/data/ground_heights.csv`)
are committed.

The install is found from `--client`, then `$XIV_CLIENT`. The first run scans the install for
layout files (about 40 s) and caches the list of area names and DAT paths in
`~/.cache/xivlegacy/terrain_layouts.json`. Pure Python, no packages; one field zone takes
about 100 MB of memory and a fraction of a second per query.

```sh
python3 tools/terrain/xivterrain.py query 128 151.635 59.928      # floors + ground_y
python3 tools/terrain/xivterrain.py query 128 151.635 59.928 45  # floor nearest y=45
python3 tools/terrain/xivterrain.py zones                         # server zone -> layout file
python3 tools/terrain/xivterrain.py batch in.csv out.csv          # zoneId,x,z[,near_y]
python3 tools/terrain/validate.py --probe <old probe results.csv>
python3 tools/terrain/spawn_heights.py planned.csv                # see world_spawns README
python3 tools/terrain/height_update.py                            # seed 292 from the 101 diff
```

```python
from xivterrain import Terrain
t = Terrain("/path/to/FINAL FANTASY XIV 1.23b")
t.ground_y(128, 151.6, 59.9)             # highest floor, None off the ground
t.ground_y(128, 151.6, 59.9, near_y=45)  # the floor nearest a height (bridges, caves)
t.floors(128, 151.6, 59.9)               # all floors, low to high
```

Floors are up-facing collision triangles. Tops of primitive colliders (tree trunks, crates,
posts) are left out unless `props=True`. Below the real ground there is often a second floor:
the sea-level plane at y=0 in La Noscea, or a lower cliff layer.

**Scope:** field zones (`*Field*`, 19 zones plus 190/236/257/264). Towns and dungeons have
layouts too, but the server's town and dungeon coordinates do not line up with them (NPC
positions miss by tens of yalms), so their answers should not be trusted yet.

**Dungeons** line up after one constant offset each (server = layout + offset), found by
sliding the dungeon's monster spawns over the layout's floor until every one lands on it:

| Zone | Layout | Offset x, y, z | Spawns on floor |
| --- | --- | --- | --- |
| 159 Toto-Rak | `fst_f0_dun03` | 1216.5, -40.0, 737.0 | 138 / 138 |
| 231 Dzemael Darkhold | `roc_r0_dun01` | -12.0, 187.7, 34.0 | 140 / 140 |
| 245 Aurum Vale | `roc_r0_dun04` | -938.5, 195.5, 1377.5 | 91 / 91 |
| 246 Cutter's Cry | `wil_w0_dun05` | -1213.0, 251.4, -1627.5 | 87 / 87 |
| 235 Shposhae | `sea_s0_dun04` | 256.0, 20.3, 288.0 | see below |

Shposhae had no monsters to slide, so its x and z come from fitting the layout's floor over
its five client floor maps (map ids 1091-1099, map sheet area 114). Its y comes from the
Lower La Noscea cave that the dungeon's first passage overlaps. In the client, four points on
different floors landed within 0.3 yalm of the layout floor.

The y offset is the median (multi-level dungeons spread a few yalms). This is how Toto-Rak's
three boss chambers were found: round rooms by the chamber doors with no monsters in them.

## Validation

`validate.py` compares the floor nearest each known height:

| Known heights | Points | Result |
| --- | --- | --- |
| Client-measured ground, zone 128 (old probe, `status=ok`) | 12 | all within 0.13 (median 0.08) |
| Logged player positions, zone 128 | 99 | all within 0.31 (median 0.02) |
| Logged player positions, zone 150 | 93 | 56 within 0.5; 31 have no floor and 5 miss by 40+ (a path near Gridania that no field layout covers) |
| Retail capture spawns in seed 101 (zones 145-172) | 139 | all within 1.4; Black Shroud monsters ride about 0.85 above the floor |
| NPC spawn positions (`031_server_spawn_locations`), field zones | 140 | 118 within 1, 138 within 3 |

## File formats

All files are `data/XX/YY/ZZ/WW.DAT`; a file's id is `0xXXYYZZWW`.

### MapLayout (one per area)

```
0x00  "MapLayoutResourceData" ... "1.1.0"
0x24  u32 N resources
0x60  N x 32 bytes: char[16] key ("1kWWics0f0_ca_h": 6-char hash + name), char[4] type
      reversed ("bhp" = phb collision, "brt" = trb model), u32 DAT id, u32 flags
```

Then a `SEDBlyb` container (0x30-byte SEDB header, `lyb\0`, u32 size), a serialized object
graph whose pointers are byte offsets from the `lyb\0` tag. The area's name is the string after
`Root Folder\0` (`sea_s0_fld01`); the server's `sea0Field01` maps to it by rule.

- Class records, 5 words: `id, 0, name, 0, parent` (`RefObjects/InstanceObject`, ...).
- Objects start `id, class`.
- `InstanceObject`: word 8-10 world position, 11 -> rotation (x, y, z radians), 12 -> scale,
  15 -> base object.
- `UnitTreeObject` (prefab): word 12 -> members, 13 count; member (0x30 bytes): 0-2 local
  position, 3 -> rotation, 4 -> scale, 6 -> base object.
- `AttributeBaseObject`: word 9 -> resource key; the collision objects.
- `BGPartsBaseObject` / `BGChipBaseObject`: word 8 -> key; a few keys have a phb too.

World matrix = instance (T * Rz * Ry * Rx * S) x member (same). Positions are server world
coordinates.

### PHB (collision mesh)

```
"PHB.GBD" block at 0xC0, then u32: size, 0x212, n, o1, l1, o2, l2, o3, l3, o_cells, l_cells,
  n_cells, o_verts, n_verts (offsets from the GBD tag); AABB min/max (f32 x4) at +0x40/+0x50
vertices   n_verts x f32[3] at o_verts
triangles  u16 a, b, c, attr; n_tri of them end where the vertices start (padded to 0x80)
cells      "PHB.TBC" + "PHB.TBD" BVH per cell; TBD +0x14 count, +0x18 offset of a u16 list
           of triangle ids. n_tri = largest id + 1
```
