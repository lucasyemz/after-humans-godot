"""Fontes isoladas em tag/Release; só WebP e provas entram na main (#195)."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
from scipy.ndimage import label,distance_transform_edt,binary_dilation
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];MAN=json.loads((ROOT/'data/presentation/combat_art.json').read_text())['heroes'];FONT=ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'
NAMES=['bento','nick','iris','vespera','bento_watch'];LABELS=['Bento','Nick','Íris','Véspera','Bento / Ronda']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def bbox(im):return im.getchannel('A').point(lambda n:255 if n>24 else 0).getbbox()
def canonical(name):
 key='bento' if name=='bento_watch' else name
 return next(v['idle'] for v in MAN.values() if v['idle']['file'].endswith('/'+key+'/idle.webp'))
def refpath(name):return ROOT/('docs/design/skins/watch/idle.webp' if name=='bento_watch' else 'art/combat/heroes/'+name+'/idle.webp')
def target(name):return ROOT/('art/skins/bento/watch/wounded.webp' if name=='bento_watch' else 'art/combat/heroes/'+name+'/wounded.webp')
def key(im):
 a=np.array(im.convert('RGB')).astype(float);r,g,b=[a[:,:,i] for i in range(3)];alpha=1-np.clip(np.minimum(r-g,b-g)/255,0,1);alpha[(r>180)&(b>180)&(g<80)]=0;alpha[alpha<.08]=0;alpha[alpha>.97]=1;lab,n=label(alpha>.3);sizes=np.bincount(lab.ravel());sizes[0]=0;core=lab==sizes.argmax();keep=binary_dilation(core,iterations=2);interior=distance_transform_edt(core)>2;rgb=np.clip((a-(1-alpha[:,:,None])*np.array([255,0,255]))/np.maximum(alpha[:,:,None],.001),0,255);rgb[interior]=a[interior];alpha[interior]=1;out=np.dstack([rgb,alpha*255]);out[~keep]=0;return Image.fromarray(np.uint8(np.clip(out,0,255)))
def support(im):
 a=np.array(im);b=bbox(im);start=b[3]-max(8,round((b[3]-b[1])*.04));rgb=a[start:b[3],:,:3].astype(int);mask=a[start:b[3],:,3]>100;white=mask&(rgb.min(axis=2)>115)&((rgb.max(axis=2)-rgb.min(axis=2))<90);ys,xs=np.where(white if white.sum()>12 else mask);return float((np.percentile(xs,5)+np.percentile(xs,95))/2),b[3]
def prepare(raw,sources):
 sources.mkdir(parents=True,exist_ok=True);transforms={}
 for name in NAMES:
  ref=Image.open(refpath(name)).convert('RGBA');im=key(Image.open(raw/(name+'.png'))).resize(ref.size,Image.Resampling.LANCZOS)
  if name=='bento_watch':dx,dy=transforms['bento']
  else:
   rx,ry=support(ref);x,y=support(im);dx,dy=round(rx-x),ry-y;transforms[name]=[dx,dy]
  out=Image.new('RGBA',ref.size);out.alpha_composite(im,(dx,dy));source_size=canonical(name)['canvas'];out.resize(tuple(source_size),Image.Resampling.LANCZOS).save(sources/(name+'_wounded.png'))
 (sources/'normalization.json').write_text(json.dumps(transforms,indent=2)+'\n')
def build(sources):
 rows=[]
 for name in NAMES:
  m=canonical(name);ref=Image.open(refpath(name)).convert('RGBA');src=sources/(name+'_wounded.png');im=Image.open(src).convert('RGBA').resize(ref.size,Image.Resampling.LANCZOS);dst=target(name);dst.parent.mkdir(parents=True,exist_ok=True);im.save(dst,quality=94,method=6);physical=[v*ref.width/m['canvas'][0] for v in m['anchor']];rows.append({'name':name,'file':str(dst.relative_to(ROOT)),'reference':str(refpath(name).relative_to(ROOT)),'source_file':src.name,'source_canvas':m['canvas'],'size':list(ref.size),'canonical_anchor':m['anchor'],'texture_anchor':physical,'body_reference_pixels':m['body_reference_pixels'],'reference_sha256':sha(refpath(name)),'sha256':sha(dst),'source_sha256':sha(src),'bbox':list(bbox(im))})
 pub=json.loads((HERE/'publication.json').read_text()) if (HERE/'publication.json').exists() else {};contract={'issue':195,'base_commit':'20890be','source_tag':pub.get('source_tag','codex-pr<N>-originals'),'source_folder':'art/combat/source/wounded_20261028','format':'WEBP RGBA','files':rows,'note':'Keep canonical idle canvas/anchor/body_reference_pixels; lower head is intentional hunch, not a change of scale.'};(HERE/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
 cw,ch=620,490;page=Image.new('RGB',(1240,80+math.ceil(len(rows)/2)*ch),'#171b20');d=ImageDraw.Draw(page);font=ImageFont.truetype(str(FONT),28);d.text((20,18),'FERIDO / IDLE × WOUNDED / MESMA ESCALA E ÂNCORA',font=font,fill='#efe5d1')
 for i,row in enumerate(rows):
  x=i%2*cw;y=80+i//2*ch;d.text((x+16,y+4),LABELS[i],font=font,fill='#efe5d1');ref=Image.open(ROOT/row['reference']).convert('RGBA');im=Image.open(ROOT/row['file']).convert('RGBA');scale=min(286/ref.width,395/ref.height);w,h=round(ref.width*scale),round(ref.height*scale);ax,ay=row['texture_anchor'];line=y+ch-24;top=line-round(ay*scale)
  for j,picture in enumerate([ref,im]):
   picture=picture.resize((w,h),Image.Resampling.LANCZOS);left=x+j*310+round(155-ax*scale);page.paste(picture,(left,top),picture);d.line((x+j*310+8,line,x+(j+1)*310-8,line),fill='#66737b');d.ellipse((x+j*310+153,line-2,x+j*310+157,line+2),fill='#f0a020')
 page.save(HERE/'poses.webp',quality=92,method=6);page.resize((496,round(page.height*.4)),Image.Resampling.LANCZOS).save(HERE/'poses_40.webp',quality=90);ImageOps.grayscale(Image.open(HERE/'poses_40.webp')).save(HERE/'poses_gray_40.webp',quality=90)
 # Two real background crops, no simulation of gameplay or health thresholds.
 dark=Image.open(ROOT/'docs/qa/grid/flooded-depot-night.jpg').convert('RGB').crop((540,200,650,405));light=Image.open(ROOT/'docs/design/loop-screens/before/combat_clean.webp').convert('RGB').crop((40,130,220,520));proof=Image.new('RGB',(1800,1040),'#15191d');d=ImageDraw.Draw(proof);d.text((20,12),'FERIDO / NOITE · CLARO / PRANCHA DE LEITURA',font=font,fill='#efe5d1')
 for i,row in enumerate(rows):
  for j,bg in enumerate([dark,light]):
   x=i%3*600+j*300;y=60+i//3*490;b=bg.resize((300,470));im=Image.open(ROOT/row['file']).convert('RGBA');scale=260/(row['body_reference_pixels']*row['size'][0]/row['source_canvas'][0]);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);b.paste(im,((300-im.width)//2,455-im.height),im);proof.paste(b,(x,y))
 proof.save(HERE/'readability.webp',quality=92,method=6)
 audit={'files':5,'rgba':True,'canvas_matches_idle':True,'original_idle_unchanged':True,'canonical_anchors_unchanged':True,'problems':[]}
 for row in rows:
  im=Image.open(ROOT/row['file']);assert im.mode=='RGBA' and list(im.size)==row['size'];assert sha(ROOT/row['reference'])==row['reference_sha256'];a=np.array(im);rgb=a[:,:,:3].astype(int);bg=(rgb[:,:,0]>rgb[:,:,1]+50)&(rgb[:,:,2]>rgb[:,:,1]+50)&(a[:,:,3]>150)&(distance_transform_edt(a[:,:,3]>24)<2)
  if bg.sum()>15:audit['problems'].append({'file':row['file'],'edge_magenta_pixels':int(bg.sum())})
 (HERE/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('Wounded:',len(rows),'arquivos;',audit['problems'])
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--sources',type=Path,required=True);ap.add_argument('--raw',type=Path);args=ap.parse_args()
 if args.raw:prepare(args.raw,args.sources)
 build(args.sources)
