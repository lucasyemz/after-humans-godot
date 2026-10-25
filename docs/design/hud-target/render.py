"""Reconstitui a estrutura do alvo aprovado sobre o frame real, sem alterar personagens ou regras."""
import sys,json,hashlib,io,math
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageEnhance
import cairosvg
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;ART=ROOT/'art/ui/kit/combat';MAN=json.loads((OUT/'assets.json').read_text());ASSETS=MAN['assets'];FONT=ROOT/MAN['font']['file'];SOURCE=ROOT/'docs/design/loop-screens/before/combat_clean.webp';META=json.loads(SOURCE.with_name('combat.json').read_text());QUOTES=json.loads((ROOT/'docs/design/hud-c/session_quotes.json').read_text())['combat'];ABILITIES=[r for r in json.loads((ROOT/'data/abilities.json').read_text()) if r['ClassId']=='gato'];COMBAT=json.loads((ROOT/'data/presentation/combat_art.json').read_text());ALL=[]
FACE={'Bento':'bento','Nick':'nick','Íris':'iris','Véspera':'vespera'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def nine(im,size,sl):
 l,t,r,b=sl;w,h=size;sw,sh=im.size;out=Image.new('RGBA',size)
 for y0,y1,dy0,dy1 in [(0,t,0,t),(t,sh-b,t,h-b),(sh-b,sh,h-b,h)]:
  for x0,x1,dx0,dx1 in [(0,l,0,l),(l,sw-r,l,w-r),(sw-r,sw,w-r,w)]:
   if dx1>dx0 and dy1>dy0:out.alpha_composite(im.crop((x0,y0,x1,y1)).resize((dx1-dx0,dy1-dy0),Image.Resampling.LANCZOS),(dx0,dy0))
 return out
class Board:
 def __init__(self,large=False,cb=False):
  self.large=large;self.cb=cb;self.scale=1.3 if large else 1;self.im=Image.open(SOURCE).convert('RGBA');self.labels=[];self.pieces=[];self.hits=[];self.source_icons={}
  self.images={k:Image.open(ROOT/r['file']).convert('RGBA') for k,r in ASSETS.items()};self.color={'text':'#efe6d6','amber':'#f0a020','ally':'#56b4e9' if cb else '#2fb6bd','enemy':'#e69f00' if cb else '#d23a2e'}
 def part(self,key,rect):
  x,y,w,h=map(round,rect);im=self.images[key];sl=ASSETS[key]['nine_slice_ltrb'];im=nine(im,(w,h),sl) if sl else im.resize((w,h),Image.Resampling.LANCZOS);self.im.alpha_composite(im,(x,y));self.pieces.append({'part':key,'rect':[x,y,w,h]})
 def text(self,t,box,size=28,align='left',role='label'):
  t=t.upper();x,y,w,h=box;n=round(size*self.scale);f=ImageFont.truetype(str(ROOT/MAN['font']['emphasis_file']) if role=='hero_name' else str(FONT),n);bb=f.getbbox(t,anchor='lt');tw=f.getlength(t);th=bb[3]-bb[1];xx=x+(w-tw)/2 if align=='center' else x;yy=y+(h-th)/2;ImageDraw.Draw(self.im).text((round(xx),round(yy)),t,font=f,fill=self.color['text'],anchor='lt',stroke_width=0);self.labels.append({'text':t,'size':n,'role':role,'box':list(box),'rect':[xx,yy,tw,th],'fits':tw<=w and th<=h})
 def image(self,p,rect,background=None):
  x,y,w,h=map(round,rect);im=ImageOps.fit(p.convert('RGBA'),(w,h),Image.Resampling.LANCZOS)
  if background:
   b=Image.new('RGBA',im.size,background);b.alpha_composite(im);im=b
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon([(6,0),(w-7,0),(w-1,6),(w-1,h-7),(w-7,h-1),(6,h-1),(0,h-7),(0,6)],fill=255);im.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').asarray(im.getchannel('A')),__import__('numpy').asarray(mask))));self.im.alpha_composite(im,(x,y))
 def key(self,t,x,y):self.part('key_tab',[x,y,42,42]);self.text(t,[x+4,y+4,34,34],26,'center','binding')
 def line_icon(self,name,rect):
  x,y,w,h=rect
  if name=='exit':im=self.images['exit'].resize((w,h),Image.Resampling.LANCZOS)
  else:
   svg=(ROOT/f'art/ui/icons/{name}.svg').read_bytes();im=Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg,output_width=w,output_height=h))).convert('RGBA')
  a=im.getchannel('A');im=Image.new('RGBA',im.size,self.color['text']);im.putalpha(a);self.im.alpha_composite(im,(x,y))
 def fill(self,rect,ratio,role):
  x,y,w,h=map(round,rect);ww=round(w*max(0,min(1,ratio)))
  if ww<=0:return
  rgb=tuple(int(self.color[role][i:i+2],16) for i in [1,3,5]);im=Image.new('RGBA',(ww,h));d=ImageDraw.Draw(im)
  for yy in range(h):
   factor=.7+.4*(1-abs(yy-h*.32)/(h*.8));d.line((0,yy,ww,yy),fill=tuple(min(255,round(v*factor)) for v in rgb)+(255,))
  d.line((2,1,max(2,ww-3),1),fill='#b9e5df' if role=='ally' else '#ffb2a0',width=1);mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon([(2,0),(ww-3,0),(ww-1,2),(ww-1,h-3),(ww-3,h-1),(2,h-1),(0,h-3),(0,2)],fill=255);im.putalpha(mask);self.im.alpha_composite(im,(x,y))
 def portrait(self,u):
  if u['player']:return Image.open(ROOT/f"art/ui/portraits/{FACE[u['name']]}.png").crop((40,0,230,190))
  data=COMBAT['enemies'][u['enemy_id']]['idle'];p=Image.open(ROOT/data['file'].removeprefix('res://')).convert('RGBA');region={'recreador':(360,20,800,460),'sussurrador':(360,160,850,650)}[u['enemy_id']];sx=p.width/data['canvas'][0];sy=p.height/data['canvas'][1];region=tuple(round(n*(sx if i%2==0 else sy)) for i,n in enumerate(region));face=p.crop(region);assert face.getbbox() is not None;return face
 def order(self):
  self.part('round_strip',[636,30,720,64]);self.part('register',[636,30,184,64]);self.text('RODADA 1',[660,39,160,50],30);d=ImageDraw.Draw(self.im);d.line((816,66,858,66),fill=self.color['amber'],width=2);d.polygon([(835,62),(839,66),(835,70),(831,66)],fill=self.color['amber'])
  ts=[r['text'] for r in META['texts']];idx=next(i for i,t in enumerate(ts) if t.startswith('RODADA'));remaining=META['units'][:];order=[]
  for name in ts[idx+1:idx+7]:
   name=name.split(' · agora')[0];u=next((u for u in remaining if name in u['name']),remaining[0]);remaining.remove(u);order.append(u)
  for i,u in enumerate(order):
   x=864+i*76;self.image(self.portrait(u),[x+2,32,60,60], '#192026' if u['player'] else '#421b1b');self.part('square_portrait',[x,30,64,64])
   if u['id']==META['actor']:
    ImageDraw.Draw(self.im).rounded_rectangle((x,30,x+64,94),4,outline=self.color['amber'],width=3)
  self.order_ids=[u['id'] for u in order]
 def world(self):
  actor=next(u for u in META['units'] if u['id']==META['actor']);label=next(t for t in META['texts'] if t['text']==actor['name'] and 700<t['rect'][1]<800);cx=round(label['rect'][0]+label['rect'][2]/2);ring=self.images['actor_ring'].resize((248,64),Image.Resampling.LANCZOS);a=ring.getchannel('A');ImageDraw.Draw(a).rectangle((60,0,204,38),fill=0);ring.putalpha(a);self.im.alpha_composite(ring,(cx-124,724));self.ring={'center':[cx,756],'rect':[cx-124,724,248,64],'occlusion':'boots mask in frozen composition; depth-tested under unit in game'}
  for u in META['units']:
   label=next(t for t in META['texts'] if t['text']==u['name'] and 650<t['rect'][1]<800);cx=round(label['rect'][0]+label['rect'][2]/2);x=cx-100;y=760;role='ally' if u['player'] else 'enemy';self.part('health_'+role,[x,y,200,44]);self.fill([x+14,y+6,172,10],u['hp']/u['max_hp'],role);self.text(f"{int(u['hp'])}/{int(u['max_hp'])}",[x+14,y+17,172,25],26,'center','hp')
   if u['id']==META['actor']:self.part('active_health',[x,y,200,44])
  self.part('target_tab',[1280,348,176,56]);self.text('RECREADOR',[1292,350,152,37],26,'center');ImageDraw.Draw(self.im).rounded_rectangle((1292,393,1444,397),2,fill=self.color['enemy'])
 def hero(self):
  self.image(Image.open(ROOT/'art/ui/portraits/nick.png').crop((48,18,216,186)),[76,848,184,184],'#1b1d20');self.part('hero_panel',[64,836,564,212]);self.text('NICK',[296,878,300,48],40,role='hero_name')
  self.part('main_bar',[292,940,308,40]);self.fill([300,946,292,28],1,'ally');self.text('24/24',[300,944,292,32],32,'center','hp')
  self.part('main_bar',[292,988,308,40]);self.text('0/200',[300,992,292,32],32,'center','instinct')
  self.hits.append({'id':'inspect_actor','rect':[64,836,208,212]})
 def abilities(self):
  self.part('target_tab',[856,816,336,40]);self.text('ESCOLHA UM ALVO',[872,820,304,30],26)
  self.part('ability_header',[684,852,624,56]);self.image(Image.open(ROOT/'art/combat/icons/gato_corte_fase.webp'),[698,860,40,40]);self.text('CORTE DE FASE',[754,858,420,44],32);ImageDraw.Draw(self.im).line((1192,858,1192,902),fill='#5a5b59',width=2);self.text('4–6',[1204,858,88,44],28,'center','range')
  for i,a in enumerate(ABILITIES):
   x=688+i*160;y=916;q=QUOTES['options'][i];p=ROOT/f"art/combat/icons/{a['Name']}.webp";im=Image.open(p).convert('RGBA');self.source_icons[str(p.relative_to(ROOT))]=sha(p)
   if not q['usable']:
    gray=ImageOps.grayscale(im).convert('RGBA');gray.putalpha(im.getchannel('A'));im=ImageEnhance.Brightness(gray).enhance(.6)
   self.image(im,[x+8,y+8,116,116]);self.part('ability_slot',[x,y,132,132])
   if i==0:self.part('selected_slot',[x,y,132,132])
   self.key(str(i+1),x+90,y+90);self.hits.append({'id':a['Name'],'rect':[x,y,140,140],'disabled':not q['usable'],'reason':q['reason']})
 def actions(self):
  for i,(icon,cap,action) in enumerate([('intent-move','Q','combat_move'),('intent-block','W','combat_defend'),('item-generic','I','inventory'),('exit','F','combat_flee')]):
   x=1584+(i%2)*136;y=836+(i//2)*112;self.part('action_button',[x,y,128,100]);self.line_icon(icon,[x+34,y+17,48,48]);self.key(cap,x+78,y+54);self.hits.append({'id':action,'rect':[x,y-6,128,112]})
 def render(self):
  self.part('register',[46,32,272,64]);self.text('REGISTRO',[86,42,162,44],30);self.key('L',254,40);self.hits.append({'id':'combat_log','rect':[46,24,272,112]});self.order();self.world();self.hero();self.abilities();self.actions()
  suffix=('_large' if self.large else '')+('_colorblind' if self.cb else '');name='hud'+suffix;self.im.convert('RGB').save(OUT/(name+'.webp'),quality=94,method=6);self.im.convert('RGB').resize((768,432),Image.Resampling.LANCZOS).save(OUT/(name+'_40.webp'),quality=91)
  if self.large and self.cb:ImageOps.grayscale(self.im.convert('RGB')).save(OUT/'hud_gray.webp',quality=90)
  ref=Image.open(ROOT/'docs/design/reference/hud-target-2026-10-25.webp').convert('RGB').resize((1920,1080),Image.Resampling.LANCZOS);pair=Image.new('RGB',(3840,1152),'#121518');d=ImageDraw.Draw(pair);f=ImageFont.truetype(str(FONT),32);d.text((32,20),'ALVO APROVADO / LUCAS',font=f,fill='#efe6d6');d.text((1952,20),'ENTREGA / '+('MAIOR' if self.large else 'NORMAL')+(' / DALTONISMO' if self.cb else ''),font=f,fill='#efe6d6');pair.paste(ref,(0,72));pair.paste(self.im.convert('RGB'),(1920,72));pair.save(OUT/('comparison'+suffix+'.webp'),quality=93,method=6)
  record={'file':name+'.webp','large':self.large,'colorblind':self.cb,'labels':self.labels,'pieces':self.pieces,'hits':self.hits,'ring':self.ring,'order':self.order_ids,'unchanged_ability_art':self.source_icons,'overflows':[t for t in self.labels if not t['fits']],'sha256':sha(OUT/(name+'.webp'))};ALL.append(record)
def main():
 for large,cb in [(False,False),(True,False),(False,True),(True,True)]:Board(large,cb).render()
 (OUT/'checks.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'source_sha256':sha(SOURCE),'reference':MAN['source_reference'],'reference_sha256':MAN['source_sha256'],'profiles':ALL},ensure_ascii=False,indent=2)+'\n');print('Profiles4; label overflows',sum(len(r['overflows']) for r in ALL))
if __name__=='__main__':main()
