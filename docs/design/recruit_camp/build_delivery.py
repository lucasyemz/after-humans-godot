"""WebP/contrato e prancha da #210 a partir dos PNG normalizados da tag."""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'docs/design/recruit_layers'))
from prepare_layers import key,box,clean_chroma
LABELS={'dog':'Cão','cat':'Gato','frog':'Sapo','owl':'Coruja','raccoon':'Guaxinim','armadillo':'Tatu'}
HEIGHTS={'dog':1.72,'cat':1.5,'frog':1.38,'owl':1.66,'raccoon':1.3,'armadillo':1.35}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare(raw,sources):
 manifest=json.loads((ROOT/'data/presentation/combat_art.json').read_text())
 for name in ['raccoon','armadillo']:
  idle=manifest['recruits'][name+'_recruit_01']['idle'];ref=Image.open(ROOT/idle['file'].removeprefix('res://'));ratio=ref.width/idle['canvas'][0];ax,ay=[v*ratio for v in idle['anchor']]
  for state in ['seat','sleep']:
   im=key(Image.open(raw/(name+'_'+state+'.png')),True);im=im.crop(box(im));max_width = (440 if name=="raccoon" else 405) if state=="sleep" else 550;scale=min(max_width/im.width,.45 if name=="raccoon" else .5);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);out=Image.new('RGBA',ref.size);out.alpha_composite(im,(round(ax-im.width/2),round(ay)-im.height));out=clean_chroma(out);sources.mkdir(parents=True,exist_ok=True);out.resize(tuple(idle['canvas']),Image.Resampling.LANCZOS).save(sources/(name+'_'+state+'.png'))
def build(sources):
 manifest=json.loads((ROOT/'data/presentation/combat_art.json').read_text());pub=json.loads((HERE/'publication.json').read_text()) if (HERE/'publication.json').exists() else {};poses=[];checks=[]
 contract=json.loads((ROOT/'docs/design/camp/contract.json').read_text());contract['poses']=[p for p in contract['poses'] if p.get('recruit_id') not in ['raccoon_recruit_01','armadillo_recruit_01']]
 for name in ['raccoon','armadillo']:
  actor=name+'_recruit_01';idle=manifest['recruits'][actor]['idle'];ref=Image.open(ROOT/idle['file'].removeprefix('res://'));ratio=ref.width/idle['canvas'][0]
  for state in ['seat','sleep']:
   src=sources/(name+'_'+state+'.png');im=clean_chroma(Image.open(src).convert('RGBA').resize(ref.size,Image.Resampling.LANCZOS));dest=ROOT/'art/camp'/(actor+'_'+state+'.webp');im.save(dest,lossless=True,method=6);official={k:idle[k] for k in ['canvas','anchor','body_reference_pixels']};official['file']='res://'+str(dest.relative_to(ROOT));pose={'recruit_id':actor,'state':state,'file':str(dest.relative_to(ROOT)),'texture_canvas':list(ref.size),'texture_anchor':[v*ratio for v in idle['anchor']],'texture_body_reference_pixels':idle['body_reference_pixels']*ratio,'manifest_canvas':idle['canvas'],'manifest_anchor':idle['anchor'],'body_reference_pixels':idle['body_reference_pixels'],'alpha_bbox':list(box(im)),'nine_slice':None,'use':'show_art','show_art':official,'source_of_truth':'data/presentation/combat_art.json:recruits.'+actor+'.idle','issue':210,'source_file':src.name,'source_sha256':sha(src),'sha256':sha(dest),'reference_sha256':sha(ROOT/idle['file'].removeprefix('res://'))};poses.append(pose);contract['poses'].append(pose);checks.append({'file':pose['file'],'rgba':Image.open(dest).mode=='RGBA','size':Image.open(dest).size==ref.size,'source_canvas':list(Image.open(src).size)==idle['canvas'],'support_delta_px':round(box(im)[3]-pose['texture_anchor'][1],3)})
 (ROOT/'docs/design/camp/contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
 delivery={'issue':210,'base_commit':'ff8fc83','source_tag':pub.get('source_tag','codex-pr<N>-originals'),'source_folder':'art/combat/source/recruit_camp_20261028','poses':poses};(HERE/'contract.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n');(HERE/'audit.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
 page=Image.new('RGB',(1920,1320),'#1b2025');draw=ImageDraw.Draw(page);font=ImageFont.truetype(str(ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'),28)
 for row,state in enumerate(['idle','seat','sleep']):
  y=row*440;draw.text((16,y+8),{'idle':'LUTA ATUAL','seat':'SENTADO NO CHÃO','sleep':'DORMINDO NO CHÃO'}[state],font=font,fill='#efe5d1');line=y+406
  for col,(name,label) in enumerate(LABELS.items()):
   actor=name+'_recruit_01';idle=manifest['recruits'][actor]['idle'];ratio=Image.open(ROOT/idle['file'].removeprefix('res://')).width/idle['canvas'][0];art=idle if state=='idle' else next(p['show_art'] for p in contract['poses'] if p.get('recruit_id')==actor and p['state']==state);im=Image.open(ROOT/art['file'].removeprefix('res://')).convert('RGBA');s=160*HEIGHTS[name]/(idle['body_reference_pixels']*ratio);ax,ay=[v*ratio for v in art['anchor']];thumb=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);x=col*320;page.paste(thumb,(x+round(160-ax*s),line-round(ay*s)),thumb);draw.line((x+8,line,x+312,line),fill='#66737b');draw.ellipse((x+158,line-2,x+162,line+2),fill='#e9c47c');draw.text((x+18,y+56),label,font=font,fill='#efe5d1')
 page.save(HERE/'poses.webp',quality=94,method=6);page.resize((768,528),Image.Resampling.LANCZOS).save(HERE/'poses_40.webp',quality=92);ImageOps.grayscale(Image.open(HERE/'poses_40.webp')).save(HERE/'poses_gray_40.webp',quality=92)
 print('Quatro poses exportadas; contrato de acampamento estendido sem alterar dados do jogo.')
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--sources',required=True,type=Path);ap.add_argument('--raw',type=Path);a=ap.parse_args()
 if a.raw:prepare(a.raw,a.sources)
 build(a.sources)
