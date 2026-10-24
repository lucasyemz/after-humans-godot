"""Variante de etiqueta do componente Sequência (#69), só documentação."""
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import json
from PIL import Image, ImageOps
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'docs/design/ui-kit'))
import render as kit
OUT=Path(__file__).resolve().parent
def tag(c,x,y,state,lang,scale=1,chosen=False,focus=False):
    c.s=scale
    big=scale>1
    w,h=(272,112) if big else (240,96)
    title=('Estação Raiz' if lang=='pt' else 'Root Station') if state=='refuge' else ('Fase 3' if lang=='pt' else 'Phase 3')
    word={'pt':{'available':'Disponível','locked':'Bloqueada','completed':'Concluída','refuge':'Refúgio'},'en':{'available':'Available','locked':'Locked','completed':'Completed','refuge':'Refuge'}}[lang][state]
    c.box(x,y,w,h,'ability_selected' if chosen else 'panel_normal')
    icon={'available':'marker-available','locked':'node-combat','completed':'marker-visited','refuge':'node-start'}[state]
    color='good' if state=='completed' else 'text'
    c.icon(x+16,y+18,icon,24,color)
    c.text(x+56,y+16,title,'body',color='text')
    c.text(x+16,y+(64 if big else 56),word,'detail',color='muted')
    if state=='locked':c.badge(x+w-40,y+h-36,'disabled')
    if chosen:c.diamond(x+w-24,y+h-24)
    if focus:c.focus(x,y,w,h)
    return {'width':w,'height':h}
for lang in ['pt','en']:
 for cb in [False,True]:
    c=kit.Canvas(cb=cb);c.header('Etiquetas do mapa / '+lang.upper(),'Sequência 09 + painel 01 + seleção 11; mesmo kit, sem nova textura de runtime')
    for row,(label,s) in enumerate([('Normal',1),('Grande',1.15),('Maior',1.3)]):
      c.s=1;c.text(48,240+row*232,label,'body','copper')
      for j,state in enumerate(['available','locked','completed','refuge']):tag(c,320+j*384,224+row*232,state,lang,s,chosen=(row==0 and j==0),focus=(row==2 and j==1))
    c.s=1;c.footer('Detalhe nunca abaixo18px / fundo opaco / idioma não muda tamanho da caixa')
    c.im.save(OUT/f'labels_{lang}{"_colorblind" if cb else ""}.webp',quality=88,method=6)
    if cb:ImageOps.grayscale(c.im).save(OUT/f'labels_{lang}_gray.webp',quality=88,method=6)
    c.im.resize((768,432)).save(OUT/f'labels_{lang}{"_colorblind" if cb else ""}_40.webp',quality=88,method=6)
(OUT/'checks.json').write_text(json.dumps({'minimum_font':18,'outside_canvas':kit.CHECKS and [r for r in kit.CHECKS if r['right']>1920 or r['bottom']>1080],'states':['available','locked','completed','refuge'],'languages':['pt','en'],'scales':[1,1.15,1.3],'runtime_art_added':False},indent=2)+'\n')
