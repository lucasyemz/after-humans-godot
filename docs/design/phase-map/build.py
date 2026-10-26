"""Arte #86. Origem pesada fica fora do Git; camadas são máscaras para tint do AHUiStyle."""
import sys
sys.dont_write_bytecode=True
from pathlib import Path
import json,hashlib,math,argparse
from PIL import Image,ImageDraw,ImageOps,ImageFilter
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'art/ui/map/network';DOC=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as kit
SIZE=(1120,630)
REGIONS=[
 ('refuge',None,'Estação Raiz',[200,405],[(20,300),(110,284),(255,317),(369,377),(350,469),(208,531),(15,450)]),
 ('shop','fase_1','Rua das Vitrines',[325,215],[(145,150),(290,100),(470,180),(500,245),(385,315),(155,242)]),
 ('bridge','fase_2','Ponte das Raízes e Cais do Rio',[615,430],[(365,308),(455,320),(725,449),(785,504),(730,589),(608,567),(529,506),(367,420)]),
 ('shelter','fase_3','Sala Esquecida / Abrigo Lacrado',[620,145],[(493,95),(600,69),(738,119),(748,173),(660,234),(526,196)]),
 ('lab','fase_4','Laboratório Silencioso / Portão de Triagem',[960,385],[(791,280),(870,251),(1107,330),(1100,452),(973,525),(794,430)]),
 ('depot','fase_5','Túneis do Eco e Depósito Inundado',[990,145],[(791,79),(940,46),(1113,106),(1118,213),(993,263),(817,198)]),
]
STATES=['available','selected','completed','locked']
def save(im,path):
 path.parent.mkdir(exist_ok=True,parents=True);im.save(path,lossless=True,method=6)
def lock():
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);d.arc((8,3,24,23),180,360,fill='white',width=3);d.rounded_rectangle((5,14,27,30),3,outline='white',width=3);d.ellipse((14,19,18,23),fill='white');d.line((16,22,16,26),fill='white',width=2);return im

def main():
 ap=argparse.ArgumentParser();ap.add_argument('original',type=Path);a=ap.parse_args();OUT.mkdir(exist_ok=True,parents=True)
 base=ImageOps.fit(Image.open(a.original).convert('RGB'),SIZE,Image.Resampling.LANCZOS);base.save(OUT/'network_map.webp',quality=86,method=6)
 lum=np.asarray(ImageOps.grayscale(base),dtype=np.float32);edges=np.asarray(ImageOps.grayscale(base).filter(ImageFilter.FIND_EDGES),dtype=np.float32);yy,xx=np.indices((630,1120));rng=np.random.default_rng(86);noise=rng.uniform(.72,1,(630,1120));records=[]
 for key,phase,name,anchor,poly in REGIONS:
  m=Image.new('L',SIZE);ImageDraw.Draw(m).polygon(poly,fill=255);mask=np.asarray(m)/255
  pmap={}
  for state in STATES:
   strength={'available':1,'selected':1.35,'completed':.86,'locked':.35}[state]
   raw=(50+edges*.9+lum*.25)*(np.where(yy%6<2,.3,1))*noise*mask*strength
   if state=='locked':raw*=np.where((xx+yy)%18<4,.5,1)
   alpha=Image.fromarray(np.uint8(np.clip(raw,0,168)));d=ImageDraw.Draw(alpha)
   # Contorno quebrado e irregular, projeção velha; não substituir por um polígono futurista sólido.
   for i,p in enumerate(poly):
    q=poly[(i+1)%len(poly)];length=math.dist(p,q)
    for n in range(0,int(length),14):
     t=n/length;u=min(1,(n+9)/length);d.line((p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t,p[0]+(q[0]-p[0])*u,p[1]+(q[1]-p[1])*u),fill=210 if state!='locked' else 72,width=3 if state=='selected' else 2)
   im=Image.new('RGBA',SIZE,'white');im.putalpha(alpha)
   if state=='completed':
    check=kit.glyph('marker-visited',32,'#ffffff');im.alpha_composite(check,(anchor[0]-16,anchor[1]-16))
   if state=='locked':im.alpha_composite(lock(),(anchor[0]-16,anchor[1]-16))
   box=im.getbbox();file=f'{key}_{state}.webp';save(im.crop(box),OUT/file);pmap[state]={'file':str((OUT/file).relative_to(ROOT)),'origin':[box[0],box[1]],'size':[box[2]-box[0],box[3]-box[1]]}
  records.append({'key':key,'phase_id':phase,'name':name,'anchor':anchor,'hit_polygon':poly,'states':pmap})
 save(lock(),OUT/'lock_32.webp')
 # Rotas da Estação aos cinco lugares: mesmo caminho, padrões diferentes.
 paths={'shop':[(200,405),(230,350),(325,285),(325,215)],'bridge':[(200,405),(310,440),(440,494),(530,470),(615,430)],'shelter':[(200,405),(230,350),(325,285),(500,240),(620,145)],'lab':[(200,405),(310,440),(440,494),(615,430),(800,490),(960,385)],'depot':[(200,405),(230,350),(325,285),(500,240),(620,145),(820,180),(990,145)]}
 routes={}
 for key,points in paths.items():
  routes[key]={}
  for done in [False,True]:
   im=Image.new('RGBA',SIZE);d=ImageDraw.Draw(im)
   for p,q in zip(points,points[1:]):
    length=math.dist(p,q)
    for n in range(0,int(length),18):
     t=n/length;u=min(1,(n+(18 if done else 8))/length);d.line((p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t,p[0]+(q[0]-p[0])*u,p[1]+(q[1]-p[1])*u),fill=(255,255,255,205 if done else 145),width=4 if done else 3)
   file=f'route_{key}_{"traversed" if done else "remaining"}.webp';save(im,OUT/file);routes[key]['traversed' if done else 'remaining']=str((OUT/file).relative_to(ROOT))
 portraits={};art=json.loads((ROOT/'data/presentation/combat_art.json').read_text())['enemies']
 for key,row in art.items():
  payload=row['idle'];src=Image.open(ROOT/payload['file'].removeprefix('res://')).convert('RGBA')
  if payload.get('frames'):
   x,y,w,h=payload['frames'][0];src=src.crop((x,y,x+w,y+h))
  l,t,r,b=src.getbbox();overrides={'porteiro':(215,170,460,415),'carcaca_colonizada':(265,285,505,525),'vigia_enferrujado':(230,95,375,240),'faisca':(215,295,465,545),'rastejante_raiz':(340,315,535,510),'robot':(80,0,180,100)};region=overrides.get(key,(l,t,r,round(t+(b-t)*.48)));face=src.crop(region);face=ImageOps.fit(face,(48,48),Image.Resampling.LANCZOS)
  circle=Image.new('L',(48,48));ImageDraw.Draw(circle).ellipse((0,0,47,47),fill=255);face.putalpha(Image.fromarray(np.minimum(np.asarray(face.getchannel('A')),np.asarray(circle))));save(face,OUT/f'portrait_{key}.webp');portraits[key]=f'art/ui/map/network/portrait_{key}.webp'
 for kind in ['boss','enemies','supplies','story']:
  size=64 if kind=='boss' else 48
  for reading in ['known','unknown','partial']:
   im=Image.new('RGBA',(size,size));d=ImageDraw.Draw(im);d.ellipse((2,2,size-3,size-3),fill=(13,16,18,245),outline='white',width=2)
   if kind=='boss':d.arc((6,6,size-7,size-7),0,360,fill='white',width=2)
   if reading!='known':icon='intent-unknown'
   else:icon={'boss':'node-boss','enemies':'node-combat','supplies':'lobby-food','story':'node-event'}[kind]
   glyph=kit.glyph(icon,32,'#ffffff')
   if not (reading=='known' and kind in ['boss','enemies']):im.alpha_composite(glyph,((size-32)//2,(size-32)//2))
   if reading=='partial':
    for j in range(3):d.line((size-17+j*4,size-12-j*3,size-17+j*4,size-6),fill='white',width=2)
    # Ruído e segmentos de sinal, sem revelar o rosto.
    d.line((8,size//2,size-8,size//2),fill=(13,16,18,255),width=2)
   save(im,OUT/f'marker_{kind}_{reading}.webp')
 im=Image.new('RGBA',(48,48));d=ImageDraw.Draw(im);d.ellipse((2,2,45,45),fill=(13,16,18,245),outline='white',width=2);d.line((14,24,34,24),fill='white',width=3);save(im,OUT/'marker_story_none.webp')
 contract={'issue':86,'canvas':list(SIZE),'background':'art/ui/map/network/network_map.webp','source_sha256':hashlib.sha256(a.original.read_bytes()).hexdigest(),'source_outside_git':str(a.original),'coordinates':'top-left; original texture pixels; no half-resolution conversion','layer_tint':{'available':'blue; neutral text in colorblind','selected':'copper','completed':'good','locked':'muted'},'layers_are_monochrome':True,'regions':records,'routes':routes,'portraits':portraits,'marker_sizes':{'boss':64,'enemies':48,'supplies':48,'story':48},'reading_states':['unknown','partial','known','none'],'seeded_example':{'seed':4242,'guardian_by_phase':{'fase_1':'robot','fase_2':'carcaca_colonizada','fase_3':'vigia_enferrujado','fase_4':'robot_fungo','fase_5':'porteiro'}},'integration':'Claude #87 uses the guardian of the fixed route; examples are not permanent boss assignments'}
 (DOC/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
 print('Exported',len(list(OUT.glob('*.webp'))),'WebP')
if __name__=='__main__':main()
