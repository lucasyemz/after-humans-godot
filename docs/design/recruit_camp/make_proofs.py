"""Empacota capturas reais da Godot; não desenha personagens ou altera o cenário."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def make(folder):
 font=ImageFont.truetype(str(ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'),36)
 for state in ['seat','sleep']:
  page=Image.new('RGB',(3840,1140),'#171b20');d=ImageDraw.Draw(page)
  for col,stage in enumerate(['before','after']):
   im=Image.open(folder/(stage+'_'+state+'.png')).convert('RGB');assert im.size==(1920,1080);im.save(HERE/(stage+'_'+state+'.webp'),quality=95,method=6);d.text((col*1920+24,8),('ANTES / MAIN ff8fc83' if stage=='before' else 'DEPOIS / PROPOSTA NA GODOT')+' / '+state.upper(),font=font,fill='#efe5d1');page.paste(im,(col*1920,60))
  page.save(HERE/('before_after_'+state+'.webp'),quality=94,method=6);page.resize((1536,456),Image.Resampling.LANCZOS).save(HERE/('before_after_'+state+'_40.webp'),quality=92)
  ImageOps.grayscale(page.resize((1536,456),Image.Resampling.LANCZOS)).save(HERE/('before_after_'+state+'_gray_40.webp'),quality=92)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--captures',required=True,type=Path);make(p.parse_args().captures)
