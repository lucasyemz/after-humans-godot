"""Registered crops/conversions of approved art. No anatomy regeneration or per-layer recentering."""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=argparse.ArgumentParser();p.add_argument('--repo',required=True,type=Path);p.add_argument('--sources',required=True,type=Path);p.add_argument('--redraw',required=True,type=Path);p.add_argument('--legacy',required=True,type=Path);p.add_argument('--out',required=True,type=Path);p.add_argument('--prototypes',required=True,type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);a.prototypes.mkdir(parents=True,exist_ok=True)
SIZE=(1178,1335);KEYS=['base_a','base_b','clothes','scarf','bag','cap','badge_protection','badge_healing','badge_ranged','badge_chemistry'];COLORS=['#c98a4b','#8fb4f0','#86c98f','#b7a6f4','#d55e00','#a69a84'];order=['bag','base','clothes','scarf','cap','badge'];masks=json.loads((Path(__file__).parent/'masks.json').read_text());refspec=json.loads((a.redraw/'contract.json').read_text());ft=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),28);sf=ImageFont.truetype(str(a.repo/'art/ui/fonts/barlow_condensed_medium.ttf'),22)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def mask(polys):
 im=Image.new('L',(SIZE[0]*4,SIZE[1]*4));d=ImageDraw.Draw(im)
 for poly in polys:d.polygon([(x*4,y*4) for x,y in poly],fill=255)
 return np.array(im.resize(SIZE,Image.Resampling.LANCZOS),dtype=np.float32)/255

def cut(im,m):
 ar=np.array(im);ar[:,:,3]=np.uint8(np.round(ar[:,:,3].astype(float)*m));ar[ar[:,:,3]==0]=0;return Image.fromarray(ar)
def gray(im):
 alpha=im.getchannel('A');g=ImageOps.grayscale(im).convert('RGBA');g.putalpha(alpha);return g

def tint(im,color):
 ar=np.array(im);rgb=np.array(tuple(bytes.fromhex(color[1:])),dtype=float)/255;ar[:,:,:3]=np.uint8(np.round(ar[:,:,:3].astype(float)*rgb));return Image.fromarray(ar)
def accessory(folder,key,rect):
 old=Image.open(a.legacy/folder/(key+'.png')).convert('RGBA');old=old.crop(old.getbbox());x0,y0,x1,y1=rect;scale=min((x1-x0)/old.width,(y1-y0)/old.height);old=old.resize((round(old.width*scale),round(old.height*scale)),Image.Resampling.LANCZOS);im=Image.new('RGBA',SIZE);im.alpha_composite(old,(x0+(x1-x0-old.width)//2,y0+(y1-y0-old.height)//2));return im

def compose(images,i):
 base=['base_a','base_b'][i%2];extra=[[],['scarf'],['bag'],['cap'],['scarf','bag'],['scarf','bag','cap']][i];role=['protection','healing','ranged','chemistry'][i%4];im=Image.new('RGBA',SIZE)
 if 'bag' in extra:im.alpha_composite(images['bag'])
 im.alpha_composite(images[base]);im.alpha_composite(tint(images['clothes'],COLORS[i]))
 if 'scarf' in extra:im.alpha_composite(tint(images['scarf'],COLORS[(i+2)%6]))
 if 'cap' in extra:im.alpha_composite(tint(images['cap'],COLORS[i]))
 im.alpha_composite(images['badge_'+role]);return im,{'base':base,'clothes_color':COLORS[i],'scarf_color':COLORS[(i+2)%6],'accessories':extra,'badge':role}

contract={'issue':239,'base_commit':'5bb2928','source_tag':'codex-pr<N>-originals','source_folder':'art/combat/source/recruit_layers_refresh_20261028','dependencies':['codex-pr229-originals','codex-pr211-originals'],'frame_origin':[0,0],'blend':'straight-alpha source-over','order':order,'colors':COLORS,'actors':{}};audit={'files':0,'problems':[],'assets':{}}
for n,pre,label in [('raccoon','rato','Guaxinim'),('armadillo','tatu','Tatu')]:
 source=a.redraw/n/(pre+'-idle.png');orig=Image.open(source).convert('RGBA');cfg=masks[n];cm=mask(cfg['clothes'])*(1-mask(cfg['exclude']));sm=mask(cfg['scarf']);cm*=1-sm
 if n=='raccoon':cm*=1-mask([[[480,848],[537,846],[558,866],[545,914],[527,945],[489,950],[472,933]],[[688,853],[716,854],[735,873],[730,907],[711,953],[674,946],[674,910]]])
 alpha=np.asarray(orig.getchannel('A'),dtype=float)/255;skin=mask(cfg['skin'])*(1-cm)*(1-sm);oldar=np.array(orig);ar=oldar.copy();g=np.array(ImageOps.grayscale(orig));neutral=np.maximum(cm,sm)
 ar[:,:,:3]=np.uint8(np.round(ar[:,:,:3]*(1-neutral[:,:,None])+g[:,:,None]*neutral[:,:,None]));base_a=Image.fromarray(ar);b=ar.copy();rgb=b[:,:,:3].astype(float);lum=np.mean(rgb,axis=2)
 if n=='raccoon':
  weight=np.clip((lum-40)/70,0,1)*np.clip((250-lum)/60,0,1)*skin;target=np.clip(rgb*np.array([1.23,1.035,.78])+np.array([5,1,-2]),0,255)
 else:
  weight=skin;target=np.clip((.38*rgb+.62*lum[:,:,None])*np.array([.91,.97,1.045]),0,255)
 b[:,:,:3]=np.uint8(np.round(rgb*(1-weight[:,:,None])+target*weight[:,:,None]));base_b=Image.fromarray(b)
 images={'base_a':base_a,'base_b':base_b,'clothes':gray(cut(orig,cm)),'scarf':gray(cut(orig,sm)),'bag':accessory(n,'bag',cfg['attach']['bag']),'cap':gray(accessory(n,'cap',cfg['attach']['cap']))}
 for r in ['protection','healing','ranged','chemistry']:images['badge_'+r]=accessory(n,'badge_'+r,cfg['attach']['badge'])
 folder=a.sources/n;folder.mkdir(parents=True,exist_ok=True);assets={}
 for k in KEYS:
  im=images[k];arr=np.array(im);arr[arr[:,:,3]==0]=0;im=Image.fromarray(arr);im.save(folder/(k+'.png'));images[k]=im;proto=a.prototypes/n/(k+'.webp');proto.parent.mkdir(parents=True,exist_ok=True);im.resize((589,668),Image.Resampling.LANCZOS).save(proto,lossless=True,method=6)
  if k in ['clothes','scarf','cap']:assert np.array_equal(arr[:,:,0],arr[:,:,1]) and np.array_equal(arr[:,:,1],arr[:,:,2])
  assert im.mode=='RGBA' and im.size==SIZE
  info={'source_file':n+'/'+k+'.png','source_sha256':sha(folder/(k+'.png')),'prototype_file':n+'/'+k+'.webp','bbox':im.getbbox(),'tintable':k in ['clothes','scarf','cap']};assets[k]=info;audit['assets'][n+'/'+k]=info;audit['files']+=1
 # Exact bases: alpha matches approved drawing, outside skin color changes the two bases are equal.
 assert np.array_equal(np.array(base_a)[:,:,3],oldar[:,:,3]);assert np.array_equal(np.array(base_b)[:,:,3],oldar[:,:,3]);assert not np.any((np.any(np.array(base_a)[:,:,:3]!=np.array(base_b)[:,:,:3],axis=2))&(skin<=0))
 spec=refspec['actors'][n]['assets']['idle'];actor={'id':n+'_recruit_01','class_id':pre,'canvas':list(SIZE),'texture_canvas':[589,668],'anchor':spec['anchor'],'texture_anchor':[v*.5 for v in spec['anchor']],'body_reference_pixels':1240,'height_m':1.44 if n=='raccoon' else 1.56,'old_height_m':1.3 if n=='raccoon' else 1.35,'source_pose':'#225 idle; do not apply to #221 alternate stance','assets':assets,'attachments':cfg['attach'],'combinations':[]}
 sheet=Image.new('RGB',(1800,1120),'#20262a');d=ImageDraw.Draw(sheet);d.text((20,10),label+' / SEIS COMBINAÇÕES / MESMO CORPO E PÉ',font=ft,fill='#e9c47c')
 for i in range(6):
  im,combo=compose(images,i);actor['combinations'].append(combo);proto=a.prototypes/n/f'combination_{i+1}.webp';im.resize((589,668),Image.Resampling.LANCZOS).save(proto,lossless=True);x=(i%3)*600;y=55+(i//3)*530;d.text((x+15,y),f'{i+1} / {combo["base"]} / {combo["badge"]}',font=sf,fill='#efe5d1');scale=.32;thumb=im.resize((round(1178*scale),round(1335*scale)),Image.Resampling.LANCZOS);sheet.paste(thumb,(round(x+300-spec['anchor'][0]*scale),round(y+470-spec['anchor'][1]*scale)),thumb);d.line((x+5,y+470,x+595,y+470),fill='#768188')
 sheet.save(a.out/(n+'_combinations.webp'),quality=92);sheet.resize((720,448),Image.Resampling.LANCZOS).save(a.out/(n+'_40.webp'),quality=90);ImageOps.grayscale(sheet).resize((720,448)).save(a.out/(n+'_gray_40.webp'),quality=90)
 layers=Image.new('RGB',(1800,1110),'#252b30');d=ImageDraw.Draw(layers);d.text((20,5),label+' / CAMADAS SEPARADAS — ORIGEM COMUM (0,0)',font=ft,fill='#e9c47c')
 for i,k in enumerate(KEYS):
  x=i%5*360;y=60+i//5*520;d.text((x+8,y),k,font=sf,fill='#efe5d1');im=images[k].resize((330,374),Image.Resampling.LANCZOS);layers.paste(im,(x+15,y+65),im);d.line((x+8,y+439,x+352,y+439),fill='#66737b')
 layers.save(a.out/(n+'_layers.webp'),quality=92);contract['actors'][n]=actor
 # QA prototype used by existing scene capture harness (temporary file, not production).
 default,_=compose(images,5);default.resize((589,668),Image.Resampling.LANCZOS).save(a.prototypes/n/'idle.webp',lossless=True)
 actor['preview_idle']={k:spec[k] for k in ['canvas','anchor','body_reference_pixels']};actor['preview_idle']['prototype_file']=n+'/idle.webp'
(a.out/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n');(a.out/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('20 layers, exact body alpha and grayscale checked')
