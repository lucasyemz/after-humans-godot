"""Derivados leves dos caixotes já aprovados; nenhuma imagem de origem nova no Git."""
import sys,json,hashlib,math
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'art/ui/loop';HERE=Path(__file__).resolve().parent
OUT.mkdir(exist_ok=True,parents=True);record={};raws={}
for state in ['closed','open']:
 p=ROOT/f'art/street/search_props/street_crates_{state}.webp';im=Image.open(p).convert('RGBA');raws[state]=(p,im,im.getbbox())
scale=min(176/(b[3]-b[1]) for _,_,b in raws.values())
for state,(p,im,bbox) in raws.items():
 anchor=((bbox[0]+bbox[2])/2,bbox[3]);a=im.transform((224,192),Image.Transform.AFFINE,(1/scale,0,anchor[0]-112/scale,0,1/scale,anchor[1]-184/scale),Image.Resampling.BICUBIC)
 box=a.getbbox();shift=184-box[3];fixed=Image.new('RGBA',(224,192));fixed.alpha_composite(a,(0,shift));fixed.save(OUT/f'cargo_{state}.webp',lossless=True,method=6)
 record[state]={'source':str(p.relative_to(ROOT)),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_bbox':list(bbox),'source_anchor':list(anchor),'uniform_scale':scale,'post_shift_y':shift,'file':f'art/ui/loop/cargo_{state}.webp','canvas':[224,192],'anchor':[112,184],'alpha_bbox':list(fixed.getbbox())}
for filled in [False,True]:
 im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im);points=[]
 for i in range(10):
  r=56 if i%2==0 else 25;a=-math.pi/2+i*math.pi/5;points.append((64+math.cos(a)*r,64+math.sin(a)*r))
 d.polygon(points,fill='white' if filled else None);d.line(points+[points[0]],fill='white',width=8,joint='curve');im=im.resize((32,32),Image.Resampling.LANCZOS);im.save(OUT/f'star_{"filled" if filled else "outline"}.webp',lossless=True,method=6)
(HERE/'assets.json').write_text(json.dumps({'issue':96,'cargo':record,'star_canvas':[32,32],'source_art_unchanged':True},ensure_ascii=False,indent=2)+'\n')
print('Cargo224x192, anchor112,184; stars32x32')
