"""Normalize newly generated stances, export disposable prototypes and review sheets."""
from pathlib import Path
import argparse,json,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--raw',type=Path,required=True);p.add_argument('--sources',type=Path,required=True);p.add_argument('--redraw-sources',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--prototypes',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);a.prototypes.mkdir(parents=True,exist_ok=True)
m=json.loads((a.repo/'data/presentation/combat_art.json').read_text());base225=json.loads((a.redraw_sources/'contract.json').read_text());font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';ft=ImageFont.truetype(font,22);small=ImageFont.truetype(font,18)
keys=['bento','nick','iris','vespera','raccoon','armadillo','watch'];names=['Bento','Nick','Íris','Véspera','Guaxinim','Tatu','Bento Ronda'];ids=['hero_cao_bento','hero_gato_nick','hero_sapo_iris','hero_coruja_vespera','raccoon_recruit_01','armadillo_recruit_01','hero_cao_bento'];heights=[1.72,1.5,1.38,1.66,1.44,1.56,1.72];target_heights=[1375,1200,1180,1250,1200,1240,1375]
contract={'issue':221,'base_commit':'5bb2928','source_tag':'codex-pr<N>-originals','dependency':{'issue':225,'source_tag':'codex-pr229-originals','note':'Recruits use approved redraw, not old production proportions.'},'actors':{}}
rows=[]
for i,k in enumerate(keys):
 if k in ['raccoon','armadillo']:
  old=base225['actors'][k]['assets']['idle'].copy();old['file']=str(a.redraw_sources/old['source_file']);old['source_tag']='codex-pr229-originals';art=Image.open(old['file']).convert('RGBA');old['file']='tag://codex-pr229-originals/art/combat/source/recruits_redraw_20261028/'+old['source_file']
 else:
  old=m['heroes'][ids[i]]['idle'].copy();old['file']='res://art/skins/bento/watch/idle.webp' if k=='watch' else old['file'];art=Image.open(a.repo/old['file'].removeprefix('res://')).convert('RGBA');art=art.resize(tuple(old['canvas']),Image.Resampling.LANCZOS)
 raw=Image.open(a.raw/(k+'.png')).convert('RGBA');alpha=np.array(raw.getchannel('A'));mask=alpha>12;ys,xs=np.where(mask);box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));crop=raw.crop(box);h=target_heights[i];w=round(crop.width*h/crop.height);crop=crop.resize((w,h),Image.Resampling.LANCZOS)
 canvas=old['canvas'];anchor=old['anchor']
 def support(im):
  ar=np.array(im.getchannel('A'));yy,xx=np.where(ar>32);bottom=yy.max();xx=np.where((ar>32)&(np.indices(ar.shape)[0]>=bottom-round(im.height*.08)))[1];return float((np.percentile(xx,3)+np.percentile(xx,97))/2)
 old_support=support(art);new_support=support(crop);px=round(old_support-new_support);py=round(anchor[1]-h);assert px>=0 and py>=0 and px+w<=canvas[0] and py+h<=canvas[1],(k,w,h,px,py,canvas)
 new=Image.new('RGBA',canvas);new.alpha_composite(crop,(px,py));arr=np.array(new);arr[arr[:,:,3]<4]=0;new=Image.fromarray(arr)
 mode='idle' if k=='armadillo' else 'combat_idle';folder=a.sources/k;folder.mkdir(parents=True,exist_ok=True);source=folder/(mode+'.png');new.save(source);newmeta={'canvas':canvas,'anchor':anchor,'body_reference_pixels':old['body_reference_pixels'],'body_width_pixels':w,'visible':[px,py,px+w,py+h],'source_file':str(source.relative_to(a.sources)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'generated_bbox':box,'normalization':{'uniform_scale':h/(box[3]-box[1]),'translation':[px,py],'body_height_pixels':h,'old_support_center_x':old_support,'new_support_center_x':new_support,'support_quantiles':[3,97],'support_band':0.08},'mode':mode}
 (folder/'registration.json').write_text(json.dumps(newmeta,indent=2)+'\n')
 states={'exploration':(new,newmeta) if k=='armadillo' else (art,old),'combat':(art,old) if k=='armadillo' else (new,newmeta)}
 entry={'id':ids[i],'name':names[i],'skin_id':'watch' if k=='watch' else None,'height_m':heights[i],'new_pose':mode,'baseline':old,'states':{}}
 for state,(im,meta) in states.items():
  proto=a.prototypes/k/(state+'.webp');proto.parent.mkdir(parents=True,exist_ok=True);im.resize((round(canvas[0]*.5),round(canvas[1]*.5)),Image.Resampling.LANCZOS).save(proto,lossless=True)
  data={x:meta[x] for x in ['canvas','anchor','body_reference_pixels']};data['prototype_file']=str(proto.relative_to(a.prototypes));data['source_file']=meta.get('source_file');data['reused_from']=old['file'] if im is art else None;entry['states'][state]=data
 contract['actors'][k]=entry;rows.append((k,art,states,old,heights[i],names[i]))
# Two actors per page. Same pixels/metre and ground reference within each row.
for page in range(4):
 group=rows[page*2:page*2+2];sheet=Image.new('RGB',(1920,1020 if len(group)==2 else 550),'#20262a');d=ImageDraw.Draw(sheet)
 for j,(k,art,states,old,height,name) in enumerate(group):
  y=j*500;d.text((24,y+10),name,fill='#e9c47c',font=ft)
  for col,(label,(im,meta)) in enumerate([('BASE APROVADA',(art,old)),('EXPLORAÇÃO',states['exploration']),('COMBATE',states['combat'])]):
   x=col*640;d.text((x+20,y+45),label,fill='#efe5d1',font=small);scale=215*height/old['body_reference_pixels'];size=(round(im.width*scale),round(im.height*scale));mini=im.resize(size,Image.Resampling.LANCZOS);ground=y+470;sheet.paste(mini,(round(x+320-old['anchor'][0]*scale),round(ground-old['anchor'][1]*scale)),mini);d.line((x+8,ground,x+630,ground),fill='#6b7478')
  d.text((24,y+480),f"{height:.2f} m | canvas {old['canvas']} | pé {old['anchor']}",fill='#a69a84',font=small)
 path=a.out/f'poses_{page+1}.webp';sheet.save(path,quality=90);sheet.resize((round(sheet.width*.4),round(sheet.height*.4)),Image.Resampling.LANCZOS).save(a.out/f'poses_{page+1}_40.webp',quality=90);ImageOps.grayscale(sheet).resize((round(sheet.width*.4),round(sheet.height*.4))).save(a.out/f'poses_{page+1}_gray_40.webp',quality=90)
(a.out/'contract.json').write_text(json.dumps(contract,indent=2,ensure_ascii=False)+'\n');audit={'new_poses':len(rows),'png_count':len(list(a.sources.glob('*/*.png'))),'problems':[]};(a.out/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');print(json.dumps(audit))
