from pathlib import Path
from PIL import Image,ImageOps
import json,hashlib
repo=Path('/workspace/after-humans-godot');src=Path(__file__).parent;out=repo/'docs/design/lobby_outfits'
assets={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for key in ['founders','recruits','raccoon_armadillo']:
 p=src/f'{key}_concept.png';im=Image.open(p).convert('RGB');im.save(out/f'{key}.webp',quality=90,method=6)
 small=im.resize((round(im.width*.4),round(im.height*.4)),Image.Resampling.LANCZOS)
 small.save(out/f'{key}_40.webp',quality=90,method=6);ImageOps.grayscale(small).save(out/f'{key}_gray_40.webp',quality=90,method=6)
 assets[key]={'source_file':p.name,'source_sha256':sha(p),'canvas':list(im.size),'review_file':f'{key}.webp','review_sha256':sha(out/f'{key}.webp'),'reduced_canvas':list(small.size),'production_sprite':False,'anchor':None}
refs={
 'founders':[repo/f'art/combat/heroes/{h}/idle.webp' for h in ['bento','nick','iris','vespera']],
 'recruits':[repo/f'art/combat/recruits/{h}_recruit_01_idle.webp' for h in ['dog','cat','frog','owl']],
 'raccoon_armadillo':[Path('/workspace/art-originals/codex-225/art/combat/source/recruits_redraw_20261028')/f'{a}/{b}-idle.png' for a,b in [('raccoon','rato'),('armadillo','tatu')]]}
for key,paths in refs.items():
 sheet=Image.new('RGB',(len(paths)*460,800),(221,216,207));records=[]
 for i,p in enumerate(paths):
  im=Image.open(p).convert('RGBA');im=im.crop(im.getbbox());im.thumbnail((440,740),Image.Resampling.LANCZOS);sheet.paste(im,(i*460+(460-im.width)//2,770-im.height),im)
  records.append({'file':str(p.relative_to(repo)) if p.is_relative_to(repo) else '/'.join(p.parts[-2:]),'sha256':sha(p),'origin':'main 5bb29281' if p.is_relative_to(repo) else 'approved #225 / codex-pr229-originals'})
 sheet.save(out/f'{key}_originals.webp',quality=90,method=6);assets[key]['references']=records
(out/'assets.json').write_text(json.dumps({'issue':243,'stage':'costume concepts pending Lucas approval; no production poses','source_tag':None,'base_commit':'5bb29281c578f37f135a859a3d0073cd2f083f58','assets':assets},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'images':len(list(out.glob('*.webp'))),'bytes':sum(p.stat().st_size for p in out.glob('*.webp'))}))
