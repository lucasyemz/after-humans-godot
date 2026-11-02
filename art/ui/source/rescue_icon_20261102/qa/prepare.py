from pathlib import Path
from PIL import Image,ImageOps
import numpy as np
from scipy import ndimage
import hashlib,json
base=Path(__file__).resolve().parents[1]
im=Image.open(base/'qa/raw/node_rescue_r2.png').convert('RGBA');a=np.array(im.getchannel('A'))>180
lab,n=ndimage.label(a);counts=np.bincount(lab.ravel());counts[0]=0;a=lab==counts.argmax()
ys,xs=np.where(a);mask=Image.fromarray((a*255).astype('uint8')).crop((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
fit=ImageOps.contain(mask,(104,104),Image.Resampling.LANCZOS)
alpha=Image.new('L',(128,128));alpha.paste(fit,((128-fit.width)//2,(128-fit.height)//2))
rgb=Image.new('RGBA',(128,128),(255,255,255,255));rgb.putalpha(alpha);ar=np.array(rgb);ar[ar[:,:,3]==0,:3]=0;rgb=Image.fromarray(ar)
rgb.save(base/'node-rescue.png')
rt=rgb.resize((64,64),Image.Resampling.LANCZOS);ar=np.array(rt);ar[ar[:,:,3]==0,:3]=0;rt=Image.fromarray(ar);rt.save(base/'node-rescue.webp',lossless=True,method=6)
old=json.loads((base/'assets.json').read_text()) if (base/'assets.json').exists() else {}
meta={'source_tag':old.get('source_tag'),'id':'node-rescue','source':'node-rescue.png','source_canvas':[128,128],'runtime_file':'node-rescue.webp','runtime_canvas':[64,64],'runtime_destination':'art/ui/kit/station/icons/node-rescue.webp','kind':'glyph_white_tintable','anchor':[64,64],'runtime_anchor':[32,32],'nine_slice_ltrb':None,'source_sha256':hashlib.sha256((base/'node-rescue.png').read_bytes()).hexdigest(),'runtime_sha256':hashlib.sha256((base/'node-rescue.webp').read_bytes()).hexdigest(),'use_sizes_px':[22,25.76,30,32],'policy':'One tintable glyph, existing kit colors/states; hidden route nodes retain ?; no new frame or glow.'}
meta['source_alpha_bbox_xyxy']=list(rgb.getchannel('A').getbbox())
meta['runtime_alpha_bbox_xyxy']=list(rt.getchannel('A').getbbox())
meta['runtime_core_bbox_xyxy']=list(rt.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox())
(base/'assets.json').write_text(json.dumps(meta,indent=2)+'\n')
print('Prepared one 128 PNG and 64 WebP tintable glyph.')
