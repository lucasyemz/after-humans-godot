"""Prova de estados e barras; valores de catálogo, não estado de uma luta."""
import sys,json
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
from render import C,OUT
rows=[]
for large,cb,suffix in [(False,False,''),(True,False,'_large'),(False,True,'_colorblind'),(True,True,'_large_colorblind')]:
 c=C('ready',large,cb);c.im=Image.new('RGBA',(1920,1080),'#0d1012');c.rec=[];c.text(48,32,'Latão noturno / estados da HUD',32,serif=True);names=['Normal','Mouse','Foco','Pressionado','Bloqueado','Escolhido','Alerta']
 for i,name in enumerate(names):
  x=48+i*264;c.text(x+120,128,name,18,center=True);xx=x+64;yy=192;off=2 if name=='Pressionado' else 0;c.part('slot',xx+off,yy+off,112,112);c.glyph('exit',xx+36+off,yy+36+off,40,'muted' if name=='Bloqueado' else 'text')
  if name=='Foco':c.focus(xx,yy,112,112)
  if name=='Mouse':ImageDraw.Draw(c.im).line((xx+4,yy+16,xx+4,yy+4,xx+20,yy+4),fill='#c98a4b',width=2)
  if name=='Escolhido':c.selected(xx+56,yy-12)
  if name=='Bloqueado':
   d=ImageDraw.Draw(c.im);d.line((xx+12,yy+12,xx+28,yy+28),fill=c.color('muted'),width=3);d.line((xx+20,yy+12,xx+36,yy+28),fill=c.color('muted'),width=3)
  if name=='Alerta':
   d=ImageDraw.Draw(c.im);d.polygon([(xx+96,yy-8),(xx+112,yy+20),(xx+80,yy+20)],outline=c.color('danger'),width=3);c.text(xx+96,yy-2,'!',18,center=True,color=c.color('danger'))
  c.keycap(xx+32,320,'E');c.part('primary' if name=='Foco' else 'secondary',x+8+off,408+off,224,72);c.text(x+120,432,'Bloqueado' if name=='Bloqueado' else 'Confirmar',24,center=True,color=c.color('muted') if name=='Bloqueado' else c.color('text'))
  ratio=[1,.75,.5,.25,0,1,.15][i];c.gauge(x,536,240,56,ratio,'danger' if name=='Alerta' else 'team',f'{round(ratio*100)}/100');c.text(x+120,616,'Exemplo de estado',18,center=True,color=c.color('muted'))
 c.text(48,712,'Instinto / exemplos de preenchimento',24,serif=True)
 for i,value in enumerate([0,.25,.75,.9,1]):
  x=48+i*368;role='danger' if value>=.9 else 'instinct';c.gauge(x,800,336,56,value,role,f'{round(200*value)}/200');c.text(x+168,880,'Crise' if value==1 else 'Crise próxima' if value>=.9 else f'{round(value*100)}%',18,center=True,color=c.color(role))
 c.text(48,1008,'Amostras de catálogo; o jogo usa os valores e limites da sessão.',18,color=c.color('muted'))
 c.im.convert('RGB').save(OUT/('states'+suffix+'.webp'),quality=91,method=6);outside=[r for r in c.rec if r['right']>1920 or r['bottom']>1080];rows.append({'profile':suffix or 'normal','labels':c.rec,'outside':outside})
(OUT/'states_checks.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print('state sheets4; outside',sum(len(r['outside']) for r in rows))
# Ícone novo em dois fundos,22 e32 de verdade, sem inflar a ampliação.
proof=Image.new('RGB',(800,240),'#0d1012');d=ImageDraw.Draw(proof);d.rectangle((400,0,800,240),fill='#efe5d1');im=c.parts['exit']
for side in range(2):
 for i,sz in enumerate([22,32,64]):
  p=im.resize((sz,sz),Image.Resampling.LANCZOS);color='#efe5d1' if side==0 else '#233839';t=Image.new('RGBA',p.size,color);t.putalpha(p.getchannel('A'));proof.paste(t,(side*400+48+i*112,64),t)
proof.save(OUT/'exit_readability.webp',quality=94)
