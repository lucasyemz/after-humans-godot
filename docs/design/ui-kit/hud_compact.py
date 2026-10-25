import sys
sys.dont_write_bytecode=True
sys.path.insert(0,'docs/design/ui-kit')
import render as k
c=k.Canvas();c.header('Variantes compactas / HUD v2','Placa 04 · Botão 02 · Ficha 06 · Sequência 09 / mesmas molduras e estados')
for i,(large,y) in enumerate([(False,264),(True,624)]):
 c.large=large;c.s=1.3 if large else 1;c.text(48,y-56,'Maior 130%' if large else 'Normal 100%','body','copper')
 c.box(48,y,208,72);c.text(64,y+24,'1','detail');c.d.rectangle((96,y+24,240,y+36),fill=c.c('text'));c.d.rectangle((96,y+48,240,y+52),fill=c.c('edge'));c.focus(48,y,208,72);c.text(48,y+144,'Placa: nome/vida no foco','detail',width=360)
 c.box(480,y,136,104);c.icon(504,y+16,'intent-block',40);c.text(568,y+40,'W','detail');c.focus(480,y,136,104);c.text(480,y+144,'Ação: nome/efeito no foco','detail',width=360)
 c.box(912,y,312,64,'resource_chip');c.icon(936,y+16,'lobby-food',32);c.text(984,y+16,'4','body');c.text(912,y+144,'Ficha: ícone + valor','detail',width=360)
 c.box(1328,y,544,96)
 for j,t in enumerate(['bento','nick','iris','vespera']):
  from PIL import Image
  im=Image.open(k.ROOT/f'art/ui/portraits/{t}.png').convert('RGBA').resize((48,48));c.im.paste(im,(1352+j*56,y+16),im)
 c.diamond(1376,y+80);c.text(1328,y+144,'Ordem: atual e foco distintos','detail',width=520)
c.s=1;c.footer('9-slice 16 / rank 18–23 / clique no corpo inteiro / nenhum asset novo de produção')
c.im.quantize(colors=256).save('docs/design/ui-kit/hud_compact.png',optimize=True)
