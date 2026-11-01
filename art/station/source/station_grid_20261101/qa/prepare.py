"""Normalize original generation canvases for #275; all outputs stay outside main."""
from pathlib import Path
import json,hashlib,argparse
from PIL import Image,ImageOps
import numpy as np
from scipy import ndimage as ndi
BASE=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);args=ap.parse_args()
RAW=BASE/'qa/raw';OUT=args.out.resolve();OUT.mkdir(parents=True,exist_ok=True)
for folder in ['illustrations','frames','icons']:(BASE/folder).mkdir(exist_ok=True);(OUT/folder).mkdir(exist_ok=True)
previous_meta=json.loads((BASE/'assets.json').read_text()) if (BASE/'assets.json').exists() else {}
previous_tag=previous_meta.get('source_tag')
meta={'source_tag':previous_tag,'source_folder':'art/station/source/station_grid_20261101','world_cell_m':[6,3.2],'source_scale_to_runtime':0.5,'assets':{}}
def record(key,im,folder,notes,extra=None):
 path=BASE/folder/(key+'.png');im.save(path)
 runtime=im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS)
 if im.mode=='RGBA':
  ar=np.array(runtime);ar[ar[:,:,3]==0,:3]=0;runtime=Image.fromarray(ar)
 runtime.save(OUT/folder/(key+'.webp'),lossless=True,method=6)
 d={'source':str(path.relative_to(BASE)),'prototype':folder+'/'+key+'.webp','source_canvas':list(im.size),'runtime_canvas':list(runtime.size),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'anchor':[0,0],'notes':notes}
 d['suggested_runtime_path']=('art/station/cards/buried/'+key+'.webp') if folder=='illustrations' else ('art/ui/kit/station/excavation/'+folder+'/'+key+'.webp')
 if extra:d.update(extra)
 meta['assets'][key]=d
for field in ['revision','render_policy']:
 if field in previous_meta:meta[field]=previous_meta[field]
for key in ['platform_rubble','overturned_wagon','maintenance_machine','exposed_cables','flooded_duct','root_chamber']:
 raw=RAW/(key+'.png')
 if key=='overturned_wagon' and (RAW/'overturned_wagon_r2.png').exists():raw=RAW/'overturned_wagon_r2.png'
 if (RAW/(key+'_muted_r2.png')).exists():raw=RAW/(key+'_muted_r2.png')
 im=Image.open(raw).convert('RGB')
 normalized=ImageOps.fit(im,(1200,640),Image.Resampling.LANCZOS,centering=(.5,.5))
 record(key,normalized,'illustrations','Muted background grade; restrained highlights, desaturated warm tones and painted charcoal veil baked in; no additional runtime veil; no text/UI; opaque; uniform crop to 6:3.2.' if '_muted_r2' in raw.stem else 'Own inspection-lit station vignette; no text/UI; opaque; crop uniformly to 6:3.2 aspect.',{'raw_source':'qa/raw/'+raw.name,'safe_focus_xywh':[120,150,960,340],'nine_slice_ltrb':None})
def clean_alpha(im):
 a=np.array(im.convert('RGBA'));alpha=a[:,:,3].copy();alpha[alpha<16]=0;alpha[alpha>=245]=255
 labels,n=ndi.label(alpha>0)
 areas=np.bincount(labels.ravel());small=np.where((areas<=3)&(np.arange(len(areas))>0))[0]
 if len(small):alpha[np.isin(labels,small)]=0
 solid=alpha>=220
 if solid.any():
  idx=ndi.distance_transform_edt(~solid,return_distances=False,return_indices=True)
  edge=(alpha>0)&(alpha<220);a[edge,:3]=a[idx[0][edge],idx[1][edge],:3]
 a[:,:,3]=alpha;a[alpha==0,:3]=0
 return Image.fromarray(a)
def nine_resize(im,size,src_margin=72,dst_margin=96):
 out=Image.new('RGBA',size)
 x=[0,src_margin,im.width-src_margin,im.width];y=[0,src_margin,im.height-src_margin,im.height]
 xx=[0,dst_margin,size[0]-dst_margin,size[0]];yy=[0,dst_margin,size[1]-dst_margin,size[1]]
 for row in range(3):
  for col in range(3):
   region=im.crop((x[col],y[row],x[col+1],y[row+1])).resize((xx[col+1]-xx[col],yy[row+1]-yy[row]),Image.Resampling.LANCZOS)
   out.paste(region,(xx[col],yy[row]))
 return clean_alpha(out)
sheet=Image.open(RAW/'frames_sheet.png').convert('RGBA')
keys=['frame_locked','frame_available','frame_neighbor','room_choice_card']
for j,key in enumerate(keys):
 x0=(j%2)*(sheet.width//2);y0=(j//2)*(sheet.height//2)
 crop=sheet.crop((x0,y0,x0+sheet.width//2,y0+sheet.height//2));arr=np.array(crop);mask=arr[:,:,3]>128
 lab,n=ndi.label(mask);areas=np.bincount(lab.ravel());areas[0]=0;largest=areas.argmax();ys,xs=np.where(lab==largest)
 bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));crop=crop.crop(bbox)
 im=nine_resize(clean_alpha(crop),(1200,640))
 extra={'raw_source':'qa/raw/frames_sheet.png','raw_crop_xyxy':[bbox[0]+x0,bbox[1]+y0,bbox[2]+x0,bbox[3]+y0],'source_nine_slice_ltrb':[96,96,96,96],'nine_slice_ltrb':[48,48,48,48],'content_xywh':[24,24,552,272],'transparent_center':True}
 if key=='room_choice_card':extra.update({'nine_slice_ltrb':None,'source_nine_slice_ltrb':None,'resize_policy':'fixed-aspect template; preserve aspect ratio; use existing kit plaque as an independent overlay if a variable-width header is needed'})
 record(key,im,'frames','Native painted border normalized by 9-slice; empty alpha center; text and badges remain runtime elements.',extra)
raw=RAW/('icons_sheet_r2.png' if (RAW/'icons_sheet_r2.png').exists() else 'icons_sheet.png')
sheet=Image.open(raw).convert('RGBA')
for j,key in enumerate(['buried','excavate','work_in_progress','choose_room']):
 x0=(j%2)*(sheet.width//2);y0=(j//2)*(sheet.height//2)
 crop=sheet.crop((x0,y0,x0+sheet.width//2,y0+sheet.height//2));ar=np.array(crop);mask=ar[:,:,3]>128;ys,xs=np.where(mask)
 bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));crop=crop.crop(bbox)
 a=np.array(crop);a[:,:,3]=np.where(a[:,:,3]>180,255,0).astype('uint8');a[a[:,:,3]>0,:3]=255;a[a[:,:,3]==0,:3]=0;crop=Image.fromarray(a)
 tile=Image.new('RGBA',(192,192));fit=ImageOps.contain(crop,(160,160),Image.Resampling.LANCZOS);tile.paste(fit,((192-fit.width)//2,(192-fit.height)//2))
 record(key,clean_alpha(tile),'icons','White tintable mask, centered in a 192 source / 96 runtime canvas; test at 22/32 px.',{'raw_source':'qa/raw/'+raw.name,'raw_crop_xyxy':[bbox[0]+x0,bbox[1]+y0,bbox[2]+x0,bbox[3]+y0],'nine_slice_ltrb':None,'tintable':True,'anchor':[96,96],'runtime_anchor':[48,48],'layout_anchor_top_left':[0,0]})
(BASE/'assets.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');(OUT/'assets.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'assets':len(meta['assets']),'source':str(BASE),'prototypes':str(OUT)}))
