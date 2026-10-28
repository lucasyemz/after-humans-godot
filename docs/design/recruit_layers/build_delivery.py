"""Converte as fontes em camadas alinhadas e monta seis combinações por classe (#191)."""
import argparse,hashlib,io,json,math,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
import cairosvg
from prepare_layers import key,box,clean_chroma
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];REFS=json.loads((HERE/'references.json').read_text());ATTACH=json.loads((HERE/'attachments.json').read_text());FONT=ROOT/'art/ui/fonts/barlow_condensed_medium.ttf';NAMES={'dog':'Cão','cat':'Gato','frog':'Sapo','owl':'Coruja','raccoon':'Guaxinim','armadillo':'Tatu'}
ROLES={'protection':'intent-block','healing':'intent-heal','ranged':'status-marked_good','chemistry':'item-ampoule'}
COLORS=['#c98a4b','#8fb4f0','#86c98f','#b7a6f4','#d55e00','#a69a84']
ROLE_LABELS={'protection':'PROTEÇÃO','healing':'CURA','ranged':'TIRO','chemistry':'QUÍMICA'}
ORDER=['bag','base','clothes','scarf','cap','badge'];KEYS=['base_a','base_b','clothes','scarf','bag','cap']+['badge_'+r for r in ROLES]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def gray(im):
 a=im.getchannel('A');g=ImageOps.grayscale(im).convert('RGBA');g.putalpha(a);return g
def tint(im,color):
 a=np.array(im);rgb=np.array([int(color[i:i+2],16) for i in [1,3,5]])/255;a[:,:,:3]=np.uint8(a[:,:,:3].astype(float)*rgb);return Image.fromarray(a)
def place(item,size,rect,top=False):
 x,y,w,h=rect;item=item.crop(box(item));item=ImageOps.contain(item,(w,h),Image.Resampling.LANCZOS);out=Image.new('RGBA',size);out.alpha_composite(item,(round(x+(w-item.width)/2),y if top else round(y+(h-item.height)/2)));return out
def prepare_accessories(raw,sources):
 for row in REFS:
  name=row['name'];ref=Image.open(ROOT/row['idle']['file'].removeprefix('res://')).convert('RGBA');sheet=Image.open(raw/(name+'_accessories.png')).convert('RGB');parts=[]
  for j in range(4):parts.append(key(sheet.crop((round(j%2*sheet.width/2),round(j//2*sheet.height/2),round((j%2+1)*sheet.width/2),round((j//2+1)*sheet.height/2)))))
  folder=sources/name
  for j,k in enumerate(['scarf','bag','cap']):
   im=place(parts[j],ref.size,ATTACH[name][k],k in ['scarf','bag']);im=gray(im) if k!='bag' else im
   if name=='armadillo' and k=='scarf':
    mask=Image.new('L',ref.size);ImageDraw.Draw(mask).polygon([(370,232),(507,247),(519,422),(472,480),(362,454),(349,270)],fill=255);a=np.asarray(im.getchannel('A'),float)*(1-np.asarray(mask,float)/255);im.putalpha(Image.fromarray(np.uint8(a)))
   im.resize(tuple(row['idle']['canvas']),Image.Resampling.LANCZOS).save(folder/(k+'.png'))
  frame=place(parts[3],ref.size,ATTACH[name]['badge']);x,y,w,h=ATTACH[name]['badge']
  for role,icon in ROLES.items():
   im=frame.copy();glyph=Image.open(io.BytesIO(cairosvg.svg2png(bytestring=(ROOT/f'art/ui/icons/{icon}.svg').read_bytes(),output_width=64,output_height=64))).convert('RGBA');glyph=glyph.crop(glyph.getchannel('A').getbbox());glyph=ImageOps.contain(glyph,(max(14,h-8),max(14,h-8)),Image.Resampling.LANCZOS);paint=Image.new('RGBA',glyph.size,'#efe5d1');paint.putalpha(glyph.getchannel('A'));im.alpha_composite(paint,(round(x+(w-glyph.width)/2),round(y+(h-glyph.height)/2)));im.resize(tuple(row['idle']['canvas']),Image.Resampling.LANCZOS).save(folder/('badge_'+role+'.png'))
def compose(images,index):
 out=Image.new('RGBA',images['base_a'].size);role=list(ROLES)[index%4];base='base_a' if index%2==0 else 'base_b';color=COLORS[index];accessories=[[],['scarf'],['bag'],['cap'],['scarf','bag'],['scarf','bag','cap']][index]
 if 'bag' in accessories:out.alpha_composite(images['bag'])
 out.alpha_composite(images[base]);out.alpha_composite(tint(images['clothes'],color))
 for k in ['scarf','cap']:
  if k in accessories:out.alpha_composite(tint(images[k],COLORS[(index+2)%6] if k=='scarf' else color))
 out.alpha_composite(images['badge_'+role]);return out,{'base':base,'cloth_tint':color,'scarf_tint':COLORS[(index+2)%6],'accessories':accessories,'badge':role}
def build(sources):
 rows=[];overview=Image.new('RGB',(1800,80+len(REFS)*440),'#171b20');od=ImageDraw.Draw(overview);font=ImageFont.truetype(str(FONT),27);od.text((20,16),'RECRUTAS / 6 COMBINAÇÕES POR CLASSE / CAMADAS ALINHADAS',font=font,fill='#efe5d1');audit={'classes':len(REFS),'files':0,'problems':[]}
 for ri,row in enumerate(REFS):
  name=row['name'];refpath=ROOT/row['idle']['file'].removeprefix('res://');ref=Image.open(refpath);dest=ROOT/'art/combat/recruits/layers'/name;dest.mkdir(parents=True,exist_ok=True);images={};assets={}
  for k in KEYS:
   src=sources/name/(k+'.png');source=clean_chroma(Image.open(src).convert('RGBA'));source.save(src);im=source.resize(ref.size,Image.Resampling.LANCZOS)
   if k in ['clothes','scarf','cap']:im=gray(im)
   arr=np.array(im);rgb=arr[:,:,:3].astype(int);bad=(rgb[:,:,0]>rgb[:,:,1]+65)&(rgb[:,:,2]>rgb[:,:,1]+65)&(rgb[:,:,0]>120)&(rgb[:,:,2]>120);lum=np.uint8(rgb.mean(axis=2));arr[bad,:3]=np.repeat(lum[bad,None],3,axis=1);arr[arr[:,:,3]==0]=0;im=Image.fromarray(arr);p=dest/(k+'.webp');im.save(p,lossless=True,method=6);images[k]=Image.open(p).convert('RGBA');assets[k]={'file':str(p.relative_to(ROOT)),'source_file':name+'/'+k+'.png','size':list(im.size),'tintable':k in ['clothes','scarf','cap'],'frame_origin':[0,0],'sha256':sha(p),'source_sha256':sha(src),'bbox':list(box(im))};audit['files']+=1;assert Image.open(p).mode=='RGBA' and Image.open(p).size==ref.size
   if k in ['clothes','scarf','cap']:
    rgb=np.array(Image.open(p))[:,:,:3];assert np.array_equal(rgb[:,:,0],rgb[:,:,1]) and np.array_equal(rgb[:,:,1],rgb[:,:,2])
  combos=[];page=Image.new('RGB',(1200,1060),'#171b20');d=ImageDraw.Draw(page);d.text((18,14),NAMES[name]+' / 2 BASES · ROUPA TINGIDA · ACESSÓRIOS',font=font,fill='#efe5d1');ax,ay=[v*ref.width/row['idle']['canvas'][0] for v in row['idle']['anchor']];scale=300/(row['idle']['body_reference_pixels']*ref.width/row['idle']['canvas'][0])
  for i in range(6):
   im,combo=compose(images,i);combo['index']=i+1;combos.append(combo);x=i%3*400;y=64+i//3*490;d.text((x+16,y),f"{i+1} / {combo['base'][-1].upper()} / {ROLE_LABELS[combo['badge']]}",font=font,fill='#efe5d1');thumb=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);line=y+442;left=x+round(200-ax*scale);top=line-round(ay*scale);page.paste(thumb,(left,top),thumb);d.line((x+8,line,x+392,line),fill='#66737b');d.ellipse((x+198,line-2,x+202,line+2),fill='#f0a020')
   s=240/(row['idle']['body_reference_pixels']*ref.width/row['idle']['canvas'][0]);thumb=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);ox=i*300;oy=80+ri*440;od.text((ox+10,oy+4),(NAMES[name]+' / ' if i==0 else '')+str(i+1),font=font,fill='#efe5d1');overview.paste(thumb,(ox+round(150-ax*s),oy+402-round(ay*s)),thumb)
  page.save(HERE/(name+'_combinations.webp'),quality=93,method=6);page.resize((480,424),Image.Resampling.LANCZOS).save(HERE/(name+'_40.webp'),quality=91);ImageOps.grayscale(Image.open(HERE/(name+'_40.webp'))).save(HERE/(name+'_gray_40.webp'),quality=90)
  lp=Image.new('RGB',(1500,1040),'#252b30');ld=ImageDraw.Draw(lp);ld.text((18,12),NAMES[name]+' / CAMADAS NO MESMO CANVAS',font=font,fill='#efe5d1')
  for i,k in enumerate(KEYS):
   x=i%5*300;y=60+i//5*490;ld.text((x+10,y),k.upper(),font=font,fill='#efe5d1');im=images[k];s=260/(row['idle']['body_reference_pixels']*ref.width/row['idle']['canvas'][0]);im=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);line=y+430;lp.paste(im,(x+round(150-ax*s),line-round(ay*s)),im);ld.line((x+8,line,x+292,line),fill='#66737b')
  lp.save(HERE/(name+'_layers.webp'),quality=92,method=6)
  rows.append({'name':name,'label':NAMES[name],'id':row['id'],'class_id':row['class_id'],'reference':str(refpath.relative_to(ROOT)),'reference_sha256':sha(refpath),'size':list(ref.size),'source_canvas':row['idle']['canvas'],'canonical_anchor':row['idle']['anchor'],'texture_anchor':[ax,ay],'body_reference_pixels':row['idle']['body_reference_pixels'],'draw_order':ORDER,'assets':assets,'combinations':combos})
 overview.save(HERE/'overview.webp',quality=93,method=6);overview.resize((720,round(overview.height*.4)),Image.Resampling.LANCZOS).save(HERE/'overview_40.webp',quality=90);ImageOps.grayscale(Image.open(HERE/'overview_40.webp')).save(HERE/'overview_gray_40.webp',quality=90)
 pub=json.loads((HERE/'publication.json').read_text()) if (HERE/'publication.json').exists() else {};contract={'issue':191,'base_commit':'20890be','source_tag':pub.get('source_tag','codex-pr<N>-originals'),'source_folder':'art/combat/source/recruit_layers_20261028','frame_origin':[0,0],'blend':'straight-alpha source-over, no additive blend','color_samples':COLORS,'palette_status':'Preview samples from existing kit; final selectable palette belongs to Lucas.','role_glyphs':{r:'art/ui/icons/'+k+'.svg' for r,k in ROLES.items()},'classes':rows};(HERE/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n');(HERE/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('Camadas:',audit['classes'],'classes;',audit['files'],'WebP; cinzas exatos.')
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--sources',required=True,type=Path);ap.add_argument('--accessories',type=Path);a=ap.parse_args()
 if a.accessories:prepare_accessories(a.accessories,a.sources)
 build(a.sources)
 from proofs import build_proofs
 build_proofs()
