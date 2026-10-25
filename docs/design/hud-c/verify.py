"""Audita a entrega estática e o vínculo com a sessão; não substitui QA da integração."""
import sys,json,hashlib,re,subprocess
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
checks=json.loads((HERE/'checks.json').read_text());sheets=json.loads((HERE/'states_checks.json').read_text());assets=json.loads((HERE/'assets.json').read_text())['assets'];quotes=json.loads((HERE/'session_quotes.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert len(checks)==36 and len(sheets)==4 and len(assets)==13
for name,a in assets.items():
 p=ROOT/a['file'];im=Image.open(p);assert im.size==tuple(a['size']) and im.mode=='RGBA';assert sha(p)==a['sha256'];assert p.with_suffix('.webp.import').exists()
 if a['slice_ltrb']:
  l,t,r,b=a['slice_ltrb'];assert l+r<im.width and t+b<im.height
 if name in ['exit','bar_glass']:assert all(tuple(rgb)==(255,255,255) for *rgb,alpha in im.getdata() if alpha>0)
for row in checks:
 assert not row['outside'];im=Image.open(HERE/row['file']);assert im.size==(1920,1080);assert sha(HERE/row['file'])==row['sha256'];assert sha(ROOT/row['source'])==row['source_sha256'];assert all(r['size']>=18 for r in row['labels'])
 source='combat-boss' if row['case'].startswith('boss') else 'combat';quote=quotes[source];assert row['actor']==quote['actor'];assert len(row['initiative'])==(7 if source=='combat-boss' else 6)
 for hit in row['hits']:
  x,y,w,h=hit['rect'];assert w>=112 and h>=112 and x>=0 and y>=0 and x+w<=1920 and y+h<=1080,hit
  if hit['kind']=='ability':
   q=next(q for q in quote['options'] if q['id']==hit['id']);assert hit['disabled']==(not q['usable']);assert hit['uses']==q['uses'] and hit['reason']==q['reason']
  if hit.get('id')=='combat_flee':assert hit['disabled']==(not quote['can_flee'])
 for i,a in enumerate(row['hits']):
  x,y,w,h=a['rect']
  for b in row['hits'][i+1:]:
   xx,yy,ww,hh=b['rect'];assert not (x<xx+ww and xx<x+w and y<yy+hh and yy<y+h),(row['case'],a,b)
for row in sheets:assert not row['outside']
for case in {r['case'] for r in checks}:
 rows=[r for r in checks if r['case']==case];assert len({r['source_sha256'] for r in rows})==1;assert len({r['actor'] for r in rows})==1
 assert Image.open(HERE/(case+'_40.webp')).size==(768,432);assert Image.open(HERE/(case+'_gray.webp')).size==(1920,1080)
# Original images of Nick have not been replaced or edited.
icons={}
for p in sorted((ROOT/'art/combat/icons').glob('gato_*.webp')):
 rel=str(p.relative_to(ROOT));assert hashlib.sha256(subprocess.check_output(['git','show','HEAD:'+rel],cwd=ROOT)).hexdigest()==sha(p);icons[rel]=sha(p)
assert len(icons)==4
for doc in [HERE.parent/'hud-c.md',HERE.parent/'hud-direction.md',HERE.parent/'ui-kit.md',HERE.parent/'hud-variations.md',HERE.parent/'ui-kit/v2-style.md']:
 for target in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
  if not target.startswith(('http','#')):assert (doc.parent/target.split('#')[0]).exists(),(doc,target)
report={'verdict':'APROVADO for design delivery; game integration still required','mockups':36,'state_sheets':4,'runtime_webp':13,'runtime_webp_bytes':sum((ROOT/a['file']).stat().st_size for a in assets.values()),'minimum_font':18,'text_outside_canvas':0,'overlapping_input_targets':0,'minimum_input_width':112,'minimum_input_height':112,'frozen_source_per_encounter':True,'unchanged_nick_icons':icons,'composed_webp_sha256':{p.name:sha(p) for p in sorted(HERE.glob('*.webp'))}}
(HERE/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('APROVADO:36 cenas,4 folhas,13 RGBA; zero alvos sobrepostos;4 ícones do Nick intactos.')
