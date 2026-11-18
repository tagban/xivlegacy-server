import json,time,urllib.request,urllib.parse,sys,os
names=json.load(open('move_names.json'))
out=json.load(open('modern.json')) if os.path.exists('modern.json') else {}
F='Name,CastType,EffectRange,XAxisModifier,Range,Cast100ms,Recast100ms,IsPlayerAction,AttackType.Name,Aspect,TargetArea,CanTargetSelf,CanTargetHostile,CanTargetParty'
for n in names:
    if n in out: continue
    q=urllib.parse.quote(f'Name="{n}"')
    url=f'https://beta.xivapi.com/api/1/search?sheets=Action&query={q}&fields={F}&limit=20'
    try:
        r=json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'xivlegacy-research'}),timeout=30))
        out[n]=[x['row_id'] and dict(x['fields'],row_id=x['row_id']) for x in r.get('results',[])]
    except Exception as e:
        out[n]={'error':str(e)}
    json.dump(out,open('modern.json','w'))
    time.sleep(1.0)
print('done',len(out))
