import argparse,hashlib,json
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);a=p.parse_args();base=Path(__file__).resolve().parent
if base.resolve()==a.out.resolve() or base.resolve() in a.out.resolve().parents:raise SystemExit('Stage outside the source archive.')
if a.out.exists():raise SystemExit('Use a new output directory.')
if any((x/'project.godot').exists() for x in [a.out,*a.out.parents]):raise SystemExit('Stage outside the game project.')
m=json.loads((base/'assets.json').read_text());src=base/m['source'];assert hashlib.sha256(src.read_bytes()).hexdigest()==m['source_sha256']
im=Image.open(src);assert list(im.size)==m['source_canvas'];im=im.resize(tuple(m['runtime_canvas']),Image.Resampling.LANCZOS)
zero=im.getchannel('A').point(lambda x:255 if x==0 else 0);im.paste((0,0,0,0),mask=zero)
a.out.mkdir(parents=True);dst=a.out/m['runtime_file'];im.save(dst,lossless=True,method=6)
assert hashlib.sha256(dst.read_bytes()).hexdigest()==m['runtime_sha256'];print('1 runtime WebP reproduced.')
