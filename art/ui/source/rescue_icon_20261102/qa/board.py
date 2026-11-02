from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import argparse
ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--captures',type=Path);a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=True)
base=Path(__file__).resolve().parents[1]
def font(n):return ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_semibold.ttf'),n)
def text(im,x,y,s,n=25,color='#efe6d6'):ImageDraw.Draw(im).text((x,y),s,font=font(n),fill=color)
def save(im,n):im.save(a.out/(n+'.webp'),quality=94,method=6)
def glyph(im,key,x,y,size,color='#efe6d6'):
 p=base/'node-rescue.webp' if key=='node-rescue' else a.repo/'art/ui/kit/station/icons'/(key+'.webp')
 alpha=Image.open(p).convert('RGBA').getchannel('A').resize((size,size),Image.Resampling.LANCZOS)
 layer=Image.new('RGBA',(size,size),color);layer.putalpha(alpha);im.paste(layer,(x,y),layer)
b=Image.new('RGB',(1600,1000),'#0d1012');text(b,35,20,'RESGATE / UMA MÃO ERGUIDA PEDINDO AJUDA',42)
text(b,35,78,'Um só símbolo tingível / mesmo canvas dos ícones de trecho / sem texto na textura',25)
for j,(key,label) in enumerate([('node-rescue','RESGATE'),('node-combat','COMBATE'),('node-loot','SUPRIMENTOS'),('node-rest','DESCANSO'),('node-event','EVENTO')]):
 x=40+j*310
 glyph(b,key,x+60,145,96,'#f0a020' if j==0 else '#efe6d6');text(b,x,260,label,28)
text(b,35,330,'ESCALAS REAIS / os pequenos abaixo não foram ampliados',27)
for x,size in [(55,22),(220,26),(385,30),(550,32),(715,64)]:
 glyph(b,'node-rescue',x,396,size);text(b,x,476,str(size)+' px',23)
text(b,900,365,'Sobre fundo claro',25);ImageDraw.Draw(b).rectangle((900,412,1120,460),fill='#efe6d6');glyph(b,'node-rescue',920,423,22,'#0d1012');glyph(b,'node-rescue',1020,420,32,'#0d1012')
text(b,35,555,'TINTAS DO KIT / a forma identifica o resgate em todos os estados',27)
for i,(name,color) in enumerate([('Conhecido','#efe6d6'),('Atual','#f0a020'),('Resolvido','#6cc77c'),('Pino/alerta','#e2584a'),('Resolvido / daltonismo','#56b4e9'),('Alerta / daltonismo','#e8743a')]):
 x=40+i*255
 glyph(b,'node-rescue',x+22,632,32,color);text(b,x,701,name,22)
glyph(b,'node-rescue',1230,415,32,'#d55e00');text(b,1190,476,'QA / vermelhão d55e00',22)
text(b,35,805,'Trecho desconhecido conserva “?”; resolvido usa o check e atual usa a moldura já existentes.',25)
text(b,35,857,'O glyph é branco. Cores, molduras, rótulos e estados continuam sendo desenhados pelo jogo.',25)
text(b,35,927,'Fonte 128 × 128 / jogo 64 × 64 / integração Claude 2 (#188) / issue #295',25)
save(b,'board');save(ImageOps.grayscale(b).convert('RGB'),'board_gray');save(b.resize((640,400),Image.Resampling.LANCZOS),'board_40')
if a.captures:
 for view in ['route','map']:
  for variant in ['normal','larger','colorblind']:
   before=Image.open(a.captures/(view+'_before_'+variant+'.png')).convert('RGB');after=Image.open(a.captures/(view+'_after_'+variant+'.png')).convert('RGB')
   pair=Image.new('RGB',(3840,1140),'#0d1012');pair.paste(before,(0,60));pair.paste(after,(1920,60));text(pair,28,10,'ANTES / MAIN e2f0b58a / '+variant.upper(),34);text(pair,1948,10,'DEPOIS / MESMA CENA + GLYPH EXTERNO #295',34);save(pair,'before_after_'+view+'_'+variant)
   if variant=='normal':save(after.resize((768,432),Image.Resampling.LANCZOS),view+'_40');save(ImageOps.grayscale(after).convert('RGB'),view+'_gray')
print('Boards built.')
