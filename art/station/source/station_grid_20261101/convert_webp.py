"""Convert the approved #275 PNGs with Pillow only; never modifies the game repository."""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);args=p.parse_args()
base=Path(__file__).resolve().parent;out=args.out.resolve()
if any((folder/'project.godot').is_file() for folder in [out,*out.parents]):raise SystemExit('Stage outside the Godot project; integration is a separate step.')
if out.exists():raise SystemExit('Use a new empty output path; existing folders are not overwritten.')
if base.resolve()==out or base.resolve() in out.parents:raise SystemExit('Output must stay outside the source archive.')
spec=json.loads((base/'assets.json').read_text())
# Validate the entire bundle before creating output.
for key,a in spec['assets'].items():
 src=(base/a['source']).resolve()
 if base.resolve() not in src.parents:raise SystemExit('Unsafe source path.')
 if hashlib.sha256(src.read_bytes()).hexdigest()!=a['source_sha256']:raise SystemExit('Source checksum differs: '+key)
 with Image.open(src) as im:
  if list(im.size)!=a['source_canvas']:raise SystemExit('Canvas differs: '+key)
out.mkdir(parents=True)
for key,a in spec['assets'].items():
 with Image.open(base/a['source']) as image:
  im=image.copy().resize(tuple(a['runtime_canvas']),Image.Resampling.LANCZOS)
 if im.mode=='RGBA':
  zero=im.getchannel('A').point(lambda x:255 if x==0 else 0)
  im.paste((0,0,0,0),mask=zero)
 dst=out/a['prototype'];dst.parent.mkdir(exist_ok=True,parents=True);im.save(dst,lossless=True,method=6)
(out/'assets.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
print(f'{len(spec["assets"])} WebP prepared in {out}; no production files changed.')
