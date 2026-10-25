"""QA visual: recortes do alvo e da entrega, sem tentar igualar conteúdo de personagens/ordem."""
import sys,json,hashlib
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;FONT=ROOT/'art/ui/fonts/barlow_condensed_semibold.ttf'
ref=Image.open(ROOT/'docs/design/reference/hud-target-2026-10-25.webp').convert('RGB').resize((1920,1080),Image.Resampling.LANCZOS)
images=[ref,Image.open(OUT/'hud.webp'),Image.open(OUT/'hud_large.webp'),Image.open(OUT/'hud_large_colorblind.webp')]
parts=[('REGISTRO / AÇO',[46,32,318,96]),('FAIXA DA RODADA',[636,26,1356,106]),('VIDA DOS HERÓIS',[196,760,1104,812]),('VIDA DOS INIMIGOS',[1260,760,1732,812]),('NOME DO ALVO',[1270,344,1464,408]),('PAINEL ÚNICO DO HERÓI',[60,832,636,1052]),('HABILIDADE / ALCANCE /4 ÍCONES',[680,812,1312,1060]),('AÇÕES /2 X2',[1580,832,1852,1058]),('ANEL DO ATOR',[636,712,916,792]),('F / SAÍDA, NÃO MIRA',[1716,944,1856,1058])]
o=Image.new('RGB',(1920,96+len(parts)*252),'#111519');d=ImageDraw.Draw(o);f=ImageFont.truetype(str(FONT),26)
for i,t in enumerate(['ALVO APROVADO','NORMAL','MAIOR','MAIOR / DALTONISMO']):d.text((i*480+16,20),t,font=f,fill='#efe6d6')
for row,(label,box) in enumerate(parts):
 y=96+row*252
 for col,im in enumerate(images):
  d.text((col*480+16,y+4),label,font=f,fill='#efe6d6');p=ImageOps.contain(im.crop(box).convert('RGB'),(448,192),Image.Resampling.LANCZOS);o.paste(p,(col*480+16+(448-p.width)//2,y+44+(192-p.height)//2))
o.save(OUT/'piece_comparison.webp',quality=94,method=6)
# Escala de leitura real do novo estilo e do símbolo exigido em F.
proof=Image.new('RGB',(1200,280),'#111519');d=ImageDraw.Draw(proof);d.rectangle((600,0,1200,280),fill='#efe6d6');exit=Image.open(ROOT/'art/ui/kit/combat/exit.webp').convert('RGBA')
for side in range(2):
 for j,n in enumerate([22,32,48]):
  im=exit.resize((n,n),Image.Resampling.LANCZOS);t=Image.new('RGBA',im.size,'#efe6d6' if side==0 else '#25282c');t.putalpha(im.getchannel('A'));proof.paste(t,(side*600+48+j*160,64),t);d.text((side*600+48+j*160,160),str(n)+' PX',font=f,fill='#efe6d6' if side==0 else '#25282c')
proof.save(OUT/'readability.webp',quality=93)
geometry={'register':{'reference':[46,34,270,58],'delivery':[46,32,272,64]},'round':{'reference':[637,30,718,64],'delivery':[636,30,720,72]},'hero':{'reference':[63,836,563,209],'delivery':[64,836,564,212]},'ability_header':{'reference':[685,852,618,49],'delivery':[684,852,624,56]},'slots':{'reference':[685,913,132,126],'delivery':[688,916,132,132]},'actions':{'reference':[1584,847,264,200],'delivery':[1584,836,264,212],'reason':'128x100 visual buttons;112px vertical pitch allows112-high touch targets without overlap'}}
(OUT/'target_comparison.json').write_text(json.dumps({'reference_measures':'hud-direction.md; approximate approved-target boxes','pieces':geometry,'explicit_exceptions':['F uses exit instead of the crosshair in target','Canonical game portraits/body art retained','Initiative and current actor from actual captured session; not duplicated generated portraits']},ensure_ascii=False,indent=2)+'\n')
print('Piece-by-piece comparison10 rows,4 columns')
