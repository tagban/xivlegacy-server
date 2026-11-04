"""Find 1.0 monster move names on cached ZAM monster pages.

Writes move_names.json (name -> command ids, from the client move sheet)
and zam_hits.json (ZAM mob id -> move names seen on its page). The page
text itself stays out of the repo; only the matches are used.
"""
import json, re, glob, html, collections

C = '/Volumes/AppStorage/xivlegacy-reference-cache/'
rows = json.load(open(C + 'sheets.json'))[16]['rows']
moves = {}
for k, v in rows.items():
    n = v[0].strip()
    if n and n not in ('-', 'Attack', 'Ranged Attack') and len(n) > 3:
        moves.setdefault(n, []).append(int(k))
json.dump(moves, open('move_names.json', 'w'), indent=0)
pat = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, moves), key=len, reverse=True)) + r')\b', re.I)
hits = collections.defaultdict(dict)
for f in glob.glob(C + 'mob/*.html'):
    mid = f.split('/')[-1][:-5]
    t = open(f, errors='ignore').read()
    t = html.unescape(re.sub(r'<script.*?</script>|<style.*?</style>', '', t, flags=re.S))
    t = ' '.join(re.sub(r'<[^>]+>', ' ', t).split())
    for m in pat.finditer(t):
        name = next(n for n in moves if n.lower() == m.group(1).lower())
        hits[mid][name] = True
json.dump(hits, open('zam_hits.json', 'w'), indent=1)
print(len(moves), 'move names;', len(hits), 'ZAM pages name a move')
