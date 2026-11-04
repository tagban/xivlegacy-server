# Archived (pre-ARR, 2012-2013) Gamer Escape pages for 1.0 monster moves:
# family from the "<Family> Actions" category. 4 workers; resumable.
import json, re, html, subprocess, sys, os, urllib.parse, threading
from concurrent.futures import ThreadPoolExecutor
info, out, pdir = sys.argv[1:4]
names = sorted({n.replace("''", "'") for n in re.findall(r"^\(\d+, '((?:[^']|'')*)'", open(info).read(), re.M)})
res = json.load(open(out)) if os.path.exists(out) else {}
lock = threading.Lock()
def one(n):
    f = pdir + '/' + re.sub(r'[^A-Za-z0-9_-]', '_', n) + '.html'
    if not (os.path.exists(f) and os.path.getsize(f) > 6000):
        slug = urllib.parse.quote(n.replace(' ', '_'), safe="_-'(),")
        subprocess.run(['curl', '-sL', '-m', '60', '-A', 'xivlegacy-research', '-o', f,
                        f'http://web.archive.org/web/20120701id_/http://ffxiv.gamerescape.com/wiki/{slug}'])
    s = open(f, errors='ignore').read() if os.path.exists(f) else ''
    cats = [html.unescape(c) for c in re.findall(r'title="Category:([^"]+)"', s)]
    fams = sorted({c[:-8] for c in cats if c.endswith(' Actions') and c != 'Mob Actions'})
    genus = sorted({c[6:] for c in cats if c.startswith('Genus:')})
    t = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', re.sub(r'<script.*?</script>', '', s, flags=re.S))))
    m = re.search(r'Family: (.{0,60})', t)
    r = {'size': len(s), 'arr': 'Patch 2.0' in cats or bool(genus), 'families': fams, 'genus': genus,
         'family_text': m.group(1) if m else '', 'cats': cats}
    with lock:
        res[n] = r
        json.dump(res, open(out, 'w'), indent=1)
        print(n, '|', ','.join(fams or genus), flush=True)
todo = [n for n in names if n not in res or res[n]['size'] < 6000]
with ThreadPoolExecutor(4) as ex:
    list(ex.map(one, todo))
print('done', len(res), flush=True)
