from pathlib import Path
import argparse,json,hashlib,re
import numpy as np
from PIL import Image
from scipy import ndimage
ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True,type=Path);ap.add_argument('--captures',required=True,type=Path);a=ap.parse_args();base=Path(__file__).resolve().parents[1];review=a.repo/'docs/design/rescue_icon'
spec=json.loads((base/'assets.json').read_text());r=json.loads((a.captures/'capture.json').read_text());assert len(r['records'])==6
for f,size in [('node-rescue.png',(128,128)),('node-rescue.webp',(64,64))]:
 im=Image.open(base/f).convert('RGBA');ar=np.array(im);assert im.size==size;assert np.all(ar[ar[:,:,3]>0,:3]==255);assert np.all(ar[ar[:,:,3]==0,:3]==0)
 mask=ar[:,:,3]>=128;lab,n=ndimage.label(mask);assert n==1,(f,n)
assert hashlib.sha256((base/spec['source']).read_bytes()).hexdigest()==spec['source_sha256']
assert hashlib.sha256((base/spec['runtime_file']).read_bytes()).hexdigest()==spec['runtime_sha256']
cases=[]
for x in r['records']:
 key=x['view'];variant=x['variant'];before=np.array(Image.open(a.captures/f'{key}_before_{variant}.png').convert('RGB'));after=np.array(Image.open(a.captures/f'{key}_after_{variant}.png').convert('RGB'));assert before.shape==after.shape==(1080,1920,3)
 v=[float(n) for n in re.findall(r'-?\d+(?:\.\d+)?',x['rect'].split('(')[1])];left,top,w,h=v
 outside=np.any(before!=after,axis=2);total=int(outside.sum());outside[max(0,int(top)-3):int(top+h)+4,max(0,int(left)-3):int(left+w)+4]=False
 extra=int(outside.sum());assert total>0;assert extra==0,(key,variant,extra)
 cases.append({'view':key,'variant':variant,'rect':v,'pixels_changed':total,'outside_glyph_changed':extra})
images=[]
for p in sorted(review.glob('*.webp')):
 im=Image.open(p);im.load();images.append({'file':p.name,'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
report={'base':'e2f0b58a','source_tag':spec['source_tag'],'assets':1,'qa_verdict':'APROVADO','qa_rounds':1,'source_pngs':len(list(base.rglob('*.png'))),'white_tintable':True,'single_core_alpha_component':True,'converter_byte_equality':True,'proof_cases':cases,'review_images':images}
(review/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(base/'qa/verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'assets':1,'review_images':len(images),'cases':cases},indent=2))
