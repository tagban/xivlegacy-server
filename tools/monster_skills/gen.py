"""Generate the monster skill data files for xivlegacy-server.

Inputs: client move sheet (ZAM cache sheets.json, sheet 16), ZAM mob-page
sightings (zam_hits.json), modern Action data (modern.json from XIVAPI).
Outputs (into the repo): server_battle_commands rows for 1.0 monster moves,
server_battlenpc_skill_info (one row per move: family, evidence, modern
match), server_battlenpc_skill_list (family lists), pools skillListId.
"""
import json, re, sys, collections

REPO = sys.argv[1]
C = '/Volumes/AppStorage/xivlegacy-reference-cache/'
sheet = json.load(open(C + 'sheets.json'))[16]['rows']
modern = json.load(open('modern.json'))
zam = json.load(open('zam_hits.json'))

GENUS = {}
for l in open('genus.tsv'):
    g, n, k = l.rstrip('\n').split('\t')
    GENUS[int(g)] = n

# (first id, last id, genusId, evidence, ZAM anchor pages)
# evidence: zam = a ZAM page shows this family using a move in the block;
# name = family inferred from the move names / their modern owners.
FAMILIES = [
    (23013, 23020, 42, 'zam', [2102001, 2202003]),          # Dodo: Regurgitate, Rancid Belch, Fowl Stench
    (23028, 23031, 32, 'zam', [2100203]),                   # Raptor: Foul Breath, Ripper Fang, Scythe Tail
    (23032, 23036, 64, 'zam', [2101605, 2101602]),          # Bomb: Fireball, Self-destruct, Combustion, Fast Burn
    (23047, 23049, 43, 'name', [2204102, 2104101]),         # Bat: Guano Lob, Ultrasonics, Blood Drain
    (23050, 23051, 36, 'zam', [2105603]),                   # Chigoe: Digestive Ooze, Mortal Mist
    (23052, 23056, 11, 'zam', [2105703]),                   # Mole: Gravel Burst, Breakout, Spinout
    (23057, 23059, 45, 'zam', [2100101, 2100109]),          # Puk: Cliff Cry, Backflip, Tail Chase
    (23060, 23062, 17, 'zam', [2104501, 2104506]),          # Orobon: Brine Blast, Rage of the Deep, Feeding Frenzy
    (23073, 23075, 4, 'zam', [2100502, 2200405]),           # Opo-opo: Reaching Scratch, Drop Kick, Deep Scratch
    (23084, 23085, 38, 'zam', [2103901, 2103902, 2103904]), # Beetle: Bombardier, Spoil
    (23086, 23089, 15, 'zam', [2102705]),                   # Flying-trap: Seedvolley, Germinate, Seedspray, Sough
    (23090, 23093, 1, 'zam', [2102301, 2102303, 2102305]),  # Aldgoat: Bleat, Head Butt, Alpine Fury, Seismic Scream
    (23098, 23100, 21, 'zam', [2104201]),                   # Slug: Aqueous/Viscous/Mucous Discharge
    (23101, 23104, 32, 'zam', [2100205]),                   # Raptor: Tail Strike, Frenzied Claw, Forward Kick, Squawk
    (23105, 23106, 31, 'name', []),                         # Basilisk: Basilisk Breath, Stomp
    (23113, 23114, 49, 'zam', [2102101, 2102109]),          # Coblyn: Mine Dust, Cluster Geyser
    (23115, 23118, 52, 'zam', [2202601, 2202603]),          # Imp: Sphere of Cold, Impish Incantations
    (23132, 23135, 22, 'zam', [2107614]),                   # Megalo-crab: Brackish Bubble, Claw Guard, Bubble Shower, Backclip
    (23138, 23140, 12, 'zam', [2105501]),                   # Rodent: Piercing Din, Corrosive Spit, Brain Spike
    (23141, 23145, 3, 'zam', [2101401, 2101321]),           # Wolf: Vertical Lash, Midnight Howl, Threatening Growl, Foul Bite, Sanguine Bite
    (23146, 23150, 13, 'zam', [2100910, 2100901]),          # Cactuar: Needleshot, 1000 Needles, Tender Thrust, Sun Spines, Desert Respite
    (23154, 23157, 9, 'name', []),                          # Boar: Snort, Reckless Charge, Bristle, Bellowing Grunt
    (23158, 23159, 19, 'zam', [2101317]),                   # Salamander: Circlespark, Thundervapor
    (23207, 23209, 40, 'zam', [2102901]),                   # Apkallu: Flying Sardine, Yawn, Flying Marlin
    (23226, 23229, 33, 'name', []),                         # Ant-ring: Trap Jaws, Stridulation, Mandible Bite, Formic Pheromones
    (23238, 23240, 7, 'zam', [2106011]),                    # Sheep: Wooly Spindle, Lullaby, Dream Bubble
    (23250, 23256, 14, 'zam', [2105901, 2105903, 2105915]), # Funguar: Slumber Spores/Cloud, Queasy Spores, Hypha Whip, Queasy Cloud
    (23258, 23261, 53, 'zam', [2105801, 2105803]),          # Will-O-Wisp: Stellar Flame, Blinding Burst, Innernova, Hypernova
    (23262, 23269, 18, 'name', []),                         # Gigantoad: Sticky Tongue, Ranine Stare/Glare, Slimy Secretion, Livid Lap, Gut Press
    (23281, 23286, 16, 'zam', [2101001]),                   # Morbol: Sour Breath, Vine Probe, Sweeping Lash, Tendril Tremor, Bad/Sweet Breath
    (23311, 23315, 26, 'name', [2110301]),                  # Goblin: Bomb Toss, Hail Mary, Firecracker Shower
    (23318, 23324, 25, 'name', []),                         # Qiqirn: Charged Whisker, Blaster, Chaotic Eye, Whisker Charge
]

STATUS = [  # (word in the move name, status id) for moves whose effect the name gives away
    ('Slumber', 228001), ('Lullaby', 228001), ('Dream Bubble', 228001), ('Yawn', 228001),
    ('Silencing', 223006), ('Blinding', 223007), ('Petrify', 223004), ('Stone Gaze', 223004),
    ('Queasy', 223011), ('Poison', 223011), ('Numbing', 223005), ('Binding', 228011),
    ('Sticky Web', 228011), ('Stun', 223015),
]

def blank(n):
    return not n or n.strip() in ('', '-', 'Attack', 'Ranged Attack', 'explosion')

def snake(n):
    return re.sub(r'[^a-z0-9]+', '_', n.lower()).strip('_')

def modern_match(name):
    rows = modern.get(name)
    if not isinstance(rows, list):
        return None
    rows = [r for r in rows if r.get('Name', '').lower() == name.lower() and not r.get('IsPlayerAction')]
    return rows[0] if rows else None

ASPECT = {1: 5, 2: 6, 3: 7, 4: 8, 5: 9, 6: 10}  # modern Aspect -> ActionProperty
PHYS = {'Slashing': 1, 'Piercing': 2, 'Blunt': 3, 'Shot': 4}

fam_of = {}
for a, b, g, ev, anchors in FAMILIES:
    slot = 0
    for i in range(a, b + 1):
        n = sheet.get(str(i), [''])[0]
        if blank(n):
            continue
        slot += 1
        fam_of[i] = (g, ev, anchors, slot)

existing = set(range(23456, 23465))  # Chimera rows already in the commands data
cmd_rows, info_rows, list_rows = [], [], []
HITBOX = 3.0  # rough monster radius, yalms
stats = collections.Counter()
for k in sorted(sheet, key=int):
    i = int(k)
    n = sheet[k][0].strip()
    if blank(n):
        continue
    m = modern_match(n)
    g, ev, anchors, slot = fam_of.get(i, (0, '', [], 0))
    # ZAM sighting of this exact move on one of the family's anchor pages
    seen = [a for a in anchors if n in zam.get(str(a), {})]
    evidence = 'zam' if seen else ('block' if ev == 'zam' else ev)
    notes = []
    if seen:
        notes.append('ZAM mob ' + ','.join(map(str, seen)))
    # shape and timing: modern data when found, else a single-target melee move
    aoe_type, aoe_range, cone, rng, cast, recast = 0, 0.0, 0.0, 5.0, 0, 10
    centered = False  # True: the AoE is drawn around the caster
    action_type, prop = 1, 3
    if m:
        ct, er = m.get('CastType', 1), float(m.get('EffectRange') or 0)
        if ct in (2, 5, 7):
            aoe_type, aoe_range = 1, er
            centered = not m.get('Range')
        elif ct == 3:
            aoe_type, aoe_range, cone, centered = 2, er, 0.5, True
        elif ct == 4:
            aoe_type, aoe_range, centered = 3, er, True
        if m.get('Range'):
            # modern reach starts at the hitbox edge; keep at least melee reach
            rng = max(5.0, float(m['Range']))
        if centered and aoe_range:
            # modern AoE radii start at the caster's hitbox edge too; the 1.0
            # server measures from the monster's center, so add its size
            aoe_range += HITBOX
        cast = int(m.get('Cast100ms') or 0) * 100
        recast = max(1, int(m.get('Recast100ms') or 100) // 10)
        at = (m.get('AttackType') or {}).get('fields', {}).get('Name', '')
        asp = m.get('Aspect', 0)
        if at in PHYS:
            action_type, prop = 1, PHYS[at]
        elif asp in ASPECT:
            action_type, prop = 2, ASPECT[asp]
        elif at == 'Magic':
            action_type, prop = 2, 0
        notes.append(f'modern Action {m["row_id"]}')
        stats['modern'] += 1
    status = next((s for w, s in STATUS if w.lower() in n.lower()), 0)
    if status:
        notes.append('status from the move name')
    if i not in existing:
        anim = (19 << 24) | (slot << 12)
        is_ranged = 1 if rng > 5 else 0
        # Caster-centered moves aim at the monster itself, like the
        # Chimera rows (mainTarget 31, aoeTarget self); the rest aim at its
        # enemy, like player weaponskills (mainTarget 768, aoeTarget target).
        main_target = 31 if centered else 768
        cmd_rows.append((i, snake(n), 0, 1, 0, main_target, 17152, aoe_type, aoe_range, 0.0, cone, 0.0, 1 if centered else 0,
                         100, 1, 0, 0, rng, 0, 0, 10, 2, status, 15 if status else 0, 1.0 if status else 0.0,
                         11 if cast else 0, cast, recast, 0, 0, 19, 0, slot, 3, anim, 0, 0, 0, 3, 0.0, 30301,
                         2, action_type, prop, is_ranged, 0, -1, 0.0, -1, 0.0, 0.0))
    info_rows.append((i, n, g, evidence, slot, m['row_id'] if m else 0, '; '.join(notes)))
    if g:
        list_rows.append((g, i, evidence))
        stats['listed'] += 1
    stats['moves'] += 1

def lit(v):
    if isinstance(v, str):
        return "'" + v.replace("'", "''") + "'"
    if isinstance(v, float):
        return repr(v)
    return str(v)

MODE = "SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';\n"

def table_file(name, cols, rows, note):
    out = [f'-- {name}: game data, {len(rows)} rows. Reloaded whole when this file changes.\n', f'-- {note}\n', MODE,
           f'DELETE FROM `{name}`;\n']
    if rows:
        out.append(f'INSERT INTO `{name}` (' + ', '.join(f'`{c}`' for c in cols) + ') VALUES\n')
        out.append(',\n'.join('(' + ', '.join(lit(v) for v in r) + ')' for r in rows) + ';\n')
    return ''.join(out)

open(f'{REPO}/common/sql/data/server_battlenpc_skill_info.sql', 'w').write(table_file(
    'server_battlenpc_skill_info',
    ['skillId', 'displayName', 'genusId', 'evidence', 'slot', 'modernActionId', 'notes'], info_rows,
    'Monster moves (1.23b command sheet 23011-23645): family, evidence (zam / block / name / empty = unassigned), modern match. Built by tools/monster_skills.'))
open(f'{REPO}/common/sql/data/server_battlenpc_skill_list.sql', 'w').write(table_file(
    'server_battlenpc_skill_list', ['skillListId', 'skillId', 'evidence'], list_rows,
    'One list per monster family: skillListId = genusId.'))

# commands: append monster rows after the existing data, keeping the file's own rows
cpath = f'{REPO}/common/sql/data/server_battle_commands.sql'
src = open(cpath).read()
src = re.sub(r'\n-- monster moves \(generated.*', '', src, flags=re.S)
header = src.split('\n')[3]  # the INSERT column list line
assert header.startswith('INSERT INTO `server_battle_commands`'), header
src = src.rstrip() + '\n'
src += '\n-- monster moves (generated by tools/monster_skills; 1.0 names, shape/timing from modern data where found)\n'
src += header + '\n' + ',\n'.join('(' + ', '.join(lit(v) for v in r) + ')' for r in cmd_rows) + ';\n'
open(cpath, 'w').write(src)

# pools: skillListId = genusId for every pool of a family that has a list
fams = {g for g, _, _ in list_rows}
ppath = f'{REPO}/common/sql/data/server_battlenpc_pools.sql'
p = open(ppath).read()
changed = 0
def fix(mo):
    global changed
    g = int(mo.group(2))
    want = str(g) if g in fams else '0'
    if mo.group(3) != want:
        changed += 1
    return mo.group(1) + want + ')' + mo.group(4)
p = re.sub(r"^(\(\d+, \d+, '[^']*', (\d+), .*, )(\d+)\)([,;])$", fix, p, flags=re.M)
open(ppath, 'w').write(p)
print(dict(stats), 'commands', len(cmd_rows), 'families', len(fams), 'pools changed', changed)
