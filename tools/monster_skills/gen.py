"""Generate the monster skill data files for xivlegacy-server.

Inputs: client move sheet (ZAM cache sheets.json, sheet 16), ZAM mob-page
sightings (zam_hits.json), modern Action data (modern.json from XIVAPI).
Outputs (into the repo): server_battle_commands rows for 1.0 monster moves,
server_battlenpc_skill_info (one row per move: family, evidence, modern
match), server_battlenpc_skill_list (family lists), pools skillListId.
"""
import json, os, re, sys, collections

REPO = sys.argv[1]
C = '/Volumes/AppStorage/xivlegacy-reference-cache/'
sheet = json.load(open(C + 'sheets.json'))[16]['rows']
modern = json.load(open('modern.json'))
zam = json.load(open('zam_hits.json'))
# Archived (2012-13) Gamer Escape pages: move name -> family it names, and
# whether the page was already the ARR (2.0) version. From fetch_ge.py.
ge = json.load(open('ge_family.json')) if os.path.exists('ge_family.json') else {}
ge_arr = {k: v.get('arr') for k, v in json.load(open('ge3.json')).items()} if os.path.exists('ge3.json') else {}
# Modern (ARR+) users with levels, from consolegameswiki. From fetch_cgw.py.
cgw = json.load(open('cgw.json')) if os.path.exists('cgw.json') else {}

GENUS = {}
for l in open('genus.tsv'):
    g, n, k = l.rstrip('\n').split('\t')
    GENUS[int(g)] = n

# Monster kinds: one model family each, so its moves share animation slots.
# (list id, family, genera whose pools use it, pool-name regex, named pool
#  ids, blocks of (first id, last id, block evidence, ZAM anchor pages),
#  names a Gamer Escape page may use for it)
# List id = the genus id where the kind is a genus, 101+ for kinds that are
# not, and the pool id for a named boss's own list.
# block evidence: zam = ZAM page shows a move of the block on that family;
#   ge = an archived 1.0 Gamer Escape page names the family for one of the
#   block's moves; modern = only an ARR-era page does; name = the names.
KINDS = [
    (12, 'Rodent', [12], r'squirrel|marmot|rat\b|dormouse|lemming|chinchilla', [], [(23011, 23012, 'ge', [])], ['Rodent']),
    (39, 'Yarzon', [], r'yarzon', [], [(23138, 23140, 'zam', [2105501])], ['Yarzon']),
    (42, 'Dodo', [42], '', [], [(23013, 23020, 'zam', [2102001, 2202003])], ['Dodo']),
    (31, 'Basilisk', [31], '', [], [(23021, 23027, 'ge', []), (23105, 23106, 'name', [])], ['Basilisk', 'Peiste']),
    (32, 'Raptor', [32], '', [], [(23028, 23031, 'zam', [2100203]), (23101, 23104, 'zam', [2100205])], ['Raptor']),
    (64, 'Bomb', [64], '', [], [(23032, 23036, 'zam', [2101605, 2101602])], ['Bomb']),
    (20, 'Jellyfish', [20], '', [], [(23037, 23040, 'ge', [])], ['Aurelia', 'Jellyfish']),
    (60, 'Ogre', [60], '', [], [(23041, 23046, 'ge', [])], ['Ogre', 'Dhara']),
    (43, 'Bat', [43], '', [], [(23047, 23049, 'name', [2204102, 2104101])], ['Bat']),
    (36, 'Chigoe', [36], '', [], [(23050, 23051, 'zam', [2105603])], ['Chigoe']),
    (101, 'Snurble', [], r'porcupine|snurble', [], [(23069, 23072, 'ge', [])], ['Snurble']),
    (11, 'Mole', [11], '', [], [(23052, 23056, 'zam', [2105703])], ['Mole']),
    (45, 'Puk', [45], '', [], [(23057, 23059, 'zam', [2100101, 2100109])], ['Puk']),
    (17, 'Orobon', [17], '', [], [(23060, 23062, 'zam', [2104501, 2104506])], ['Orobon']),
    (37, 'Gnat', [37], '', [], [(23063, 23068, 'modern', [])], ['Gnat']),
    (4, 'Opo-opo', [4], '', [], [(23073, 23076, 'zam', [2100502, 2200405])], ['Opo-Opo', 'Opo-opo']),
    (2, 'Antelope', [2], '', [], [(23078, 23079, 'modern', [])], ['Antelope']),
    (44, 'Hippogryph', [44], '', [], [(23080, 23083, 'ge', [])], ['Hippogryph']),
    (38, 'Beetle', [38], '', [], [(23084, 23085, 'zam', [2103901, 2103902, 2103904])], ['Beetle']),
    (15, 'Flytrap', [15], '', [], [(23086, 23089, 'zam', [2102705])], ['Landtrap', 'Flytrap']),
    (1, 'Aldgoat', [1], '', [], [(23090, 23092, 'zam', [2102301, 2102303, 2102305])], ['Aldgoat']),
    (51, 'Ahriman', [51], '', [], [(23093, 23095, 'ge', [])], ['Ahriman']),
    (5, 'Coeurl', [5], '', [], [(23096, 23097, 'name', [])], ['Coeurl']),
    (21, 'Slug', [21], '', [], [(23098, 23100, 'zam', [2104201])], ['Slug']),
    (49, 'Coblyn', [49], '', [], [(23113, 23114, 'zam', [2102101, 2102109])], ['Coblyn']),
    (52, 'Imp', [52], '', [], [(23115, 23119, 'zam', [2202601, 2202603])], ['Imp']),
    (50, 'Spriggan', [50], '', [], [(23121, 23125, 'ge', []), (23168, 23177, 'ge', [])], ['Spriggan']),
    (46, 'Ghost', [46], '', [], [(23127, 23130, 'zam', [2204305])], ['Ghost', 'Bogy']),
    (22, 'Crab', [22], '', [], [(23132, 23135, 'zam', [2107614])], ['Crab', 'Megalocrab']),
    (3, 'Wolf', [], r'wolf|hound|watchdog|mongrel', [], [(23141, 23145, 'zam', [2101401, 2101321])], ['Wolf']),
    (13, 'Cactuar', [13], '', [], [(23146, 23150, 'zam', [2100910, 2100901])], ['Cactuar']),
    (102, 'Elemental', [54, 55, 56, 57, 58, 59], '', [], [(23151, 23153, 'name', []), (23178, 23182, 'name', [])], ['Elemental']),
    (9, 'Boar', [9], '', [], [(23154, 23157, 'ge', [])], ['Boar']),
    (19, 'Salamander', [19], '', [], [(23158, 23159, 'zam', [2101317])], ['Salamander']),
    (27, 'Kobold', [27], r'kobold', [], [(23183, 23187, 'ge', []), (23394, 23398, 'ge', [])], ['Kobold']),
    (28, 'Sylph', [28], '', [], [(23189, 23190, 'name', [])], ['Sylph']),
    (24, 'Ixal', [24], r'ixal', [], [(23192, 23196, 'modern', [])], ['Ixal']),
    (23, "Amalj'aa", [23], r"amalj|ahzabb", [], [(23198, 23206, 'zam', [2206523])], ["Amalj'aa"]),
    (40, 'Apkallu', [40], '', [], [(23207, 23209, 'zam', [2102901])], ['Apkallu']),
    (6, 'Goobbue', [6], '', [], [(23210, 23215, 'zam', [2103301])], ['Goobbue']),
    (104, 'Garlean', [], r"^imperial|^elite |magitek transmitter", [], [(23223, 23224, 'modern', [])], ['Magitek Armor']),
    (105, 'Magitek Vanguard', [], r'magitek vanguard', [], [(23565, 23567, 'ge', [])], ['Vanguard']),
    (33, 'Ant', [33], '', [], [(23226, 23229, 'name', [])], ['Ant', 'Antling']),
    (106, 'Fomor', [], '', [], [(23230, 23232, 'ge', [])], ['Fomor']),
    (41, 'Vulture', [41], '', [], [(23233, 23237, 'zam', [2101204, 2101205])], ['Vulture']),
    (7, 'Sheep', [7], '', [], [(23238, 23240, 'zam', [2106011])], ['Ram', 'Sheep']),
    (48, 'Wight', [48], '', [], [(23244, 23247, 'zam', [2101903, 2201901])], ['Wight', 'Skeleton']),
    (14, 'Funguar', [14], '', [], [(23250, 23256, 'zam', [2105901, 2105903, 2105915])], ['Funguar']),
    (34, 'Swarm', [34], '', [], [(23257, 23257, 'zam', [2105302, 2105301, 2105202])], ['Swarm']),
    (53, 'Wisp', [53], '', [], [(23258, 23261, 'zam', [2105801, 2105803])], ['Firefly', 'Wisp']),
    (18, 'Gigantoad', [18], '', [], [(23262, 23269, 'name', [])], ['Gigantoad', 'Toad']),
    (30, 'Drake', [30], '', [], [(23270, 23278, 'ge', [])], ['Drake']),
    (16, 'Morbol', [16], '', [], [(23281, 23286, 'zam', [2101001])], ['Morbol']),
    (35, 'Diremite', [35], r'diremite|miteling|banemite|cell mite', [], [(23288, 23294, 'ge', [])], ['Diremite']),
    (8, 'Buffalo', [8], '', [], [(23296, 23299, 'modern', [])], ['Buffalo']),
    (63, 'Flan', [63], '', [], [(23306, 23308, 'name', [])], ['Flan', 'Pudding']),
    (26, 'Goblin', [26], '', [], [(23311, 23315, 'name', [2110301])], ['Goblin']),
    (25, 'Qiqirn', [25], '', [], [(23318, 23324, 'name', [])], ['Qiqirn']),
    (107, 'Gargoyle', [], '', [], [(23350, 23354, 'modern', [])], ['Gargoyle']),
    (103, 'Golem', [], r'golem', [], [(23385, 23393, 'modern', []), (23638, 23641, 'modern', [])], ['Golem']),
    (108, 'Moogle', [], r'moogle|mog', [], [(23410, 23424, 'ge', []), (23451, 23453, 'ge', [])], ['Moogle']),
    (109, 'Treant', [], r'treant', [], [(23438, 23450, 'ge', []), (23642, 23643, 'modern', [])], ['Treant']),
    (110, 'Chimera', [], r'chimera', [], [(23456, 23464, 'modern', [])], ['Chimera', 'Chimera Genus']),
    (111, 'Bahamut', [], '', [], [(23596, 23596, 'name', []), (23617, 23626, 'name', [])], []),
    (112, 'Cyclops', [], r'cyclops', [], [(23476, 23482, 'modern', []), (23629, 23630, 'name', [])], ['Cyclops']),
    (30100, 'Ifrit', [], '', [30100], [(23361, 23376, 'modern', []), (23408, 23409, 'name', []), (23577, 23583, 'modern', []), (23592, 23595, 'modern', [])], ['Primal']),
    (30109, 'Garuda', [], '', [30109], [(23537, 23559, 'modern', []), (23568, 23573, 'modern', [])], ['Primal']),
    (30115, 'Nael van Darnus', [], '', [30115], [(23603, 23615, 'name', []), (23627, 23627, 'name', []), (23631, 23631, 'name', [])], []),
]
BOSS_LISTS = {k[0] for k in KINDS if k[4]}
# Class move lists for human and beastman enemies with no kind list,
# matched by the pool's currentJob or its name: (list id, family, jobs,
# pool-name regex, blocks). The client keeps these copies of player class
# actions with the monster moves.
JOB_LISTS = [
    (122, 'Enemy pugilist', {2, 15}, r'brawler|pugilist', [(23486, 23488, 'name', [])]),
    (123, 'Enemy marauder', {4, 17}, r'cleaver|marauder|axeman', [(23484, 23485, 'name', []), (23489, 23491, 'name', [])]),
    (124, 'Enemy lancer', {8, 19}, r'spearman|pikeman|lancer', [(23492, 23496, 'name', [])]),
]
# Spell lists (pool spellListId) for casters, matched the same way. The
# client's monster spell block 23508-23534 holds the "II" tier of the 1.0
# thaumaturge and conjurer spells.
THM_SPELLS = [23508, 23509, 23510, 23511, 23512, 23513, 23520, 23521, 23522, 23526, 23527, 23530, 23531, 23532, 23534]
CNJ_SPELLS = [23514, 23515, 23516, 23517, 23518, 23519, 23523, 23524, 23525, 23528, 23529, 23533]
SPELL_LISTS = [
    (120, 'Enemy thaumaturge', {22, 26}, r'divinator|stargazer|signifer|thunder_mage|zombie mage|transfigurator', THM_SPELLS),
    (121, 'Enemy conjurer', {23, 24}, r'medicus|soilseer|bedesman|shaman', CNJ_SPELLS),
]

# Inside a block but known to belong elsewhere (a stray copy of another
# family's move): left out of the block's kind.
SKIP = {23560}  # Formic Pheromones inside Garuda's block

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
for lid, fam, genera, rx, named, blocks, aliases in KINDS:
    for a, b, ev, anchors in blocks:
        slot = 0
        for i in range(a, b + 1):
            n = sheet.get(str(i), [''])[0]
            if blank(n):
                continue
            slot += 1
            if i in SKIP:
                continue
            assert i not in fam_of, (i, fam, fam_of[i])
            fam_of[i] = (lid, fam, ev, anchors, slot, aliases)

for lid, fam, jobs, rx, blocks in JOB_LISTS:
    for a, b, ev, anchors in blocks:
        slot = 0
        for i in range(a, b + 1):
            n = sheet.get(str(i), [''])[0]
            if blank(n):
                continue
            slot += 1
            assert i not in fam_of, (i, fam)
            fam_of[i] = (lid, fam, ev, anchors, slot, [])
for lid, fam, jobs, rx, ids in SPELL_LISTS:
    for i in ids:
        assert i not in fam_of, (i, fam)
        fam_of[i] = (lid, fam, 'name', [], i - 23507, [])

def genus_of(lid):
    return lid if lid in GENUS else 0

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
    lid, fam, ev, anchors, slot, aliases = fam_of.get(i, (0, '', '', [], 0, []))
    # ZAM sighting of this exact move on one of the family's anchor pages
    seen = [a for a in anchors if n in zam.get(str(a), {})]
    ge_names = ge.get(n, '') in aliases
    if seen:
        evidence = 'zam'
    elif ge_names:
        evidence = 'modern' if ge_arr.get(n) else 'ge'
    elif lid:
        evidence = 'block' if ev in ('zam', 'ge', 'modern') else ev
    else:
        evidence = ''
    notes = []
    if seen:
        notes.append('ZAM mob ' + ','.join(map(str, seen)))
    if ge_names:
        notes.append(('ARR-era' if ge_arr.get(n) else '1.0') + f' Gamer Escape page: family {ge[n]}')
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
    info_rows.append([i, n, genus_of(lid), lid, fam, evidence, slot, m['row_id'] if m else 0, notes])
    if lid:
        list_rows.append([lid, i, 1, '', evidence])
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

# pools -> lists: a named boss's own list first, then a kind whose name
# pattern matches the pool, then a kind that covers the pool's genus
ppath = f'{REPO}/common/sql/data/server_battlenpc_pools.sql'
POOL_RE = re.compile(r"^(\((\d+), (\d+), '((?:[^']|'')*)', (\d+), (\d+), .*, )(\d+), (\d+)\)([,;])$", re.M)
listed = {r[0] for r in list_rows}
def list_for(pool, name, genus, job):
    name = name.replace("''", "'")
    for lid, fam, genera, rx, named, blocks, aliases in KINDS:
        if pool in named:
            return lid
    for lid, fam, genera, rx, named, blocks, aliases in KINDS:
        if rx and re.search(rx, name, re.I):
            return lid
    for lid, fam, jobs, rx, blocks in JOB_LISTS:
        if job in jobs or re.search(rx, name, re.I):
            return lid
    for lid, fam, genera, rx, named, blocks, aliases in KINDS:
        if genus in genera and not rx:
            return lid
    for lid, fam, genera, rx, named, blocks, aliases in KINDS:
        if genus in genera:  # genus covered, but the name pattern is the gate
            return 0
    return 0
def spell_list_for(name, job):
    name = name.replace("''", "'")
    for lid, fam, jobs, rx, ids in SPELL_LISTS:
        if job in jobs or re.search(rx, name, re.I):
            return lid
    return 0
pool_list, pool_spells = {}, {}
for mo in POOL_RE.finditer(open(ppath).read()):
    pid, job = int(mo.group(2)), int(mo.group(6))
    lid = list_for(pid, mo.group(4), int(mo.group(5)), job)
    pool_list[pid] = lid if lid in listed else 0
    pool_spells[pid] = spell_list_for(mo.group(4), job)

# levels: spawn level range of the pools using each list
span = collections.defaultdict(lambda: [999, 0])
for l in open(f'{REPO}/common/sql/data/server_battlenpc_groups.sql'):
    mo = re.match(r"\((\d+), (\d+), '(?:[^']|'')*', (\d+), (\d+),", l)
    if not mo:
        continue
    for lid in (pool_list.get(int(mo.group(2))), pool_spells.get(int(mo.group(2)))):
        if lid:
            sp = span[lid]
            sp[0] = min(sp[0], int(mo.group(3)))
            sp[1] = max(sp[1], int(mo.group(4)))
SPREAD = 40  # at most this many levels from a kind's first move to its last

def modern_level(n):
    lv = []
    for u in cgw.get(n, {}).get('users', []):
        if not u['duty']:
            lv += [int(x) for x in re.findall(r'\d+', u['level'])[:1]]
    return min(lv) if lv else 0

by_list = collections.defaultdict(list)
for r in list_rows:
    by_list[r[0]].append(r)
for lid, rows in by_list.items():
    rows.sort(key=lambda r: r[1])
    if lid in BOSS_LISTS:
        for r in rows:
            r[2], r[3] = 1, 'boss'
        continue
    if lid not in span:
        continue  # no pools use it yet: level 1, no source
    lo, hi = span[lid]
    hi = min(hi, lo + SPREAD)
    for k, r in enumerate(rows):
        r[2], r[3] = lo + (k * (hi - lo)) // len(rows), 'spawn'
        mlv = modern_level(sheet[str(r[1])][0].strip())
        if mlv:
            r[2], r[3] = max(lo, min(hi, mlv)), 'modern'
# Class move and spell lists: the 1.0 class learn level of the same
# action (the 1.23b player row, else an archived 1.0 page's "Level
# Learned"); a "II" spell takes its base spell's level.
ge_levels = json.load(open('ge_levels.json')) if os.path.exists('ge_levels.json') else {}
player_lvl = {}
for l in open(f'{REPO}/common/sql/data/server_battle_commands.sql'):
    mo = re.match(r"\((\d+), '([a-z0-9_]+)', (\d+), (\d+),", l)
    if mo and mo.group(3) != '0':
        player_lvl.setdefault(mo.group(2), int(mo.group(4)))
def class_level(n):
    if snake(n) in player_lvl:
        return player_lvl[snake(n)]
    if n in ge_levels:
        return ge_levels[n]
    base = re.sub(r' II$', '', n)
    if base != n and snake(base) in player_lvl:
        return player_lvl[snake(base)]
    return 0
CLASS_LISTS = {j[0] for j in JOB_LISTS} | {j[0] for j in SPELL_LISTS}
for r in list_rows:
    if r[0] in CLASS_LISTS:
        clv = class_level(sheet[str(r[1])][0].strip())
        if clv:
            r[2], r[3] = clv, 'class'
level_of = {r[1]: (r[2], r[3]) for r in list_rows}
for r in info_rows:
    if r[0] in level_of and level_of[r[0]][1]:
        lv, src = level_of[r[0]]
        r[8].append(f'unlocks at level {lv} ({src})')
    r[8] = '; '.join(r[8])

open(f'{REPO}/common/sql/data/server_battlenpc_skill_info.sql', 'w').write(table_file(
    'server_battlenpc_skill_info',
    ['skillId', 'displayName', 'genusId', 'skillListId', 'family', 'evidence', 'slot', 'modernActionId', 'notes'], info_rows,
    'Monster moves (1.23b command sheet 23011-23645): kind, list, evidence (zam / ge / modern / block / name / empty = unassigned), modern match. Built by tools/monster_skills.'))
open(f'{REPO}/common/sql/data/server_battlenpc_skill_list.sql', 'w').write(table_file(
    'server_battlenpc_skill_list', ['skillListId', 'skillId', 'minLevel', 'levelSource', 'evidence'], list_rows,
    'One list per monster kind (skillListId = genusId, 101+ for kinds with no genus, poolId for a named boss); minLevel gates each move.'))

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

# pools: point each at its list
p = open(ppath).read()
changed = 0
def fix(mo):
    global changed
    pid = int(mo.group(2))
    spell, skill = str(pool_spells.get(pid, 0)), str(pool_list.get(pid, 0))
    if (mo.group(7), mo.group(8)) != (spell, skill):
        changed += 1
    return mo.group(1) + spell + ', ' + skill + ')' + mo.group(9)
p = POOL_RE.sub(fix, p)
open(ppath, 'w').write(p)
print(dict(stats), 'commands', len(cmd_rows), 'lists', len(listed),
      'pools with a list', sum(1 for v in pool_list.values() if v),
      'pools with spells', sum(1 for v in pool_spells.values() if v), 'pools changed', changed)
