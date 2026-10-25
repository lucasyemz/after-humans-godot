"""Propostas #86 sobre capturas reais; somente as famílias do kit #59."""
import sys,json,hashlib,importlib.util
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;ASSET=ROOT/'art/ui/map/network'
sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as kit
spec=importlib.util.spec_from_file_location('hud_v2',ROOT/'docs/design/hud-v2/render.py');hud=importlib.util.module_from_spec(spec);spec.loader.exec_module(hud)
CONTRACT=json.loads((OUT/'contract.json').read_text());RADAR=json.loads((OUT/'radar_snapshot.json').read_text());ENEMIES={r['Name']:r for r in json.loads((ROOT/'data/enemies.json').read_text())}
MAP_ORIGIN=(68,248)
def tint(im,color):
 out=Image.new('RGBA',im.size,color);out.putalpha(im.getchannel('A'));return out
def paste(c,path,x,y,color=None,size=None):
 im=Image.open(ROOT/path).convert('RGBA')
 if size:im=im.resize(size,Image.Resampling.LANCZOS)
 if color:im=tint(im,c.c(color))
 c.im.paste(im,(round(x),round(y)),im)
def marker(c,kind,reading,x,y,enemy=None,size=None):
 sz=size or (64 if kind=='boss' else 40);path=f'art/ui/map/network/marker_{kind}_{reading}.webp';paste(c,path,x-sz/2,y-sz/2,size=(sz,sz))
 if enemy and reading=='known':
  key=ENEMIES.get(enemy,{}).get('SpriteKey',enemy)
  if key in CONTRACT['portraits']:
   face=48 if kind=='boss' else 28;paste(c,CONTRACT['portraits'][key],x-face/2,y-face/2,size=(face,face))
def city(c,state='overview'):
 c.box(48,160,1160,800);c.text(72,184,'Lugares','body');c.text(784,192,'Rede antiga / VIGIA','detail','muted')
 im=Image.open(ASSET/'network_map.webp').convert('RGB');c.im.paste(im,MAP_ORIGIN);shade=Image.new('RGBA',im.size,(0,0,0,62));c.im.paste(shade,MAP_ORIGIN,shade)
 chosen={'selected':'bridge','locked':'lab','late':'depot'}.get(state)
 if chosen:
  for mode in ['remaining','traversed']:
   img=Image.open(ROOT/CONTRACT['routes'][chosen][mode]).convert('RGBA')
   if mode=='traversed':
    alpha=img.getchannel('A');ImageDraw.Draw(alpha).rectangle((420,0,1120,630),fill=0);img.putalpha(alpha)
   img=tint(img,c.c('text' if mode=='traversed' else 'muted'));c.im.paste(img,MAP_ORIGIN,img)
 for idx,r in enumerate(CONTRACT['regions']):
  key=r['key'];phase=r['phase_id'];status='completed' if key=='refuge' else 'locked'
  if state in ['overview','locked'] and idx==1:status='available'
  if state=='selected' and idx==1:status='completed'
  if state=='late' and 1<=idx<=4:status='completed'
  if key==chosen and state!='locked':status='selected'
  payload=r['states'][status];x,y=payload['origin'];paste(c,payload['file'],MAP_ORIGIN[0]+x,MAP_ORIGIN[1]+y,{'available':'blue','selected':'copper','completed':'good','locked':'muted'}[status])
  ax,ay=r['anchor'];px,py=MAP_ORIGIN[0]+ax,MAP_ORIGIN[1]+ay
  if key=='refuge':
   c.box(px-24,py-24,48,48);c.icon(px-16,py-16,'node-start',32);label='Estação Raiz'
  else:
   known=state=='late' or (state=='selected' and key in ['shop','bridge']);reading='known' if known else ('partial' if state=='selected' and key=='shelter' else 'unknown')
   samples=RADAR['phases'][phase];boss=samples['guardians'][0]['enemy_id'];counts=samples['patrol_enemy_counts'];common=sorted(counts,key=lambda k:(-counts[k],k))[0]
   marker(c,'boss',reading,px,py-40,boss)
   visited=(state=='selected' and key=='shop') or (state=='late' and idx<=4)
   for j,kind in enumerate(['enemies','supplies','story']):
    read=reading
    if kind=='supplies':read='known' if visited or state=='late' else 'partial' if known else 'unknown'
    if kind=='story':read=('known' if phase in ['fase_2','fase_3','fase_5'] else 'none') if visited or state=='late' else 'unknown'
    marker(c,kind,read,px-48+j*48,py+20,common if kind=='enemies' else None)
   label='Fase '+phase[-1]
  c.box(px-104,py+48,208,48);c.text(px-88,py+64,label,'detail')
  if status=='locked':paste(c,'art/ui/map/network/lock_32.webp',px+64,py+56)
  if status=='completed' and key!='refuge':c.icon(px+64,py+56,'marker-visited',32,'good')
  if status=='selected':c.diamond(px+84,py+72)
  if key==chosen:c.focus(px-104,py+48,208,48)
 # Legenda dos padrões: estado de leitura é independente de progresso da fase.
 c.icon(72,904,'intent-unknown',24);c.text(112,908,'Não lido','detail','muted');c.text(328,908,'Parcial: sinal com ruído','detail','muted');c.text(744,908,'Rota sólida / tracejada','detail','muted')
 return chosen

def draw(c,state):
 c.header('Mapa da Rede');chosen=city(c,state)
 if not chosen:
  x,y,w=c.panel('Escolha um lugar');c.text(x,y,'A cidade vista do terminal da Estação.','body',width=w);c.text(x,y+128,'Escolha o lugar no mapa ou pela lista.','body',width=w);c.text(x,y+288,'O sinal ainda não foi lido.','body',width=w);c.text(x,y+384,'Recuperar a Estação melhora a leitura.','detail','muted',w)
 else:
  r=next(r for r in CONTRACT['regions'] if r['key']==chosen);phase=r['phase_id'];title={'bridge':'Ponte das Raízes','lab':'Laboratório Silencioso','depot':'Túneis do Eco'}[chosen];x,y,w=c.panel(title);level={'bridge':3,'lab':7,'depot':9}[chosen];c.text(x,y,f'Fase {phase[-1]} · Nível recomendado {level}','detail','muted',w)
  c.text(x,y+64,'Mapa da Rede: '+('não lido' if state=='locked' else 'leitura ampliada' if state=='late' else 'leitura parcial'),'body',width=w)
  sample=RADAR['phases'][phase];boss=sample['guardians'][0]['enemy_id'];counts=sample['patrol_enemy_counts'];common=sorted(counts,key=lambda k:(-counts[k],k))[0]
  values=[('Chefe',ENEMIES[boss]['DisplayName']),('Inimigos',ENEMIES[common]['DisplayName']),('Suprimentos','Há pontos de busca' if state=='late' else 'Sinal parcial'),('História','Há sinal de história' if state=='late' else 'Não lido'),('Clima',{'night':'Noite','nightRain':'Noite com chuva','sunset':'Fim de tarde'}.get(sample['weather'],'Sinal parcial') if state=='late' else 'Não lido')]
  for i,(label,value) in enumerate(values):
   yy=y+176+i*72;c.icon(x,yy,{'Chefe':'node-boss','Inimigos':'node-combat','Suprimentos':'lobby-food','História':'node-event','Clima':'intent-unknown'}[label],32);c.text(x+48,yy,label,'detail','muted');c.text(x+48,yy+32,'Não lido' if state=='locked' else value,'detail',width=w-48)
  if state=='locked':c.text(x,808,'Conclua a fase anterior.','detail','muted',w)
  if state=='locked':c.button(x,864,w,'Indisponível',focus=True,disabled=True)
  else:c.box(x,864,w,c.h,'button_primary');c.text(x+24,886,'Preparar expedição');c.focus(x,864,w,c.h)
 c.footer('Setas · Lugar    E · Escolher','Esc · Estação')

def main():
 (OUT/'before').mkdir(exist_ok=True);records=[]
 for large,profile in [(False,'normal'),(True,'large')]:
  src=Path('/workspace/scratch/round86_96')/profile/'station-map.png';clean=src.parent/'station-map_clean.png'
  Image.open(src).convert('RGB').save(OUT/'before'/f'map_{profile}.jpg',quality=78,optimize=True);Image.open(clean).convert('RGB').save(OUT/'before'/f'map_{profile}_clean.webp',quality=84,method=6)
  records.append({'profile':profile,'commit':'f9fe25a','source_png_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'clean_png_sha256':hashlib.sha256(clean.read_bytes()).hexdigest()})
 for state in ['overview','selected','locked','late']:
  for large,cb,suffix in [(False,False,''),(True,False,'_large'),(False,True,'_colorblind'),(True,True,'_large_colorblind')]:
   c=hud.Board(OUT/'before'/f'map_{"large" if large else "normal"}_clean.webp',large,cb);kit.CHECKS.clear();draw(c,state);c.im.save(OUT/f'{state}{suffix}.webp',quality=85,method=6)
   assert not [r for r in kit.CHECKS if r['right']>1920 or r['bottom']>1080]
   if cb and large:ImageOps.grayscale(c.im).save(OUT/f'{state}_gray.webp',quality=82,method=6)
   if not cb and not large:c.im.resize((768,432),Image.Resampling.LANCZOS).save(OUT/f'{state}_40.webp',quality=85,method=6)
 (OUT/'captures.json').write_text(json.dumps(records,indent=2)+'\n')
 print('16 propostas WebP e evidências 40%/cinza')
if __name__=='__main__':main()
