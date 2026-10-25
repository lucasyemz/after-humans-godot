"""#96: propostas em WebP sobre capturas reais. Valores novos estão em fixtures.json."""
import sys,json,hashlib,importlib.util
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as kit
spec=importlib.util.spec_from_file_location('hud96',ROOT/'docs/design/hud-v2/render.py');hud=importlib.util.module_from_spec(spec);spec.loader.exec_module(hud)
spec=importlib.util.spec_from_file_location('map86',ROOT/'docs/design/phase-map/render.py');mp=importlib.util.module_from_spec(spec);spec.loader.exec_module(mp)
FIX=json.loads((OUT/'fixtures.json').read_text());ROSTER=json.loads((OUT/'snapshot_roster.json').read_text());PERKS={r['Name']:r for r in json.loads((ROOT/'data/perks.json').read_text())};ENEMIES={r['Name']:r for r in json.loads((ROOT/'data/enemies.json').read_text())};CLASSES={r['Name']:r for r in json.loads((ROOT/'data/classes.json').read_text())};RESEARCH=json.loads((ROOT/'data/research.json').read_text())
PAGES={
'briefing':'station-preparation','briefing_next':'station-preparation','debriefing':'station-characters',
'hero_card_combat':'combat','hero_card_preparation':'station-preparation','enemy_card':'combat','boss_card':'combat-boss',
'fight_result':'combat-result','xp_gain':'combat-result','cargo_choose':'combat-boss','cargo_reveal':'combat-boss',
 'training_ready':'station-characters','training_choice':'station-characters','training_locked':'station-characters','training_max':'station-characters','training_done':'station-characters',
'missions_map':'station-map','mission_locked':'station-map','mission_replay':'station-map',
'research_tree':'station-research','research_running':'station-research','research_complete':'station-research','research_locked':'station-research','research_scrolled':'station-research',
'bond_preparation_friend':'station-preparation','bond_preparation_rival':'station-preparation','bond_combat_friend':'combat-bond-friend','bond_combat_rival':'combat-bond-rival'}
SHORT_PERKS={'loyal':'Companheiro fiel: protege aliado vivo, -5 Instinto próprio, 1x/rodada.','machine-fear':'Temor das máquinas: dano recebido delas, +3 Instinto, 1x/rodada.','gloomy':'Pessimista: -5 pontos percentuais de Superação.','brave':'Corajoso: +5 pontos percentuais de Superação.','agile':'Ágil: +1 Velocidade enquanto no grupo.'}
CHECKS=[]
def paste(c,path,x,y,size=None,color=None):
 im=Image.open(ROOT/path).convert('RGBA')
 if size:im=im.resize(size,Image.Resampling.LANCZOS)
 if color:im=mp.tint(im,c.c(color))
 c.im.paste(im,(round(x),round(y)),im)
def stars(c,x,y,n=3):
 for i in range(3):paste(c,f'art/ui/loop/star_{"filled" if i<n else "outline"}.webp',x+i*48,y,color='gold' if i<n else 'muted')
def bar(c,x,y,w,current,maximum=100):
 c.d.rounded_rectangle((x,y,x+w,y+12),4,fill=c.c('edge'));fill=round(w*min(1,current/max(1,maximum)))
 if fill:c.d.rounded_rectangle((x,y,x+fill,y+12),4,fill=c.c('gold' if current>=maximum else 'text'))
def prep(c):
 c.header('Preparação')
 for i,h in enumerate(ROSTER):
  x=48+i*296;y=744;c.box(x,y,272,208);c.portrait(['bento','nick','iris','vespera'][i],x+24,y+24,48);c.text(x+88,y+24,h['display_name'],'body',width=160);c.text(x+24,y+96,f'Posição {i+1}','detail');c.text(x+24,y+144,f"Vida {h['hp']}/{h['max_hp']}",'detail','muted')
 c.footer('Setas · Aliado    Foco · Ficha','Esc · Voltar')
def combat(c):
 units=c.meta['units'];actor=next((u for u in units if u['id']==c.meta.get('actor')),next(u for u in units if u['player']));faces={'Bento':'bento','Nick':'nick','Íris':'iris','Véspera':'vespera'};c.actor=actor['name'];c.actor_file=faces[c.actor]
 # Iniciativa: nomes e ordem da captura, com resolução dos nomes abreviados do HUD.
 ts=[r['text'] for r in c.meta['texts']];idx=next(i for i,t in enumerate(ts) if t.startswith('RODADA'));order=[];remaining=units[:]
 for label in ts[idx+1:idx+1+len(units)]:
  name=label.split(' · agora')[0];u=next((r for r in remaining if name in r['name']),remaining[0]);order.append(u);remaining.remove(u)
 c.box(632,32,656,96);c.text(656,64,'Rodada 1','detail')
 for i,u in enumerate(order):
  xx=824+i*56
  if u['player']:c.portrait(faces[u['name']],xx,52,48)
  else:paste(c,'art/ui/map/network/portrait_'+ENEMIES[u['enemy_id']].get('SpriteKey',u['enemy_id'])+'.webp',xx,52,size=(48,48))
  if u['id']==actor['id']:c.diamond(xx+24,112)
 boss=len(units)>6
 for u in units:
  if u['player']:xx={'Bento':904,'Nick':672,'Íris':440,'Véspera':208}[u['name']];ww=160
  elif boss:xx={1:1080,3:1496,4:1704}[u['rank']];ww=208 if u['rank']==1 else 160
  else:xx=1256+(u['rank']-1)*256;ww=208
  xx=round(xx);c.box(xx,760,ww,72,'ability_selected' if u['id']==actor['id'] else 'panel_normal');c.text(xx+16,784,str(int(u['rank'])),'detail');c.d.rounded_rectangle((xx+48,784,xx+ww-16,796),3,fill=c.c('edge'));c.d.rounded_rectangle((xx+48,784,xx+48+max(1,round((ww-64)*u['hp']/u['max_hp'])),796),3,fill=c.c('text'))
  if u['player']:c.d.rectangle((xx+48,808,xx+ww-16,812),fill=c.c('muted'))
  else:c.icon(xx+ww-48,728,'intent-attack',32)
 c.box(48,864,1824,184);c.portrait(c.actor_file,72,896,80);c.text(176,896,c.actor,'body');c.diamond(176,968)
 skills=[r for r in hud.ABILITIES if r['ClassId']==actor['class_id']][:4];ranks=[]
 for u in units:
  if not u['player']:ranks.extend(range(int(u['rank']),int(u['rank'])+ENEMIES[u['enemy_id']].get('FormationSize',1)))
 for i,a in enumerate(skills):
  xx=448+i*128;locked=actor['rank'] not in a.get('OriginRanks',[]) or (a.get('TargetType')=='SingleEnemy' and not set(a.get('TargetRanks',[])).intersection(ranks));c.box(xx,896,104,104,'ability_locked' if locked else 'ability_normal');paste(c,'art/combat/icons/'+a['Name']+'.webp',xx+20,904,size=(64,64));c.text(xx+16,968,str(i+1),'detail')
  if locked:c.badge(xx+68,976,'disabled')
 for i,(icon,key) in enumerate([('intent-move','Q'),('intent-block','W'),('item-generic','I'),('node-start','F')]):
  xx=1152+i*160;c.box(xx,896,136,104);c.icon(xx+24,912,icon,40);c.text(xx+88,936,key,'detail')
def portrait_dora(c,x,y,size=112):
 data=json.loads((ROOT/'data/presentation/civilians.json').read_text())['civil_dora'];im=Image.open(ROOT/data['file'].removeprefix('res://')).convert('RGBA');u=data['portrait_uv'];im=ImageOps.fit(im.crop((round(u[0]*im.width),round(u[1]*im.height),round(u[2]*im.width),round(u[3]*im.height))),(size,size));c.im.paste(im,(x,y),im)
def briefing(c,page):
 c.header('Relatório da volta' if page=='debriefing' else 'Antes de partir')
 x,y,w=c.panel('Dora' if page!='debriefing' else 'Bento',480,432,960,536)
 if page=='debriefing':
  c.portrait('bento',x,y,112);text='A Estação aguenta mais alguns dias. O que os Antigos deixaram, ninguém aqui sabe fazer de novo.'
 else:
  portrait_dora(c,x,y);text=('Quero recuperar um caderno de receitas esquecido numa mercearia abandonada.' if page=='briefing' else 'Vitrines tomadas por raízes ainda guardam comida e peças que a Estação não sabe mais fabricar.')
 c.text(x+144,y,text,'body',width=w-144);c.text(x,784,'Volta da travessia' if page=='debriefing' else 'Coleta · Rua das Vitrines','detail','muted')
 c.button(x,864,560,'Continuar' if page=='debriefing' else 'Próximo',focus=True);c.button(x+584,864,328,'Pular');c.footer('E · Próximo    Esc · Pular','1 / 2' if page=='briefing' else '2 / 2' if page=='briefing_next' else '1 / 1')
def ficha(c,page):
 if page=='hero_card_preparation':prep(c);unit=next(u for u in c.normal_combat['units'] if u['name']=='Bento');x=1232
 else:
  combat(c);unit=next(u for u in c.meta['units'] if u['name']=='Bento') if page=='hero_card_combat' else next(u for u in c.meta['units'] if not u['player']);x=48
 xx,y,w=c.panel(unit['name'],x,144,640,824)
 if unit['player']:
  c.portrait('bento',xx,y,80);cl=CLASSES[unit['class_id']];c.text(xx+104,y,cl['DisplayName'],'body',width=w-104);c.text(xx+104,y+64,'Nível 1 · '+cl['Role'],'detail','muted',w-104)
  stats=[('Vida',f"{unit['hp']}/{unit['max_hp']}"),('Instinto',f"{unit['instinct']}/200"),('Velocidade',str(unit['speed'])),('Posição',str(unit['rank']))]
 else:
  enemy=ENEMIES[unit['enemy_id']];key=enemy.get('SpriteKey',unit['enemy_id']);paste(c,f'art/ui/map/network/portrait_{key}.webp',xx,y,size=(80,80));c.text(xx+104,y,'Máquina' if enemy['Category']=='Machine' else enemy['Category'],'body');c.text(xx+104,y+64,enemy['Role'],'detail','muted',w-104)
  slots=enemy.get('FormationSize',1);stats=[('Vida',f"{unit['hp']}/{unit['max_hp']}"),('Instinto','Não usa'),('Velocidade',str(unit['speed'])),('Posição',str(unit['rank']) if slots==1 else f"{unit['rank']} a {unit['rank']+slots-1}")]
 for i,(label,value) in enumerate(stats):
  sx=xx+(i%2)*304;sy=392+(i//2)*96;c.text(sx,sy,label,'detail','muted');c.text(sx,sy+32,value,'body')
 if unit['player']:
  c.text(xx,584,'Passivos','body');yy=648
  for perk in ROSTER[0]['perks']:
   yy+=c.text(xx,yy,SHORT_PERKS[perk],'detail','danger' if not PERKS[perk]['bPositive'] else 'text',w)+8
  c.text(xx,920,'Relíquia / Treino / Laço: nenhum ativo','detail','muted',w)
 else:
  c.text(xx,584,'Resistências e estados','body');c.text(xx,648,f"Dano por turno: {round(enemy.get('DotResist',0)*100)}% de resistência.",'detail',width=w)
  c.text(xx,704,'Imune a deslocamento.' if enemy.get('DisplacementResist')==1 else f"Deslocamento: {round(enemy.get('DisplacementResist',0)*100)}% de resistência.",'detail',width=w)
  c.text(xx,776,'Bloqueio '+str(unit['block'])+' · Esquiva '+str(unit['dodge']),'detail');c.text(xx,832,'Atordoamento: '+str(unit['stun']),'detail','muted')
 c.footer('Mouse fora · Fechar    Esc · Fechar','Ficha no foco')
def result(c,page):
 c.header('Fim de luta');x,y,w=c.panel('Vitória',480,144,960,816);stars(c,x,y,3);c.text(x+176,y,'3 de 3 estrelas','body')
 c.text(x,y+80,'Critérios','body');c.text(x+456,y+80,'Experiência','body')
 for i,(label,value) in enumerate([('Ninguém caiu','Sim'),('Rodadas','3'),('Golpe final','Registrado'),('Instinto controlado','Sim')]):
  yy=y+160+i*112;c.icon(x,yy,'marker-visited',24,'good');c.text(x+40,yy,label,'body',width=360);c.text(x+40,yy+48,value,'detail','muted')
 for i,h in enumerate(ROSTER):
  xx=x+456;yy=y+160+i*112;xp=FIX['xp_before'][i]+(FIX['xp_gain'][i] if page=='xp_gain' else 0)
  c.text(xx,yy,h['display_name'],'body');c.text(xx+240,yy,'Nível 1','detail','muted');c.text(xx,yy+48,f'{xp} / 100 XP · +20','detail');bar(c,xx,yy+88,432,xp)
 if page=='xp_gain':c.text(1232,72,'Bento: Treino disponível','body','gold',592)
 c.button(x,864,w,'Continuar',focus=True);c.footer('E · Continuar    Esc · Pular animação','')
def cargo(c,page):
 c.header('Carga recuperada');revealed=page=='cargo_reveal';selected=FIX['cargo_selected_index'];c.text(456,176,'Recebido: 1 fragmento. As outras caixas não são recolhidas.' if revealed else 'Escolha 1 das 6 caixas.','body',width=1008)
 ch=296 if c.large else 272;top=232 if c.large else 256
 for i,reward in enumerate(FIX['cargo_rewards']):
  x=456+(i%3)*344;y=top+(i//3)*(ch+24);active=revealed and i==selected;c.box(x,y,320,ch,'ability_selected' if active else 'button_disabled' if revealed else 'panel_normal');paste(c,'art/ui/loop/cargo_open.webp' if revealed else 'art/ui/loop/cargo_closed.webp',x+48,y+16)
  if revealed:c.icon(x+138,y+88,reward['icon'],44,'gold' if active else 'muted')
  c.text(x+24,y+(256 if c.large else 232),reward['label'] if revealed else f'Caixa {i+1}','detail','text' if active or not revealed else 'muted',272)
  if active:c.diamond(x+296,y+ch-24);c.icon(x+16,y+16,'marker-visited',32,'good')
  elif revealed:c.badge(x+272,y+24,'disabled')
  elif i==0:c.focus(x,y,320,ch)
 if revealed:c.button(456,864,1008,'Continuar',focus=True)
 c.footer('E · Continuar' if revealed else 'Setas · Caixa    E · Escolher','1 de 6')
def training(c,page):
 c.header('Personagens')
 if page=='training_choice':
  x,y,w=c.panel('Treino de Bento',480,144,960,816);c.text(x,y,'Nível 1 para 2','body');c.text(x,y+64,'100 / 100 XP · Custo: 4 sementes · Disponíveis: 30','detail','muted',w)
  for i,(title,effect,preview) in enumerate([('Vida máxima','+2 de vida','34 para 36'),('Instinto','+10 antes da crise','200 para 210')]):
   xx=x+i*456;h=272 if c.large else 240;c.box(xx,400,432,h,'ability_selected' if i==0 else 'panel_normal');c.text(xx+24,424,title,'body',width=384);c.text(xx+24,496,effect,'body',width=384);c.text(xx+24,568,preview,'detail','muted')
   if i==0:c.diamond(xx+408,400+h-24)
   else:c.focus(xx,400,432,h)
  c.button(x,864,w,'Confirmar Treino · 4 sementes',focus=True);c.footer('Setas · Comparar    E · Confirmar','Esc · Voltar');return
 x,y,w=c.panel('Elenco',48,160,640,800)
 for i,h in enumerate(ROSTER):
  yy=y+i*144;c.portrait(['bento','nick','iris','vespera'][i],x,yy,64);c.text(x+88,yy,h['display_name']);level=10 if page=='training_max' and i==0 else 2 if page=='training_done' and i==0 else 1;c.text(x+88,yy+48,f'Nível {level}','detail','muted');bar(c,x+88,yy+96,400,0 if page=='training_done' and i==0 else 100 if i==0 else FIX['xp_before'][i])
 c.focus(x-8,y-8,w+16,128)
 x,y,w=c.panel('Bento');c.text(x,y,'Cão Protetor','body');c.text(x,y+64,'Nível '+('10' if page=='training_max' else '2' if page=='training_done' else '1'),'body')
 if page=='training_max':
  c.text(x,y+176,'Limite de nível atingido.','body',width=w);c.text(x,y+320,'Os efeitos já obtidos permanecem.','detail','muted',w);c.button(x,864,w,'Nível máximo',disabled=True)
 elif page=='training_done':
  c.icon(x,y+176,'marker-visited',32,'good');c.text(x+48,y+176,'Treino concluído','body','good',w-48);c.text(x,y+272,'Vida máxima: 34 para 36','body',width=w);c.text(x,y+368,'Vida atual: 34 / 36','body');c.text(x,y+464,'XP do nível consumido · Sementes: 26','detail','muted',w);c.button(x,864,w,'Voltar ao elenco',focus=True)
 else:
  locked=page=='training_locked';xp=80 if locked else 100;c.text(x,y+176,f'{xp} / 100 XP','body');bar(c,x,y+240,w,xp);c.text(x,y+320,'Custo: 4 sementes','body');c.text(x,y+384,'Disponíveis: '+('2' if locked else '30'),'detail','muted');c.text(x,y+480,'Faltam 20 XP e 2 sementes.' if locked else 'Treino disponível','body','danger' if locked else 'gold',w);c.button(x,864,w,'Treinar',focus=True,disabled=locked)
 c.footer('Setas · Personagem    E · Treino','Esc · Voltar')
def missions(c,page):
 c.header('Mapa da Rede');mp.city(c,'selected');x,y,w=c.panel('Ponte das Raízes');c.text(x,y,'3 estrelas acumuladas · Nível recomendado 3','detail','muted',w)
 selected=4 if page=='mission_locked' else 1 if page=='mission_replay' else 2
 labels=['Travessia de história','Patrulha','Resgate','Coleta','Guardião do lugar'];start=296 if c.large else 328;rh=104 if c.large else 88
 for i,label in enumerate(labels):
  yy=start+i*(rh+8);locked=i in [3,4];c.box(x,yy,w,rh,'ability_locked' if locked else 'ability_selected' if i==selected else 'panel_normal');c.text(x+24,yy+16,label,'body',width=w-176);c.text(x+24,yy+56,'Requer 6 · Faltam 3 estrelas' if locked else '10 trechos' if i==0 else 'Repetir · Prêmio menor' if i==1 and page=='mission_replay' else 'Concluída · 3 de 3' if i==1 else '3 a 5 minutos','detail','muted',w-48)
  if i>0:
   for j in range(3):paste(c,f'art/ui/loop/star_{"filled" if i==1 else "outline"}.webp',x+w-136+j*32,yy+16,size=(24,24),color='gold' if i==1 else 'muted')
  if locked:c.badge(x+w-48,yy+60,'disabled')
  if i==selected:c.focus(x,yy,w,rh)

 c.button(x,864,w,'Bloqueado' if page=='mission_locked' else 'Jogar de novo' if page=='mission_replay' else 'Preparar Resgate',disabled=page=='mission_locked',focus=True);c.footer('Setas · Missão    E · Escolher','Esc · Lugares')
def research(c,page):
 c.header('Centro de Pesquisa');c.box(48,160,1160,800);c.text(72,184,'Árvore da Pesquisa','title')
 scroll=page=='research_scrolled';selected='supplies' if page=='research_locked' else 'history' if scroll else 'machines' if page=='research_running' else 'cao'
 classes=[('sapo','Carga Voltaica'),('coruja','Recurso de Emergência')] if scroll else [('cao','Punho de Sucata'),('gato','Corte de Fase')]
 cols=[[(k,t,'Disponível') for k,t in classes],[('production','Produção','Concluída'),('capacity','Capacidade','Bloqueada')],[('supplies','Suprimentos','Concluída'),('history','História e clima','Disponível')] if scroll else [('machines','Máquinas','Em andamento' if page=='research_running' else 'Disponível'),('supplies','Suprimentos','Bloqueada')]]
 if page=='research_complete':cols[0][0]=('cao','Punho de Sucata','Concluída')
 for col,title in enumerate(['Classe','Estação','Radar']):
  hx=72+col*368;c.button(hx,264,344,title);nx=hx+24
  if col==0:
   c.d.line((hx+172,344,hx+8,360,hx+8,624,nx+160,624,nx+160,640),fill=c.c('muted'),width=2)
  else:
   c.d.line((nx+160,344,nx+160,384),fill=c.c('muted'),width=3)
   bottom=384+(208 if c.large else 176)
   if cols[col][1][2]=='Bloqueada':
    for sy in range(bottom,640,16):c.d.line((nx+160,sy,nx+160,min(640,sy+8)),fill=c.c('muted'),width=2)
   else:c.d.line((nx+160,bottom,nx+160,640),fill=c.c('muted'),width=3)
  for row,(key,name,status) in enumerate(cols[col]):
   yy=384+row*256;wrapped=kit.font(round(24*c.s)).getlength(name)>232;h=(240 if c.large else 208) if wrapped else 208 if c.large else 176;is_selected=key==selected;c.box(nx,yy,320,h,'ability_locked' if status=='Bloqueada' else 'ability_selected' if is_selected else 'panel_normal');th=c.text(nx+24,yy+24,name,'body',width=232);dy=24+th+16;c.text(nx+24,yy+dy,status,'detail','good' if status=='Concluída' else 'muted',272);c.text(nx+24,yy+dy+48,'3 fragmentos' if col==0 else '2 expedições','detail','muted')
   if status=='Bloqueada':c.badge(nx+272,yy+24,'disabled')
   if status=='Concluída':c.icon(nx+264,yy+24,'marker-visited',32,'good')
   if is_selected:c.focus(nx,yy,320,h);c.diamond(nx+296,yy+h-24)
 c.text(72,920,'1 pesquisa por vez · Progresso por expedições','detail','muted')
 x,y,w=c.panel('Pesquisa');title={'cao':'Punho de Sucata','machines':'Sinais de máquinas','supplies':'Suprimentos','history':'História e clima'}[selected];c.text(x,y,title,'body',width=w)
 text={ 'cao':'+1 nos limites de dano ou cura de Punho de Sucata.','machines':'Ao concluir, ler inimigos e chefe no Mapa da Rede.','supplies':'Ao concluir, ler os pontos de busca no Mapa da Rede.','history':'Ao concluir, ampliar a leitura de história e clima.'}[selected]
 c.text(x,y+80,text,'body',width=w);c.text(x,y+256,'Custo: 3 fragmentos' if selected=='cao' else 'Custo: 2 sucatas e 1 fragmento','detail','muted',w);c.text(x,y+336,'Duração: 2 expedições','body')
 if page=='research_running':
  c.text(x,y+416,'Progresso: 1 / 2 expedições','body',width=w);bar(c,x,y+496,w,1,2);c.text(x,800,'Uma pesquisa em andamento.','detail','muted',w);button='Aguardando a volta'
 elif page=='research_locked':c.text(x,y+448,'Requer: Sinais de máquinas','body','danger',w);button='Pré-requisito pendente'
 elif page=='research_complete':
  c.icon(1176,68,'marker-visited',32,'good');c.text(1232,72,'Pesquisa concluída','body','good');c.text(x,y+448,'Melhoria disponível na equipe.','body','good',w);button='Concluída'
 else:button='Iniciar pesquisa'
 c.button(x,864,w,button,focus=True,disabled=page in ['research_running','research_locked','research_complete']);c.footer('Setas · Pesquisa    E · Detalhe','Rolar · Outros nós')
def bonds(c,page):
 friend=page.endswith('friend');effect='Parceiro vivo recebe 1 Bloqueio quando o amigo chega ao Último Fôlego.' if friend else 'Se o rival sofre um crítico inimigo, o outro recebe +5 Instinto.'
 if page.startswith('bond_preparation'):
  prep(c);x,y,w=c.panel('Laços da equipe');c.portrait('bento',x,y,80);c.portrait('nick',x+104,y,80);c.text(x+208,y,'Bento e Nick','body',width=w-208);c.text(x,y+136,'Amizade' if friend else 'Rivalidade','body','good' if friend else 'danger');c.text(x,y+208,effect,'body',width=w);c.text(x,y+448,'O que muda o laço','body');c.text(x,y+512,'Superação aproxima; colapso afasta.','detail','muted',w);c.text(x,y+592,'Escala de -3 a +3.','detail','muted')
 else:
  combat(c)
  for u in c.meta['units']:
   if not u['player']:continue
   xx={'Bento':904,'Nick':672,'Íris':440,'Véspera':208}[u['name']]
   if u['instinct']>0:c.d.rectangle((xx+48,808,xx+48+max(1,round(96*u['instinct']/200)),812),fill=c.c('instinct'))
   if u['block']>0:c.icon(xx+64,720,'intent-block',32,'good')
  c.box(592,176,736,144 if c.large else 112);c.icon(616,208,'intent-block' if friend else 'intent-attack',32,'good' if friend else 'danger');c.text(672,200,'Amizade: Bento no Último Fôlego; Nick +1 Bloqueio.' if friend else 'Rivalidade: crítico em Bento; Nick +5 Instinto.','body','good' if friend else 'danger',624)


def main():
 import argparse,shutil
 ap=argparse.ArgumentParser();ap.add_argument('--documented-frames',action='store_true');ap.add_argument('--only',default='');ap.add_argument('--audit-only',action='store_true');args=ap.parse_args();manifest={};before=OUT/'before';before.mkdir(exist_ok=True)
 if args.documented_frames:manifest=json.loads((OUT/'captures.json').read_text())
 else:
  src=Path('/workspace/scratch/round86_96')
  for profile in ['normal','large']:
   manifest[profile]={}
   for folder in [profile,'boss-'+profile,'bonds-'+profile]:
    for p in (src/folder).glob('*.json'):
     clean=p.with_name(p.stem+'_clean.png');raw=p.with_suffix('.png')
     if not clean.exists():continue
     key=p.stem+('_large' if profile=='large' else '');Image.open(raw).convert('RGB').save(before/(key+'.jpg'),quality=78);Image.open(clean).convert('RGB').save(before/(key+'_clean.webp'),quality=84,method=6);shutil.copyfile(p,before/(key+'.json'))
     manifest[profile][p.stem]={'before':'before/'+key+'.jpg','background':'before/'+key+'_clean.webp','metadata':'before/'+key+'.json','capture_png_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'clean_png_sha256':hashlib.sha256(clean.read_bytes()).hexdigest(),'commit':'f9fe25a' if folder==profile else 'af3513b','staged':p.stem in ['combat-result','combat-boss','combat-bond-friend','combat-bond-rival']}
   shutil.copyfile(src/('bonds-'+profile)/'evidence.json',OUT/('bond_evidence_'+profile+'.json'))
 (OUT/'captures.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 audit=json.loads((OUT/'checks.json').read_text()) if args.only and (OUT/'checks.json').exists() else []
 if args.only:audit=[r for r in audit if r['page'] not in args.only.split(',')]
 for page,source in PAGES.items():
  if args.only and page not in args.only.split(','):continue
  for large,cb,suffix in [(False,False,''),(True,False,'_large'),(False,True,'_colorblind'),(True,True,'_large_colorblind')]:
   profile='large' if large else 'normal';m=manifest[profile][source];c=hud.Board(OUT/m['background'],large,cb);c.meta=json.loads((OUT/m['metadata']).read_text());c.normal_combat=json.loads((OUT/manifest[profile]['combat']['metadata']).read_text());c.source_texts=[r['text'] for r in c.meta['texts']];kit.CHECKS.clear()
   if page.startswith(('briefing','debriefing')):briefing(c,page)
   elif 'card' in page:ficha(c,page)
   elif page in ['fight_result','xp_gain']:result(c,page)
   elif page.startswith('cargo'):cargo(c,page)
   elif page.startswith('training'):training(c,page)
   elif page.startswith(('mission','missions')):missions(c,page)
   elif page.startswith('research'):research(c,page)
   else:bonds(c,page)
   if not args.audit_only:c.im.save(OUT/(page+suffix+'.webp'),quality=84,method=6)
   if not args.audit_only and not large and not cb:c.im.resize((768,432),Image.Resampling.LANCZOS).save(OUT/(page+'_40.webp'),quality=85)
   if not args.audit_only and large and cb:ImageOps.grayscale(c.im).save(OUT/(page+'_gray.webp'),quality=83)
   audit.append({'page':page,'profile':suffix or 'normal','source':m['before'],'labels':c.records,'bounds':[r for r in kit.CHECKS if r['right']>1920 or r['bottom']>1080]})
 (OUT/'captures.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(OUT/'checks.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
 sheet=Image.new('RGB',(1920,((len(PAGES)+2)//3)*400),kit.P['bg']);d=ImageDraw.Draw(sheet)
 for i,page in enumerate(PAGES):
  x=(i%3)*640;y=(i//3)*400;sheet.paste(Image.open(OUT/(page+'_large.webp')).resize((640,360)),(x,y));d.text((x+8,y+366),page,font=kit.font(18),fill=kit.P['text'])
 sheet.save(OUT/'overview.webp',quality=85);print('states',len(PAGES),'profiles',len(audit),'outside',sum(len(x['bounds']) for x in audit),flush=True)
if __name__=='__main__':main()
