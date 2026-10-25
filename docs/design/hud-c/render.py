"""HUD C consolidada: composição de design, não código do jogo."""
import sys,json,importlib.util,hashlib,io
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageChops,ImageEnhance
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;ART=ROOT/'art/ui/kit/v2'
spec=importlib.util.spec_from_file_location('variations',ROOT/'docs/design/hud-variations/compose.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
ASSETS=json.loads((OUT/'assets.json').read_text())['assets'];ENEMIES={r['Name']:r for r in json.loads((ROOT/'data/enemies.json').read_text())};ABILITIES=json.loads((ROOT/'data/abilities.json').read_text());ALL=[]
QUOTES=json.loads((OUT/'session_quotes.json').read_text())
CASES=['log','locked_skill','ready','skill_focus','target','exit_focus','boss','boss_exit','actor_focus']
def nine(im,size,slices):
 w,h=size;l,t,r,b=slices;sw,sh=im.size;out=Image.new('RGBA',size)
 for yy,(y0,y1,dy0,dy1) in enumerate([(0,t,0,t),(t,sh-b,t,h-b),(sh-b,sh,h-b,h)]):
  for xx,(x0,x1,dx0,dx1) in enumerate([(0,l,0,l),(l,sw-r,l,w-r),(sw-r,sw,w-r,w)]):
   if dx1>dx0 and dy1>dy0:out.alpha_composite(im.crop((x0,y0,x1,y1)).resize((dx1-dx0,dy1-dy0),Image.Resampling.LANCZOS),(dx0,dy0))
 return out
class C(v.HUD):
 def __init__(self,case,large=False,cb=False):
  self.case=case;self.large=large;self.cb=cb;self.scale=1.3 if large else 1;self.key='c';self.rec=[];self.rects=[];self.hits=[];self.notes=[]
  boss=case.startswith('boss');name='combat-boss' if boss else 'combat';folder=ROOT/'docs/design/loop-screens/before';suffix='';self.source=folder/(name+suffix+'_clean.webp');self.meta=json.loads((folder/(name+suffix+'.json')).read_text());self.units=self.meta['units'];self.actor_unit=next(u for u in self.units if u['id']==self.meta['actor']);self.actor_name=self.actor_unit['name'];self.actor_key=v.FACE[self.actor_name]
  self.im=Image.open(self.source).convert('RGBA');alpha=np.zeros((1080,1920),dtype=np.uint8)
  for y in range(1080):alpha[y,:]=round(max(0,(y-744)/336)*185)
  shade=Image.new('RGBA',self.im.size,(5,10,14));shade.putalpha(Image.fromarray(alpha));self.im=Image.alpha_composite(self.im,shade)
  self.parts={k:Image.open(ROOT/r['file']).convert('RGBA') for k,r in ASSETS.items()};self.quote=QUOTES[name];self.can_flee=self.quote['can_flee'];self.options={r['id']:r for r in self.quote['options']}
 def color(self,role):return {'team':'#56b4e9' if self.cb else '#77ddd4','machine':'#e69f00' if self.cb else '#e7aa55','text':'#efe5d1','muted':'#a69a84','instinct':'#b7a6f4','good':'#56b4e9' if self.cb else '#86c98f','danger':'#e69f00' if self.cb else '#e2675b'}[role]
 def text(self,x,y,t,n=24,color='#efe5d1',serif=False,center=False,width=None):
  n=round(n*self.scale);f=v.font(n,serif);lines=[]
  if width:
   line=''
   for word in t.split():
    candidate=(line+' '+word).strip()
    if line and f.getlength(candidate)>width:lines.append(line);line=word
    else:line=candidate
   lines.append(line)
  else:lines=[t]
  lh=round(n*1.36)
  for i,line in enumerate(lines):
   xx=x-f.getlength(line)/2 if center else x;yy=y+i*lh;ImageDraw.Draw(self.im).text((round(xx),round(yy)),line,font=f,fill=color,anchor='lt',stroke_width=1,stroke_fill='#0b1218');self.rec.append({'text':line,'size':n,'x':xx,'y':yy,'right':xx+f.getlength(line),'bottom':yy+n})
  return lh*len(lines)
 def part(self,name,x,y,w,h,fit=False):
  name={'medal':'portrait','coin':'key','diamond':'action','bar':'bar_frame','instinct':'bar_frame'}.get(name,name);p=self.parts[name]
  if ASSETS[name]['slice_ltrb']:p=nine(p,(w,h),ASSETS[name]['slice_ltrb'])
  else:p=ImageOps.contain(p,(w,h),Image.Resampling.LANCZOS)
  self.im.alpha_composite(p,(round(x+(w-p.width)/2),round(y+(h-p.height)/2)));self.rects.append({'part':name,'rect':[x,y,w,h]})
 def plaque(self,x,y,w,h,t,selected=False,n=24):
  self.part('primary' if selected else 'plate',x,y,w,h);size=round(n*self.scale);self.text(x+w/2,y+(h-size*.8)/2,t,n,serif=True,center=True)
 def focus(self,x,y,w,h):
  d=ImageDraw.Draw(self.im);col=self.color('team')
  for xx,yy,sx,sy in [(x-5,y-5,1,1),(x+w+5,y-5,-1,1),(x-5,y+h+5,1,-1),(x+w+5,y+h+5,-1,-1)]:d.line([(xx,yy+sy*14),(xx,yy),(xx+sx*14,yy)],fill=col,width=3)
 def selected(self,x,y):ImageDraw.Draw(self.im).polygon([(x,y-8),(x+8,y),(x,y+8),(x-8,y)],fill='#e9c47c')
 def keycap(self,x,y,t,size=None):
  sz=size if size is not None else (64 if t=='Esc' else 48) if self.large else (56 if t=='Esc' else 40);self.part('key',x,y,sz,sz);n=round(18*self.scale);self.text(x+sz/2,y+(sz-n*.8)/2,t,18,center=True)
 def glyph(self,name,x,y,sz=36,role='text'):
  if name=='exit':
   im=self.parts['exit'].resize((sz,sz),Image.Resampling.LANCZOS);mask=im.getchannel('A');im=Image.new('RGBA',im.size,self.color(role));im.putalpha(mask);self.im.alpha_composite(im,(x,y))
  else:self.svg(name,x,y,sz,self.color(role))
 def gauge(self,x,y,w,h,ratio,role='team',value=None):
  left=x+32;right=x+w-32;top=y+16;bottom=y+h-14;d=ImageDraw.Draw(self.im);d.rounded_rectangle((left,top,right,bottom),4,fill='#102029')
  if ratio>0:
   rr=left+(right-left)*min(1,ratio);ww=max(1,round(rr-left));hh=round(bottom-top);rgb=tuple(int(self.color(role)[i:i+2],16) for i in [1,3,5]);liquid=Image.new('RGBA',(ww,hh));ld=ImageDraw.Draw(liquid)
   for yy in range(hh):
    factor=.68-.35*yy/max(1,hh-1);ld.line((0,yy,ww,yy),fill=tuple(round(n*factor) for n in rgb)+(255,))
   mask=Image.new('L',liquid.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,ww-1,hh-1),4,fill=255);liquid.putalpha(mask);self.im.alpha_composite(liquid,(round(left),round(top)));d=ImageDraw.Draw(self.im);d.line((left+4,top+2,max(left+4,rr-4),top+2),fill=self.color(role),width=1)
  glass=self.parts['bar_glass'].resize((round(right-left),round(bottom-top)),Image.Resampling.LANCZOS);self.im.alpha_composite(glass,(round(left),round(top)));self.part('bar_frame',x,y,w,h)
  if value:
   n=round(24*self.scale);self.text(x+w/2,top+((bottom-top)-n*.74)/2,value,24,color='#f6efdc',center=True)
 def log_control(self):
  self.part('secondary',48,32,272,64);self.text(80,52,'Registro',24,serif=True);self.keycap(264,44,'L',size=40);self.hits.append({'kind':'action','id':'combat_log','binding':'L','label':'Registro','rect':[48,32,272,112],'disabled':False})
  if self.case=='log':self.focus(48,32,272,64)
 def initiative(self):
  ts=[r['text'] for r in self.meta['texts']];i=next(i for i,t in enumerate(ts) if t.startswith('RODADA'));remaining=self.units[:];order=[]
  for label in ts[i+1:i+1+len(self.units)]:
   name=label.split(' · agora')[0];u=next((r for r in remaining if name in r['name']),remaining[0]);order.append(u);remaining.remove(u)
  sz=64 if self.large else 56;step=80 if self.large else 72;start=1872-((len(order)-1)*step+sz);self.plaque(start-248,32,224,56,'Rodada 1',n=24)
  for idx,u in enumerate(order):
   x=start+idx*step;key=v.FACE.get(u['name']) if u['player'] else ENEMIES[u['enemy_id']].get('SpriteKey',u['enemy_id']);p=ROOT/f'art/ui/portraits/{key}.png' if u['player'] else ROOT/f'art/ui/map/network/portrait_{key}.webp';self.image(Image.open(p),x+sz*.14,32+sz*.14,round(sz*.72),round(sz*.72),'circle');self.part('portrait',x,32,sz,sz)
   if u['id']==self.meta['actor']:self.selected(x+sz/2,32+sz+12)
  self.order=[u['id'] for u in order]
 def target(self):
  d=ImageDraw.Draw(self.im);x,y,w,h=1240,420,216,336
  for xx,yy,sx,sy in [(x,y,1,1),(x+w,y,-1,1),(x,y+h,1,-1),(x+w,y+h,-1,-1)]:d.line([(xx,yy+sy*18),(xx,yy),(xx+sx*18,yy)],fill=self.color('machine'),width=2)
 def plates(self):
  boss=self.case.startswith('boss');self.anchors={}

  for u in self.units:
   label=next(r for r in self.meta['texts'] if r['text']==u['name'] and 650<r.get('rect',[0,0])[1]<800);mid=round(label['rect'][0]+label['rect'][2]/2);self.anchors[u['id']]={'x':mid,'source_rect':label['rect']};w=224 if u['enemy_id']=='porteiro' else 160 if boss and u['player'] else 176;x=mid-w/2;role='team' if u['player'] else 'machine';ratio=u['hp']/max(1,u['max_hp']);self.gauge(x,776,w,56,ratio,role,f"{int(u['hp'])}/{int(u['max_hp'])}")
   self.part('action',x-8,748,40,40);size=ENEMIES.get(u['enemy_id'],{}).get('FormationSize',1);rank=str(int(u['rank'])) if size==1 else str(int(u['rank']))+'–'+str(int(u['rank'])+size-1)
   if size>1:self.part('plate',x-8,748,72,40);self.text(x+28,758,rank,18,center=True)
   else:self.text(x+12,758,rank,18,center=True)
   if u['player']:
    d=ImageDraw.Draw(self.im);d.line((x+32,836,x+w-32,836),fill='#667078',width=3)
    if u['instinct']>0:d.line((x+32,836,x+32+(w-64)*u['instinct']/200,836),fill=self.color('instinct'),width=3)
   else:self.glyph('intent-attack',round(x+w-36),732,28,'machine')
 def actor(self):
  sz=128 if self.large else 112;self.face(self.actor_name,48,888,sz);species={'cao':'Cão','gato':'Gato','sapo':'Sapo','coruja':'Coruja'}[self.actor_unit['class_id']];self.plaque(192,848,272,56,self.actor_name,n=24)
  u=self.actor_unit;self.gauge(184,912,288,56,u['hp']/u['max_hp'],'team',f"{int(u['hp'])}/{int(u['max_hp'])}");self.gauge(184,976,288,56,u['instinct']/200,'instinct',f"{int(u['instinct'])}/200")
  self.hits.append({'kind':'inspect_actor','id':self.meta['actor'],'rect':[48 if self.large else 40,888 if self.large else 880,128,128],'disabled':False})
  if self.case=='actor_focus':self.focus(48,888,sz,sz)
 def skills(self):
  self.skills_list=[a for a in ABILITIES if a['ClassId']==self.actor_unit['class_id']][:4];sz=112 if self.large else 104;y=904 if self.large else 912;occupied=[]
  for u in self.units:
   if not u['player']:occupied.extend(range(int(u['rank']),int(u['rank'])+ENEMIES[u['enemy_id']].get('FormationSize',1)))
  for i,a in enumerate(self.skills_list):
   x=520+i*128;locked=not self.options[a['Name']]['usable'];art=Image.open(ROOT/f"art/combat/icons/{a['Name']}.webp").convert('RGBA')
   if locked:
    gray=ImageOps.grayscale(art).convert('RGBA');gray.putalpha(art.getchannel('A'));art=ImageEnhance.Brightness(gray).enhance(.5)
   self.image(art,x+16,y+16,sz-32,sz-32,'rounded');self.part('slot',x,y,sz,sz)
   uses=self.options[a['Name']]['uses']
   if uses>=0:
    gem=self.parts['portrait'].crop((50,0,78,28)).resize((40,40),Image.Resampling.LANCZOS);self.im.alpha_composite(gem,(x+sz-36,y-12));self.text(x+sz-16,y, str(uses),18,center=True)
   if locked:ImageDraw.Draw(self.im).line((x+16,y+sz-24,x+32,y+sz-8),fill=self.color('muted'),width=4)
   if self.case=='locked_skill' and i==3:self.focus(x,y,sz,sz)
   if self.case in ['skill_focus','target'] and i==0:
    self.selected(x+sz/2,y-12)
    if self.case=='skill_focus':self.focus(x,y,sz,sz)
   self.keycap(x+(sz-(48 if self.large else 40))/2,1008,str(i+1));self.hits.append({'kind':'ability','id':a['Name'],'rect':[x-(112-sz)/2,y-(112-sz)/2,112,1056-(y-(112-sz)/2)],'disabled':locked,'reason':self.options[a['Name']]['reason'],'uses':self.options[a['Name']]['uses'],'cooldown':self.options[a['Name']]['cooldown']})
  chosen=self.skills_list[0]
  if self.case in ['skill_focus','target']:
   self.plaque(512,840,448,56,chosen['DisplayName'],True,n=24)
   dr=chosen.get('DamageRange')
   if dr:
    ImageDraw.Draw(self.im).ellipse((984,844,1048,908),fill='#142026');ImageDraw.Draw(self.im).line((960,868,980,876),fill='#c98a4b',width=2);self.part('portrait',976,836,80,80);self.text(1016,862,f"{dr['Min']}–{dr['Max']}",24,center=True)

 def actions(self):
  for i,(icon,key,label) in enumerate([('intent-move','Q','Mover'),('intent-block','W','Defender'),('item-generic','I','Mochila'),('exit','F','Fugir')]):
   cx=1672+(i%2)*120;cy=856+(i//2)*120;sz=88 if self.large else 80;x=cx-sz/2;y=cy-sz/2;self.part('action',x,y,sz,sz);disabled=key=='F' and not self.can_flee;self.glyph(icon,round(cx-20),round(cy-20),40,'muted' if disabled else 'text');self.keycap(round(cx+16),round(cy+16),key,size=40);self.hits.append({'kind':'action','id':{'Q':'combat_move','W':'combat_defend','I':'inventory','F':'combat_flee'}[key],'binding':key,'label':label,'rect':[cx-56,cy-56,112,112],'disabled':disabled})
   if disabled:
    d=ImageDraw.Draw(self.im);d.line((x+8,y+8,x+24,y+24),fill=self.color('muted'),width=3);d.line((x+16,y+8,x+32,y+24),fill=self.color('muted'),width=3)
   if self.case in ['exit_focus','boss_exit'] and key=='F':self.focus(x,y,sz,sz)
 def panel(self,x,y,w,h,title,lines):
  # Altura por conteúdo; reservar48 para os cantos com raízes, sem um painel vazio fixo.
  f=v.font(round(18*self.scale));lh=round(round(18*self.scale)*1.36);count=0
  for line in lines:
   acc='';nn=1
   for word in line.split():
    candidate=(acc+' '+word).strip()
    if acc and f.getlength(candidate)>w-64:nn+=1;acc=word
    else:acc=candidate
   count+=nn
  h=((88+count*lh+max(0,len(lines)-1)*12+64+7)//8)*8
  fill=self.parts['panel_material'];layer=Image.new('RGBA',(w-40,h-40))
  for xx in range(0,layer.width,64):
   for yy in range(0,layer.height,64):layer.alpha_composite(fill,(xx,yy))
  self.im.alpha_composite(layer,(x+20,y+20));self.part('panel',x,y,w,h);self.text(x+32,y+24,title,24,serif=True,width=w-64);yy=y+88
  for line in lines:yy+=self.text(x+32,yy,line,18,width=w-64)+12
 def details(self):
  if self.case=='log':
   texts=[r['text'] for r in self.meta['texts']];idx=next(i for i,t in enumerate(texts) if t.startswith('REGISTRO'));self.panel(48,160,640,240,'Registro da luta',[texts[idx+1]])
  elif self.case=='target':
   self.target();self.plaque(1224,352,256,56,'Recreador',n=24);self.plaque(1104,928,432,64,'Escolha um alvo',n=24)
  elif self.case=='locked_skill':
   a=self.skills_list[-1];self.panel(48,160,560,304 if self.large else 256,a['DisplayName'],[self.options[a['Name']]['reason'],'Requer inimigo Marcado ou Vulnerável.'])
  elif self.case=='skill_focus':
   a=self.skills_list[0];dr=a.get('DamageRange',{});self.panel(48,160,560,256 if self.large else 224,a['DisplayName'],[f"Dano {dr.get('Min',0)}–{dr.get('Max',0)} · Alvos 1 e 2",a['Description']])
  elif self.case in ['exit_focus','boss_exit']:
   self.panel(48,160,560,272 if self.large else 232,'Fugir — F',['Indisponível contra o Porteiro.'] if not self.can_flee else ['60% de chance de recuar e sair da luta.','Na fuga, larga o que carregava.'])
  elif self.case=='actor_focus':
   u=self.actor_unit;self.panel(48,160,560,272 if self.large else 232,self.actor_name,[f"Posição {int(u['rank'])} · Velocidade {int(u['speed'])}",f"Vida {int(u['hp'])}/{int(u['max_hp'])} · Instinto {int(u['instinct'])}/200"])
  else:self.plaque(1104,928,432,64,'Escolha uma ação',n=24)
 def render(self):
  self.log_control();self.initiative();self.plates();self.actor();self.skills();self.actions();self.details();suffix=('_large' if self.large else '')+('_colorblind' if self.cb else '');name=self.case+suffix;self.im.convert('RGB').save(OUT/(name+'.webp'),quality=90,method=6)
  if not self.large and not self.cb:self.im.convert('RGB').resize((768,432),Image.Resampling.LANCZOS).save(OUT/(self.case+'_40.webp'),quality=88)
  if self.large and self.cb:ImageOps.grayscale(self.im.convert('RGB')).save(OUT/(self.case+'_gray.webp'),quality=88)
  outside=[r for r in self.rec if r['x']<0 or r['y']<0 or r['right']>1920 or r['bottom']>1080];ALL.append({'case':self.case,'profile':suffix or 'normal','source':str(self.source.relative_to(ROOT)),'source_sha256':v.sha(self.source),'actor':self.meta['actor'],'initiative':self.order,'foot_anchors':self.anchors,'labels':self.rec,'pieces':self.rects,'hits':self.hits,'outside':outside,'file':name+'.webp','sha256':v.sha(OUT/(name+'.webp'))})
def before_after():
 sheet=Image.new('RGB',(1920,624),'#0d1012');d=ImageDraw.Draw(sheet)
 for i,(label,path) in enumerate([('C escolhida',ROOT/'docs/design/hud-variations/hud_c.webp'),('C consolidada',OUT/'target.webp')]):
  d.text((i*960+24,20),label,font=v.font(24),fill='#efe5d1');sheet.paste(Image.open(path).resize((960,540),Image.Resampling.LANCZOS),(i*960,72))
 sheet.save(OUT/'before_after.webp',quality=91,method=6)
def main():
 if '--proofs-only' in sys.argv:before_after();return
 for case in CASES:
  for large,cb in [(False,False),(True,False),(False,True),(True,True)]:C(case,large,cb).render()
 (OUT/'checks.json').write_text(json.dumps(ALL,ensure_ascii=False,indent=2)+'\n');print('profiles',len(ALL),'outside',sum(len(r['outside']) for r in ALL),flush=True)
 overview=Image.new('RGB',(1920,3*624),'#0d1012');d=ImageDraw.Draw(overview)
 for i,case in enumerate(['target','exit_focus','boss_exit']):
  for j,suffix in enumerate(['','_large']):
   d.text((j*960+24,i*624+12),case+(' / Maior' if j else ' / Normal'),font=v.font(24),fill='#efe5d1');overview.paste(Image.open(OUT/(case+suffix+'.webp')).resize((960,540),Image.Resampling.LANCZOS),(j*960,i*624+64))
 overview.save(OUT/'overview.webp',quality=90,method=6);before_after()
if __name__=='__main__':main()
