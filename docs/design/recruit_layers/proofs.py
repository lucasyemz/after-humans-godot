from pathlib import Path
import json,subprocess,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
root=Path(__file__).resolve().parents[3]
from build_delivery import compose,KEYS,sha
def build_proofs():
 here=root/'docs/design/recruit_layers';contract=json.loads((here/'contract.json').read_text());font=ImageFont.truetype(str(root/'art/ui/fonts/barlow_condensed_medium.ttf'),27)
 page=Image.new('RGB',(1800,1900),'#171b20');d=ImageDraw.Draw(page);d.text((18,12),'ANTES / BASE A + ROUPA / BASE B + ROUPA — MESMA ESCALA E PÉ',font=font,fill='#efe5d1')
 proof=Image.new('RGB',(1800,1900),'#171b20');pd=ImageDraw.Draw(proof);pd.text((18,12),'ALFA E LEITURA / FUNDO ESCURO · CLARO / CINZA A 40%',font=font,fill='#efe5d1')
 for ri,row in enumerate(contract['classes']):
  refpath=root/row['reference'];assert subprocess.check_output(['git','show',contract['base_commit']+':'+row['reference']],cwd=root)==refpath.read_bytes()
  images={k:Image.open(root/v['file']).convert('RGBA') for k,v in row['assets'].items()};ref=Image.open(refpath).convert('RGBA');refscale=ref.width/row['source_canvas'][0];s=220/(row['body_reference_pixels']*refscale);ax,ay=row['texture_anchor'];x=ri%2*900;y=60+ri//2*600
  d.text((x+12,y),row['label'],font=font,fill='#efe5d1')
  for ci,im in enumerate([ref,compose(images,0)[0],compose(images,1)[0]]):
   line=y+460;thumb=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);left=x+ci*300+round(150-ax*s);page.paste(thumb,(left,line-round(ay*s)),thumb);d.line((x+ci*300+6,line,x+ci*300+294,line),fill='#66737b')
  for ci,bg in enumerate(['#0d1012','#d9d3c4','#34393d']):
   panel=Image.new('RGB',(300,480),bg);im=compose(images,5)[0];im=ImageOps.grayscale(im).convert('RGBA') if ci==2 else im
   if ci==2:im.putalpha(compose(images,5)[0].getchannel('A'))
   thumb=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);panel.paste(thumb,(round(150-ax*s),450-round(ay*s)),thumb);proof.paste(panel,(x+ci*300,y+30))
  pd.text((x+12,y),row['label'],font=font,fill='#efe5d1')
 page.save(here/'before_after.webp',quality=94,method=6);proof.save(here/'readability.webp',quality=94,method=6)
 for k in ['before_after','readability']:
  im=Image.open(here/(k+'.webp'));im.resize((round(im.width*.4),round(im.height*.4)),Image.Resampling.LANCZOS).save(here/(k+'_40.webp'),quality=92)
 audit=json.loads((here/'audit.json').read_text());audit['canonical_hashes_checked_against_git']=True;audit['alpha_fringe_pixels']={};rgba=[];frames=[];grays=[];unchanged=[]
 for row in contract['classes']:
  unchanged.append(subprocess.check_output(['git','show',contract['base_commit']+':'+row['reference']],cwd=root)==(root/row['reference']).read_bytes())
  for k,a in row['assets'].items():
   im=Image.open(root/a['file']);rgba.append(im.mode=='RGBA');frames.append(list(im.size)==row['size']);ar=np.array(im).astype(int);
   if a['tintable']:grays.append(bool(np.array_equal(ar[:,:,0],ar[:,:,1]) and np.array_equal(ar[:,:,1],ar[:,:,2])))
   r,g,b,alpha=[ar[:,:,i] for i in range(4)];bad=(r>g+65)&(b>g+65)&(r>120)&(b>120)&(alpha>24);count=int(bad.sum());audit['alpha_fringe_pixels'][row['name']+'/'+k]=count
   if count:audit['problems'].append({'file':a['file'],'magenta_pixels':count})
 audit.update(rgba=all(rgba),frame_matches=all(frames),gray_tint_layers=all(grays),canonical_unchanged=all(unchanged))
 (here/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');assert not audit['problems'],audit['problems'];print('Alfa limpo e referências intactas.')

if __name__=='__main__':build_proofs()
