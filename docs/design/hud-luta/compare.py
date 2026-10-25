"""As provas do lote 4: a tela da luta montada só com o kit da Awesomic lado a lado com o alvo aprovado, nos quatro
perfis, e a matriz peça por peça (alvo, kit do Codex que sai, kit da Awesomic que entra), também em cinza no daltonismo.

Uso (da raiz do repositório, depois do render.mjs e do compose.py do lote):
    python3 docs/design/hud-luta/compare.py
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
RENDER = HERE / ".render"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
TARGET = Image.open(ROOT / "docs/design/reference/hud-target-2026-10-25.webp").convert("RGB").resize((1920, 1080), Image.Resampling.LANCZOS)
CODEX = ROOT / "docs/design/hud-target"
NAMES = {"normal": "NORMAL", "large": "MAIOR", "colorblind": "DALTONISMO", "large_colorblind": "MAIOR + DALTONISMO"}
INK = (239, 230, 214)
BG = (18, 21, 24)


def font(size):
    return ImageFont.truetype(str(FONT), size)


def side_by_side():
    for profile, title in NAMES.items():
        mine = Image.open(RENDER / f"combat_{profile}.png").convert("RGB")
        out = Image.new("RGB", (3840 + 24, 1080 + 72), BG)
        d = ImageDraw.Draw(out)
        d.text((32, 18), "ALVO APROVADO (LUCAS, 25/10)", font=font(36), fill=INK)
        d.text((1920 + 24 + 32, 18), f"SÓ O KIT DA AWESOMIC · {title}", font=font(36), fill=INK)
        out.paste(TARGET, (0, 72))
        out.paste(mine, (1920 + 24, 72))
        suffix = "" if profile == "normal" else f"_{profile}"
        out.save(HERE / f"comparison{suffix}.webp", quality=88, method=6)


# As regiões das peças na tela de 1920x1080: [nome, caixa].
REGIONS = [
    ("Ordem da rodada (round_strip)", (626, 22, 1366, 102)),
    ("Aba, barra e quadrados das habilidades", (676, 806, 1316, 1056)),
    ("Anel no chão e vida de quem age (actor_ring)", (600, 696, 1120, 820)),
    ("Nome do alvo (target_tab)", (1262, 330, 1474, 424)),
    ("Vida dos inimigos (forma do lado)", (1250, 740, 1730, 830)),
]


def matrix(profile="normal", gray=False):
    mine = Image.open(RENDER / f"combat_{profile}.png").convert("RGB")
    suffix = "" if profile == "normal" else f"_{profile}"
    codex = Image.open(CODEX / f"hud{suffix}.webp").convert("RGB")
    cols = [("ALVO", TARGET), ("KIT DO CODEX (SAI)", codex), ("KIT DA AWESOMIC (ENTRA)", mine)]
    rows = []
    for name, box in REGIONS:
        w, h = box[2] - box[0], box[3] - box[1]
        k = min(2.0, 760 / w)
        cw, ch = round(w * k), round(h * k)
        row = Image.new("RGB", (3 * cw + 4 * 16, ch + 52), BG)
        d = ImageDraw.Draw(row)
        d.text((16, 8), name.upper(), font=font(30), fill=(240, 160, 32))
        for i, (_, im) in enumerate(cols):
            crop = im.crop(box).resize((cw, ch), Image.Resampling.LANCZOS)
            if gray:
                crop = ImageOps.grayscale(crop).convert("RGB")
            row.paste(crop, (16 + i * (cw + 16), 48))
        rows.append(row)
    width = max(r.width for r in rows)
    head = Image.new("RGB", (width, 64), BG)
    d = ImageDraw.Draw(head)
    cw = (width - 64) // 3
    for i, (title, _) in enumerate(cols):
        d.text((16 + i * (cw + 16), 14), title + ("" if profile == "normal" else f" · {NAMES[profile]}") + (" · CINZA" if gray else ""), font=font(32), fill=INK)
    out = Image.new("RGB", (width, 64 + sum(r.height for r in rows)), BG)
    out.paste(head, (0, 0))
    y = 64
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    return out


def main():
    side_by_side()
    matrix("normal").save(HERE / "piece_comparison.webp", quality=88, method=6)
    matrix("large").save(HERE / "piece_comparison_large.webp", quality=88, method=6)
    matrix("colorblind").save(HERE / "piece_comparison_colorblind.webp", quality=88, method=6)
    matrix("large_colorblind", gray=True).save(HERE / "piece_comparison_gray.webp", quality=88, method=6)
    print("comparações: 4 telas e 4 matrizes")


if __name__ == "__main__":
    main()
