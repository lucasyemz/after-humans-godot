"""A exploração antes e depois do lote B: os glifos do kit entram sozinhos onde o exploration_hud.gd já procura o nome
antigo no kit (a faixa do corredor, o objetivo, a patrulha, o guardião).

Uso: python3 -B docs/design/hud-icones/compose.py <antes> <depois>
<antes> e <depois> são pastas do tools/capture_106.gd, sem e com os glifos em art/ui/kit/station/icons/. Grava
before_after_explore.webp e explore.webp (a tela inteira, depois).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL = (13, 16, 18)
TEXT = (239, 230, 214)
MUTED = (169, 162, 148)
# (tela, recorte, o que mostra)
CROPS = [("explore", (20, 10, 1270, 250), "O corredor (início, pontos, guardião); o pino do objetivo ainda não muda"),
         ("patrol", (1620, 290, 1900, 410), "A patrulha à frente (luta)"),
         ("boss_choice", (430, 140, 1470, 250), "Diante do guardião (guardião)")]


def main(before: str, after: str) -> None:
    f = ImageFont.truetype(FONT, 28)
    small = ImageFont.truetype(FONT, 24)
    rows = []
    for shot, box, label in CROPS:
        a = Image.open(Path(before) / f"{shot}.png").convert("RGB").crop(box)
        b = Image.open(Path(after) / f"{shot}.png").convert("RGB").crop(box)
        rows.append((label, a, b))
    w = max(a.width for _, a, _ in rows) * 2 + 60
    h = sum(a.height + 80 for _, a, _ in rows) + 20
    out = Image.new("RGB", (w, h), PANEL)
    d = ImageDraw.Draw(out)
    y = 16
    half = (w - 60) // 2
    for label, a, b in rows:
        d.text((20, y), label, font=f, fill=TEXT)
        d.text((20, y + 36), "antes", font=small, fill=MUTED)
        d.text((40 + half, y + 36), "depois", font=small, fill=MUTED)
        out.paste(a, (20, y + 66))
        out.paste(b, (40 + half, y + 66))
        y += a.height + 80
    out.save(HERE / "before_after_explore.webp", quality=85, method=6)
    Image.open(Path(after) / "explore.png").convert("RGB").save(HERE / "explore.webp", quality=82, method=6)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
