"""A prancha dos 7 glifos novos do lote 8: cada um a 64, 32 e 22 px (os tamanhos que o qa.md pede), tingido como o jogo
faz, e em cinza.

Uso: python3 -B docs/design/hud-ajustes2/glyph_sheet.py   (grava glyphs.webp e glyphs_gray.webp)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL, TEXT, AMBER, MUTED = (13, 16, 18), (239, 230, 214), (240, 160, 32), (169, 162, 148)
GLYPHS = [("lock", "Cômodo bloqueado", MUTED), ("weather", "Admin: Clima", TEXT), ("admin", "Admin", AMBER), ("skip", "Pular", TEXT),
          ("night_rat", "Noite: rato na despensa", TEXT), ("night_talk", "Noite: alguém conversa", TEXT), ("night", "A noite", AMBER)]


def main() -> None:
    f = ImageFont.truetype(FONT, 22)
    cols, cw, rh = 4, 460, 110
    im = Image.new("RGBA", (cols * cw + 20, 20 + rh * 2), PANEL + (255,))
    d = ImageDraw.Draw(im)
    for i, (name, label, color) in enumerate(GLYPHS):
        x, y = 20 + (i % cols) * cw, 20 + (i // cols) * rh
        g = Image.open(ROOT / f"art/ui/kit/station/icons/{name}.webp").convert("RGBA")
        xx = x
        for side in (64, 32, 22):
            s = g.resize((side, side), Image.Resampling.LANCZOS)
            t = ImageChops.multiply(s.convert("RGB"), Image.new("RGB", s.size, color))
            t.putalpha(s.getchannel("A"))
            im.alpha_composite(t, (xx, y + (64 - side) // 2))
            xx += side + 16
        d.text((xx + 6, y + 18), label, font=f, fill=TEXT)
    im.convert("RGB").save(HERE / "glyphs.webp", quality=92, method=6)
    im.convert("L").convert("RGB").save(HERE / "glyphs_gray.webp", quality=92, method=6)
    print("ok")


if __name__ == "__main__":
    main()
