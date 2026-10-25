"""Três estudos de HUD sobre o mesmo frame real. Só docs; não é interface implementada."""
import sys,json,hashlib,io
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageFilter,ImageChops
import numpy as np
import cairosvg
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
SOURCE=ROOT/'docs/design/loop-screens/before/combat_clean.webp';META=json.loads((SOURCE.parent/'combat.json').read_text())
FONTS=ROOT/'art/ui/fonts';RECORDS=[]
CONFIG={
'a':{'title':'Raízes gravadas','source':'exec-f95f4e6b-9e9b-4b2f-93b8-af42fe22a4ac.png','parts':{'card':[39,70,529,942],'medal':[576,36,958,406],'slot':[640,413,897,664],'bar':[562,689,976,766],'instinct':[627,785,909,853],'coin':[711,871,822,982],'diamond':[1061,37,1493,472],'plate':[1054,490,1500,587],'primary':[1037,621,1509,735],'secondary':[1039,754,1507,856],'divider':[1064,883,1487,957]}},
'b':{'title':'Marcas da Estação','source':'exec-a9b28abe-1be7-40e6-b3b4-a958f1419d23.png','parts':{'card':[24,63,560,941],'medal':[600,10,960,380],'slot':[608,382,952,693],'bar':[581,687,1001,780],'instinct':[647,789,933,861],'coin':[709,867,843,1003],'diamond':[1036,8,1511,484],'plate':[1038,491,1511,596],'primary':[1042,628,1509,753],'secondary':[1046,771,1503,875],'divider':[1013,893,1513,997]}},
'c':{'title':'Latão noturno','source':'exec-167209ca-2953-42c7-b7ce-dfaa87fecdb1.png','parts':{'card':[35,93,546,911],'medal':[587,49,956,403],'slot':[650,420,894,657],'bar':[580,674,1002,754],'instinct':[636,763,912,834],'coin':[703,841,836,979],'diamond':[1066,47,1474,453],'plate':[1047,454,1494,555],'primary':[1047,582,1494,694],'secondary':[1047,717,1493,826],'divider':[1051,869,1492,947]}}}
# O PNG mestre é externo. Os WebP abaixo são estudos leves de composição, não runtime.
FACE={'Bento':'bento','Nick':'nick','Íris':'iris','Véspera':'vespera','Recreador':'recreador','Emissor de Comando':'sussurrador'}
ORDER=['Nick','Íris','Emissor de Comando','Bento','Véspera','Recreador']
ABILITIES=[r for r in json.loads((ROOT/'data/abilities.json').read_text()) if r['ClassId']=='gato']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def font(n,serif=False):return ImageFont.truetype(str(FONTS/('cinzel-latin-700-normal.ttf' if serif else 'plus-jakarta-sans-latin-400-normal.ttf')),n)
def base():
 im=Image.open(SOURCE).convert('RGBA');a=np.zeros((1080,1920),dtype=np.uint8)
 for y in range(1080):a[y,:]=round(max(0,(y-744)/336)*185)
 shade=Image.new('RGBA',im.size,(5,10,14));shade.putalpha(Image.fromarray(a));return Image.alpha_composite(im,shade)
class HUD:
 def __init__(self,key):
  self.key=key;self.im=base();self.rec=[];self.rects=[];self.skin=Image.open(OUT/f'skin_{key}.webp').convert('RGBA');self.parts={k:self.skin.crop(b) for k,b in CONFIG[key]['parts'].items()}
 def text(self,x,y,t,n=22,color='#efe5d1',serif=False,center=False):
  f=font(n,serif);x=x-f.getlength(t)/2 if center else x;ImageDraw.Draw(self.im).text((round(x),round(y)),t,font=f,fill=color,anchor='lt',stroke_width=1,stroke_fill='#0b1218');self.rec.append({'text':t,'size':n,'x':x,'y':y,'right':x+f.getlength(t),'bottom':y+n})
 def part(self,name,x,y,w,h,fit=False):
  p=self.parts[name];p=ImageOps.contain(p,(w,h),Image.Resampling.LANCZOS) if fit else p.resize((w,h),Image.Resampling.LANCZOS);self.im.alpha_composite(p,(round(x+(w-p.width)/2),round(y+(h-p.height)/2)));self.rects.append({'part':name,'rect':[x,y,w,h]})
 def plaque(self,x,y,w,h,t,selected=False,n=22):
  self.part('primary' if selected else 'plate',x,y,w,h);self.text(x+w/2,y+(h-n)/2-1,t,n,serif=t.startswith(('Nick','Corte de Fase')) or t=='Rodada 1',center=True)
 def image(self,p,x,y,w,h,shape=None):
  p=ImageOps.fit(p.convert('RGBA'),(w,h),method=Image.Resampling.LANCZOS)
  if shape:
   m=Image.new('L',(w,h));d=ImageDraw.Draw(m)
   if shape=='circle':d.ellipse((0,0,w-1,h-1),fill=255)
   elif shape=='diamond':d.polygon([(w/2,0),(w-1,h/2),(w/2,h-1),(0,h/2)],fill=255)
   elif shape=='octagon':d.polygon([(w*.25,0),(w*.75,0),(w-1,h*.25),(w-1,h*.75),(w*.75,h-1),(w*.25,h-1),(0,h*.75),(0,h*.25)],fill=255)
   else:d.rounded_rectangle((0,0,w-1,h-1),12,fill=255)
   p.putalpha(ImageChops.multiply(p.getchannel('A'),m))
  self.im.alpha_composite(p,(round(x),round(y)))
 def face(self,name,x,y,sz,selected=False):
  p=ROOT/f'art/ui/portraits/{FACE[name]}.png' if name in ['Bento','Nick','Íris','Véspera'] else ROOT/f'art/ui/map/network/portrait_{FACE[name]}.webp'
  self.image(Image.open(p),x+sz*.13,y+sz*.13,round(sz*.74),round(sz*.74),'octagon' if self.key=='b' else 'circle');self.part('medal',x,y,sz,sz,True)
  if selected:
   d=ImageDraw.Draw(self.im);d.polygon([(x+sz/2,y+sz+3),(x+sz/2+7,y+sz+11),(x+sz/2,y+sz+19),(x+sz/2-7,y+sz+11)],fill='#8de6df')
 def svg(self,name,x,y,sz=28,color='#efe5d1'):
  p=ROOT/f'art/ui/icons/{name}.svg';im=Image.open(io.BytesIO(cairosvg.svg2png(bytestring=p.read_bytes(),output_width=sz,output_height=sz))).convert('RGBA');a=im.getchannel('A');im=Image.new('RGBA',im.size,color);im.putalpha(a);self.im.alpha_composite(im,(x,y))
 def gauge(self,x,y,w,h,ratio,color,kind='bar',value=None):
  # Vidro e preenchimento separados: zero permanece vazio, sem falso progresso luminoso.
  d=ImageDraw.Draw(self.im);left=x+round(w*.15);right=x+round(w*.85);top=y+round(h*.32);bottom=y+round(h*.7)
  d.rounded_rectangle((left,top,right,bottom),max(2,h//8),fill='#101a20')
  if ratio>0:d.rounded_rectangle((left,top,max(left+1,left+(right-left)*ratio),bottom),max(2,h//8),fill=color)
  self.part(kind,x,y,w,h)
  # Canal segue visível sob o vidro, sem cobrir as capas ornamentadas.
  if ratio>0:
   glass=Image.new('RGBA',self.im.size);gd=ImageDraw.Draw(glass);gd.rounded_rectangle((left,top,max(left+1,left+(right-left)*ratio),bottom),max(2,h//8),fill=(*tuple(int(color[i:i+2],16) for i in [1,3,5]),145));self.im.alpha_composite(glass)
  if value:self.text(x+w/2,y+(h-18)/2,value,18,center=True)
 def keycap(self,x,y,t):
  sz=40 if t=='Esc' else 32;self.part('coin',x,y,sz,sz,True);self.text(x+sz/2,y+(sz-18)/2,t,18,center=True)
 def target(self):
  # Mesmo estado proposto nas três: Corte de Fase em foco, Recreador apontado.
  d=ImageDraw.Draw(self.im);x,y,w,h=1240,420,216,336;col='#edb66d'
  for xx,yy,sx,sy in [(x,y,1,1),(x+w,y,-1,1),(x,y+h,1,-1),(x+w,y+h,-1,-1)]:d.line([(xx,yy+sy*18),(xx,yy),(xx+sx*18,yy)],fill=col,width=2)
 def plates(self):
  xs={'Véspera':248,'Íris':456,'Nick':664,'Bento':904,'Recreador':1248,'Emissor de Comando':1512}
  for u in META['units']:
   x=xs[u['name']];color='#77ddd4' if u['player'] else '#e7aa55';w=176 if u['player'] else 208
   if self.key=='b':
    self.part('diamond',x,770,40,40,True);self.text(x+20,782,str(u['rank']),18,center=True);self.gauge(x+32,770,w-24,36,1,color,value=f"{u['hp']}/{u['max_hp']}")
   else:
    self.part('plate',x,768,w,64);self.text(x+24,785,str(u['rank']),18,center=True);self.gauge(x+32,780,w-40,32,1,color,value=f"{u['hp']}/{u['max_hp']}")
   if not u['player']:self.svg('intent-attack',x+w-32,728,28,'#edb66d')
 def initiative(self):
  if self.key=='b':
   self.plaque(40,104,112,40,'Ordem',n=20)
   for i,name in enumerate(ORDER):self.face(name,56,160+i*82,64,i==0)
  else:
   start=752 if self.key=='a' else 1352;sz=64 if self.key=='a' else 48;step=80 if self.key=='a' else 64
   self.plaque(start-208,40,184,48,'Rodada 1',n=22)
   for i,name in enumerate(ORDER):self.face(name,start+i*step,32,sz,i==0)
 def actor(self):
  if self.key=='a':
   self.part('card',48,792,184,264);self.image(Image.open(ROOT/'art/ui/portraits/nick.png'),64,810,152,132,'rounded');self.text(140,946,'Nick',24,serif=True,center=True);self.gauge(60,978,160,28,1,'#77ddd4',value='24/24');self.gauge(60,1012,160,26,0,'#b7a6f4',kind='instinct',value='0/200')
  elif self.key=='b':
   self.face('Nick',56,856,160);self.plaque(232,872,280,48,'Nick · Gato',n=24);self.gauge(224,932,296,40,1,'#77ddd4',value='24/24');self.gauge(224,984,296,36,0,'#b7a6f4',kind='instinct',value='0/200')
  else:
   self.face('Nick',48,896,112);self.plaque(176,888,232,48,'Nick · Gato',n=24);self.gauge(168,944,248,36,1,'#77ddd4',value='24/24');self.gauge(168,992,248,32,0,'#b7a6f4',kind='instinct',value='0/200')
 def skills(self):
  if self.key=='a':start,yy,step,sz=376,904,136,104
  elif self.key=='b':start,yy,step,sz=600,896,156,120
  else:start,yy,step,sz=536,924,112,88
  for i,a in enumerate(ABILITIES):
   x=start+i*step;y=yy-(16 if self.key=='b' and i in [1,2] else 0);p=Image.open(ROOT/f"art/combat/icons/{a['Name']}.webp")
   if self.key=='b' and (OUT/'skill_glyphs.webp').exists():
    atlas=Image.open(OUT/'skill_glyphs.webp').convert('RGBA');gw=atlas.width//4;p=atlas.crop((i*gw,0,(i+1)*gw,atlas.height));p=p.crop(p.getbbox());s=round(sz*.54);p=ImageOps.contain(p,(s,s),Image.Resampling.LANCZOS);mask=p.getchannel('A');p=Image.new('RGBA',p.size,['#8ee5dd','#a4d27b','#bca7ed','#efb867'][i]);p.putalpha(mask);self.im.alpha_composite(p,(x+(sz-p.width)//2,y+(sz-p.height)//2));self.part('slot',x,y,sz,sz,True)
   else:
    self.image(p,x+sz*.14,y+sz*.14,round(sz*.72),round(sz*.72),'diamond' if self.key=='b' else 'rounded');self.part('slot',x,y,sz,sz,True)
   if i==0:
    d=ImageDraw.Draw(self.im);d.polygon([(x+sz/2,y-16),(x+sz/2+7,y-8),(x+sz/2,y),(x+sz/2-7,y-8)],fill='#86e6df')
   self.keycap(x+sz//2-16,y+sz+8,str(i+1))
  if self.key=='a':tx,ty,tw=368,840,560
  elif self.key=='b':tx,ty,tw=600,816,588
  else:tx,ty,tw=520,864,464
  self.plaque(tx,ty,tw,48 if self.key=='a' else 56,'Corte de Fase · 4–6 dano',True,n=24 if self.key!='c' else 22)
 def actions(self):
  if self.key=='c':
   for i,(icon,key) in enumerate([('intent-move','Q'),('intent-block','W'),('item-generic','I'),('node-start','F')]):
    xx=1704+(i%2)*88;yy=872+(i//2)*88;self.part('diamond',xx,yy,64,64,True);self.svg(icon,xx+18,yy+18,28);self.keycap(xx+48,yy+48,key)
   self.plaque(1096,944,424,56,'Escolha um alvo',n=22);self.keycap(1292,1012,'Esc')
  else:
   for i,(icon,key,label) in enumerate([('intent-move','Q','Mover'),('intent-block','W','Defender'),('item-generic','I','Mochila'),('node-start','F','Retirar')]):
    xx=1120+(i%2)*264 if self.key=='a' else 1328+(i%2)*240;yy=904+(i//2)*72;ww=248 if self.key=='a' else 224;self.part('secondary',xx,yy,ww,56);self.svg(icon,xx+24,yy+14,28);self.text(xx+64,yy+18,label,20);self.keycap(xx+ww-48,yy+12,key)
 def render(self):
  self.plaque(40 if self.key!='b' else 216,24,400,56,self.key.upper()+' / '+CONFIG[self.key]['title'],n=22);self.initiative();self.plates();self.target();self.actor();self.skills();self.actions()
  outside=[r for r in self.rec if r['x']<0 or r['y']<0 or r['right']>1920 or r['bottom']>1080]
  self.im.convert('RGB').save(OUT/f'hud_{self.key}.webp',quality=92,method=6);self.im.convert('RGB').resize((768,432),Image.Resampling.LANCZOS).save(OUT/f'hud_{self.key}_40.webp',quality=89);ImageOps.grayscale(self.im.convert('RGB')).save(OUT/f'hud_{self.key}_gray.webp',quality=88)
  RECORDS.append({'variant':self.key,'title':CONFIG[self.key]['title'],'canvas':[1920,1080],'labels':self.rec,'pieces':self.rects,'outside':outside,'sha256':sha(OUT/f'hud_{self.key}.webp')})
def main():
 for key,c in CONFIG.items():
  p=OUT/f'skin_{key}.webp'
  if not p.exists():Image.open(Path('/workspace/generated_images')/c['source']).save(p,lossless=True,method=6)
  HUD(key).render()
 (OUT/'composition.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'source_sha256':sha(SOURCE),'metadata':'../loop-screens/before/combat.json','same_turn_and_units':True,'style_state':'Corte de Fase focused, Recreador pointed; composed proposal','variants':RECORDS,'skin_crops':{k:c['parts'] for k,c in CONFIG.items()}},ensure_ascii=False,indent=2)+'\n')
 o=Image.new('RGB',(1920,3*1152),'#0d1012');d=ImageDraw.Draw(o)
 for i,k in enumerate(CONFIG):
  d.text((48,i*1152+20),k.upper()+' / '+CONFIG[k]['title'],font=font(30,True),fill='#efe5d1');o.paste(Image.open(OUT/f'hud_{k}.webp'),(0,i*1152+72))
 o.save(OUT/'comparison.webp',quality=90,method=6)
 quick=Image.new('RGB',(1920,432),'#0d1012');qd=ImageDraw.Draw(quick)
 for i,k in enumerate(CONFIG):
  qd.text((i*640+24,20),k.upper()+' / '+CONFIG[k]['title'],font=font(24,True),fill='#efe5d1');quick.paste(Image.open(OUT/f'hud_{k}.webp').resize((640,360),Image.Resampling.LANCZOS),(i*640,72))
 quick.save(OUT/'overview.webp',quality=90,method=6);print('3HUDs; outside',sum(len(r['outside']) for r in RECORDS))
if __name__=='__main__':main()
