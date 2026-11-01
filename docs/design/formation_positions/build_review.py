"""Package unchanged Godot captures as documented WebP review sheets (#260)."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

p = argparse.ArgumentParser()
p.add_argument('captures', type=Path)
p.add_argument('--out', type=Path, default=Path(__file__).parent)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
font_path = Path(__file__).resolve().parents[3] / 'art/ui/fonts/barlow_condensed_semibold.ttf'
font = ImageFont.truetype(str(font_path), 34)
for view in ('formation', 'sheet', 'kit_change'):
    for variant in ('normal', 'larger', 'colorblind'):
        im = Image.open(a.captures / f'{view}_{variant}.png').convert('RGB')
        assert im.size == (1920, 1080)
        im.save(a.out / f'{view}_{variant}.webp', quality=92, method=6)
    normal = Image.open(a.captures / f'{view}_normal.png').convert('RGB')
    normal.resize((768, 432), Image.Resampling.LANCZOS).save(a.out / f'{view}_40.webp', quality=94, method=6)
    variant = 'normal' if view == 'formation' else 'larger'
    before = Image.open(a.captures / f'current_{variant}.png').convert('RGB')
    after = Image.open(a.captures / f'{view}_{variant}.png').convert('RGB')
    sheet = Image.new('RGB', (3840, 1140), '#0d1012')
    sheet.paste(before, (0, 60))
    sheet.paste(after, (1920, 60))
    draw = ImageDraw.Draw(sheet)
    draw.text((28, 9), f'ANTES / MAIN 31e77ba6 / SALA / {variant.upper()}', font=font, fill='#efe6d6')
    draw.text((1948, 9), 'DEPOIS / MESMA CENA + MODAL DO KIT / PROPOSTA #260', font=font, fill='#efe6d6')
    sheet.save(a.out / f'before_after_{view}.webp', quality=90, method=6)
gray = Image.new('RGB', (1920, 3240), '#0d1012')
for i, view in enumerate(('formation', 'sheet', 'kit_change')):
    gray.paste(ImageOps.grayscale(Image.open(a.captures / f'{view}_normal.png')).convert('RGB'), (0, i*1080))
gray.save(a.out / 'grayscale.webp', quality=92, method=6)
