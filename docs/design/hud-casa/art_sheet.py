"""As pranchas da arte nova do lote 7: os cards da Enfermaria (lado a lado, na mesma escala em cm, com o tamanho de cada
um) e os 12 glifos (a 64, 32 e 24 px, tingidos como o jogo faz, e em cinza).

Uso: python3 -B docs/design/hud-casa/art_sheet.py   (grava cards.webp, glyphs.webp e glyphs_gray.webp)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL, TEXT, MUTED, AMBER = (13, 16, 18), (239, 230, 214), (169, 162, 148), (240, 160, 32)
# O tamanho proposto na Estação (cm de largura), o que vale na integração (b.card(nome, base, largura, altura)).
CARDS = [("Infirmary_Bed", "Leito", 172), ("Infirmary_Cabinet", "Armário de remédios", 92), ("Infirmary_Drip", "Soro", 40),
         ("Infirmary_Screen", "Biombo (nível 2)", 140), ("Infirmary_Washstand", "Lavatório (nível 2)", 70), ("Infirmary_Trolley", "Carrinho (nível 2)", 80)]
GLYPHS = [("state_fallen", "Caído"), ("state_recovering", "Em recuperação"), ("job_research", "Posto: Pesquisa"), ("job_forge", "Posto: Forja"),
          ("job_canteen", "Posto: Cantina"), ("job_dormitory", "Posto: Dormitório"), ("job_infirmary", "Posto: Enfermaria"), ("room_infirmary", "Enfermaria"),
          ("inspect", "Inspecionar"), ("helpers", "Ajudantes"), ("formation_swap", "Trocar a formação"), ("dawn", "Amanhecer")]


def cards() -> None:
    f = ImageFont.truetype(FONT, 24)
    px_cm = 1.6
    im = Image.new("RGB", (1880, 520), PANEL)
    d = ImageDraw.Draw(im)
    d.line((20, 440, 1860, 440), fill=(60, 64, 70), width=2)
    x = 30
    for name, label, cm in CARDS:
        c = Image.open(ROOT / f"art/station/cards/{name}.webp").convert("RGBA")
        w = round(cm * px_cm)
        c = c.resize((w, round(c.height * w / c.width)), Image.Resampling.LANCZOS)
        im.paste(c, (x, 440 - c.height), c)
        d.text((x, 452), label, font=f, fill=TEXT)
        d.text((x, 482), f"{name} · {cm} cm", font=ImageFont.truetype(FONT, 20), fill=MUTED)
        x += max(w, 200) + 40
    im.save(HERE / "cards.webp", quality=90, method=6)


def glyphs() -> None:
    f = ImageFont.truetype(FONT, 22)
    cols, cw, rh = 4, 460, 110
    im = Image.new("RGBA", (cols * cw + 20, 20 + rh * 3), PANEL + (255,))
    d = ImageDraw.Draw(im)
    for i, (name, label) in enumerate(GLYPHS):
        x, y = 20 + (i % cols) * cw, 20 + (i // cols) * rh
        g = Image.open(ROOT / f"art/ui/kit/station/icons/{name}.webp").convert("RGBA")
        color = (226, 103, 91) if name.startswith("state") else AMBER if name.startswith(("job", "room")) else TEXT
        xx = x
        for side in (64, 32, 24):
            s = g.resize((side, side), Image.Resampling.LANCZOS)
            t = ImageChops.multiply(s.convert("RGB"), Image.new("RGB", s.size, color))
            t.putalpha(s.getchannel("A"))
            im.alpha_composite(t, (xx, y + (64 - side) // 2))
            xx += side + 16
        d.text((xx + 6, y + 18), label, font=f, fill=TEXT)
    im.convert("RGB").save(HERE / "glyphs.webp", quality=92, method=6)
    im.convert("L").convert("RGB").save(HERE / "glyphs_gray.webp", quality=92, method=6)


if __name__ == "__main__":
    cards()
    glyphs()
