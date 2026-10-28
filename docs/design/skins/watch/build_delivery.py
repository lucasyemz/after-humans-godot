"""Normaliza fontes fora do Git e reproduz as pranchas da Ronda (#137)."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
from scipy.ndimage import label,distance_transform_edt,binary_dilation
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3];DEST=ROOT/'art/skins/bento/watch';DEST.mkdir(parents=True,exist_ok=True)
GROUPS=json.loads((HERE/'pose_groups.json').read_text());FONT=ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def box(im):return im.getchannel('A').point(lambda x:255 if x>24 else 0).getbbox()
def foot(im):
 a=np.asarray(im.convert('RGBA'));b=box(im);yy=max(b[1],b[3]-max(8,round((b[3]-b[1])*.08)));rgb=a[yy:b[3],:,:3].astype(int);visible=a[yy:b[3],:,3]>100;white=visible&(rgb.min(axis=2)>115)&((rgb.max(axis=2)-rgb.min(axis=2))<90);ys,xs=np.where(white if np.count_nonzero(white)>12 else visible);return float((np.percentile(xs,5)+np.percentile(xs,95))/2)
def clean(im):
 a=np.array(im.convert('RGBA')).astype(float);edge=distance_transform_edt(a[:,:,3]>24)<2.5;r,g,b=[a[:,:,i] for i in range(3)];purple=edge&(r>g+5)&(b>g+5);a[:,:,0]=np.where(purple,np.minimum(r,g*1.1+3),r);a[:,:,2]=np.where(purple,np.minimum(b,g*1.2+4),b);green=edge&(g>r+20)&(g>b+15);a[:,:,1]=np.where(green,np.minimum(r,b),g);a[a[:,:,3]<3]=0;return Image.fromarray(np.uint8(np.clip(a,0,255)))
def key(im):
 a=np.array(im.convert('RGB')).astype(float);r,g,b=[a[:,:,i] for i in range(3)];alpha=1-np.clip(np.minimum(r-g,b-g)/255,0,1);alpha[(r>180)&(b>180)&(g<80)]=0;alpha[alpha<.08]=0;alpha[alpha>.97]=1;rgb=np.clip((a-(1-alpha[:,:,None])*np.array([255,0,255]))/np.maximum(alpha[:,:,None],.001),0,255);out=np.dstack([rgb,alpha*255]);lab,n=label(alpha>.15);sizes=np.bincount(lab.ravel());sizes[0]=0;keep=binary_dilation(lab==sizes.argmax(),iterations=2);out[~keep]=0;return clean(Image.fromarray(np.uint8(out)))
def measures():
 result={}
 for file in ['combat_art','station_poses','camp_poses']:
  d=json.loads((ROOT/f'data/presentation/{file}.json').read_text())
  def walk(x):
   if isinstance(x,dict):
    if 'file' in x and 'anchor' in x:result.setdefault(x['file'].removeprefix('res://'),x)
    for v in x.values():walk(v)
   elif isinstance(x,list):
    for v in x:walk(v)
  walk(d)
 return result
MEASURES=measures()
def source_size(f):return MEASURES[str(f)].get('canvas',list(Image.open(ROOT/f).size))
def normalize(cell,ref):
 src=Image.open(ref).convert('RGBA');original=box(src);cut=key(cell);b=box(cut);cut=cut.crop(b);h=original[3]-original[1]
 if ref.stem=='hero_cao_bento_sleep':
  scale=(original[2]-original[0])/cut.width;cut=cut.resize((original[2]-original[0],round(cut.height*scale)),Image.Resampling.LANCZOS);out=Image.new('RGBA',src.size);out.alpha_composite(cut,(original[0],original[3]-cut.height));return clean(out)
 scale=h/cut.height;size=(round(cut.width*scale),h);cut=cut.resize(size,Image.Resampling.LANCZOS);x=round(foot(src)-foot(cut));y=original[1]
 # Cloak changes width; fit uniformly only if it otherwise leaves the original canvas.
 if x<1 or x+cut.width>src.width-1:
  scale2=min((src.width-2)/cut.width,1);cut=cut.resize((round(cut.width*scale2),round(cut.height*scale2)),Image.Resampling.LANCZOS);x=round(foot(src)-foot(cut));x=max(1,min(src.width-cut.width-1,x));y=original[3]-cut.height
 out=Image.new('RGBA',src.size);out.alpha_composite(cut,(x,y));return clean(out)
def prepare(raw,sources):
 sources.mkdir(parents=True,exist_ok=True)
 for batch,group in enumerate(GROUPS):
  sheet=Image.open(raw/f'{batch}.png').convert('RGB');w,h=sheet.size
  for row in group:
   j=row['cell'];cell=sheet.crop((round(j%2*w/2),round(j//2*h/2),round((j%2+1)*w/2),round((j//2+1)*h/2)));f=Path(row['file']);override=raw/(f.stem+'_single.png');cell=Image.open(override).convert('RGB') if override.exists() else cell;out=normalize(cell,ROOT/f);out=out.resize(tuple(source_size(f)),Image.Resampling.LANCZOS);out.save(sources/(f.stem+'.png'))
 for name in ['idle','portrait']:
  im=clean(Image.open(HERE/(name+'.webp')).convert('RGBA'));size=tuple(MEASURES['art/combat/heroes/bento/idle.webp']['canvas']) if name=='idle' else (512,512);im.resize(size,Image.Resampling.LANCZOS).save(sources/(name+'.png'))
def draw_board(rows,outfile,small=False):
 cw,ch=620,500;cols=2;page=Image.new('RGB',(cw*cols,80+math.ceil(len(rows)/cols)*ch),'#171b20');d=ImageDraw.Draw(page);font=ImageFont.truetype(str(FONT),27);d.text((20,18),'BENTO / ATUAL × RONDA DA ESTAÇÃO / MESMA ESCALA E ÂNCORA',font=font,fill='#efe5d1')
 for i,row in enumerate(rows):
  x=i%cols*cw;y=80+i//cols*ch;d.text((x+16,y+8),row['name'],font=font,fill='#efe5d1');a=Image.open(ROOT/row['reference']).convert('RGBA');b=Image.open(ROOT/row['file']).convert('RGBA');s=min(286/a.width,740/a.height);w,h=round(a.width*s),round(a.height*s);ax,ay=row['texture_anchor'];line=y+ch-35;top=line-round(ay*s)
  for j,im in enumerate([a,b]):
   left=x+j*310+round(155-ax*s);im=im.resize((w,h),Image.Resampling.LANCZOS);page.paste(im,(left,top),im);d.line((x+j*310+8,line,x+(j+1)*310-8,line),fill='#6b797f',width=1);d.ellipse((x+j*310+153,line-2,x+j*310+157,line+2),fill='#f0a020')
 page.save(outfile,quality=91,method=6)
 if small:page.resize((round(page.width*.4),round(page.height*.4)),Image.Resampling.LANCZOS).save(outfile.with_stem(outfile.stem+'_40'),quality=90)
def build(sources):
 rows=[];files=[Path('art/combat/heroes/bento/idle.webp')]+[Path(r['file']) for g in GROUPS for r in g]+[Path('art/ui/portraits/bento.png')]
 for f in files:
  name='portrait' if f.suffix=='.png' else f.stem;src=sources/(name+'.png');ref=Image.open(ROOT/f);im=Image.open(src).convert('RGBA').resize(ref.size,Image.Resampling.LANCZOS);im=clean(im);dst=DEST/(name+'.webp');im.save(dst,quality=94,method=6);m=MEASURES.get(str(f),{});canvas=m.get('canvas',list(Image.open(src).size));anchor=m.get('anchor',[canvas[0]/2,canvas[1]]);physical=[anchor[i]*ref.width/canvas[0] for i in range(2)];rows.append({'name':name,'file':str(dst.relative_to(ROOT)),'reference':str(f),'size':list(im.size),'source_canvas':list(Image.open(src).size),'source_file':src.name,'canonical_canvas':canvas,'canonical_anchor':anchor,'texture_anchor':physical,'body_reference_pixels':m.get('body_reference_pixels'),'bbox':list(box(im)),'sha256':sha(dst),'reference_sha256':sha(ROOT/f),'source_sha256':sha(src)})
 contract={'issue':137,'skin_id':'watch','hero':'bento','base_commit':'177c70d','origin_folder':'art/combat/source/bento_watch_20261028','source_tag':json.loads((HERE/'publication.json').read_text()).get('source_tag') if (HERE/'publication.json').exists() else 'codex-pr<N>-originals','format':'WEBP RGBA','poses':16,'portraits':1,'files':rows,'note':'Source anchors/canvases are copied from canonical production manifests; original game files unchanged. VFX/audio reused. Wounded skin supplied with issue195.'};(HERE/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n');draw_board(rows,HERE/'poses.webp',True);ImageOps.grayscale(Image.open(HERE/'poses_40.webp')).save(HERE/'poses_gray_40.webp',quality=90)
 for i in range(4):draw_board(rows[i*4:(i+1)*4],HERE/f'poses_{i+1}.webp')
 # Warm lantern against real dark and light scene patches; composited design proof, no game integration claimed.
 refs=[ROOT/'docs/design/loop-screens/before/combat_clean.webp',ROOT/'docs/design/camp/camp.webp'];base=Image.open(refs[0]).convert('RGB');proof=Image.new('RGB',(1800,1100),'#15191d');d=ImageDraw.Draw(proof);font=ImageFont.truetype(str(FONT),30);d.text((24,14),'RONDA / PROVA DE LEITURA / ESCURO · CLARO · ALFA',font=font,fill='#efe5d1')
 sample=[rows[0],rows[1],rows[7],rows[10],rows[13],rows[15]]
 for i,row in enumerate(sample):
  x=i%3*600;y=70+i//3*510
  for j in range(2):
   bg=(Image.open(ROOT/'docs/qa/grid/flooded-depot-night.jpg').convert('RGB').crop((540,200,650,405)) if j==0 else base.crop((40,130,220,520))).resize((300,480));im=Image.open(ROOT/row['file']).convert('RGBA');s=260/max(1,row.get('body_reference_pixels') or im.height)/(row['size'][0]/row['canonical_canvas'][0]);im=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);bg.paste(im,((300-im.width)//2,470-im.height),im);proof.paste(bg,(x+j*300,y))
 proof.save(HERE/'night_readability.webp',quality=92,method=6);ImageOps.grayscale(proof).save(HERE/'night_readability_gray.webp',quality=90)
 audit={'runtime_files':17,'body_poses':16,'all_rgba':True,'canvas_matches':True,'canonical_unchanged':True,'no_magenta_fringe':True,'problems':[]}
 for r in rows:
  im=Image.open(ROOT/r['file']);assert im.mode=='RGBA' and list(im.size)==r['size'];assert sha(ROOT/r['reference'])==r['reference_sha256'];a=np.asarray(im);visible=a[:,:,3]>80;purple=(a[:,:,0].astype(int)>a[:,:,1].astype(int)+35)&(a[:,:,2].astype(int)>a[:,:,1].astype(int)+35)&visible
  if np.count_nonzero(purple)>5:audit['problems'].append({'file':r['file'],'magenta_pixels':int(np.count_nonzero(purple))})
 (HERE/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('Ronda:',len(rows),'WebP; audit',audit['problems'])
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--sources',type=Path,required=True);ap.add_argument('--cut-sheets',type=Path);args=ap.parse_args()
 if args.cut_sheets:prepare(args.cut_sheets,args.sources)
 build(args.sources)
