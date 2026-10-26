"""A prancha de leitura dos ícones de recurso: cada um a 22, 24, 32 e 64 px sobre o painel escuro, no quadro do recurso
(resource_tile a 80 x 65, como o relatório desenha com cinco recursos, e o ícone a 46), em cinza e sobre xadrez claro
(para ver o alfa). A redução imita os mipmaps da Godot: metade em metade (caixa) até perto do tamanho e bilinear no fim.

Uso: OLD_PNG=<pasta dos PNG do docs/design/hud-kit/render_svg.mjs> python3 -B docs/design/hud-recursos/sheet.py
(grava docs/design/hud-recursos/readability.webp e o _gray)
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
ICONS = ROOT / "art/ui/kit/station/icons"
OLD = ROOT / "art/ui/icons"
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
NAMES = [("seeds", "Sementes", "lobby-seed"), ("scrap", "Sucata", "lobby-scrap"), ("fragments", "Fragmentos", "lobby-fragment"),
         ("supplies", "Comida (suprimentos)", "lobby-food"), ("water", "Água", "lobby-water"),
         ("bandages", "Curativos", "res-bandages"), ("hope", "Esperança", "res-hope"), ("power", "Energia", "lobby-energy")]
PANEL = (13, 16, 18)
TEXT = (239, 229, 209)
MUTED = (166, 154, 132)
COL = [300, 120, 90, 90, 110, 150, 150]  # nome, antigo, 22, 24, 32, 64, quadro


def reduce(icon: Image.Image, side: int) -> Image.Image:
    while icon.width >= side * 2:
        icon = icon.resize((icon.width // 2, icon.height // 2), Image.Resampling.BOX)
    return icon.resize((side, side), Image.Resampling.BILINEAR)


def checker(w: int, h: int) -> Image.Image:
    im = Image.new("RGBA", (w, h), (225, 225, 225, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            if (x // 8 + y // 8) % 2:
                d.rectangle((x, y, x + 7, y + 7), fill=(190, 190, 190, 255))
    return im


def old_icon(name: str, side: int) -> Image.Image:
    """O SVG antigo como o jogo mostra hoje: branco tingido com o texto do kit. O PNG vem do Chromium
    (docs/design/hud-kit/render_svg.mjs, a 32 px) na pasta de OLD_PNG."""
    im = Image.open(Path(os.environ.get("OLD_PNG", "/tmp")) / f"{name}_{side}.png").convert("RGBA")
    tint = Image.new("RGBA", im.size, TEXT + (255,))
    tint.putalpha(im.getchannel("A"))
    return tint


def main() -> None:
    font = ImageFont.truetype(FONT, 26)
    small = ImageFont.truetype(FONT, 22)
    row_h = 110
    w = sum(COL) + 60 + 140
    h = 70 + row_h * len(NAMES) + 20
    im = Image.new("RGBA", (w, h), PANEL + (255,))
    d = ImageDraw.Draw(im)
    tile = Image.open(ROOT / "art/ui/kit/station/resource_tile.webp").convert("RGBA").resize((80, 65))
    heads = ["", "hoje (SVG)", "22 px", "24 px", "32 px", "64 px", "no quadro", "xadrez"]
    x = 30
    for i, head in enumerate(heads):
        d.text((x, 24), head, font=small, fill=MUTED)
        x += COL[i] if i < len(COL) else 0
    for r, (key, label, old) in enumerate(NAMES):
        y = 70 + r * row_h
        icon = Image.open(ICONS / f"resource_{key}.webp").convert("RGBA")
        d.text((30, y + 36), label, font=font, fill=TEXT)
        x = 30 + COL[0]
        o = old_icon(old, 32)
        im.alpha_composite(o, (x + 30, y + 39))
        x += COL[1]
        for side, cw in ((22, COL[2]), (24, COL[3]), (32, COL[4]), (64, COL[5])):
            im.alpha_composite(reduce(icon, side), (x + 20, y + 55 - side // 2))
            x += cw
        t = tile.copy()
        t.alpha_composite(reduce(icon, 46), (17, 10))
        im.alpha_composite(t, (x, y + 22))
        x += COL[6]
        c = checker(84, 84)
        c.alpha_composite(reduce(icon, 64), (10, 10))
        im.alpha_composite(c, (x, y + 13))
    out = Path(__file__).parent
    im.convert("RGB").save(out / "readability.webp", quality=92, method=6)
    im.convert("L").convert("RGB").save(out / "readability_gray.webp", quality=92, method=6)


if __name__ == "__main__":
    main()
