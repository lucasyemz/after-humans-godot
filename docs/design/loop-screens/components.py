import sys
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as k
c=k.Canvas();c.header('Laço / mesmas famílias do kit','Cartão 03 + seleção 11 · sequência 09 + barras 05 · painel 01 / nenhuma moldura nova')
for big,y in [(False,240),(True,624)]:
 c.large=big;c.s=1.3 if big else 1;c.text(48,y-40,'Maior 130%' if big else 'Normal 100%','detail','copper')
 for j,state in enumerate(['closed','open']):
  x=48+j*344;c.box(x,y,320,296 if big else 272,'ability_selected' if j else 'panel_normal');im=Image.open(ROOT/f'art/ui/loop/cargo_{state}.webp');c.im.paste(im,(x+48,y+16),im);c.text(x+24,y+(256 if big else 232),'Recebido' if j else 'Caixa 1','detail');
  if j:c.diamond(x+296,y+(272 if big else 248))
 x=760;c.box(x,y,432,272 if big else 240);c.text(x+24,y+24,'Vida máxima');c.text(x+24,y+96,'+2 de vida');c.text(x+24,y+176,'34 para 36','detail','muted');c.focus(x,y,432,272 if big else 240)
 for i,filled in enumerate([True,True,False]):
  im=Image.open(ROOT/f'art/ui/loop/star_{"filled" if filled else "outline"}.webp');c.im.paste(im,(1280+i*48,y+32),im)
 c.text(1456,y+32,'2 de 3 estrelas','detail')
 c.text(1240,y+128,'Pesquisa: linha + cartão + ficha','detail',width=600)
 c.d.line((1240,y+208,1448,y+208),fill=c.c('muted'),width=3);c.box(1448,y+176,400,80);c.text(1472,y+200,'Requisito no foco','detail')
c.s=1;c.footer('Exemplos visuais / valores novos não definem o balanceamento / mesmos estados de foco e escolha')
c.im.save(Path(__file__).parent/'components.webp',quality=88,method=6)
