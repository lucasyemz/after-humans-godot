import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path.cwd());p.add_argument('--captures',required=True,type=Path);p.add_argument('--out',required=True,type=Path);a=p.parse_args();font=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),34);pairs={'lineup':('lineup_before','lineup_after'),'fight':('fight_before','fight_after')};records={}
for name,(before,after) in pairs.items():
 page=Image.new('RGB',(3840,1140),'#1b2025');d=ImageDraw.Draw(page)
 for i,(stage,label) in enumerate([(before,'ANTES / MAIN5bb2928 / ARTE E ALTURAS ATUAIS'),(after,'DEPOIS / CAMADAS #239 / GUAXINIM1,44 · TATU1,56')]):
  path=a.captures/(stage+'.png');im=Image.open(path).convert('RGB');assert im.size==(1920,1080);d.text((i*1920+18,10),label,font=font,fill='#efe5d1');page.paste(im,(i*1920,60));records[stage]={'png_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(im.size)}
 page.save(a.out/(name+'_before_after.webp'),quality=92,method=6);small=page.resize((1536,456),Image.Resampling.LANCZOS);small.save(a.out/(name+'_before_after_40.webp'),quality=90);ImageOps.grayscale(small).save(a.out/(name+'_before_after_gray_40.webp'),quality=90)
m=json.loads((a.captures/'capture.json').read_text());m['screenshots']=records;(a.out/'capture.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print('Two real Godot before/after pairs packaged.')
