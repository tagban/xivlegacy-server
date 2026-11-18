# Modern (ARR+) users of each monster move, with levels, from consolegameswiki
# "Locations" tables. Used for move level gates where 1.0 data is missing.
import json, re, html, subprocess, sys, time, os, urllib.parse
info, out, pdir = sys.argv[1:4]
names = sorted({n.replace("''", "'") for n in re.findall(r"^\(\d+, '((?:[^']|'')*)'", open(info).read(), re.M)})
res = json.load(open(out)) if os.path.exists(out) else {}
def cell(c): return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', c))).strip()
for n in names:
    if n in res: continue
    f = pdir + '/' + re.sub(r'[^A-Za-z0-9_-]', '_', n) + '.html'
    url = 'https://ffxiv.consolegameswiki.com/wiki/' + urllib.parse.quote(n.replace(' ', '_'), safe="_-'(),")
    subprocess.run(['curl', '-sL', '-m', '40', '-A', 'xivlegacy-research', '-o', f, url])
    s = open(f, errors='ignore').read() if os.path.exists(f) else ''
    users = []
    i = s.find('id="Locations"')
    if i >= 0:
        t = s[i:s.find('</table>', i)]
        for row in re.findall(r'<tr>(.*?)</tr>', t, re.S):
            cs = [cell(c) for c in re.findall(r'<td[^>]*>(.*?)</td>', row, re.S)]
            if len(cs) >= 3:
                dungeon = 'Dungeon' in row or 'Trial' in row or 'Raid' in row
                users.append({'enemy': cs[0], 'level': cs[1], 'where': cs[2], 'duty': dungeon})
    res[n] = {'page': 'mw-content-text' in s and 'There is currently no text' not in s, 'users': users}
    json.dump(res, open(out, 'w'), indent=1)
    print(n, len(users), flush=True)
    time.sleep(1.0)
print('done', len(res), flush=True)
