"""Pranchas estáticas da #59. Executar da raiz com Python + Pillow + CairoSVG.
Não cria assets de produção nem altera o jogo. Ver ../ui-kit.md.
"""
from pathlib import Path
from functools import lru_cache
from io import BytesIO
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps
import cairosvg
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
P={'bg':'#0d1012','surface':'#12171a','edge':'#3b3327','copper':'#c98a4b','gold':'#e9c47c','text':'#efe5d1','muted':'#a69a84','good':'#86c98f','danger':'#e2675b','enemy':'#d9893d','instinct':'#b7a6f4','blue':'#8fb4f0'}
STATES=['normal','hover','focus','pressed','disabled','alert','selected']
LABELS=['Normal','Mouse','Foco','Pressionado','Desligado','Alerta','Escolhido']
GROUPS=[['panel','card','tooltip'],['button','chip','key'],['plate','bar','notice'],['sequence','tabs','selection']]
NAMES={'panel':'01 / Painel','button':'02 / Botão','card':'03 / Cartão','plate':'04 / Placa','bar':'05 / Barras','chip':'06 / Ficha','tooltip':'07 / Dica','notice':'08 / Aviso','sequence':'09 / Sequência','key':'10 / Tecla','selection':'11 / Seleção','tabs':'12 / Abas e listas'}
# Sem interação fictícia em elementos informativos. A variante acionável é explícita.
APPLIES={
'panel':['normal','alert'], 'button':STATES[:-1], 'card':STATES,
'plate':['normal','hover','focus','alert','selected'],
'bar':['normal','alert'], 'chip':['normal','hover','focus','alert'],
'tooltip':['normal','alert'], 'notice':['normal','alert'],
'sequence':STATES, 'key':['normal','pressed','disabled'],
'selection':['normal','hover','focus','alert','selected'], 'tabs':STATES}
CHECKS=[]
@lru_cache(None)
def font(size,kind='body'):
 name={'body':'plus-jakarta-sans-latin-400-normal.ttf','bold':'plus-jakarta-sans-latin-700-normal.ttf','title':'cinzel-latin-700-normal.ttf'}[kind]
 return ImageFont.truetype(str(ROOT/'art/ui/fonts'/name),size)
@lru_cache(None)
def frame(w,h,kind):
 src=Image.open(ROOT/f'art/ui/frames/{kind}.png').convert('RGBA');sw,sh=src.size;n=16;dst=Image.new('RGBA',(w,h))
 for xa,xb,xc,xd in [(0,n,0,n),(n,sw-n,n,w-n),(sw-n,sw,w-n,w)]:
  for ya,yb,yc,yd in [(0,n,0,n),(n,sh-n,n,h-n),(sh-n,sh,h-n,h)]:
   dst.alpha_composite(src.crop((xa,ya,xb,yb)).resize((xd-xc,yd-yc)),(xc,yc))
 return dst
@lru_cache(None)
def glyph(name,size,color):
 raw=(ROOT/f'art/ui/icons/{name}.svg').read_text().replace('#ffffff',color)
 return Image.open(BytesIO(cairosvg.svg2png(bytestring=raw.encode(),output_width=size,output_height=size))).convert('RGBA')
class Canvas:
 def __init__(self,large=False,cb=False):
  self.im=Image.new('RGB',(1920,1080),P['bg']);self.d=ImageDraw.Draw(self.im);self.large=large;self.cb=cb;self.s=1.3 if large else 1
 def c(self,k):return {'good':'#56b4e9','danger':'#e69f00','blue':'#efe5d1'}.get(k,P.get(k,k)) if self.cb else P.get(k,k)
 def text(self,x,y,t,role='body',color='text',width=None):
  size=round({'title':32,'body':24,'detail':18}[role]*self.s);line_height=({'title':64,'body':48,'detail':40} if self.large else {'title':48,'body':40,'detail':32})[role];f=font(size,'title' if role=='title' else 'body');lines=[]
  if width:
   line=''
   for word in t.split():
    q=(line+' '+word).strip()
    if f.getlength(q)>width and line:lines.append(line);line=word
    else:line=q
   lines.append(line)
  else:lines=t.split('\n')
  for i,line in enumerate(lines):
   self.d.text((x,y+i*line_height),line,font=f,fill=self.c(color),anchor='lt')
   CHECKS.append({'text':line,'size':size,'right':round(x+f.getlength(line),2),'bottom':round(y+i*line_height+size,2)})
  return len(lines)*line_height
 def box(self,x,y,w,h,kind='panel_normal'):self.im.paste(frame(w,h,kind),(x,y),frame(w,h,kind))
 def icon(self,x,y,name='lobby-water',size=32,color='text'):
  g=glyph(name,size,self.c(color));self.im.paste(g,(x,y),g)
 def focus(self,x,y,w,h):
  gap=6;arm=18
  for xx,yy,sx,sy in [(x-gap,y-gap,1,1),(x+w+gap,y-gap,-1,1),(x+w+gap,y+h+gap,-1,-1),(x-gap,y+h+gap,1,-1)]:
   self.d.line((xx,yy,xx+sx*arm,yy),fill=self.c('text'),width=3);self.d.line((xx,yy,xx,yy+sy*arm),fill=self.c('text'),width=3)
 def diamond(self,x,y):self.d.polygon([(x,y-9),(x+9,y),(x,y+9),(x-9,y)],fill=self.c('gold'))
 def badge(self,x,y,state):
  if state=='disabled':self.d.line((x,y,x+12,y+12),fill=self.c('muted'),width=3);self.d.line((x+8,y,x+20,y+12),fill=self.c('muted'),width=3)
  if state=='alert':self.d.polygon([(x+10,y),(x+20,y+18),(x,y+18)],outline=self.c('danger'),width=2);self.d.line((x+10,y+5,x+10,y+11),fill=self.c('danger'),width=2)
 def header(self,title,sub):
  self.text(48,32,'AFTER HUMANS / KIT 01',color='copper',role='detail');self.text(48,76,title,'title')
  self.text(48,136,sub,'detail',color='muted');self.d.line((48,184,1872,184),fill=self.c('edge'),width=1)
 def footer(self,label):
  self.text(48,1024,label,'detail','muted');self.text(1440,1024,('Maior 130%' if self.large else 'Normal 100%')+(' / Daltonismo' if self.cb else ''),'detail','muted')
 def comp(self,k,x,y,w=232,h=176,state='normal',title=None,detail=None,icon_name='node-rest'):
  if state not in APPLIES[k]:
   self.text(x+16,y+40,'Não se aplica','detail','muted',w-32);return
  off=2 if state=='pressed' else 0; col='muted' if state=='disabled' else 'text'; sh=72 if self.large else 64
  skin='button_hover' if state=='hover' else 'button_pressed' if state=='pressed' else 'button_disabled' if state=='disabled' else 'ability_selected' if state=='selected' else 'panel_normal'
  if k=='button':
   hh=80 if self.large else 64;self.box(x,y+32,w,hh,'button_primary' if title=='Partir' and state=='normal' else skin);self.text(x+24+off,y+52+off,title or 'Continuar','body',col)
   if state=='disabled':self.badge(x+w-36,y+52,state)
   if state=='alert':self.badge(x+w-40,y+hh-28,state)
   h=hh;y+=32
  elif k=='panel':
   self.box(x,y,w,h);self.text(x+24,y+20,title or 'Mochila','body');self.d.line((x+24,y+sh,x+w-24,y+sh),fill=self.c('edge'));self.text(x+24,y+sh+16,'Conteúdo','detail','muted');self.d.line((x+24,y+h-40,x+w-24,y+h-40),fill=self.c('edge'));self.text(x+24,y+h-30,'Ações','detail','muted')
  elif k=='card':
   self.box(x,y,w,h,skin);self.icon(x+36,y+24,icon_name,40,'copper');self.text(x+104,y+24,title or 'Abrigo','body',col);self.text(x+24,y+88,detail or 'Pausa segura','detail','muted');self.text(x+24,y+128,'Disponível' if state!='disabled' else 'Bloqueado','detail',col)
  elif k=='tooltip':
   self.box(x,y,w,h);self.text(x+24,y+20,'Proteção','body');self.text(x+24,y+sh+8,'Recebe menos dano.','detail',width=w-48)
  elif k=='chip':
   hh=80 if self.large else 64;self.box(x,y+32,w,hh,'button_hover' if state=='hover' else 'resource_chip');self.icon(x+24,y+48,'lobby-water',32,'danger' if state=='alert' else 'text');self.text(x+72,y+50,'3 / 8' if state=='alert' else '12','body',col);y+=32;h=hh
  elif k=='key':
   self.box(x,y+32,sh,sh,'key_cap');self.text(x+22+off,y+50+off,'E','body',col);self.text(x+sh+16,y+52,'Interagir','detail',col);y+=32;h=sh
  elif k=='plate':
   hh=128 if self.large else 120; life_y=80 if self.large else 72
   self.box(x,y,w,hh,skin);self.text(x+24,y+24,title or 'Íris','body',col)
   self.icon(x+w-48,y+24,'intent-attack' if state=='alert' else 'intent-block',24,'danger' if state=='alert' else 'text')
   self.d.rectangle((x+24,y+life_y,x+w-24,y+life_y+11),fill=self.c('edge'))
   self.d.rectangle((x+24,y+life_y,x+int(w*.64),y+life_y+11),fill=self.c('good'))
   self.d.rectangle((x+24,y+life_y+20,x+int(w*.45),y+life_y+23),fill=self.c('instinct'));h=hh
  elif k=='bar':
   self.text(x,y,'Vida' if state!='alert' else 'Vida baixa','body', 'danger' if state=='alert' else 'text');self.d.rectangle((x,y+56,x+w,y+72),fill=self.c('edge'));self.d.rectangle((x,y+56,x+int(w*(.2 if state=='alert' else .7)),y+72),fill=self.c('danger' if state=='alert' else 'good'));self.text(x,y+100,'Instinto','detail','muted');self.d.rectangle((x,y+140,x+w,y+148),fill=self.c('edge'));self.d.rectangle((x,y+140,x+int(w*.4),y+148),fill=self.c('instinct'))
  elif k=='notice':
   self.box(x,y,w,h);self.icon(x+24,y+24,'intent-attack' if state=='alert' else 'marker-visited',32,'danger' if state=='alert' else 'text');self.text(x+24,y+sh+4,'Patrulha perto' if state=='alert' else 'Item guardado','body',width=w-48)
  elif k=='sequence':
   ns=80 if self.large else 64; step=ns+16; count=min(3,(w+16)//step)
   for i,name in enumerate(['node-start','node-combat','node-rest'][:count]):
    xx=x+i*step;self.box(xx,y+32,ns,ns,skin if i==1 else 'panel_normal');self.icon(xx+(ns-32)//2,y+32+(ns-32)//2,name,32,col)
    if i<count-1:self.d.line((xx+ns,y+32+ns//2,xx+step,y+32+ns//2),fill=self.c('copper'),width=2)
   self.text(x,y+120,'Rota / ordem','detail','muted')
  elif k=='tabs':
   self.box(x,y,w,sh,skin);self.text(x+24,y+18,'Itens','body',col);self.box(x,y+sh+16,w,sh,'panel_normal');self.text(x+24,y+sh+34,'Equipamento','detail',col)
  elif k=='selection':
   self.box(x,y,w,h,skin);self.text(x+24,y+24,'Escolha','body',col);self.text(x+24,y+88,'Persistente','detail','muted')
  if state=='focus':
   if k=='sequence':self.focus(x+step,y+32,ns,ns)
   elif k=='tabs':self.focus(x,y,w,sh)
   else:self.focus(x,y,w,h)
  if state=='selected':
   if k=='sequence':self.diamond(x+step+ns-16,y+32+ns-16)
   elif k=='tabs':self.diamond(x+w-24,y+sh-24)
   else:self.diamond(x+w-24,y+h-24)
  if state=='alert' and k not in ['button','plate','sequence','tabs']:self.badge(x+w-40,y+h-28,state)
  if state=='alert' and k=='sequence':self.badge(x+step+ns-24,y+32+ns-24,state)
  if state=='alert' and k=='tabs':self.badge(x+w-40,y+sh-28,state)
  if state=='disabled' and k=='card':self.badge(x+w-40,y+h-28,state)
  if state=='disabled' and k=='tabs':self.badge(x+w-40,y+sh-28,state)
  if state=='disabled' and k=='sequence':self.badge(x+step+ns-24,y+32+ns-24,state)
 def save(self,name):self.im.save(OUT/(name+'.webp'),quality=86,method=6)

def matrices():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  for n,group in enumerate(GROUPS,1):
   c=Canvas(large,cb);c.header(f'Componentes / {n:02d}', 'Amostras de estado. Medidas completas e regras de uso em ui-kit.md. Não são telas de jogo.')
   for j,label in enumerate(LABELS):c.text(48+j*264,212,label,'detail','muted')
   for i,k in enumerate(group):
    y=264+i*248;c.text(48,y,NAMES[k],'detail','copper')
    for j,state in enumerate(STATES):c.comp(k,48+j*264,y+40,state=state)
   c.footer('Mesma peça / sem criar um estilo por tela / 9-slice real de 16 px');c.save(f'states_{n:02d}_{profile}')

def foundations():
 c=Canvas();c.header('Fundações / uma família','Grade de 8 px • margens 48 px • superfícies opacas sob o texto • sem texto nas texturas')
 for i,(label,value) in enumerate(P.items()):
  x=48+(i%7)*264;y=240+(i//7)*120;c.d.rectangle((x,y,x+48,y+48),fill=value);c.text(x+64,y,label,'detail');c.text(x+64,y+28,value,'detail','muted')
 c.text(48,540,'Título / Cinzel 32','title');c.text(48,610,'Texto / Plus Jakarta Sans 24','body');c.text(48,662,'Detalhe / Plus Jakarta Sans 18','detail')
 c.text(960,540,'Normal → Grande → Maior','body');c.text(960,610,'32 / 24 / 18 → 37 / 28 / 21 → 42 / 31 / 23','detail');c.text(960,662,'Não reduzir fonte para caber. Aumentar altura ou rolar.','detail')
 c.text(48,772,'Destaque único','body');c.text(48,824,'Dourado só na ação principal ou na escolha atual; os demais ficam em cobre.','body')
 c.text(48,900,'Daltonismo: bom #56b4e9 / perigo #e69f00; manter ícone, forma e rótulo.','body');c.footer('Foco não escolhe / escolha não confirma / alvo não é foco');c.save('foundations')

def unity():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  c=Canvas(large,cb);c.header('Prova de unidade','Painel + cartão + placa + botão repetidos nas quatro áreas. Estudo de componentes, não redesenho final da #58.')
  for i,(name,title,action) in enumerate([('ESTAÇÃO','Forja','Produzir'),('EXPLORAÇÃO','Abrigo','Buscar'),('COMBATE','Habilidade','Usar'),('MAPA','Fase 1','Partir')]):
   x=48+i*464;c.text(x,220,name,'detail','copper');c.box(x,272,432,680);c.text(x+24,300,title,'title');c.text(x+24,370,'Informação da decisão','detail','muted')
   c.comp('card',x+24,424,384,208 if large else 176,title=['Forja','Abrigo','Proteção','Fase 1'][i],detail=['Produção disponível','Pausa segura','Reduz dano','Rota disponível'][i],icon_name=['lobby-scrap','node-rest','intent-block','node-combat'][i]);c.comp('plate',x+24,648,384,title='Íris');c.comp('button',x+24,800,384,title=action)
  c.icon(48,976,'node-event',24,'blue');c.text(88,972,'Informação: detalhes no foco','detail','blue');c.footer('Mesmo raio, filete, espaçamento, texto e ações / 4 contextos');c.save(f'unity_{profile}')

def glyphs():
 c=Canvas();c.header('Ícones / reaproveitar o acervo','Amostras rasterizadas a 22 e 32 px, sem reampliar; o jogo aplica a tinta. Retratos não são glifos.')
 names=['lobby-food','lobby-water','lobby-energy','node-rest','intent-attack','intent-block','status-poison_good','status-poison_bad']
 for i,name in enumerate(names):
  x=48+(i%4)*464;y=256+(i//4)*288;c.text(x,y,name,'detail');
  for j,color in enumerate(['text','good','danger']):
   for k,s in enumerate([22,32]):c.icon(x+j*120+k*40,y+64,name,s,color)
  for j,col in enumerate(['#56b4e9','#e69f00']):
   for k,s in enumerate([22,32]):
    g=glyph(name,s,col);c.im.paste(g,(x+j*120+k*40,y+128),g)
 c.text(48,880,'Ícone + texto na primeira decisão; só ícone com nome no foco, mouse e toque.','body');c.footer('32×32 de origem / traço 2,4 / respiro 4 / distância de texto 8');c.save('icons')
 c.im=ImageOps.grayscale(c.im).convert('RGB');c.save('icons_gray')

def anatomy():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  c=Canvas(large,cb);c.header('Anatomia / superfícies','Painel lateral 640 px / central 960 px • título + corpo rolável + rodapé fixo • mesmo componente')
  x=48;y=256;w=640;h=704;c.box(x,y,w,h);c.text(x+24,y+24,'Preparação','title');c.box(x+w-(104 if large else 88),y+12 if large else y+20,80 if large else 64,80 if large else 64,'button_normal');c.d.line((x+w-68,y+40,x+w-44,y+64),fill=c.c('text'),width=3);c.d.line((x+w-44,y+40,x+w-68,y+64),fill=c.c('text'),width=3);c.d.line((x+24,y+104,x+w-24,y+104),fill=c.c('edge'))
  c.comp('card',x+24,y+136,592,208 if large else 176,title='Íris',detail='Alquimista',icon_name='item-ampoule')
  c.text(x+24,y+392,'Corpo com rolagem','body');c.text(x+24,y+456,'Respiro 24 / intervalo 16','detail','muted')
  c.d.line((x+24,y+h-112,x+w-24,y+h-112),fill=c.c('edge'));c.comp('button',x+24,y+h-136,280,title='Partir')
  for yy,title,desc in [(256,'01 / Cabeçalho','Altura 104 / fechar 80×80' if large else 'Altura 104 / fechar 64×64'),(416,'02 / Corpo','Inset 24 / apenas o corpo rola'),(576,'03 / Rodapé','Altura 112 / ações com intervalo 16'),(736,'04 / Borda','9-slice 16 / cantos de metal existentes')]:
   c.text(784,yy,title,'body','copper');c.text(784,yy+56,desc,'body')
  c.footer('O painel muda de tamanho e conteúdo, não de linguagem visual');c.save(f'anatomy_{profile}')

def variants():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  c=Canvas(large,cb);c.header('Variações / comandos e cartões','Um contrato por família. A moldura, as fontes e os espaços não mudam entre conteúdos.')
  labels=['Principal','Secundário','Ícone + texto','Só ícone','Perigo']
  for i,label in enumerate(labels):
   x=48+i*368;c.text(x,232,label,'detail','muted')
   if i==3:
    c.box(x,288,80,80,'button_normal');c.icon(x+24,312,'lobby-settings',32);c.text(x,392,'Nome no foco','detail','muted')
   else:
    c.comp('button',x,256,320,title=['Partir','Voltar','Buscar','','Excluir'][i])
    if i==2:c.icon(x+264,304,'node-loot',32)
    if i==4:c.badge(x+268,306,'alert')
  for i,(label,title,detail,name) in enumerate([('Herói','Íris','Alquimista','item-ampoule'),('Habilidade','Proteção','Reduz dano','intent-block'),('Item','Ampola','Uso único','item-ampoule'),('Cômodo','Cantina','Refeições','lobby-food'),('Fase','Fase 1','Rota aberta','node-combat')]):
   x=48+i*368;c.text(x,496,label,'detail','muted');c.comp('card',x,552,320,208,title=title,detail=detail,icon_name=name)
   if i==0:
    im=Image.open(ROOT/'art/ui/portraits/iris.png').convert('RGBA').resize((64,64),Image.Resampling.LANCZOS);c.d.rectangle((x+24,576,x+88,640),fill=c.c('bg'));c.im.paste(im,(x+24,576),im)
  c.text(48,832,'Herói usa retrato no slot de 64 px; demais usam ícone de 32–40 px.','body')
  c.text(48,896,'Detalhe adicional abre no foco / mouse / toque; o cartão não vira um relatório.','body')
  c.footer('Um principal por contexto ativo / perigo exige confirmação explícita');c.save(f'variants_{profile}')

def feedback():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  c=Canvas(large,cb);c.header('Variações / avisos e sequência','Toast informa / faixa alerta / confirmação decide. Ordem e rota compartilham os mesmos nós.')
  c.comp('notice',48,256,448,176,title='');c.text(48,456,'Toast / até 2 linhas','detail','muted')
  c.box(560,256,1312,80);c.icon(584,280,'intent-attack',32,'danger');c.text(640,276,'Patrulha próxima — procure abrigo.','body')
  c.box(560,392,736,384);c.text(584,416,'Voltar agora?','title');c.text(584,496,'Você retorna com metade dos achados.','body',width=672)
  c.comp('button',584,624,304,title='Continuar');c.comp('button',936,624,304,title='Voltar')
  c.text(1360,416,'Confirmação','body','copper');c.text(1360,480,'Descrever a consequência. Foco inicial na opção segura. Sem sim/não genérico.','detail',width=480)
  c.comp('sequence',48,568,320,state='selected');c.text(48,776,'Ordem ou rota','detail','muted')
  c.text(48,856,'Progresso','body');c.d.rectangle((48,920,496,932),fill=c.c('edge'));c.d.rectangle((48,920,328,932),fill=c.c('copper'))
  c.footer('Avisos acionáveis compõem o botão 02; o aviso informativo não recebe foco sozinho');c.save(f'feedback_{profile}')

def selection():
 for large,cb,profile in [(False,False,'normal'),(True,False,'large'),(False,True,'colorblind'),(True,True,'large_colorblind')]:
  c=Canvas(large,cb);c.header('Três destaques / três significados','Foco navega • escolha persiste • alvo indica quem recebe a ação. Nenhum depende só da cor.')
  c.comp('card',48,288,400,176,'focus',title='Abrigo');c.text(48,520,'Foco / cantos claros','body');c.text(48,592,'Não escolhe nem executa.','detail','muted')
  c.comp('card',512,288,400,176,'selected',title='Abrigo');c.text(512,520,'Escolhido / losango','body');c.text(512,592,'Pode coexistir com foco.','detail','muted')
  for j,(label,col,mark) in enumerate([('Alvo válido','copper','outline'),('Apontado','danger','arrow'),('Outros atingidos','danger','slash')]):
   xx=1008+j*288;im=Image.open(ROOT/'art/combat/heroes/iris/idle.webp').convert('RGBA');im.thumbnail((220,328),Image.Resampling.LANCZOS);a=im.getchannel('A');rim=ImageOps.expand(a,3,fill=0).filter(__import__('PIL.ImageFilter',fromlist=['MaxFilter']).MaxFilter(7));outline=Image.new('RGBA',rim.size,c.c(col));outline.putalpha(rim);c.im.paste(outline,(xx-3,253),outline);c.im.paste(im,(xx,256),im)
   if mark=='arrow':c.d.polygon([(xx+100,224),(xx+124,224),(xx+112,244)],fill=c.c(col))
   if mark=='slash':
    for n in range(3):c.d.line((xx+12+n*16,256+im.height+20,xx+24+n*16,256+im.height+4),fill=c.c(col),width=3)
   c.text(xx,656,label,'detail',width=240)
  c.text(48,784,'Herói da vez: marcador neutro “Vez” junto à placa, sem disputar a cor do alvo.','body')
  c.text(48,864,'Área clicável = personagem inteiro. Prévia mostra todos os atingidos antes de confirmar.','body',width=1800)
  c.footer('Exemplos do componente de seleção / sem alterar regras ou implementar a #57');c.save(f'selection_{profile}')


def plate_metrics():
 c=Canvas();c.header('Placa / conta nos três tamanhos','Inset24 preservado • Grande usa geometria do Maior • Informação neutra com ícone no daltonismo')
 for i,(label,large,scale,h) in enumerate([('Normal',False,1,120),('Grande',True,1.15,128),('Maior',True,1.3,128)]):
  x=48+i*608;t=Canvas(large,True);t.s=scale;t.comp('plate',48,48,480,title='Íris');c.im.paste(t.im.crop((32,32,560,240)),(x,320));c.text(x,256,label,'body');c.text(x,600,f'H{h} / inset24 / nome'+('40' if not large else '48'),'body');c.text(x,672,'24 + '+('40' if not large else '48')+' + 8 + 12 + 8 + 4 + 24','detail');c.icon(x,784,'node-event',32,'text');c.text(x+48,788,'Informação','body')
 c.footer('Informação: só texto + ícone / sem barra ou contorno colorido');c.save('plate_metrics')

if __name__=='__main__':
 matrices();foundations();unity();glyphs();anatomy();variants();feedback();selection();plate_metrics()
 # Redução real da prova de unidade, não imagem em tamanho cheio com texto menor.
 for profile in ['normal','large','colorblind','large_colorblind']:
  im=Image.open(OUT/f'unity_{profile}.webp');im.resize((768,432),Image.Resampling.LANCZOS).save(OUT/f'unity_{profile}_40.webp',quality=86,method=6)
  ImageOps.grayscale(im).save(OUT/f'unity_{profile}_gray.webp',quality=86,method=6)
 (OUT/'render_checks.json').write_text(json.dumps({'text_runs':len(CHECKS),'min_font_px':min(t['size'] for t in CHECKS),'outside_canvas':[t for t in CHECKS if t['right']>1920 or t['bottom']>1080]},ensure_ascii=False,indent=2)+'\n')
