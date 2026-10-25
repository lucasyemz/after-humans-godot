"""Kit do alvo aprovado: aço chanfrado, sem texto ou conteúdo do personagem."""
import sys,json,hashlib,shutil
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps,ImageFilter
import numpy as np
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;OUT=ROOT/'art/ui/kit/combat';OUT.mkdir(parents=True,exist_ok=True)
raw=Path('/workspace/generated_images/exec-eabb9cb5-5001-4f3a-a6cd-e5dca7e089af.png');tilepath=OUT/'steel_material.webp'
if not tilepath.exists():
 im=Image.open(raw).convert('RGB');im=ImageOps.fit(im,(512,512),Image.Resampling.LANCZOS);im.save(tilepath,quality=93,method=6)
TILE=Image.open(tilepath).convert('RGBA');ROWS={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,im,slices=None,content=None,note=''):
 arr=np.array(im.convert('RGBA'));arr[arr[:,:,3]==0]=0;im=Image.fromarray(arr);im.save(OUT/(name+'.webp'),lossless=True,method=6);ROWS[name]={'file':'art/ui/kit/combat/'+name+'.webp','size':list(im.size),'nine_slice_ltrb':slices,'content_xywh':content,'anchor':[0,0],'note':note,'sha256':sha(OUT/(name+'.webp'))}
def polygon(w,h,c=12):return [(c,0),(w-c-1,0),(w-1,c),(w-1,h-c-1),(w-c-1,h-1),(c,h-1),(0,h-c-1),(0,c)]
REF=Image.open(ROOT/'docs/design/reference/hud-target-2026-10-25.webp').convert('RGBA')
def stretch(im,size,sl):
 w,h=size;l,t,r,b=sl;sw,sh=im.size;out=Image.new('RGBA',size)
 for sy0,sy1,dy0,dy1 in [(0,t,0,t),(t,sh-b,t,h-b),(sh-b,sh,h-b,h)]:
  for sx0,sx1,dx0,dx1 in [(0,l,0,l),(l,sw-r,l,w-r),(sw-r,sw,w-r,w)]:
   if dx1>dx0 and dy1>dy0:out.alpha_composite(im.crop((sx0,sy0,sx1,sy1)).resize((dx1-dx0,dy1-dy0),Image.Resampling.LANCZOS),(dx0,dy0))
 return out
def material(size):
 out=Image.new('RGBA',size)
 for x in range(0,size[0],512):
  for y in range(0,size[1],512):out.alpha_composite(TILE,(x,y))
 return out
# The approved frame borders themselves, with all lettering/key content removed.
TEMPLATE=REF.crop((40,28,276,83));m=Image.new('L',TEMPLATE.size);ImageDraw.Draw(m).polygon([(8,8),(228,8),(228,47),(8,47)],fill=255);TEMPLATE.paste(material(TEMPLATE.size),(0,0),m)
def frame(w,h,c=12,amber=True,poly=None,hole=None):
 if w==564 and h==212:
  im=REF.crop((54,728,548,916)).resize((w,h),Image.Resampling.LANCZOS);mask=Image.new('L',im.size);ImageDraw.Draw(mask).rectangle((216,32,w-12,h-16),fill=255);im.paste(material(im.size),(0,0),mask)
 else:im=stretch(TEMPLATE,(w,h),[20,12,20,12])
 if not amber:
  a=np.array(im);r,g,b=a[:,:,0].astype(float),a[:,:,1].astype(float),a[:,:,2].astype(float);warm=(r>100)&(r>g*1.2)&(g>b*1.35);gray=np.uint8((r+g+b)/3*.8)
  for ch in range(3):a[:,:,ch]=np.where(warm,gray,a[:,:,ch])
  im=Image.fromarray(a)
 mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon(poly or polygon(w,h,min(c,12)),fill=255);im.putalpha(mask)
 if poly and h==44:
  draw=ImageDraw.Draw(im);draw.line(poly+[poly[0]],fill='#4b5056',width=5,joint='curve');draw.line(poly+[poly[0]],fill='#a4a49c',width=1,joint='curve');im.putalpha(mask)
 if hole:
  a=im.getchannel('A');ImageDraw.Draw(a).polygon(hole,fill=0);im.putalpha(a)
 return im
save('panel',frame(256,80),[24,24,24,24],[24,16,208,48])
save('register',frame(272,64),[24,20,24,20],[24,12,224,40])
save('round_strip',frame(720,72),[24,16,24,16],[24,8,672,56])
# Correct interior mask offset; the image is filled by the component.
im=frame(72,72,8,False);a=im.getchannel('A');ImageDraw.Draw(a).rectangle((7,7,64,64),fill=0);im.putalpha(a);save('square_portrait',im,[12,12,12,12],[8,8,56,56])
hero_poly=[(20,0),(188,0),(212,24),(544,24),(563,44),(563,195),(547,211),(16,211),(0,195),(0,20)]
hero=frame(564,212,16,True,hero_poly);a=hero.getchannel('A');ImageDraw.Draw(a).polygon([(24,12),(180,12),(196,28),(196,196),(16,196),(12,192),(12,24)],fill=0);hero.putalpha(a);d=ImageDraw.Draw(hero);d.line([(20,8),(184,8),(204,28),(204,200),(16,200),(8,192),(8,20),(20,8)],fill='#85847d',width=2)
save('hero_panel',hero,[224,24,24,24],[232,40,308,152],'Keep height212; left224 protects the portrait column. Portrait content184x184 at12,12.')
save('ability_header',frame(624,56,8),[20,12,20,12],[12,8,600,40])
save('target_tab',frame(336,40,8),[16,12,16,12],[16,6,304,28])
save('action_button',frame(128,100,12),[16,16,16,16],[16,12,96,76])
save('key_tab',frame(48,48,4,False),[8,8,8,8],[8,6,32,36])
slot=frame(132,132,10,False);a=slot.getchannel('A');ImageDraw.Draw(a).polygon([(16,8),(115,8),(123,16),(123,115),(115,123),(16,123),(8,115),(8,16)],fill=0);slot.putalpha(a);save('ability_slot',slot,[16,16,16,16],[8,8,116,116])
for kind in ['ally','enemy']:
 w,h=200,44
 poly=[(12,4),(22,4),(26,0),(48,0),(52,4),(188,4),(199,15),(199,32),(188,43),(12,43),(0,32),(0,16)] if kind=='ally' else [(12,4),(188,4),(199,15),(199,29),(191,29),(191,36),(184,43),(12,43),(0,32),(0,16)]
 save('health_'+kind,frame(w,h,10,False,poly),[20,12,20,12],[16,6,168,34],'Ally top tab; enemy notch on lower-right. No position number.')
save('main_bar',frame(320,44,8,False),[12,10,12,10],[8,6,304,32])
for name,size,arm in [('selected_slot',(132,132),24),('active_health',(200,44),16)]:
 im=Image.new('RGBA',size);d=ImageDraw.Draw(im);w,h=size
 for x,y,sx,sy in [(3,3,1,1),(w-4,3,-1,1),(3,h-4,1,-1),(w-4,h-4,-1,-1)]:d.line([(x,y+sy*arm),(x,y),(x+sx*arm,y)],fill='#f0a020',width=4)
 halo=im.filter(ImageFilter.GaussianBlur(3));halo=Image.alpha_composite(halo,im);save(name,halo,[28,12 if h==44 else 28,28,12 if h==44 else 28],note='Amber corner selection, separate from base texture.')
ring=Image.new('RGBA',(256,80));d=ImageDraw.Draw(ring)
for start in [4,94,184,274]:d.arc((8,10,248,70),start,start+80,fill='#f0a020',width=3)
for x,y,sign in [(14,40,-1),(242,40,1)]:d.line([(x-sign*8,y-7),(x,y),(x-sign*8,y+7)],fill='#ffcc70',width=3)
d.line((70,67,80,73,90,67),fill='#fff0bb',width=2);d.line((170,13,180,7,190,13),fill='#fff0bb',width=2);halo=ring.filter(ImageFilter.GaussianBlur(4));halo.putalpha(halo.getchannel('A').point(lambda n:min(255,n*3)));ring=Image.alpha_composite(halo,ring);save('actor_ring',ring,note='Do not9-slice: perspective ellipse, place under feet, depth-tested. Center128,40.');ROWS['actor_ring']['anchor']=[128,40]
exit_im=Image.open(ROOT/'art/ui/kit/v2/exit.webp').convert('RGBA');save('exit',exit_im,note='Reused approved exit symbol; F is combat_flee, never a crosshair.');ROWS['exit']['anchor']=[32,32]
ROWS['steel_material']={'file':str(tilepath.relative_to(ROOT)),'size':[512,512],'nine_slice_ltrb':None,'content_xywh':[0,0,512,512],'anchor':[0,0],'note':'Repeat material; never stretch frame corners.','sha256':sha(tilepath)}
manifest={'direction':'Approved target2026-10-25; overrides ornamental C','source_reference':'docs/design/reference/hud-target-2026-10-25.webp','source_sha256':sha(ROOT/'docs/design/reference/hud-target-2026-10-25.webp'),'canvas':[1920,1080],'assets':ROWS,'font':{'file':'art/ui/fonts/barlow_condensed_semibold.ttf','license':'art/ui/fonts/OFL-BarlowCondensed.txt','source':'https://github.com/google/fonts/tree/main/ofl/barlowcondensed','sha256':sha(ROOT/'art/ui/fonts/barlow_condensed_semibold.ttf'),'case':'UPPERCASE'},'originals':'Generated material PNG outside repository; no heavy masters committed'}
(HERE/'assets.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(OUT/'assets.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print('Assets',len(ROWS))
