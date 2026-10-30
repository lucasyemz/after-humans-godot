"""Verifica as quatro poses propostas sem exigir integração em dados de produção."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
c=json.loads((HERE/'contract.json').read_text());m=json.loads((ROOT/'data/presentation/combat_art.json').read_text())
assert len(c['poses'])==4
for p in c['poses']:
 idle=m['recruits'][p['recruit_id']]['idle'];official=p['show_art'];path=ROOT/p['file'];im=Image.open(path);ref=Image.open(ROOT/idle['file'].removeprefix('res://'))
 assert im.mode=='RGBA' and im.size==ref.size
 assert all(official[k]==idle[k] for k in ['canvas','anchor','body_reference_pixels'])
 assert official['file']=='res://'+p['file'] and hashlib.sha256(path.read_bytes()).hexdigest()==p['sha256']
 a=im.getchannel('A').point(lambda v:255 if v>24 else 0);b=a.getbbox();assert abs(b[3]-p['texture_anchor'][1])<=1
 ar=np.array(im).astype(int);r,g,b,alpha=[ar[:,:,i] for i in range(4)];assert not ((r>g+65)&(b>g+65)&(r>120)&(b>120)&(alpha>24)).any()
print('PASS: quatro propostas RGBA, canvas/âncoras/escala iguais aos idles, contato no chão, hashes e alfa limpo.')
