# Monster skills data

Builds the monster move data from what survives of 1.0. Run everything from
one data directory; the inputs below are written there.

1. `scan_zam.py`: monster move names from the 1.23b client command sheet
   (ids 23011-23645, via the reference-site cache) and which ZAM monster
   pages mention each one (`zam_hits.json`; carries ZAM page text, don't
   commit it).
2. `fetch_modern.py`: the modern (ARR and later) Action with the same name
   from XIVAPI, for shape, radius, range, cast and recast where 1.0 data
   is missing (`modern.json`, ~1 request a second).
3. `fetch_ge.py <info.sql> ge3.json <pagedir>`: the archived (2012-13,
   Wayback Machine) Gamer Escape page for each move name. A 1.0 page names
   the move's family ("Family: Basilisk", category "Basilisk Actions"); a
   page archived after ARR's launch names the modern family instead. Then
   reduce it to `ge_family.json` (move name -> family).
4. `fetch_cgw.py <info.sql> cgw.json <pagedir>`: modern users of each move
   and their levels from consolegameswiki "Locations" tables (few monster
   moves have pages; used for level gates where found).
5. `genus.tsv`: `SELECT genusId, name, kindredName FROM server_battlenpc_genus`.
6. `python3 gen.py <repo>`: writes `server_battlenpc_skill_info`,
   `server_battlenpc_skill_list`, the monster rows of
   `server_battle_commands` and the pools' `skillListId`.

## Kinds and lists

`KINDS` in gen.py lists each monster kind: one model family, so its moves
share animation slots. A kind is not always a genus: yarzons sit under the
rodent genus, porcupines (snurbles) under moles, and many humanoids under
wolves. List id = the genus id where the kind is a genus, 101+ for kinds
with no genus (Snurble, Elemental, Golem, Moogle, Treant...), and the pool
id for a named boss's own list (Ifrit 30100, Garuda 30109, Nael 30115).
A pool takes a named boss's list first, then a kind whose name pattern
matches it, then a class move list, then a kind that covers its genus.

Human and beastman enemies: `JOB_LISTS` holds the client's monster copies
of player class actions (pugilist 122, marauder 123, lancer 124), matched
by the pool's `currentJob` or name, for pools with no kind list.
`SPELL_LISTS` holds the "II" tier spells of the monster spell block
(thaumaturge 120, conjurer 121); they go in the pool's `spellListId`
(same table), so a caster keeps its kind's moves too.
The client has no monster copies of gladiator or archer actions, so
`PLAYER_WS_LISTS` gives those enemies the player weaponskills of the class
(enemy-targeted weaponskill rows; gladiator 125, archer 126) at their 1.0
learn level, evidence `class`.

Enemies left with no class and no kind list (bandits, assassins) take the
class of the weapon their model holds: `WEAPON_LISTS` / `WEAPON_SPELLS`
map the appearance's main-hand weapon family (`mainHand >> 20`) to a class
list, matched against pools whose class is known (56 hand-to-hand, 76/77
sword, 141 axe, 161 spear, 201 bow, 296/331 scepter, 316 staff).

Evidence per move: `zam` (a ZAM page shows that family using it), `ge` (an
archived 1.0 Gamer Escape page names the family), `modern` (only an
ARR-era page does), `block` (same client id block as such a move), `name`
(inferred from the names), empty (not placed yet: mostly humanoid job
moves, enemy spells, and one-off NM moves).

## Levels

Each list entry has `minLevel`; a monster below it can't use the move.
No 1.0 level data survives, so:
- `modern`: lowest level of an open-world ARR monster using the move;
- `spawn`: the kind's moves in client order, spread from its lowest spawn
  level here up to at most 40 levels higher (an estimate);
- `class`: class move and spell lists: the 1.0 learn level of the same
  action (1.23b player row, else an archived 1.0 page's "Level Learned");
  a "II" spell takes its base spell's level;
- `boss`: a named boss's own list, every move at level 1;
- empty: no pool uses the list yet (level 1).

## Knockback

`KNOCKBACK` in gen.py lists the moves whose archived 1.0 Gamer Escape page
says they knock back (Drop Kick, Tender Thrust, Dream Bubble, Bone
Breaker, Iron Chariot, Vulcan Burst), with a guessed strength 1-5 written
to `server_battlenpc_skill_info.knockback`. A landed hit adds the client's
knockback hit-effect bits for that level, unless the target has the
KnockbackImmune modifier.

Animations are a guess to be checked in the client: animation type 19 with
the move's slot in its block as the model animation, the same encoding the
Chimera rows (23456-23464) use.
