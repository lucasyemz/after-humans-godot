"""Recorta os atlas editados sem recentrar as peças; todas compartilham uma transformação."""
import argparse,json,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageOps,ImageDraw
from scipy.ndimage import label,distance_transform_edt,binary_dilation
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];REFS=json.loads((HERE/'references.json').read_text())
def box(im):return im.getchannel('A').point(lambda n:255 if n>24 else 0).getbbox()
def key(im,multi=False):
 a=np.array(im.convert('RGB')).astype(float);r,g,b=[a[:,:,i] for i in range(3)];alpha=1-np.clip(np.minimum(r-g,b-g)/255,0,1);alpha[(r>180)&(b>180)&(g<80)]=0;alpha[alpha<.08]=0;alpha[alpha>.97]=1;lab,n=label(alpha>.3);sizes=np.bincount(lab.ravel());sizes[0]=0;core=(sizes[lab]>25) if multi else (lab==sizes.argmax());keep=binary_dilation(core,iterations=2);interior=distance_transform_edt(core)>2;rgb=np.clip((a-(1-alpha[:,:,None])*np.array([255,0,255]))/np.maximum(alpha[:,:,None],.001),0,255);rgb[interior]=a[interior];alpha[interior]=1;out=np.dstack([rgb,alpha*255]);out[~keep]=0;return Image.fromarray(np.uint8(np.clip(out,0,255)))
def clean_chroma(im):
 a=np.array(im);rgb=a[:,:,:3].astype(int);bad=(rgb[:,:,0]>rgb[:,:,1]+65)&(rgb[:,:,2]>rgb[:,:,1]+65)&(rgb[:,:,0]>120)&(rgb[:,:,2]>120);lum=np.uint8(rgb.mean(axis=2));a[bad,:3]=np.repeat(lum[bad,None],3,axis=1);a[a[:,:,3]==0]=0;return Image.fromarray(a)
def foot(im):
 a=np.array(im);b=box(im);start=b[3]-max(8,round((b[3]-b[1])*.04));ys,xs=np.where(a[start:b[3],:,3]>100);return float((np.percentile(xs,3)+np.percentile(xs,97))/2),b[3]
def frame(im,size,scale,dx,dy):
 im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);out=Image.new('RGBA',size);out.alpha_composite(im,(dx,dy));return out
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--raw',required=True,type=Path);ap.add_argument('--sources',required=True,type=Path);args=ap.parse_args();transforms={}
 for row in REFS:
  name=row['name'];ref=Image.open(ROOT/row['idle']['file'].removeprefix('res://')).convert('RGBA');sheet=Image.open(args.raw/(name+'_body.png')).convert('RGB');parts=[key(sheet.crop((round(i*sheet.width/3),0,round((i+1)*sheet.width/3),sheet.height)),i==2).resize(ref.size,Image.Resampling.LANCZOS) for i in range(3)];b0=box(ref);b1=box(parts[0]);scale=(b0[3]-b0[1])/(b1[3]-b1[1]);scaled=parts[0].resize((round(ref.width*scale),round(ref.height*scale)),Image.Resampling.LANCZOS);rx,ry=foot(ref);x,y=foot(scaled);dx,dy=round(rx-x),ry-y;transforms[name]={'scale':scale,'translation':[dx,dy]};folder=args.sources/name;folder.mkdir(parents=True,exist_ok=True)
  for i,keyname in enumerate(['base_a','base_b','clothes']):
   out=frame(parts[i],ref.size,scale,dx,dy)
   if i==2:
    a=out.getchannel('A');mask=Image.new('L',(ref.width*4,ref.height*4));draw=ImageDraw.Draw(mask);occlusion=json.loads((HERE/'occlusion_masks.json').read_text()).get(name,{})
    for polygons in occlusion.values():
     for polygon in polygons:draw.polygon([(x*4,y*4) for x,y in polygon],fill=255)
    mask=mask.resize(ref.size,Image.Resampling.LANCZOS);a=Image.fromarray(np.uint8(np.asarray(a,dtype=float)*(1-np.asarray(mask,dtype=float)/255)));out=ImageOps.grayscale(out).convert('RGBA');out.putalpha(a)
   clean_chroma(out.resize(tuple(row['idle']['canvas']),Image.Resampling.LANCZOS)).save(folder/(keyname+'.png'))
  base=Image.open(folder/'base_a.png').convert('RGBA');cloth=Image.open(folder/'clothes.png').convert('RGBA');base.alpha_composite(cloth);base=base.resize(ref.size,Image.Resampling.LANCZOS);bg=Image.new('RGBA',base.size,'#ff00ff');bg.alpha_composite(base);bg.convert('RGB').save(args.raw/(name+'_composed.png'))
 (args.sources/'normalization.json').write_text(json.dumps(transforms,indent=2)+'\n')
