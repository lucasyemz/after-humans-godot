from pathlib import Path
import argparse,json,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--captures',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();font=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),34);pairs={'exploration':('founders/lineup_before','founders/lineup_exploration'),'combat_lineup':('founders/lineup_before','founders/lineup_combat'),'founders_fight':('founders/founders_fight_before','founders/founders_fight_after'),'recruits_fight':('recruits/recruits_fight_before','recruits/recruits_fight_after')};records={}
for name,(before,after) in pairs.items():
 page=Image.new('RGB',(3840,1140),'#1b2025');d=ImageDraw.Draw(page)
 for i,(stage,label) in enumerate([(before,'ANTES / MAIN5bb2928 / IDLE ÚNICO'),(after,'DEPOIS / PROTÓTIPO #221 / '+('EXPLORAÇÃO' if name=='exploration' else 'GUARDA DE COMBATE'))]):
  path=a.captures/(stage+'.png');im=Image.open(path).convert('RGB');assert im.size==(1920,1080);d.text((i*1920+18,10),label,font=font,fill='#efe5d1');page.paste(im,(i*1920,60));records[stage]={'png_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(im.size)}
 page.save(a.out/(name+'_before_after.webp'),quality=92,method=6);small=page.resize((1536,456),Image.Resampling.LANCZOS);small.save(a.out/(name+'_before_after_40.webp'),quality=90);ImageOps.grayscale(small).save(a.out/(name+'_before_after_gray_40.webp'),quality=90)
m={'screenshots':records,'founders':json.loads((a.captures/'founders/founders_capture.json').read_text()),'recruits':json.loads((a.captures/'recruits/recruits_capture.json').read_text())};(a.out/'capture.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print('4 before/after pairs packaged')
