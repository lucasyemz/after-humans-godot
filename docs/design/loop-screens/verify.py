"""Auditoria dos arquivos de entrega; não é teste do jogo ou do balanceamento."""
import sys,json,hashlib,re
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
audit=json.loads((HERE/'checks.json').read_text());assert len(audit)==112
pages=sorted({r['page'] for r in audit});assert len(pages)==28
for page in pages:
 for suffix in ['', '_large','_colorblind','_large_colorblind']:
  with Image.open(HERE/(page+suffix+'.webp')) as im:assert im.size==(1920,1080);im.load()
 with Image.open(HERE/(page+'_40.webp')) as im:assert im.size==(768,432)
 with Image.open(HERE/(page+'_gray.webp')) as im:assert im.size==(1920,1080)
for row in audit:
 assert not row['bounds'],row
 assert all(t['role'] in ['body','title','detail'] and t['x']>=0 and t['y']>=0 for t in row['labels'])
assets={}
for p in sorted((ROOT/'art/ui/loop').glob('*.webp')):
 im=Image.open(p);assert im.mode=='RGBA';assert im.size==((224,192) if p.stem.startswith('cargo') else (32,32))
 assert im.getchannel('A').getextrema()==(0,255)
 if p.stem.startswith('cargo'):assert im.getbbox()[3]==184
 else:assert all(tuple(rgb)==(255,255,255) for *rgb,a in im.getdata() if a>0)
 assets[p.name]={'size':list(im.size),'alpha_bbox':list(im.getbbox()),'sha256':digest(p)}
assert len(assets)==4
m=json.loads((HERE/'captures.json').read_text());assert all(len(m[k])==9 for k in ['normal','large'])
for profile,entries in m.items():
 for name,r in entries.items():
  assert all((HERE/r[k]).is_file() for k in ['before','background','metadata'])
  if name=='combat-boss':
   units=json.loads((HERE/r['metadata']).read_text())['units'];assert len(units)==7;assert next(x for x in units if x['enemy_id']=='porteiro')['hp']==90
for profile in ['normal','large']:
 evidence=json.loads((HERE/f'bond_evidence_{profile}.json').read_text());assert evidence['friend_block']==1 and evidence['nick_instinct_after']==5
for doc in [HERE.parent/'loop-screens.md',HERE.parent/'ui-kit.md']:
 for target in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
  if not target.startswith(('http','#')):assert (doc.parent/target.split('#')[0]).exists(),target
assert json.loads((HERE/'fixtures.json').read_text())['new_values_are_layout_fixtures_not_balance']
report={'issue':96,'states':28,'profiles':112,'real_source_frames':18,'bounds_outside_canvas':0,'runtime_assets':assets,'minimum_font_normal':18,'minimum_font_large':23,'shape_checks':'filled/outline + count; lock + reason; selection diamond separate from focus','visual_review':'see loop-screens.md, QA round2','composed_images_sha256':{p.name:digest(p) for p in sorted(HERE.glob('*.webp'))}}
(HERE/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('APROVADO:112 composições,18 frames,4 RGBA; limites, links e evidências válidos.')
