"""Prancha de direção #59, não atlas de runtime. Composição e tipografia sobre arte gerada."""
import sys,json,hashlib,io
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageEnhance,ImageOps,ImageFilter
import cairosvg
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
FONTS=ROOT/'art/ui/fonts'
def font(n,serif=False):return ImageFont.truetype(str(FONTS/('cinzel-latin-700-normal.ttf' if serif else 'plus-jakarta-sans-latin-400-normal.ttf')),n)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=ROOT/'docs/design/loop-screens/before/combat_clean.webp'
# PNG mestre externo. A cópia de estudo sem texto fica no docs/ com alfa e em WebP.
raw=Path('/workspace/generated_images/exec-fe707556-5534-4f1d-9b39-be049748cad5.png')
art_path=OUT/'material_study.webp'
if '--source' in sys.argv:
 raw=Path(sys.argv[sys.argv.index('--source')+1]);Image.open(raw).save(art_path,lossless=True,method=6)
elif not art_path.exists():Image.open(raw).save(art_path,lossless=True,method=6)
art=Image.open(art_path).convert('RGBA');assert art.size==(1672,940)
# Remonta o conector com recortes do próprio metal pintado: pai e dois filhos, não uma linha de três nós.
original=art.copy();ImageDraw.Draw(art).rectangle((1140,640,1668,750),fill=(0,0,0,0))
beam=original.crop((1280,679,1340,700))
for x,angle in [(1216,8),(1390,-8)]:
 piece=beam.resize((178,20),Image.Resampling.LANCZOS).rotate(angle,Image.Resampling.BICUBIC,expand=True);art.alpha_composite(piece,(x,677))
for box,origin,size in [((1154,644,1280,742),(1175,681),(88,69)),((1526,644,1658,742),(1538,681),(88,65)),((1330,636,1458,744),(1350,638),(90,76))]:
 piece=original.crop(box).resize(size,Image.Resampling.LANCZOS);art.alpha_composite(piece,origin)
bg=Image.open(source).convert('RGB');assert bg.size==(1920,1080)
bg=ImageEnhance.Brightness(bg).enhance(.48);bg=ImageEnhance.Color(bg).enhance(.8)
# Uma captura real inteira, sem redesenho, deslocamento ou reconstituição do cenário.
board=bg.convert('RGBA');shadow=Image.new('RGBA',board.size);a=art.getchannel('A');shadow.paste((0,0,0,150),(72,104),a);shadow=shadow.filter(ImageFilter.GaussianBlur(9));board=Image.alpha_composite(board,shadow);board.alpha_composite(art,(64,88));d=ImageDraw.Draw(board);records=[]
def text(x,y,t,n=24,serif=False,color='#efe5d1',center=False,local=True,shadow=False):
 if local:x+=64;y+=88
 f=font(n,serif)
 if center:x-=f.getlength(t)/2
 if t in ['34 / 34','176 / 200','VIDA','INSTINTO','XP']:
  width=f.getlength(t);glass=Image.new('RGBA',board.size);gd=ImageDraw.Draw(glass);gd.rounded_rectangle((x-12,y-6,x+width+12,y+n+8),radius=12,fill=(8,24,28,190),outline=(164,235,229,100),width=1);board.alpha_composite(glass);color='#f4efdf'
 d.text((round(x),round(y)),t,font=f,fill=color,anchor='lt',stroke_width=2 if shadow else 0,stroke_fill='#0d1012');records.append({'text':t,'x':x,'y':y,'size':n,'right':x+f.getlength(t),'bottom':y+n})
def glyph(name,x,y,size=56,col='#8ee8e5'):
 svg=(ROOT/f'art/ui/icons/{name}.svg').read_text();im=Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(),output_width=size,output_height=size))).convert('RGBA');mask=im.getchannel('A');im=Image.new('RGBA',im.size,col);im.putalpha(mask);board.alpha_composite(im,(x+64,y+88))
text(64,24,'AFTER HUMANS',32,True,local=False,shadow=True);text(420,30,'KIT V2 / ESTUDO DE MATERIAIS',24,local=False,shadow=True)
text(1770,30,'#59 · para aprovação',20,center=True,local=False,shadow=True)
text(255,36,'BENTO',30,True,center=True,color='#211b13');text(101,105,'1',48,True,center=True)
text(252,106,'Cão · Protetor',22,center=True,shadow=True)
text(246,592,'34 / 34',28,True,center=True,color='#0c2525');text(246,683,'176 / 200',28,True,center=True,color='#231723')
glyph('status-protection_good',72,779);glyph('node-combat',218,779);glyph('res-hope',358,779)
text(807,63,'RELATO',28,True,center=True,color='#211b13')
for y,t in [(160,'Madeira sustenta.'),(210,'Papel guarda a voz.'),(260,'Cobre protege a borda.')]:text(552,y,t,28,color='#32271a')
text(552,315,'Raízes nos cantos, espaço para ler.',22,color='#493b29')
for xx,sz in [(620,22),(716,32),(824,64)]:
 badge=ImageOps.contain(original.crop((1148,280,1272,398)),(sz,sz),Image.Resampling.LANCZOS);board.alpha_composite(badge,(xx+64,380+88));text(xx+sz+12,390,str(sz),18,color='#493b29')
text(1400,69,'REDE VIGIA',30,True,center=True,color='#ffce82');text(1400,135,'Vidro antigo · sinal de máquina',22,center=True,color='#f3d2a0')
text(593,525,'Normal',24,center=True,color='#efe5d1');text(812,525,'Foco',24,center=True,color='#d4ffff');text(1026,525,'Pressionado',22,center=True)
text(662,625,'Voltar',24,center=True);text(958,625,'Indisponível',22,center=True,color='#b1aaa0')
for yy,name in [(704,'VIDA'),(774,'INSTINTO'),(847,'XP')]:text(811,yy,name,24,True,center=True,color='#132126' if name!='INSTINTO' else '#23151b')
for xx,t in [(1415,'E'),(1506,'Q'),(1598,'Esc')]:text(xx,846,t,26,center=True,color='#f0e4ca')
# Correções de legibilidade e família ficam na folha de aprovação, não como regras de jogo.
text(64,1042,'Latão oxidado · madeira · papel · vidro',20,local=False,shadow=True)
text(950,1042,'Prancha de peças; não é uma tela de jogo.',20,local=False,shadow=True)
text(1752,1028,'Captura real',18,local=False,shadow=True)
board.convert('RGB').save(OUT/'style_board.webp',quality=93,method=6)
board.convert('RGB').resize((768,432),Image.Resampling.LANCZOS).save(OUT/'style_board_40.webp',quality=90)
ImageOps.grayscale(board.convert('RGB')).save(OUT/'style_board_gray.webp',quality=90)
# Prova real dos emblemas gerados a22/32. Recortes são estudos; não são assets finais.
proof=Image.new('RGB',(1200,360),'#0d1012');pd=ImageDraw.Draw(proof);pd.rectangle((600,0,1200,360),fill='#efe5d1')
for side in range(2):
 for row,y in enumerate([280,410,533]):
  for col,x in enumerate([1148,1275,1404,1528]):
   badge=art.crop((x,y,x+124,y+118));clip=Image.new('L',badge.size);ImageDraw.Draw(clip).polygon([(62,2),(122,59),(62,116),(2,59)],fill=255);import PIL.ImageChops;badge.putalpha(PIL.ImageChops.multiply(badge.getchannel('A'),clip))
   for j,sz in enumerate([22,32]):
    im=ImageOps.contain(badge,(sz,sz),Image.Resampling.LANCZOS);proof.paste(im,(side*600+40+col*128+j*48,32+row*100),im)
proof.save(OUT/'glyph_readability.webp',quality=94)
manifest={'issue':59,'status':'style study awaiting Lucas; not production atlas','canvas':[1920,1080],'art_origin':[64,88],'art_canvas':list(art.size),'screenshot':str(source.relative_to(ROOT)),'screenshot_sha256':sha(source),'screenshot_transform':{'brightness':.48,'saturation':.8,'crop':False,'resize':False},'generated_art':str(art_path.relative_to(ROOT)),'generated_art_sha256':sha(art_path),'master_original':'outside repository','fonts':{'title':'Cinzel','body':'Plus Jakarta Sans','minimum':18},'labels':records,'outside':[r for r in records if r['right']>1920 or r['bottom']>1080],'style_board_sha256':sha(OUT/'style_board.webp')}
(OUT/'composition.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print('Board1920x1080, typography minimum18, outside',len(manifest['outside']))
