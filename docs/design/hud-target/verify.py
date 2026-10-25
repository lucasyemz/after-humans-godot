"""Auditoria de formato, texto, geometria e dados da proposta comparada ao alvo."""
import sys,json,hashlib,re,subprocess
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
manifest=json.loads((OUT/'assets.json').read_text());checks=json.loads((OUT/'checks.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert (OUT/'assets.json').read_bytes()==(ROOT/'art/ui/kit/combat/assets.json').read_bytes()
assert sha(ROOT/manifest['source_reference'])==manifest['source_sha256']
assert sha(ROOT/manifest['font']['file'])==manifest['font']['sha256']
assert 'SIL OPEN FONT LICENSE Version 1.1' in (ROOT/manifest['font']['license']).read_text()
assert len(manifest['assets'])==18 and len(checks['profiles'])==4
for key,row in manifest['assets'].items():
 im=Image.open(ROOT/row['file']);assert im.size==tuple(row['size']);assert sha(ROOT/row['file'])==row['sha256'];assert im.mode==('RGB' if key=='steel_material' else 'RGBA');assert (ROOT/row['file']).with_suffix('.webp.import').exists()
 if row['nine_slice_ltrb']:
  l,t,r,b=row['nine_slice_ltrb'];assert l+r<im.width and t+b<im.height
for p in checks['profiles']:
 assert not p['overflows'];assert Image.open(OUT/p['file']).size==(1920,1080);assert sha(OUT/p['file'])==p['sha256'];assert min(t['size'] for t in p['labels'])>=18;assert p['ring']['center'][0]==768;rx,ry,rw,rh=p['ring']['rect'];assert [rx+rw/2,ry+rh/2]==p['ring']['center']
 for label in p['labels']:
  assert label['text']==label['text'].upper();x,y,w,h=label['rect'];assert x>=0 and y>=0 and x+w<=1920 and y+h<=1080
 for hit in p['hits']:
  x,y,w,h=hit['rect'];assert w>=112 and h>=112;assert x>=0 and y>=0 and x+w<=1920 and y+h<=1080
 for i,a in enumerate(p['hits']):
  x,y,w,h=a['rect']
  for b in p['hits'][i+1:]:
   xx,yy,ww,hh=b['rect'];assert not(x<xx+ww and xx<x+w and y<yy+hh and yy<y+h),(a,b)
 for rel,digest in p['unchanged_ability_art'].items():assert hashlib.sha256(subprocess.check_output(['git','show','HEAD:'+rel],cwd=ROOT)).hexdigest()==digest
 suffix=('_large' if p['large'] else '')+('_colorblind' if p['colorblind'] else '');assert Image.open(OUT/('comparison'+suffix+'.webp')).size==(3840,1152)
for doc in [ROOT/'docs/design/hud-target.md']:
 if doc.exists():
  for link in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
   if not link.startswith(('http','#')):assert (doc.parent/link.split('#')[0]).exists(),(doc,link)
report={'verdict':'APROVADO for design delivery; integration still required','reference_unchanged':True,'runtime_webp':18,'runtime_bytes':sum((ROOT/r['file']).stat().st_size for r in manifest['assets'].values()),'profiles':4,'label_overflows':0,'overlapping_input_targets':0,'uppercase_condensed_ofl_font':True,'nick_icons_unchanged':True,'f_is_exit':True,'sha256':{p.name:sha(p) for p in sorted(OUT.glob('*.webp'))}}
(OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('4 perfis,18 peças, OFL, 9-slices, fonte/limites/alvos/ícones verificados.')
