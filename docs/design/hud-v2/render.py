"""Pranchas #58: composição determinística sobre frames congelados reais.
Fontes: kit #59, capturas e metadados auditáveis; não altera o jogo.
"""
import sys
sys.dont_write_bytecode=True
from pathlib import Path
import json,re,hashlib,argparse
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as kit
OUT=Path(__file__).resolve().parent
PAGES={}
AUDIT=[]
ABILITIES=json.loads((ROOT/'data/abilities.json').read_text())
COMBAT_ART=json.loads((ROOT/'data/presentation/combat_art.json').read_text())
class Board(kit.Canvas):
 def __init__(self,bg,large=False,cb=False):
  super().__init__(large,cb);self.im=Image.open(bg).convert('RGB');self.d=ImageDraw.Draw(self.im);self.records=[];self.h=80 if large else 64;self.line=48 if large else 40
 def text(self,x,y,t,role='body',color='text',width=None):
  t=str(t).replace('→',' para ').replace('←',' de ').replace('≠',' diferente de ')
  self.records.append({'text':str(t),'x':x,'y':y,'role':role,'width':width})
  return super().text(x,y,str(t),role,color,width)
 def button(self,x,y,w,t,focus=False,disabled=False,chosen=False):
  self.box(x,y,w,self.h,'button_disabled' if disabled else 'button_normal');self.text(x+24,y+22,t,'body','muted' if disabled else 'text',w-48)
  if focus:self.focus(x,y,w,self.h)
  if disabled:self.badge(x+w-38,y+20,'disabled')
  if chosen:self.diamond(x+w-24,y+self.h/2)
 def panel(self,title,x=1232,y=144,w=640,h=824):
  self.box(x,y,w,h);th=self.text(x+24,y+24,title,'title',width=w-48);return x+24,y+24+max(80,th+16),w-48
 def notice(self,t,y=176,alert=False):
  self.box(592,y,736,96 if self.large else 80,'panel_normal');self.icon(616,y+24,'intent-unknown' if alert else 'node-event',32,'danger' if alert else 'text');self.text(672,y+24,t,'body',width=624)
 def portrait(self,name,x,y,size=64):
  src=Image.open(ROOT/f'art/ui/portraits/{name}.png').convert('RGBA').resize((size,size));self.im.paste(src,(x,y),src)
 def header(self,title,resource=False):
  self.box(48,32,1824,104);self.text(72,64,title,'title')
  if resource:
   ts=getattr(self,'source_texts',[])
   def val(k,default):
    return ts[ts.index(k)+1] if k in ts else default
   for x,icon,text in [(1040,'lobby-food',val('COMIDA','0 / 12').replace(' suprimentos','')),(1320,'lobby-water',val('ÁGUA','6').replace(' em estoque','')),(1552,'lobby-energy',val('ENERGIA','1 / 3').replace(' em uso',''))]:
    self.icon(x,64,icon,32);self.text(x+48,64,text)
 def footer(self,text='Esc · Voltar',right=''):
  self.box(48,976,1824,72);self.text(72,1000,text,'detail','muted');self.text(1400,1000,right,'detail','muted')
 def rows(self,items,x,y,w,selected=0):
  for i,item in enumerate(items):
   h=112 if self.large else 96
   self.box(x,y+i*(h+8),w,h,'ability_selected' if i==selected else 'panel_normal')
   self.text(x+24,y+24+i*(h+8),item[0],'body',width=w-48)
   if len(item)>1:self.text(x+24,y+64+i*(h+8),item[1],'detail','muted',w-48)
   if i==selected:self.diamond(x+w-24,y+i*(h+8)+24)

def strings(meta):return [r['text'] for r in meta['texts']]
def matching(ts,prefix,fallback=''):return next((t for t in ts if t.startswith(prefix)),fallback)
def station(c,name,ts):
 if name.endswith('options'):options(c,ts);return
 if name=='station-hidden':return
 c.header('Estação Raiz',True)
 if name=='station-hidden':return
 if name in ['station','station-room-focus']:
  x,y,w=c.panel('Próximo passo',48,160,560,320 if c.large else 288)
  c.text(x,y,'Recuperar a Forja','body',width=w);c.text(x,y+64,'Custo: 4 sucatas · Uso: 1 energia','detail','muted',w)
  c.button(x,y+120,w,'Ver a Forja',focus=True)
  if name.endswith('focus'):
   x,y,w=c.panel('Alojamento',48,648,560,304)
   c.text(x,y,'Conhecer e acompanhar os moradores.','body',width=w);c.button(x,y+112,w,'Gerenciar')
  c.button(1360,864,512,'Preparar expedição')
  c.footer('Setas · Cômodos    E · Abrir','F2 · Ocultar HUD');return
 if name=='station-plan':
  x,y,w=c.panel('Plano da Estação',48,160,640,800)
  room=['Alojamento','Cantina','Bar','Dormitório','Forja','Centro de Pesquisa','Depósito','Preparação']
  for i,t in enumerate(room):
   yy=y+i*72;c.icon(x,yy,'node-start',24);c.text(x+40,yy,t,'body');
   if i==4:c.focus(x-8,yy-12,w+16,56)
  x,y,w=c.panel('Forja');c.text(x,y,'Vazio','body','muted');c.text(x,y+64,'Fabrica relíquias por 3 sucatas. Gasta 1 de energia.','body',width=w);c.text(x,y+240,'Recuperar: 4 sucatas','body');c.button(x,864,w,'Ver a Forja');c.footer();return
 if name in ['station-characters','station-character-focus']:
  x,y,w=c.panel('Alojamento',48,160,640,800)
  for i,(who,hp,role) in enumerate([('Bento','34/34','Cão Protetor'),('Nick','24/24','Gato Batedor'),('Íris','23/23','Sapo Química'),('Véspera','30/30','Coruja Atiradora')]):
   yy=y+i*144;c.portrait(['bento','nick','iris','vespera'][i],x,yy);c.text(x+88,yy,who);c.text(x+88,yy+56,'Vida '+hp,'detail','muted')
  c.button(x,864,w,'Recrutar')
  x,y,w=c.panel('Bento');c.text(x,y,'Cão Protetor');c.text(x,y+64,'Vida 34/34 · Instinto 0','body',width=w);c.text(x,y+128,'0 expedições · Relíquia: nenhuma','body',width=w);c.button(x,y+240,w,'Relíquias',focus=True);c.button(x,y+344,w,'Trauma');c.footer();return
 if name=='station-preparation':
  x,y,w=c.panel('Preparação');c.text(x,y,'Rua das Vitrines','body',width=w);c.text(x,y+64,'Fase 1 · Fácil · Nível 1+','detail','muted',w)
  c.text(x,y+128,'Foco da rota','body');c.button(x,432,272,'Provisões',chosen=True);c.button(x+288,432,144,'Água');c.button(x+448,432,144,'Peças')
  c.text(x,576,'Comida','body');c.text(x,624,'4 grátis + 0 extras','detail');c.text(x,672,'Estoque 0/12 · A noite da volta pede 4','detail','muted',w);c.button(x,736,80,'−');c.button(x+w-80,736,80,'+');c.text(x+208,760,'0 extras','body');c.text(x,824,'Custo: 0 sementes','detail');c.button(x,864,w,'Partir',focus=True)
  for i,(who,hp) in enumerate([('Véspera','30/30'),('Íris','23/23'),('Nick','24/24'),('Bento','34/34')]):
   xx=48+i*288;yy=744 if c.large else 776;c.box(xx,yy,272,208 if c.large else 176);c.text(xx+24,yy+24,f'{4-i} · {who}');c.text(xx+24,yy+88,'Vida '+hp,'detail','muted');c.text(xx+24,yy+144,('3/4' if i==0 else '4/4')+' habilidades','detail','muted')
  c.footer('Setas · Posição    E · Trocar','Esc · Mapa');return
 if name=='station-map':
  from importlib.util import spec_from_file_location,module_from_spec
  spec=spec_from_file_location('map_tags',ROOT/'docs/design/ui-kit/map_labels/render.py')
  # O módulo da prancha também exporta a função semântica; composição abaixo usa o mesmo contrato.
  c.box(48,160,1160,800)
  src=Image.open(ROOT/'art/ui/map/flooded-railway-map.webp') if (ROOT/'art/ui/map/flooded-railway-map.webp').exists() else None
  if src:c.im.paste(ImageOps.fit(src.convert('RGB'),(1128,768)),(64,176))
  logical=[('Estação Raiz','Refúgio',140,480),('Fase 1','Disponível',330,300),('Fase 2','Bloqueada',520,470),('Fase 3','Bloqueada',640,210),('Fase 4','Bloqueada',830,430),('Fase 5','Bloqueada',980,190)]
  for i,(t,state,lx,ly) in enumerate(logical):
   px=round(64+lx*1128/1100);py=round(176+ly*768/660);ww,hh=(272,112) if c.large else (240,96);xx=max(72,min(1184-ww,px-ww//2));yy=py+32
   c.d.line((px,py,xx+ww//2,yy),fill=c.c('copper'),width=2);c.d.ellipse((px-12,py-12,px+12,py+12),fill=c.c('bg'),outline=c.c('text'),width=2)
   c.box(xx,yy,ww,hh,'ability_selected' if i==1 else 'panel_normal');c.icon(xx+16,yy+18,'node-start' if i==0 else 'marker-available' if i==1 else 'node-combat',24);c.text(xx+56,yy+16,t);c.text(xx+16,yy+(64 if c.large else 56),state,'detail','muted')
   if i==1:c.diamond(xx+ww-24,yy+hh-24);c.focus(xx,yy,ww,hh)
  x,y,w=c.panel('Rua das Vitrines');c.text(x,y,'Fase 1 · Fácil · Nível 1+','body',width=w);c.text(x,y+96,'10 trechos · Disponível','body',width=w);c.text(x,y+192,'Vitrines tomadas por raízes ainda guardam comida e peças que a Estação não sabe mais fabricar.','body',width=w);c.button(x,864,w,'Preparar expedição',focus=True);c.footer();return
 if name=='station-train':
  x,y,w=c.panel('Dora');c.text(x,y,'Cozinheira · Texugo','body',width=w)
  c.text(x,y+80,matching(ts,'Ponto forte:'),'body',width=w)
  c.text(x,y+256,matching(ts,'Ponto fraco:'),'body',width=w)
  c.text(x,y+416,matching(ts,'Suprimentos depois da noite:').replace(' → ',' para '),'detail',width=w)
  c.button(x,864,280,'Acolher Dora');c.button(x+296,864,296,'Recusar')
  x,y,w=c.panel('Pedido',48,160,448,352);c.text(x,y,matching(ts,'Pedido:').removeprefix('Pedido: '),'body',width=w);c.footer();return
 if name in ['station-report','station-report-focus']:
  x,y,w=c.panel('Relatório da volta',480,160,960,800)
  if name.endswith('focus'):
   c.text(x,y,'O que a equipe viu','body');c.text(x,y+80,matching(ts,'A Estação aguenta'),'body',width=w)
   c.text(x,y+320,'Agora dá para','body')
   for i,t in enumerate([matching(ts,'Recuperar a Forja'),matching(ts,'Recuperar o Centro'),matching(ts,'Melhorar o Depósito')]):c.text(x,y+400+i*80,t,'detail',width=w)
  else:
   c.text(x,y,'Vitória · Rua das Vitrines','body',width=w)
   for i,(icon,t) in enumerate([('lobby-seed','+6 sementes'),('lobby-scrap','+3 sucatas'),('lobby-fragment','+1 fragmento')]):
    xx=x+i*304;c.box(xx,y+80,288,104);c.icon(xx+24,y+112,icon,32);c.text(xx+72,y+112,t,'detail')
   for i,(who,hp) in enumerate([('Bento','34/34'),('Nick','8/24'),('Íris','23/23'),('Véspera','30/30')]):c.text(x,y+240+i*96,who);c.text(x+400,y+240+i*96,'Vida '+hp,'body','danger' if who=='Nick' else 'text')
  c.button(x,864,w,'Continuar',focus=True);c.footer();return
 if name=='station-night':
  x,y,w=c.panel('Dormitório');c.text(x,y,'Noite 1 · 4 dormindo · 0 vigiando','body',width=w);c.text(x,y+64,'4 suprimentos necessários · 6 disponíveis','detail','muted',w)
  for i,who in enumerate(['Bento','Nick','Íris','Véspera']):
   yy=y+128+i*128;c.text(x,yy,who);c.button(x+208,yy,176,'Dormir',chosen=True);c.button(x+400,yy,192,'Vigiar');c.text(x,yy+64,'Vida 8/24 · +8' if who=='Nick' else 'Vida cheia · +0','detail','muted',184)
  c.text(72,800,'+1 suprimento · 2 sementes','detail');c.button(48,864,560,'Comprar suprimento');c.button(x,864,w,'Iniciar descanso',focus=True);c.footer();return
 if name=='station-depot':
  x,y,w=c.panel('Depósito');c.text(x,y,'0 / 12 suprimentos','body');c.text(x,y+64,'O excesso estraga na volta.','detail','muted',w)
  for i,(label,value) in enumerate([('Comida','0'),('Água','6'),('Curativos','2'),('Sementes','30'),('Sucata','9'),('Fragmentos','3')]):
   xx=x+(i%2)*296;yy=y+144+(i//2)*112;c.box(xx,yy,280,96);c.text(xx+24,yy+16,label,'detail');c.text(xx+24,yy+56,value,'body')
  c.text(x,736,'Relíquias: nenhuma','detail','muted');c.text(x,784,'Ferramentas: nenhuma','detail','muted');c.text(x,832,'Custo: 5 sucatas e 1 fragmento','detail');c.button(x,864,w,'Melhorar',focus=True);c.footer();return
 titles={'canteen':'Cantina','depot':'Depósito','forge':'Forja','research':'Centro de Pesquisa','dormitory':'Dormitório','bar':'Bar'}
 key=name.removeprefix('station-');title=titles[key];x,y,w=c.panel(title);pos=next((i for i,t in enumerate(ts) if t==title),18);items=ts[pos+1:];yy=y;buttons=[]
 for t in items:
  if t.startswith(('Recuperar','Melhorar','Comprar','Passar')):buttons.append(t);continue
  yy+=c.text(x,yy,t,'body',width=w)+24
 for i,t in enumerate(buttons[:1]):
  action=t.split(' (')[0];cost=t[len(action):].strip();c.text(x,800,cost,'detail','muted',w);c.button(x,864,w,action,focus=True)
 c.footer()

def options(c,ts):
 x,y,w=c.panel('Opções',480,112,960,848)
 c.rows([('Som',),('Imagem',),('Jogo',),('Acessibilidade',)],x,y,288,3)
 xx=x+320
 c.text(xx,y,'Tamanho do texto','body');c.rows([('Normal',),('Grande',),('Maior',)],xx,y+64,568,2 if c.large else 0)
 c.text(xx,y+456,'Modo daltonismo','body');c.button(xx,y+520,568,'Ligado' if c.cb else 'Desligado',chosen=c.cb)
 c.button(x,864,w,'Voltar',focus=True);c.footer('Setas · Navegar    E · Alterar','Esc · Voltar')

def title(c,name,ts):
 if name.endswith('options'):options(c,ts);return
 if name in ['title','title-continue']:
  x,y,w=c.panel('Campanha',1232,376,640,576)
  yy=y
  for t in (['Continuar','Nova campanha','Campanhas','Opções'] if name.endswith('continue') else ['Nova campanha','Opções']):
   c.button(x,yy,w,t,focus=(yy==y));yy+=c.h+24
  return
 x,y,w=c.panel('Nova campanha' if 'empty' in name else 'Campanhas',480,160,960,800)
 if name=='title-confirm':
  c.text(x,y,'Começar uma campanha nova?','body',width=w)
  c.text(x,y+96,'Todo o progresso salvo no espaço 1 é substituído por uma campanha do zero. Os outros espaços ficam como estão.','body',width=w)
  c.button(x,744,w,'Cancelar',focus=True);c.button(x,848,w,'Começar do zero');return
 for i in range(3):
  yy=y+i*176;c.box(x,yy,w,152);c.text(x+24,yy+24,f'Espaço {i+1}')
  actual=next((t for t in ts if t.startswith(f'Espaço {i+1} ')),f'Espaço {i+1} — vazio')
  if 'vazio' in actual.lower():detail='Vazio'
  else:
   head,*tail=actual.split('\n');c.text(x+24,yy+64,head.split('—')[-1].strip(),'detail','muted',w-48);detail=(tail[0] if tail else '')
  c.text(x+24,yy+112 if 'vazio' not in actual.lower() else yy+88,detail,'detail','muted',w-48)
  if i==0:c.focus(x,yy,w,152)
 c.button(x,864,w,'Voltar')

def explore_base(c,ts,touch=False):
 c.box(48,32,640,104);c.text(72,60,ts[0],'title');c.icon(616,68,'node-boss',32)
 # Trechos como sequência: só a posição corrente é número; os demais são formas.
 c.box(736,32,448,104)
 for i in range(10):
  xx=760+i*40;c.d.ellipse((xx,76,xx+16,92),fill=c.c('gold' if i==0 else 'muted'))
 route=next((t for t in ts if t.startswith('Trecho ')),'Interior');digits=re.findall(r'\d+',route);c.text(1216,72,' / '.join(digits[:2]) if digits else 'Interior','detail')
 for i,name in enumerate(['vespera','iris','nick','bento']):
  xx=48+i*(128 if touch else 104);sz=112 if touch else 88;yy=912 if touch else 920;c.box(xx,yy,sz,sz);c.portrait(name,xx+(sz-64)//2,yy+(sz-64)//2,64)
 c.box(48,824,400,64);c.icon(72,840,'lobby-food',32);c.text(120,844,ts[ts.index('Comida')+1].split('/')[0] if 'Comida' in ts else '4');c.icon(224,840,'res-bandages',32);c.text(272,844,'2')
 for i,icon in enumerate(['item-generic','node-start','lobby-energy']):
  xx=1568+i*104;c.box(xx,920,88,88);c.icon(xx+24,944,icon,40)
 if touch:
  for xx,icon in [(48,'node-start'),(176,'marker-available'),(1616,'node-event'),(1744,'item-generic')]:
   c.box(xx,688,112,112);c.icon(xx+32,720,icon,48);c.focus(xx,688,112,112)

def explore(c,name,ts):
 if 'inventory' in name or name=='explore-item-focus':inventory(c,name,ts);return
 if name.endswith('options'):options(c,ts);return
 explore_base(c,ts,name.endswith('touch'))
 if name=='explore-team-focus':
  x,y,w=c.panel('Bento');c.text(x,y,'Vida 34/34');c.text(x,y+64,'Instinto 0/200');c.text(x,y+128,'Posição 1 · Tanque e Proteção','body',width=w);c.text(x,y+240,'Sem estados','body');c.button(x,864,w,'Fechar');return
 if name=='explore-resources-focus':
  x,y,w=c.panel('Recursos e achado');c.rows([('Comida: 4','1 comida: 15% · 3 comidas: 35%'),('Curativos: 2','Cura 8 de vida'),('Ampola: 3 cargas','Cura orgânica: 5–8 vida'),('Achado','0 sementes · 0 sucata · 0 fragmentos'),('Esperança','80')],x,y,w);return
 if name=='explore-objective-focus':
  x,y,w=c.panel('Objetivo da rota');c.text(x,y,'Vencer o guardião (trecho 10)','body',width=w);c.text(x,y+128,'Rota básica: o achado das buscas volta com a equipe.','body',width=w);return
 if name=='explore-interaction':
  c.box(776,664,368,80);c.icon(800,688,'node-loot',32);c.text(856,688,'E · Examinar');return
 if name=='explore-patrol':c.notice('Patrulha por perto',alert=True);return
 if name=='explore-loot':
  c.box(896,560,272,80);c.icon(920,584,'lobby-scrap',32);c.text(968,584,'+1 Sucata');return
 if name=='explore-search':c.notice('+1 Comida · +1 Semente');return
 if name=='explore-risk':
  x,y,w=c.panel('Abandonar a expedição?',480,256,960,576);c.text(x,y,'A equipe volta pelo trem sem enfrentar o guardião: só metade do achado chega à Estação.','body',width=w);c.button(x,616,w,'Continuar a expedição',focus=True);c.button(x,720,w,'Voltar à Estação');return
 if name=='explore-camp':
  x,y,w=c.panel('Acampamento',480,160,960,800)
  c.text(x,y,'Comida 4 · Curativos 2','body');c.text(x,y+64,'Comer: +10% vida, −5 instinto. Curativo: +8 vida.','detail','muted',w)
  for i,(who,hp) in enumerate([('Véspera','30/30'),('Íris','23/23'),('Nick','24/24'),('Bento','34/34')]):
   yy=y+144+i*128;c.text(x,yy,who);c.text(x,yy+48,f'Vida {hp} · Instinto 0','detail','muted');c.button(x+432,yy,208,'Comer',disabled=True);c.button(x+664,yy,208,'Curativo',disabled=True)
  c.button(x,864,w,'Levantar acampamento',focus=True);return
 if name in ['explore-event','scenario-event']:
  start=next(i for i,t in enumerate(ts) if t.startswith('Ao vasculhar:'))
  title=ts[start-1];body=ts[start+1];choices=ts[start+2:]
  font=kit.font(round(24*c.s));lines=1;line=''
  for word in body.split():
   q=(line+' '+word).strip()
   if font.getlength(q)>912 and line:lines+=1;line=word
   else:line=q
  ch=112 if c.large else 96;ph=104+lines*c.line+24+len(choices)*(ch+16)-16+24
  x,y,w=c.panel(title,480,112,960,ph)
  h=c.text(x,y,body,'body',width=w)
  yy=y+h+24
  for i,t in enumerate(choices):
   line=t.split('  (')[0];condition=t[len(line):].strip().strip('()')
   ch=112 if c.large else 96
   c.box(x,yy,w,ch,'button_disabled' if 'Requer' in condition else 'button_normal')
   c.text(x+24,yy+20,line,'body',width=w-48)
   if condition:c.text(x+24,yy+68,condition,'detail','muted',w-48)
   if i==1:c.focus(x,yy,w,ch)
   if 'Requer' in condition:c.badge(x+w-48,yy+24,'disabled')
   yy+=ch+16
  return

def combat_base(c,ts):
 actor=next((t.split(' · agora')[0] for t in ts if t.endswith(' · agora')),'Bento');c.actor=actor;c.actor_file={'Bento':'bento','Nick':'nick','Íris':'iris','Véspera':'vespera'}[actor];c.skills=[r for r in ABILITIES if r['DisplayName'] in ts and r['ClassId']=={'Bento':'cao','Nick':'gato','Íris':'sapo','Véspera':'coruja'}[actor]][:4];c.skill=c.skills[0] if c.skills else ABILITIES[0]
 c.box(688,32,544,96);c.text(712,64,'Rodada 1','detail')
 order=ts[next(i for i,t in enumerate(ts) if t.startswith('RODADA'))+1:][:6]
 for i,name in enumerate(order):
  who=name.split(' · agora')[0];faces={'Bento':'bento','Nick':'nick','Íris':'iris','Véspera':'vespera'}
  if who in faces:c.portrait(faces[who],872+i*56,52,48)
  else:
   art=COMBAT_ART['enemies']['recreador' if 'Recreador' in who else 'sussurrador']['idle'];im=Image.open(ROOT/art['file'].removeprefix('res://')).convert('RGBA');bounds=im.getbbox();im=ImageOps.contain(im.crop(bounds),(48,48));c.im.paste(im,(872+i*56,52),im)
  if i==0:c.diamond(896,112)
 # Âncoras das placas correspondem aos pés da captura real; a linha não recebe nome e vida duplicados.
 for i,(xx,ww) in enumerate([(208,160),(440,160),(672,160),(904,160),(1256,208),(1512,208)]):
  c.box(xx,760,ww,72,'ability_selected' if i=={'Bento':3,'Nick':2,'Íris':1,'Véspera':0}[c.actor] else 'panel_normal');c.text(xx+16,784,str([4,3,2,1,1,2][i]),'detail')
  name=['Véspera','Íris','Nick','Bento','Recreador','Emissor de Comando'][i];hp=ts[ts.index(name)+1] if name in ts else '1/1';nums=list(map(int,re.findall(r'\d+',hp)[:2]));ratio=nums[0]/max(1,nums[1]) if len(nums)==2 else 1;c.d.rounded_rectangle((xx+48,784,xx+ww-16,796),3,fill=c.c('edge'));c.d.rounded_rectangle((xx+48,784,xx+48+max(1,(ww-64)*ratio),796),3,fill=c.c('text'))
  if i<4:c.d.rectangle((xx+48,808,xx+ww-16,812),fill=c.c('muted'))
  else:c.icon(xx+ww-48,728,'intent-attack',32)
 c.box(48,864,1824,184);c.portrait(c.actor_file,72,896,80);c.text(176,896,c.actor,'body');c.diamond(176,968)
 for i,ability in enumerate(c.skills):
  xx=448+i*128;rank={'Bento':1,'Nick':2,'Íris':3,'Véspera':4}[c.actor];locked=rank not in ability.get('OriginRanks',[]) or (ability.get('TargetType')=='SingleEnemy' and not set(ability.get('TargetRanks',[])).intersection([1,2]));c.box(xx,896,104,104,'ability_locked' if locked else 'ability_normal');_art=Image.open(ROOT/('art/combat/icons/'+ability['Name']+'.webp')).convert('RGBA').resize((64,64));c.im.paste(_art,(xx+20,904),_art);c.text(xx+16,968,str(i+1),'detail');
  if locked:c.badge(xx+68,976,'disabled')
 for i,(icon,hotkey) in enumerate([('intent-move','Q'),('intent-block','W'),('item-generic','I'),('node-start','F')]):
  xx=1152+i*160;c.box(xx,896,136,104);c.icon(xx+24,912,icon,40);c.text(xx+88,936,hotkey,'detail')

def combat(c,name,ts):
 if name=='combat-result':
  x,y,w=c.panel('Vitória',480,160,960,800);c.text(x,y,'A patrulha foi neutralizada.','body',width=w)
  for i,who in enumerate(['Bento','Nick','Íris','Véspera']):
   yy=y+112+i*104;c.text(x,yy,who);c.text(x+400,yy,ts[ts.index(who)+1] if who in ts else 'Vivo','detail')
  c.button(x,864,w,'Continuar',focus=True);return
 combat_base(c,ts)
 if name=='combat':return
 if name=='combat-inventory':inventory(c,name,ts);return
 if name=='combat-crisis':c.notice('Crise de instinto · Superação',y=192,alert=True);return
 if name=='combat-result':
  x,y,w=c.panel('Vitória',480,256,960,544);c.text(x,y,'A patrulha caiu.','body');c.button(x,672,w,'Continuar',focus=True);return
 if name=='combat-action-focus':
  x,y,w=c.panel('Defender',1232,192,640,320);c.text(x,y,'+1 Bloqueio e passa a vez.','body',width=w);c.focus(1312,896,136,104);return
 if name in ['combat-unit-focus','combat-intent-focus']:
  x,y,w=c.panel(c.actor if 'unit' in name else 'Recreador',1232,160,640,544)
  rows=[next((t for t in ts if t.startswith('Vida ')),'Vida'),next((t for t in ts if t.startswith('Instinto ')),'Instinto'),'Posição '+str({'Bento':1,'Nick':2,'Íris':3,'Véspera':4}[c.actor])+' · Sem estados'] if 'unit' in name else ['Vida 8/8 · Posição 1','Pega-Pega → um de 4']
  for i,t in enumerate(rows):c.text(x,y+i*80,t,'body',width=w)
  return
 skill=c.skill
 if name=='combat-area-target':skill=next(r for r in ABILITIES if r['Name']=='sapo_coquetel_corrosivo')
 tx=608 if c.actor in ['Íris','Véspera'] else 48;tw=640 if c.large else 480
 x,y,w=c.panel(skill['DisplayName'],tx,144,tw,576)
 yy=y
 if 'DamageRange' in skill:
  yy+=c.text(x,yy,f"{skill['DamageRange']['Min']}–{skill['DamageRange']['Max']} de dano",'body')+16
 yy+=c.text(x,yy,'De: '+', '.join(map(str,skill['OriginRanks']))+' · Em: '+', '.join(map(str,skill['TargetRanks'])),'detail',width=w)+16
 yy+=c.text(x,yy,skill['Description'],'detail',width=w)+16
 if skill.get('Cooldown'):yy+=c.text(x,yy,'Recarga: '+str(skill['Cooldown']),'detail')+16
 if name in ['combat-target','combat-area-target']:
  preview=next((t for t in ts if t.startswith('Atinge:')),'Atinge: Recreador (vida 8)');picked=preview.removeprefix('Atinge: ').split(' (')[0];px=1496 if 'Emissor' in picked else 1248
  hp=ts[ts.index(picked)+1] if picked in ts else '';c.text(x,yy,picked+' · '+hp,'body',width=w)
  c.focus(px,432,240,328);c.box(px,376,160,48);c.text(px+16,392,'Alvo','detail');c.d.polygon([(px+120,416),(px+108,400),(px+132,400)],fill=c.c('text'))
  if name=='combat-area-target':
   c.box(1496,376,272,48);c.text(1512,392,'Também atingido','detail');c.d.line((1512,416,1720,416),fill=c.c('text'),width=3);c.box(1248,304,520,64);c.text(1272,328,'Recreador + Emissor','body')
 else:c.focus(448,896,104,104)

# A Mochila usa o mesmo painel e as mesmas fichas; nenhuma regra de cura é inventada.
def inventory(c,name,ts):
 x,y,w=c.panel('Mochila',480,160,960,800)
 for i,t in enumerate(['Suprimentos','Ferramentas','Recursos']):
  c.button(x+i*304,y,288,t,chosen=(i==0))
 yy=y+112
 for i,(icon,label,qty) in enumerate([('lobby-food','Comida','4 / 8'),('res-bandages','Curativo','2'),('item-ampoule','Ampola','3 cargas')]):
  xx=x+i*184;c.box(xx,yy,168,176);c.icon(xx+24,yy+24,icon,40);c.text(xx+24,yy+88,label,'detail');c.text(xx+24,yy+128,qty,'detail','muted')
  if i==0:c.focus(xx,yy,168,176)
 xx=x+592;ww=320;c.text(xx,yy,'Comida','body');target=c.actor+' · Vida '+ts[ts.index(c.actor)+1] if name.startswith('combat') else 'Bento · Vida 34/34';c.text(xx,yy+64,target,'detail',width=ww)
 for j,(action,cost) in enumerate([('Comer pouco','1 comida · 15% vida'),('Comer bem','3 comidas · 35% vida')]):
  ay=yy+128+j*144;c.box(xx,ay,ww,128,'button_disabled');c.text(xx+16,ay+24,action,'body');c.text(xx+16,ay+80,cost,'detail','muted');c.badge(xx+ww-36,ay+24,'disabled')
 c.text(x,yy+248,'O aliado já está com a vida cheia.','body',width=536)
 c.text(x,yy+352,'Na luta: ação livre do herói da vez.' if name.startswith('combat') else 'Setas · Escolher aliado','detail','muted',536)
 c.button(x,864,w,'Fechar');c.footer('Setas · Item e aliado    E · Usar','Esc · Fechar')

def options_extra(c,name,ts):
 x,y,w=c.panel('Opções',480,112,960,848)
 c.rows([('Som',),('Imagem',),('Jogo',),('Acessibilidade',)],x,y,288,0 if name.endswith('sound') else 2 if name.endswith('game') else 1)
 xx=x+320
 if name.endswith('sound'):
  for i,t in enumerate(['Música','Ambiente','Efeitos']):
   yy=y+i*176;c.text(xx,yy,t);c.text(xx+456,yy,'60%','detail');c.d.rounded_rectangle((xx,yy+64,xx+568,yy+96),8,fill=c.c('edge'));c.d.rectangle((xx+16,yy+76,xx+16+round(536*.6),yy+84),fill=c.c('text'))
 elif name.endswith('game'):
  c.text(xx,y,'Velocidade da batalha');c.button(xx,y+64,568,'1x',chosen=True)
  c.text(xx,y+200,'Dicas da primeira vez');c.button(xx,y+264,272,'Desligado');c.button(xx+288,y+264,280,'Rever dicas')
  c.text(xx,y+400,'Idioma');c.button(xx,y+464,272,'Português',chosen=True);c.button(xx+288,y+464,280,'English');c.text(xx+304,y+560,'Em teste','detail','muted')
 else:
  c.text(xx,y,'Qualidade');c.button(xx,y+64,568,'Alto',chosen=True)
  c.text(xx,y+200,'Tela cheia');c.button(xx,y+264,568,'Desligado')
  c.text(xx,y+400,'Sincronia vertical');c.button(xx,y+464,568,'Ligado');c.text(xx,y+600,'Reduzir efeitos: desligado','detail',width=568)
 c.button(x,864,w,'Voltar',focus=True);c.footer()

def visible_before(meta,base,large):
 entries=meta['texts'];excluded=[]
 if base=='station-map':
  start=next(i for i,r in enumerate(entries) if r['text']=='Mapa ferroviário')
  excluded+=[dict(r,reason='Encoberto pelo fundo opaco do mapa') for r in entries[:start]];entries=entries[start:]
 skip=[]
 if base=='station-map' and large:skip=['Ponte das Raízes\nFase 2 · Moderada · Nível 3+ · Bloqueada']
 if base=='station-plan':skip=['Recuperar: Fabrica relíquias por 3 sucatas. Gasta 1 de energia. · 4 sucatas'] if large else ['Guarda até 12 suprimentos; o excesso estraga na volta.']
 if base=='title-options' and large:skip=['Tamanho do texto','Normal','Grande','▸ Maior']
 kept=[]
 for r in entries:
  if r['clipped'] and r['text'] in skip:excluded.append(dict(r,reason='Controle intersecta o recorte, mas os glifos não são legíveis no JPG; revisão visual'))
  else:kept.append(r['text'])
 return kept,excluded

def count(texts):
 return {'text_blocks':sum(bool(re.search(r'[^\W\d_]',t)) for t in texts),'numbers':sum(len(re.findall(r'\d+(?:[.,]\d+)?',t)) for t in texts)}

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--sources',type=Path,default=Path('/workspace/scratch/round69_58'));ap.add_argument('--documented-frames',action='store_true');ap.add_argument('--reuse',action='store_true');ap.add_argument('--only',default='');args=ap.parse_args()
 source=args.sources;manifest={};(OUT/'before').mkdir(exist_ok=True)
 if args.documented_frames:
  manifest=json.loads((OUT/'captures.json').read_text())
 else:
  for size,dirs in [('normal',['audit','extra','inside','area','targets','loot']),('large',['audit-large','extra-large','inside-large','area-large','targets-large','loot-large'])]:
   manifest[size]={}
   for folder in dirs:
    for p in sorted((source/folder).glob('*.json')):
     if not (p.parent/(p.stem+'_clean.png')).exists():continue
     name=p.stem;key=name+('' if size=='normal' else '_large');meta=json.loads(p.read_text());raw=p.with_suffix('.png');clean=p.parent/(name+'_clean.png')
     if not args.reuse:
      Image.open(raw).convert('RGB').save(OUT/'before'/f'{key}.jpg',quality=78,optimize=True)
      Image.open(clean).convert('RGB').save(OUT/'before'/f'{key}_clean.webp',quality=84,method=6)
      (OUT/'before'/f'{key}.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
      cbraw=p.parent/(name+'_clean_cb.png')
      if cbraw.exists():Image.open(cbraw).convert('RGB').save(OUT/'before'/f'{key}_clean_cb.webp',quality=84,method=6)
     manifest[size][name]={'before':f'before/{key}.jpg','background':f'before/{key}_clean.webp','metadata':f'before/{key}.json','capture_png_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'clean_png_sha256':hashlib.sha256(clean.read_bytes()).hexdigest(),'capture_folder':folder,'colorblind_clean_png_sha256':hashlib.sha256((p.parent/(name+'_clean_cb.png')).read_bytes()).hexdigest() if (p.parent/(name+'_clean_cb.png')).exists() else None,'commit':'e0c15e9' if folder.startswith(('targets','loot')) else 'bc81822','staged':name in ['combat-crisis','combat-result','station-train','explore-interior','explore-search']}
 common=sorted(set(manifest['normal']) & set(manifest['large']))
 for size in ['normal','large']:
  for name,m in manifest[size].items():
   cbfile=m['background'].replace('_clean.webp','_clean_cb.webp')
   if (OUT/cbfile).exists():m['background_colorblind']=cbfile
 required={'station','station-plan','station-characters','station-forge','station-canteen','station-depot','station-research','station-dormitory','station-bar','station-train','station-preparation','station-map','station-report','station-night','explore','explore-interaction','explore-patrol','explore-camp','explore-interior','explore-search','explore-loot','explore-risk','explore-event','scenario-event','explore-inventory','explore-options','explore-touch','combat','combat-skill-focus','combat-target','combat-area-target','combat-crisis','combat-result','combat-inventory','title','title-continue','title-slots','title-slots-empty','title-confirm','title-options','station-options'}
 assert required.issubset(common),f'Faltam capturas reais Normal/Maior: {required-set(common)}'
 variants={'station-room-focus':'station','station-report-focus':'station-report','station-hidden':'station','station-character-focus':'station-characters','explore-team-focus':'explore','explore-resources-focus':'explore','explore-objective-focus':'explore','combat-unit-focus':'combat','combat-intent-focus':'combat','combat-action-focus':'combat','options-sound':'station-options','options-image':'station-options','options-game':'station-options'}
 pages={name:name for name in common};pages.update(variants)
 selected=set(args.only.split(',')) if args.only else set(pages)
 if args.only:AUDIT.extend(r for r in json.loads((OUT/'counts.json').read_text()) if r['page'] not in selected)
 for page,base in sorted(pages.items()):
  if page not in selected:continue
  for large,cb,suffix in [(False,False,''),(True,False,'_large'),(False,True,'_colorblind'),(True,True,'_large_colorblind')]:
   size='large' if large else 'normal';m=manifest[size][base];meta=json.loads((OUT/m['metadata']).read_text());ts=strings(meta)
   c=Board(OUT/m.get('background_colorblind' if cb else 'background',m['background']),large,cb);c.source_texts=ts;c.source_meta=meta;kit.CHECKS.clear()
   if page in ['options-sound','options-image','options-game']:options_extra(c,page,ts)
   elif page.startswith('title'):title(c,page,ts)
   elif page.startswith('station'):station(c,page,ts)
   elif page.startswith('combat'):combat(c,page,ts)
   else:explore(c,page,ts)
   c.im.quantize(colors=256,method=Image.Quantize.MEDIANCUT).save(OUT/f'{page}{suffix}.png',optimize=True)
   visible,excluded=visible_before(meta,base,large);before=count(visible);after=count([r['text'] for r in c.records]);record={'page':page,'profile':suffix or 'normal','source':m['before'],'before':before,'after':after,'before_exclusions':excluded,'labels':c.records,'bounds':[r for r in kit.CHECKS if r['right']>1920 or r['bottom']>1080]}
   AUDIT.append(record)
   if not cb and not large:
    c.im.resize((768,432),Image.Resampling.LANCZOS).save(OUT/f'{page}_40.webp',quality=88,method=6)
   if cb and large:
    ImageOps.grayscale(c.im).save(OUT/f'{page}_gray.webp',quality=82,method=6)
 (OUT/'captures.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (OUT/'counts.json').write_text(json.dumps(AUDIT,ensure_ascii=False,indent=2)+'\n')
 print('pages',len(pages),'profiles',len(AUDIT),'outside',sum(len(r['bounds']) for r in AUDIT))
 # Resumo em quatro linhas, sem distorcer as capturas.
 summary=Image.new('RGB',(1920,2304),kit.P['bg']);d=ImageDraw.Draw(summary)
 d.text((32,16),'ANTES / JOGO ATUAL',font=kit.font(24),fill=kit.P['text']);d.text((992,16),'DEPOIS / PROPOSTA #58',font=kit.font(24),fill=kit.P['text'])
 for i,page in enumerate(['station','explore','combat','explore-inventory']):
  yy=80+i*552
  for j,path in enumerate([OUT/manifest['normal'][page]['before'],OUT/f'{page}.png']):
   im=Image.open(path).convert('RGB').resize((928,522),Image.Resampling.LANCZOS);summary.paste(im,(16+j*960,yy))
 summary.quantize(colors=256).save(OUT/'summary.png',optimize=True)
 rows=['# Capturas reais — antes da proposta #58','','Base de produção **bc81822**, capturas adicionais de mira/achado em **e0c15e9** (só documentação mudou entre esses commits). Godot **4.7.2**, 1920×1080, português. Normal e Maior (`--text-size=2`). Campanhas e configurações isoladas sob `/workspace/scratch/round69_58/`; sem ler ou alterar saves do jogador.','','O PNG original e o frame limpo foram obtidos com a árvore pausada entre as duas leituras do viewport; só os Controls/CanvasLayers da interface foram ocultados. Câmera, cenário, atores e luz permanecem no mesmo frame. JPG e WebP aqui são cópias comprimidas de documentação. Hashes SHA-256 dos PNG originais em [captures.json](../captures.json). Os originais PNG e os scripts temporários ficam fora do Git.','','Estados encenados por chamadas às APIs reais: crise, resultado, candidato e casa já livre da patrulha. A captura de resultado mostra uma vitória apresentada pela HUD, sem afirmar que esta batalha foi efetivamente vencida. A casa é visitada com `enemy_defeated=true` numa campanha de captura. Nenhuma alteração de regra de produção.','','| Tela | Normal | Maior |','|---|---|---|']
 for name in common:rows.append(f'| {name} | [JPG]({name}.jpg) · [textos]({name}.json) | [JPG]({name}_large.jpg) · [textos]({name}_large.json) |')
 (OUT/'before/README.md').write_text('\n'.join(rows)+'\n')
 system_board()
 print('Done',OUT)
def system_board():
 c=kit.Canvas();c.header('HUD v2 / mesmo kit em todas as telas','Grade 8 · margem 48 · padding 24 · 9-slice 16 · texto 32/24/18 · Maior 130%')
 for i,t in enumerate(['panel','button','card','plate','bar','chip','tooltip','notice','sequence','key','selection','tabs']):
  x=48+i%3*624;y=216+i//3*192;c.comp(t,x,y,576,176,'focus' if 'focus' in kit.APPLIES[t] else 'normal',kit.NAMES[t], 'Componente existente / #59')
 c.footer('Foco: cantos / escolha: losango / alvo: corpo inteiro e marca / informação no foco')
 c.im.quantize(colors=256).save(OUT/'system.png',optimize=True)
if __name__=='__main__':main()
