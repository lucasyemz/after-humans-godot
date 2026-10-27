"""A prancha do kit de luz prática (#154): cada fonte apagada, acesa e acesa com o halo somado e a poça no chão, sobre
uma parede escura (o fundo de noite dos cenários). O halo é somado como no jogo (blend_add), no quadro HALO_SCALE vezes o
do card, com o mesmo centro; a poça é a T_LP_Pool tingida na cor da luz,
achatada como a câmera da exploração a vê.

Uso (da raiz do repositório, depois de cut_lights.py): python3 -B docs/design/luz-pratica/kit_sheet.py
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/scenarios"
HERE = Path(__file__).resolve().parent
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
NAMES = [("T_LP01", "Gambiarra"), ("T_LP02", "Lampião"), ("T_LP03", "Tambor com fogo"), ("T_LP04", "Luminária"),
         ("T_LP05", "Letreiro velho"), ("T_LP06", "Luz de emergência"), ("T_LP07", "Drone"),
         ("T_LP08", "Robô de serviço"), ("T_LP09", "Sensor")]
# Onde a poça cai: as fontes no chão (o lampião, o tambor) e as penduradas, mais longe; o drone usa o cone.
FLOOR = {"T_LP02", "T_LP03"}
CELL_W, CELL_H, PIECE_H = 360, 420, 230
HALO_SCALE = 2.0
PIECES = json.loads((HERE / "cut_manifest.json").read_text())["pieces"]


def with_fire(cell, at, size, frame=0):
    """O fogo do tambor somado na boca dele (FIRE_SEAT de cut_lights.py)."""
    seat = PIECES["T_LP03"]["fire_seat"]
    k = size[0] / 232
    f = Image.open(ART / f"T_LP03_Fire_{frame}.webp").convert("RGB")
    w = round(size[0] * seat["width"])
    f = f.resize((w, round(f.height * w / f.width)), Image.Resampling.LANCZOS)
    layer = Image.new("RGB", cell.size)
    layer.paste(f, (at[0] + (size[0] - w) // 2, at[1] + round(seat["bottom_y"] * k) - f.height))
    return ImageChops.add(cell, layer)


def wall(w, h):
    bg = Image.new("RGB", (w, h), (20, 21, 24))
    d = ImageDraw.Draw(bg)
    for y in range(h):
        v = int(14 + 10 * (y / h))
        d.line((0, y, w, y), fill=(v + 2, v + 2, v + 4))
    d.rectangle((0, h - 70, w, h), fill=(30, 28, 27))
    return bg


def tint(im, color):
    return ImageChops.multiply(im, Image.new("RGB", im.size, color))


def main():
    font = ImageFont.truetype(str(FONT), 30)
    small = ImageFont.truetype(str(FONT), 22)
    cols = ["Apagada", "Acesa", "Acesa, com o halo e a poça"]
    W = 260 + CELL_W * 3
    H = 70 + CELL_H * len(NAMES)
    sheet = Image.new("RGB", (W, H), (10, 11, 13))
    d = ImageDraw.Draw(sheet)
    for i, c in enumerate(cols):
        d.text((260 + CELL_W * i + 16, 22), c, font=font, fill=(239, 229, 209))
    for row, (code, label) in enumerate(NAMES):
        y0 = 70 + CELL_H * row
        d.text((20, y0 + CELL_H // 2 - 30), label, font=font, fill=(239, 229, 209))
        d.text((20, y0 + CELL_H // 2 + 8), code, font=small, fill=(166, 154, 132))
        off = Image.open(ART / f"{code}.webp").convert("RGBA")
        lit = Image.open(ART / f"{code}_Lit.webp").convert("RGBA")
        halo = Image.open(ART / f"{code}_Halo.webp").convert("RGB")
        k = min(PIECE_H / off.height, (CELL_W - 60) / off.width)
        size = (round(off.width * k), round(off.height * k))
        off_s, lit_s = off.resize(size, Image.Resampling.LANCZOS), lit.resize(size, Image.Resampling.LANCZOS)
        # O mesmo corte do jogo: alfa em 0,333, sem meio-termo.
        for im in (off_s, lit_s):
            im.putalpha(im.getchannel("A").point(lambda v: 255 if v > 85 else 0))
        color = tuple(int(c) for c in ImageStat.Stat(halo).mean)
        m = max(color) or 1
        color = tuple(min(255, int(c * 255 / m)) for c in color)
        for i in range(3):
            x0 = 260 + CELL_W * i
            cell = wall(CELL_W - 12, CELL_H - 12)
            cx = (cell.width - size[0]) // 2
            cy = cell.height - 70 - size[1] - (0 if code in FLOOR else 60)
            if i == 2:
                pool = Image.open(ART / "T_LP_Pool.webp").convert("RGB").resize((cell.width - 20, 70))
                cell.paste(ImageChops.add(cell.crop((10, cell.height - 72, cell.width - 10, cell.height - 2)),
                                          tint(pool, tuple(int(c * 0.75) for c in color))), (10, cell.height - 72))
                if code == "T_LP07":
                    lx, ly = PIECES[code]["light"]
                    bx = cx + round(lx * k) - 100
                    by = cy + round(ly * k)
                    beam = Image.open(ART / "T_LP_Beam.webp").convert("RGB").resize((200, cell.height - by))
                    region = cell.crop((bx, by, bx + beam.width, by + beam.height))
                    cell.paste(ImageChops.add(region, tint(beam, (140, 200, 210))), (bx, by))
            cell.alpha_composite if False else None
            cell = cell.convert("RGBA")
            cell.alpha_composite(off_s if i == 0 else lit_s, (cx, cy))
            cell = cell.convert("RGB")
            if code == "T_LP03" and i > 0:
                cell = with_fire(cell, (cx, cy), size)
            if i == 2:
                hs = halo.resize((round(size[0] * HALO_SCALE), round(size[1] * HALO_SCALE)), Image.Resampling.LANCZOS)
                hx = cx + size[0] // 2 - hs.width // 2
                hy = cy + size[1] // 2 - hs.height // 2
                layer = Image.new("RGB", cell.size)
                layer.paste(hs, (hx, hy))
                cell = ImageChops.add(cell, layer)
            sheet.paste(cell, (x0 + 6, y0 + 6))
    sheet.save(HERE / "kit_sheet.webp", "WEBP", quality=88, method=6)
    sheet.resize((W * 2 // 5, H * 2 // 5), Image.Resampling.LANCZOS).save(HERE / "kit_sheet_40.webp", "WEBP", quality=88)
    sheet.convert("L").save(HERE / "kit_sheet_gray.webp", "WEBP", quality=88)
    print(sheet.size)


if __name__ == "__main__":
    main()
