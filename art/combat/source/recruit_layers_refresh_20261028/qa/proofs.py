from pathlib import Path
import argparse,json,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--repo',required=True,type=Path);p.add_argument('--sources',required=True,type=Path);p.add_argument('--legacy',required=True,type=Path);p.add_argument('--redraw',required=True,type=Path);p.add_argument('--prototypes',required=True,type=Path);p.add_argument('--out',required=True,type=Path);a=p.parse_args();c=json.loads((a.out/'contract.json').read_text());ft=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),30);sf=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),24)
# Original layers use exact same project compositing order; no anatomy remapping.
def old_comp(n):
 folder=a.repo/'art/combat/recruits/layers'/n;keys=['base_a','clothes'];out=Image.new('RGBA',(589,668))
 for k in keys:
  im=Image.open(folder/(k+'.webp')).convert('RGBA')
  if k=='clothes':
   ar=np.array(im);ar[:,:,:3]=np.uint8(ar[:,:,:3].astype(float)*np.array([201,138,75])/255);im=Image.fromarray(ar)
  out.alpha_composite(im)
 return out
page=Image.new('RGB',(2100,1150),'#20262a');d=ImageDraw.Draw(page);d.text((20,10),'ANTES / CAMADAS #211 · DESENHO #225 · CAMADAS NOVAS — MESMA ESCALA',font=ft,fill='#e9c47c');read=Image.new('RGB',(2100,1150),'#20262a');rd=ImageDraw.Draw(read);rd.text((20,10),'FUNDO ESCURO · FUNDO CLARO · CINZA / PEÇAS INDEPENDENTES DO PAPEL',font=ft,fill='#e9c47c')
for ri,(n,pre,label,oldref,oldanchor) in enumerate([('raccoon','rato','Guaxinim',999,[601.5,1184]),('armadillo','tatu','Tatu',807,[601,1087])]):
 y=65+ri*530;row=c['actors'][n];ref=Image.open(a.redraw/n/(pre+'-idle.png')).convert('RGBA');d.text((20,y),label,font=ft,fill='#efe5d1');ims=[old_comp(n),ref,Image.open(a.prototypes/n/'combination_2.webp').convert('RGBA'),Image.open(a.prototypes/n/'combination_6.webp').convert('RGBA')]
 for j,im in enumerate(ims):
  x=j*525;ratio=im.width/1178;reference=oldref if j==0 else 1240;anchor=oldanchor if j==0 else row['anchor'];s=390/(reference*ratio);thumb=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);page.paste(thumb,(round(x+262-anchor[0]*ratio*s),round(y+450-anchor[1]*ratio*s)),thumb);d.line((x+5,y+450,x+520,y+450),fill='#728088');d.text((x+15,y+467),['CAMADAS ANTIGAS','BASE APROVADA #225','NOVAS / BASE B / AZUL','NOVAS / BASE B / COMPLETO'][j],font=sf,fill='#a69a84')
 for j,bg in enumerate(['#0d1012','#ded8cb','#34393d']):
  x=j*700;panel=Image.new('RGB',(700,470),bg);im=ims[3]
  if j==2:
   g=ImageOps.grayscale(im).convert('RGBA');g.putalpha(im.getchannel('A'));im=g
  scale=390/(1240*.5);thumb=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);panel.paste(thumb,(round(350-row['texture_anchor'][0]*scale),round(450-row['texture_anchor'][1]*scale)),thumb);read.paste(panel,(x,y+10));rd.text((x+10,y-18),label,font=sf,fill='#e9c47c')
for name,im in [('before_after',page),('readability',read)]:
 im.save(a.out/(name+'.webp'),quality=92);im.resize((840,460),Image.Resampling.LANCZOS).save(a.out/(name+'_40.webp'),quality=90)
# Sources/runtime checks, independent of the construction masks.
audit=json.loads((a.out/'audit.json').read_text());audit['runtime_files']=0;audit['source_files']=0;audit['checks']={};root=a.sources
for n,row in c['actors'].items():
 ref=Image.open(a.redraw/n/(('rato' if n=='raccoon' else 'tatu')+'-idle.png')).convert('RGBA');refa=np.array(ref.getchannel('A'));audit['checks'][n]={'base_alpha_matches_approved':True,'body_contact_unchanged':True,'grayscale_exact':True}
 for key,asset in row['assets'].items():
  source=root/asset['source_file'];im=Image.open(source);ar=np.array(im);assert im.mode=='RGBA' and im.size==(1178,1335);assert hashlib.sha256(source.read_bytes()).hexdigest()==asset['source_sha256'];assert np.all(ar[ar[:,:,3]==0]==0);audit['source_files']+=1
  runtime=Image.open(a.prototypes/asset['prototype_file']);rr=np.array(runtime);assert runtime.mode=='RGBA' and runtime.size==(589,668);audit['runtime_files']+=1
  if asset['tintable']:assert np.array_equal(ar[:,:,0],ar[:,:,1]) and np.array_equal(ar[:,:,1],ar[:,:,2]);assert np.array_equal(rr[:,:,0],rr[:,:,1]) and np.array_equal(rr[:,:,1],rr[:,:,2])
  if key.startswith('base_'):assert np.array_equal(ar[:,:,3],refa);assert abs(im.getbbox()[3]-row['anchor'][1])<=1
assert audit['source_files']==20 and audit['runtime_files']==20
(a.out/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('20 PNG +20 WebP checked: grayscale, body registration, alpha, hashes')
