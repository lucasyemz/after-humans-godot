"""Pranchas/contrato da #225 e protótipos temporários. Não altera produção."""
import argparse,hashlib,json,math
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps,ImageChops
P=argparse.ArgumentParser();P.add_argument('--repo',type=Path,default=Path.cwd());P.add_argument('--sources',required=True,type=Path);P.add_argument('--out',required=True,type=Path);P.add_argument('--prototypes',required=True,type=Path);A=P.parse_args();ROOT=A.repo.resolve();OUT=A.out;OUT.mkdir(parents=True,exist_ok=True);A.prototypes.mkdir(parents=True,exist_ok=True)
M=json.loads((ROOT/'data/presentation/combat_art.json').read_text());F=ROOT/'art/ui/fonts/barlow_condensed_medium.ttf';FONT=ImageFont.truetype(str(F),28);SMALL=ImageFont.truetype(str(F),23);NAMES={'raccoon':'GUAXINIM','armadillo':'TATU'};HEIGHTS={'hero_cao_bento':1.72,'hero_coruja_vespera':1.66,'hero_gato_nick':1.5,'hero_sapo_iris':1.38};HEROES=list(HEIGHTS)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def bbox(im):return im.getchannel('A').point(lambda a:255 if a>24 else 0).getbbox()
def save(im,name):
 im.save(OUT/(name+'.webp'),quality=94,method=6);im.resize((round(im.width*.4),round(im.height*.4)),Image.Resampling.LANCZOS).save(OUT/(name+'_40.webp'),quality=92);ImageOps.grayscale(im.resize((round(im.width*.4),round(im.height*.4)),Image.Resampling.LANCZOS)).save(OUT/(name+'_gray_40.webp'),quality=92)
def draw_sprite(page,im,art,height,cx,line,ppm):
 ratio=im.width/art['canvas'][0];scale=height*ppm/(art['body_reference_pixels']*ratio);thumb=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);ax,ay=[v*ratio for v in art['anchor']];page.paste(thumb,(round(cx-ax*scale),round(line-ay*scale)),thumb)
def old_entry(n,state):
 old=M['recruits'][n+'_recruit_01'];ref=old['idle']
 if state=='idle':return ROOT/ref['file'].removeprefix('res://'),ref,'MAIN'
 if state in old['actions']:
  a=old['actions'][state]['execucao'];return ROOT/a['file'].removeprefix('res://'),a,'MAIN'
 if state in old['reactions']:
  a=old['reactions'][state];return ROOT/a['file'].removeprefix('res://'),a,'MAIN'
 if state in ['seat','sleep']:return A.sources/'qa/before'/(n+'_'+state+'.webp'),ref,'PROPOSTA #220'
 return ROOT/ref['file'].removeprefix('res://'),ref,'SEM POSE / FALLBACK IDLE'
contract={'issue':225,'related_issue':210,'base_commit':'561f798','source_folder':'art/combat/source/recruits_redraw_20261028','source_tag':'codex-pr<N>-originals','delivery':'PR contains review sheets/docs only; production assets come from source tag via PC integration.','actors':{},'portraits':{},'integration':{'body_conversion':'PNG 1178x1335 -> WebP 589x668; use fixed idle registration across all states.','portraits':'PNG256x256, copy at 1:1, no half-scale.','legacy_source_filenames':'Same rato/tatu-idle, attackN-ability, hurt,dodge,block,defeat prefixes; add item,seat,sleep.','old_layers':'Raccoon/armadillo layers from #211 have old proportions; do not overlay them on this redraw.'}};audit={'bodies':0,'portraits':0,'problems':[]}
for n in NAMES:
 folder=A.sources/n;meta=json.loads((folder/'registration.json').read_text());assets={};old=M['recruits'][n+'_recruit_01'];target=meta['height_m'];proto=A.prototypes/n;proto.mkdir(exist_ok=True)
 for state,fn in meta['files'].items():
  src=folder/fn;im=Image.open(src).convert('RGBA');assert im.size==(1178,1335);bb=bbox(im);assert abs(bb[3]-1305)<=1;ar=np.array(im).astype(int);r,g,b,alpha=[ar[:,:,i] for i in range(4)];bad=int(((r>g+65)&(b>g+65)&(r>120)&(b>120)&(alpha>24)).sum());assert bad==0,(n,state,bad);tmp=proto/(state+'.webp');im.resize((589,668),Image.Resampling.LANCZOS).save(tmp,lossless=True,method=6);op,oa,origin=old_entry(n,state);asset={'source_file':n+'/'+fn,'source_sha256':sha(src),'prototype_file':n+'/'+state+'.webp','canvas':[1178,1335],'texture_canvas':[589,668],'anchor':meta['anchor'],'body_reference_pixels':1240,'body_width_pixels':meta['idle_bbox'][2]-meta['idle_bbox'][0],'visible':list(bb),'world_width_m':round((bb[2]-bb[0])*target/1240,4),'old_reference':str(op.relative_to(ROOT)) if op.is_relative_to(ROOT) else 'qa/before/'+op.name,'old_origin':origin,'old_sha256':sha(op)};assets[state]=asset;audit['bodies']+=1
 actor={'class_id':old['class_id'],'id':n+'_recruit_01','height_m':target,'old_height_m':1.3 if n=='raccoon' else 1.35,'idle_height_ratio':1240/1335,'assets':assets};contract['actors'][n]=actor
 portrait=json.loads((folder/'portrait.json').read_text());src=folder/portrait['file'];assert Image.open(src).size==(256,256);portrait.update(source_file=n+'/'+portrait['file'],source_sha256=sha(src));contract['portraits'][n]=portrait;audit['portraits']+=1
 states=list(meta['files']);groups=[states[:5],states[5:10],states[10:]]
 for group_id,group in enumerate(groups,1):
  page=Image.new('RGB',(1600,70+len(group)*450),'#1c2126');d=ImageDraw.Draw(page);d.text((18,10),NAMES[n]+' / ANTES E DEPOIS À MESMA ALTURA DE DESTINO '+str(target)+' m',font=FONT,fill='#efe5d1')
  for i,state in enumerate(group):
   y=70+i*450;line=y+400;oldpath,oldart,origin=old_entry(n,state);new=assets[state];d.text((18,y),state.upper(),font=FONT,fill='#efe5d1');d.text((220,y),'ANTES / '+origin,font=SMALL,fill='#a69a84');d.text((1000,y),'DEPOIS / #225',font=SMALL,fill='#e9c47c');draw_sprite(page,Image.open(oldpath).convert('RGBA'),oldart,target,450,line,180);draw_sprite(page,Image.open(folder/meta['files'][state]).convert('RGBA'),new,target,1250,line,180);d.line((12,line,1588,line),fill='#59656f')
  save(page,n+'_poses_'+str(group_id))
# Os seis, na mesma escala métrica; uma linha de chão por fila.
page=Image.new('RGB',(2100,1500),'#1c2126');d=ImageDraw.Draw(page)
for row,title in enumerate(['A / MAIN ATUAL: GUAXINIM1,30 · TATU1,35','B / ARTE ANTIGA NAS ALTURAS DE DESTINO','C / REDESENHO #225: GUAXINIM1,44 · TATU1,56']):
 y=row*500;line=y+448;d.text((18,y+10),title,font=FONT,fill='#e9c47c')
 for h in [.5,1,1.5]:d.line((0,line-round(h*195),2100,line-round(h*195)),fill='#343c44')
 for j,hero in enumerate(HEROES):
  art=M['heroes'][hero]['idle'];im=Image.open(ROOT/art['file'].removeprefix('res://')).convert('RGBA');draw_sprite(page,im,art,HEIGHTS[hero],j*350+175,line,195);d.text((j*350+16,line+8),hero.split('_')[-1].upper()+' '+str(HEIGHTS[hero]),font=SMALL,fill='#efe5d1')
 for j,n in enumerate(NAMES,4):
  actor=contract['actors'][n];art=M['recruits'][actor['id']]['idle'] if row<2 else actor['assets']['idle'];im=Image.open(ROOT/art['file'].removeprefix('res://')).convert('RGBA') if row<2 else Image.open(A.sources/actor['assets']['idle']['source_file']).convert('RGBA');height=actor['old_height_m'] if row==0 else actor['height_m'];draw_sprite(page,im,art,height,j*350+175,line,195);d.text((j*350+12,line+8),NAMES[n]+' '+str(height),font=SMALL,fill='#efe5d1')
 d.line((0,line,2100,line),fill='#a69a84')
save(page,'scale_comparison')
# Retratos: recorte do idle, olho em144,104, prova circular e miniaturas reais.
page=Image.new('RGB',(1600,680),'#1c2126');d=ImageDraw.Draw(page);d.text((18,8),'RETRATOS / #26 / OLHO(144,104) / QUADRADO, CÍRCULO,48/64/128 E CINZA',font=FONT,fill='#efe5d1')
for x,label in [(20,'ANTES'),(300,'DEPOIS'),(580,'CÍRCULO')]:d.text((x,40),label,font=SMALL,fill='#a69a84')
for row,n in enumerate(NAMES):
 y=70+row*300;old=Image.open(ROOT/'art/ui/portraits'/(n+'_recruit_01.png')).convert('RGBA');new=Image.open(A.sources/contract['portraits'][n]['source_file']).convert('RGBA');d.text((18,y),NAMES[n],font=SMALL,fill='#efe5d1');page.paste(old,(20,y+30),old);page.paste(new,(300,y+30),new);mask=Image.new('L',(256,256));ImageDraw.Draw(mask).ellipse((15,15,241,241),fill=255);circ=new.copy();circ.putalpha(ImageChops.multiply(new.getchannel('A'),mask));page.paste(circ,(580,y+30),circ)
 for i,size in enumerate([48,64,128]):
  thumb=new.resize((size,size),Image.Resampling.LANCZOS);page.paste(thumb,(880+i*160,y+100),thumb);d.text((880+i*160,y+45),str(size),font=SMALL,fill='#efe5d1')
 gray=ImageOps.grayscale(new).convert('RGBA');gray.putalpha(new.getchannel('A'));gray=gray.resize((128,128));page.paste(gray,(1400,y+100),gray)
save(page,'portraits')
(OUT/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n');(OUT/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('Sources:',audit['bodies'],'body sprites +',audit['portraits'],'portraits. No runtime assets or active contracts changed.')
