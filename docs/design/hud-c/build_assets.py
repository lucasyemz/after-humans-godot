"""Recortes da direção C e símbolo de saída. Nenhum ícone de habilidade é alterado."""
import sys,json,hashlib
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageEnhance,ImageFilter
import numpy as np
import scipy.ndimage as nd
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;OUT=ROOT/'art/ui/kit/v2';OUT.mkdir(parents=True,exist_ok=True)
src=ROOT/'docs/design/hud-variations/skin_c.webp';skin=Image.open(src).convert('RGBA')
BOX={'plate':(1047,454,1494,555),'primary':(1047,582,1494,694),'secondary':(1047,717,1493,826),'slot':(650,420,894,657),'portrait':(587,49,956,403),'action':(1066,47,1474,453),'key':(703,841,836,979),'divider':(1051,869,1492,947),'bar':(580,674,1002,754),'panel':(35,93,546,911)}
def save(name,im,sl=None,content=None):
 im.save(OUT/(name+'.webp'),lossless=True,method=6);rows[name]={'file':'art/ui/kit/v2/'+name+'.webp','size':list(im.size),'slice_ltrb':sl,'content':content,'sha256':hashlib.sha256((OUT/(name+'.webp')).read_bytes()).hexdigest()}
rows={}
for key in ['plate','primary','secondary']:
 im=skin.crop(BOX[key]).resize((256,64),Image.Resampling.LANCZOS);save(key,im,[32,16,32,16],[32,16,192,32])
for key,size in [('slot',(112,112)),('portrait',(128,128)),('action',(88,88)),('key',(48,48)),('divider',(320,56))]:
 im=Image.new('RGBA',size);piece=ImageOps.contain(skin.crop(BOX[key]),size,Image.Resampling.LANCZOS);im.alpha_composite(piece,((size[0]-piece.width)//2,(size[1]-piece.height)//2));save(key,im,content=[16,16,size[0]-32,size[1]-32])
bar=skin.crop(BOX['bar']).resize((256,48),Image.Resampling.LANCZOS);glass=bar.crop((32,16,224,34));mask=bar.getchannel('A');ImageDraw.Draw(mask).rounded_rectangle((32,16,223,33),3,fill=0);bar.putalpha(mask);save('bar_frame',bar,[32,16,32,14],[32,16,192,18])
g=ImageOps.grayscale(glass);a=g.point(lambda v:round(v*.35));ref=Image.new('RGBA',glass.size,'white');ref.putalpha(a);d=ImageDraw.Draw(ref);d.line((3,1,188,1),fill=(255,255,255,72),width=1);save('bar_glass',ref,content=[0,0,192,18])
# Janela de dica: cantos preservados; miolo material repetível, separado da moldura.
panel=skin.crop(BOX['panel']).resize((256,410),Image.Resampling.LANCZOS);out=Image.new('RGBA',(256,160));coords=[(0,0,32,32),(32,0,224,32),(224,0,256,32),(0,32,32,362),(32,32,224,362),(224,32,256,362),(0,362,32,410),(32,362,224,410),(224,362,256,410)];dest=[(0,0,32,32),(32,0,224,32),(224,0,256,32),(0,32,32,112),(32,32,224,112),(224,32,256,112),(0,112,32,160),(32,112,224,160),(224,112,256,160)]
for b,t in zip(coords,dest):out.alpha_composite(panel.crop(b).resize((t[2]-t[0],t[3]-t[1]),Image.Resampling.LANCZOS),(t[0],t[1]))
save('panel',out,[32,32,32,48],[32,32,192,80]);material=skin.crop((170,766,234,830));save('panel_material',material)
exit_path=Path('/workspace/generated_images/exec-8a224374-c3a8-4546-9908-1612b109d5c3.png')
if exit_path.exists():
 im=Image.open(exit_path).convert('RGBA');a=np.array(im.getchannel('A'))>170;a=nd.binary_opening(a,iterations=3);labels,n=nd.label(a);sizes=np.bincount(labels.ravel());keep=sizes>1000;keep[0]=False;a=keep[labels];glyph=Image.new('RGBA',im.size,'white');glyph.putalpha(Image.fromarray((a*255).astype('uint8')));glyph=glyph.crop(glyph.getbbox());glyph=ImageOps.contain(glyph,(56,56),Image.Resampling.LANCZOS);im=Image.new('RGBA',(64,64));im.alpha_composite(glyph,((64-glyph.width)//2,(64-glyph.height)//2));save('exit',im,content=[4,4,56,56])
else:
 im=Image.open(OUT/'exit.webp').convert('RGBA');save('exit',im,content=[4,4,56,56])
(HERE/'assets.json').write_text(json.dumps({'source':str(src.relative_to(ROOT)),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'originals':'outside repository','assets':rows},ensure_ascii=False,indent=2)+'\n');print(len(rows),'WebP RGBA')
