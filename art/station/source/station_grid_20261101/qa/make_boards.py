"""Review layout only; never edits the generated scene art."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True,type=Path);ap.add_argument('--captures',required=True,type=Path);ap.add_argument('--prototypes',required=True,type=Path);ap.add_argument('--out',required=True,type=Path);a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=True)
def font(n,bold=False):return ImageFont.truetype(str(a.repo/'art/ui/fonts'/('barlow_condensed_semibold.ttf' if bold else 'barlow_condensed_medium.ttf')),n)
def canvas(size):return Image.new('RGB',size,'#0d1012')
def save(im,name):im.save(a.out/(name+'.webp'),quality=92,method=6)
def text(im,xy,value,n=28,fill='#efe6d6',bold=False):ImageDraw.Draw(im).text(xy,value,font=font(n,bold),fill=fill)
def icon(im,key,xy,size,tint='#efe6d6'):
 mask=Image.open(a.prototypes/'icons'/(key+'.webp')).convert('RGBA').getchannel('A').resize((size,size),Image.Resampling.LANCZOS)
 layer=Image.new('RGBA',(size,size),tint);layer.putalpha(mask);im.paste(layer,xy,layer)
scenes=[('platform_rubble','Escombros da plataforma'),('overturned_wagon','Vagão tombado'),('maintenance_machine','Máquina antiga de manutenção'),('exposed_cables','Cabos expostos'),('flooded_duct','Duto alagado'),('root_chamber','Raízes')]
board=canvas((1920,1000));text(board,(30,18),'ESTAÇÃO RAIZ / SEIS BLOCOS SOTERRADOS',40,bold=True)
for i,(key,name) in enumerate(scenes):
 x=30+(i%3)*630;y=96+(i//3)*428
 board.paste(Image.open(a.prototypes/'illustrations'/(key+'.webp')).convert('RGB'),(x,y))
 text(board,(x,y+333),name,30,bold=True)
text(board,(30,950),'Ilustrações próprias / luz pintada e recuos por bloco / sem texto nas texturas de produção',25)
save(board,'art_board');save(board.resize((768,400),Image.Resampling.LANCZOS),'art_board_40');save(ImageOps.grayscale(board).convert('RGB'),'art_board_gray')
fr=canvas((1920,610));text(fr,(30,18),'MOLDURAS / MESMA ILUSTRAÇÃO, ESTADOS DIFERENTES',38,bold=True)
for i,(key,title,caption) in enumerate([('frame_locked','BLOQUEADO','Trilho escuro contínuo / patamar fechado'),('frame_available','LIBERADO PARA ESCAVAR','Trilho claro duplo / cantos âmbar'),('frame_neighbor','DEPENDE DO VIZINHO','Faixa vermelha hachurada / trilho interrompido')]):
 x=30+i*630;y=104;fr.paste(Image.open(a.prototypes/'illustrations/platform_rubble.webp').convert('RGB'),(x,y))
 layer=Image.open(a.prototypes/'frames'/(key+'.webp')).convert('RGBA');fr.paste(layer,(x,y),layer)
 text(fr,(x,y+340),title,30,bold=True);text(fr,(x,y+391),caption,25)
text(fr,(30,554),'As palavras e os avisos são desenhados pela HUD. Vermelho reforça a hachura; não é o único sinal.',25)
save(fr,'frame_board');save(ImageOps.grayscale(fr).convert('RGB'),'frame_board_gray')
ib=canvas((1500,770));text(ib,(30,20),'ÍCONES / ALFA LIMPO / MÁSCARAS TINGÍVEIS',38,bold=True)
for x,name in [(390,'22 px'),(470,'32 px'),(650,'22 px / claro'),(850,'32 px / claro')]:text(ib,(x,88),name,25)
for i,(key,name) in enumerate([('buried','Soterrado'),('excavate','Escavar'),('work_in_progress','Marca da obra'),('choose_room','Escolher cômodo')]):
 y=150+i*145;text(ib,(30,y+23),name,28,bold=True);icon(ib,key,(240,y),96);icon(ib,key,(400,y+30),22);icon(ib,key,(480,y+25),32)
 for x,sz in [(660,22),(870,32)]:
  ImageDraw.Draw(ib).rectangle((x-12,y+12,x+sz+12,y+sz+36),fill='#efe6d6');icon(ib,key,(x,y+24),sz,'#1a1408')
 text(ib,(1010,y+20),key,25)
text(ib,(30,735),'Amostras em tamanho real: não ampliadas dentro da prancha. Fontes, PNG e conversor ficam na tag.',22)
save(ib,'icons_board')
# UI stage samples: illustrative review sheet, not a claimed gameplay capture.
w=canvas((1320,535));text(w,(30,16),'MARCA DA OBRA / ESTUDOS EM 1/3 E 2/3',36,bold=True)
for i,progress in enumerate([1,2]):
 x=30+i*650;y=86;w.paste(Image.open(a.prototypes/'illustrations/exposed_cables.webp').convert('RGB'),(x,y));layer=Image.open(a.prototypes/'frames/frame_available.webp').convert('RGBA');w.paste(layer,(x,y),layer);icon(w,'work_in_progress',(x+30,y+26),56,'#f0a020')
 text(w,(x,y+337),f'Em obra / {progress}/3',28,bold=True)
 ImageDraw.Draw(w).rectangle((x,y+385,x+600,y+407),fill='#25282c');ImageDraw.Draw(w).rectangle((x,y+385,x+int(600*progress/3),y+407),fill='#f0a020')
text(w,(30,507),'Estudo de componente, sem recompensa inventada. Na Godot, a amostra real da frente 1:2 está em 1/2.',20)
save(w,'work_stage_board')
for view in ['overview','work','choice']:
 for variant in ['normal','larger','colorblind']:
  im=Image.open(a.captures/(view+'_'+variant+'.png')).convert('RGB');assert im.size==(1920,1080);save(im,view+'_'+variant)
 variant='normal' if view=='overview' else 'larger'
 before=Image.open(a.captures/('before_'+variant+'.png')).convert('RGB');after=Image.open(a.captures/(view+'_'+variant+'.png')).convert('RGB');pair=canvas((3840,1140));pair.paste(before,(0,60));pair.paste(after,(1920,60))
 text(pair,(28,8),'ANTES / MAIN 7345f7a1 / CÂMERA DE QA / '+variant.upper(),34,bold=True);text(pair,(1948,8),'DEPOIS / MESMA ESTAÇÃO + CARTÕES ILUSTRADOS #275',34,bold=True);save(pair,'before_after_'+view)
im=Image.open(a.captures/'overview_normal.png').convert('RGB');save(im.resize((768,432),Image.Resampling.LANCZOS),'overview_40');save(ImageOps.grayscale(im).convert('RGB'),'overview_gray')
print('Review boards saved:',len(list(a.out.glob('*.webp'))))
