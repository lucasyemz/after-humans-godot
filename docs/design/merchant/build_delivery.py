"""Fontes normalizadas da #218 -> WebP, contrato e prancha; sem dados de produção."""
import argparse,hashlib,json,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'docs/design/recruit_layers'))
from prepare_layers import key,box,clean_chroma
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def head_width(im):
 b=box(im);region=im.crop((0,b[1],im.width,b[1]+round((b[3]-b[1])*.10)));h=box(region);return h[2]-h[0]
def sole_anchor(im):
 a=np.array(im)[:,:,3];b=box(im);ys,xs=np.where((a[max(0,b[3]-24):b[3],:] >100)&(np.arange(im.width)[None,:] > im.width*.35));return [round(float((np.percentile(xs,3)+np.percentile(xs,97))/2),1),1429]
def prepare(raw,sources):
 idle=Image.open(sources/'idle.png').convert('RGBA');target=head_width(idle);registration=json.loads((sources/'registration.json').read_text());registration['head_reference_width']=target;registration['poses']={}
 for state in ['walk','trade']:
  im=key(Image.open(raw/(state+'.png')),True);b=box(im);head=head_width(im);scale=target/head;crop=im.crop(b);crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
  if crop.width>1070 or crop.height>1425:raise ValueError(f'{state}: quadro excedido ao manter escala da cabeça: {crop.size}')
  out=Image.new('RGBA',(1086,1448));paste=[(1086-crop.width)//2,1429-crop.height];out.alpha_composite(crop,tuple(paste));out=clean_chroma(out);out.save(sources/(state+'.png'));registration['poses'][state]={'raw_bbox':b,'head_reference_width':target,'raw_head_width':head,'scale':scale,'paste':paste,'anchor':sole_anchor(out),'head_width_after':head_width(out)}
 portrait=key(Image.open(raw/'portrait.png'),True);portrait=portrait.crop(box(portrait));portrait=ImageOps.contain(portrait,(944,944),Image.Resampling.LANCZOS);out=Image.new('RGBA',(1024,1024));out.alpha_composite(portrait,((1024-portrait.width)//2,40));clean_chroma(out).save(sources/'portrait.png');(sources/'registration.json').write_text(json.dumps(registration,indent=2)+'\n')
def build(sources):
 meta=json.loads((sources/'registration.json').read_text());pub=json.loads((HERE/'publication.json').read_text()) if (HERE/'publication.json').exists() else {};assets={};checks=[]
 for state in ['idle','walk','trade','portrait']:
  src=sources/(state+'.png');im=Image.open(src).convert('RGBA');size=(256,256) if state=='portrait' else (543,724);im=clean_chroma(im.resize(size,Image.Resampling.LANCZOS));dest=ROOT/('art/ui/portraits/merchant.webp' if state=='portrait' else 'art/civilians/merchant/'+state+'.webp');dest.parent.mkdir(parents=True,exist_ok=True);im.save(dest,lossless=True,method=6);anchor=meta['anchor'] if state=='idle' else meta.get('poses',{}).get(state,{}).get('anchor');asset={'file':'res://'+str(dest.relative_to(ROOT)),'texture_canvas':list(size),'source_canvas':[1024,1024] if state=='portrait' else meta['canvas'],'source_file':src.name,'source_sha256':sha(src),'sha256':sha(dest),'alpha_bbox':list(box(im)),'nine_slice':None}
  if state!='portrait':asset.update(canvas=meta['canvas'],anchor=anchor,texture_anchor=[v*.5 for v in anchor],body_reference_pixels=1419,height_m=1.72)
  assets[state]=asset;arr=np.array(im).astype(int);r,g,b,a=[arr[:,:,i] for i in range(4)];bad=int(((r>g+65)&(b>g+65)&(r>120)&(b>120)&(a>24)).sum());check={'file':asset['file'],'rgba':Image.open(dest).mode=='RGBA','size':list(Image.open(dest).size)==list(size),'magenta_pixels':bad,'source_size':list(Image.open(src).size)==asset['source_canvas']};checks.append(check);assert check['rgba'] and check['size'] and check['source_size'] and bad==0
  if state!='portrait':assert abs(box(im)[3]-asset['texture_anchor'][1])<=1
 c={'issue':218,'base_commit':'ff8fc83','asset_group':'merchant','source_tag':pub.get('source_tag','codex-pr<N>-originals'),'source_folder':'art/combat/source/merchant_20261028','body_reference':'Same 1.72m and 1419 source pixels as Bento idle. Anchor measured at ground contact for each pose.','registration':meta,'portrait_fallback_face_box_source_idle':[480,0,390],'portrait_fallback_face_box_texture_idle':[240,0,195],'assets':assets};(HERE/'contract.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');(HERE/'audit.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
 page=Image.new('RGB',(1800,980),'#1b2025');d=ImageDraw.Draw(page);font=ImageFont.truetype(str(ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'),30);d.text((20,12),'MERCADOR / DESENHO ORIGINAL / MESMA ALTURA DO BENTO',font=font,fill='#efe5d1')
 manifest=json.loads((ROOT/'data/presentation/combat_art.json').read_text());bento=manifest['heroes']['hero_cao_bento']['idle'];items=[('BENTO ATUAL',bento)]+[(label,assets[state]) for state,label in [('idle','DE PÉ'),('walk','ANDANDO'),('trade','NEGOCIANDO')]]
 for i,(label,art) in enumerate(items):
  im=Image.open(ROOT/art['file'].removeprefix('res://')).convert('RGBA');ratio=im.width/art['canvas'][0];scale=520/(art['body_reference_pixels']*ratio);ax,ay=[v*ratio for v in art['anchor']];thumb=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);x=i*450;line=740;page.paste(thumb,(x+round(250-ax*scale),line-round(ay*scale)),thumb);d.text((x+18,90),label,font=font,fill='#efe5d1');d.line((x+8,line,x+442,line),fill='#66737b');d.ellipse((x+248,line-2,x+252,line+2),fill='#e9c47c')
 portrait=Image.open(ROOT/assets['portrait']['file'].removeprefix('res://')).convert('RGBA');page.paste(portrait.resize((180,180)),(20,784),portrait.resize((180,180)));d.text((225,800),'RETRATO 256×256 / FUNDO TRANSPARENTE',font=font,fill='#efe5d1');d.text((225,850),'Sementes, sucata e roupa remendada; sem marcas ou texto.',font=font,fill='#a69a84');page.save(HERE/'poses.webp',quality=94,method=6);page.resize((720,392),Image.Resampling.LANCZOS).save(HERE/'poses_40.webp',quality=92);ImageOps.grayscale(Image.open(HERE/'poses_40.webp')).save(HERE/'poses_gray_40.webp',quality=92);print('Mercador: três poses, um retrato, alfa e contratos conferidos.')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--sources',required=True,type=Path);p.add_argument('--raw',type=Path);a=p.parse_args()
 if a.raw:prepare(a.raw,a.sources)
 build(a.sources)
