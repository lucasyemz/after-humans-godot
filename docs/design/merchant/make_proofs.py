"""Pranchas de capturas da Godot e provas de alfa/retrato, sem alterar cenas/personagens."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def make(folder):
 font=ImageFont.truetype(str(ROOT/'art/ui/fonts/barlow_condensed_medium.ttf'),36)
 for state in ['idle','walk','trade']:
  page=Image.new('RGB',(3840,1140),'#171b20');d=ImageDraw.Draw(page)
  for col,stage in enumerate(['before','after_'+state]):
   im=Image.open(folder/(stage+'.png')).convert('RGB');assert im.size==(1920,1080);im.save(HERE/(stage+'.webp'),quality=95,method=6);d.text((col*1920+24,8),('ANTES / MAIN ff8fc83 / SEM ARTE DO MERCADOR' if col==0 else 'DEPOIS / PROTÓTIPO NA GODOT / '+state.upper()),font=font,fill='#efe5d1');page.paste(im,(col*1920,60))
  page.save(HERE/('before_after_'+state+'.webp'),quality=94,method=6);small=page.resize((1536,456),Image.Resampling.LANCZOS);small.save(HERE/('before_after_'+state+'_40.webp'),quality=92);ImageOps.grayscale(small).save(HERE/('before_after_'+state+'_gray_40.webp'),quality=92)
 c=json.loads((HERE/'contract.json').read_text());page=Image.new('RGB',(1600,850),'#1b2025');d=ImageDraw.Draw(page);d.text((18,8),'ALFA E LEITURA / ESCURO E CLARO / RETRATO EM TAMANHOS REAIS',font=font,fill='#efe5d1')
 for i,state in enumerate(['idle','walk','trade']):
  a=c['assets'][state];im=Image.open(ROOT/a['file'].removeprefix('res://')).convert('RGBA');im=ImageOps.contain(im,(240,460),Image.Resampling.LANCZOS)
  for j,bg in enumerate(['#0d1012','#ddd6c4']):
   p=Image.new('RGB',(250,540),bg);p.paste(im,((250-im.width)//2,540-im.height),im);page.paste(p,(i*510+j*250,70))
 portrait=Image.open(ROOT/c['assets']['portrait']['file'].removeprefix('res://')).convert('RGBA')
 for i,s in enumerate([22,32,48,64,128]):
  im=portrait.resize((s,s),Image.Resampling.LANCZOS);x=25+i*200;page.paste(im,(x,680),im);d.text((x,635),str(s)+' PX',font=font,fill='#efe5d1')
 page.save(HERE/'readability.webp',quality=95,method=6)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--captures',required=True,type=Path);make(p.parse_args().captures)
