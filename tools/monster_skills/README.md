# Monster skills data

Builds the monster move data from what survives of 1.0:

1. `scan_zam.py`: monster move names from the 1.23b client command sheet
   (ids 23011-23645, via the reference-site cache) and which ZAM monster
   pages mention each one.
2. `fetch_modern.py`: the modern (ARR and later) Action with the same name
   from XIVAPI, for shape, radius, range, cast and recast where 1.0 data
   is missing (~1 request a second).
3. `genus.tsv`: `SELECT genusId, name, kindredName FROM server_battlenpc_genus`.
4. `python3 gen.py <repo>`: writes `server_battlenpc_skill_info`,
   `server_battlenpc_skill_list` (one list per family, skillListId =
   genusId), the monster rows of `server_battle_commands` and the pools'
   `skillListId`.

Family blocks live in `FAMILIES` in gen.py with their evidence:
`zam` (a ZAM page shows the family using the move), `block` (same id block
as a ZAM-confirmed move), `name` (inferred from the names / modern owner).
Animations are a guess to be checked in the client: animation type 19 with
the move's slot in its family as the model animation, the same encoding the
Chimera rows (23456-23464) use.
