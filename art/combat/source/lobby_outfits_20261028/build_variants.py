from pathlib import Path
from PIL import Image,ImageOps
import json,hashlib
repo=Path('/workspace/after-humans-godot');src=Path(__file__).parent;out=repo/'docs/design/lobby_outfits';contract=json.loads((out/'assets.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
orders={'dog_cat':['dog_male','dog_female','cat_male','cat_female'],'frog_owl':['frog_male','frog_female','owl_male','owl_female'],'raccoon_armadillo':['raccoon_male','raccoon_female','armadillo_male','armadillo_female']}
for pair,order in orders.items():
 key=pair+'_variants';p=src/(key+'_concept.png');im=Image.open(p).convert('RGB');im.save(out/(key+'.webp'),quality=90,method=6)
 small=im.resize((round(im.width*.4),round(im.height*.4)),Image.Resampling.LANCZOS);small.save(out/(key+'_40.webp'),quality=90,method=6);ImageOps.grayscale(small).save(out/(key+'_gray_40.webp'),quality=90,method=6)
 contract['assets'][key]={'source_file':p.name,'source_sha256':sha(p),'canvas':list(im.size),'review_file':key+'.webp','review_sha256':sha(out/(key+'.webp')),'reduced_canvas':list(small.size),'production_sprite':False,'anchor':None,'left_to_right':order,'male_role':'comparison redraw of approved outfit','female_approval':'pending'}
contract.update({'source_tag':'codex-pr244-originals-r3','revision':3,'supersedes_source_tag':'codex-pr244-originals-r2','stage':'initial 10 outfits approved by Lucas; 6 female variants pending visual approval; no production poses'})
for key in ['founders','recruits','raccoon_armadillo']:contract['assets'][key]['lucas_approval']='approved after owl arms correction'
(out/'assets.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'concepts':len(contract['assets']),'webp_files':len(list(out.glob('*.webp'))),'webp_bytes':sum(p.stat().st_size for p in out.glob('*.webp'))}))
