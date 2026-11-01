"""Os ajustes do Lucas de 28/10 no #224, dentro do jogo: o antes é este PR como ele o viu (a6224cb, com a main) e o
depois, com os ajustes (os objetos apoiados no chão, a luminária de emergência nova e sem as raízes), os dois de
capture_game.gd, na mesma câmera, com a mesma equipe e no mesmo ponto. E a prancha do que mudou na arte.

Uso: python3 -B docs/design/tutorial-acabamento/compose_ajustes.py <antes> <depois>
"""
import io
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from compose import ART, ROOT, SHOTS, font, pair  # noqa: E402

OUT = ROOT / "docs/design/tutorial-acabamento/ajustes"
BEFORE = "a6224cb"
# O que mudou na arte: o antes (do Git) e o depois, lado a lado.
CHANGED = [("T_TU08_Lit", "A luminária de emergência", 0.30), ("T_TU01", "A parede do corredor, sem a raiz", 1.0),
           ("T_TU12", "A parede da rota do Nick, sem as raízes", 1.0), ("T_TU03", "A parede da plataforma, sem as raízes", 1.0),
           ("T_TU10", "O vagão, sem as raízes no teto", 1.0)]


def old(code: str) -> Image.Image:
    raw = subprocess.run(["git", "show", f"{BEFORE}:art/scenarios/{code}.webp"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(raw)).convert("RGBA")


def on_dark(im: Image.Image, h: int) -> Image.Image:
    im = im.resize((max(1, round(im.width * h / im.height)), h), Image.Resampling.LANCZOS)
    bg = Image.new("RGBA", im.size, (38, 30, 30, 255))
    return Image.alpha_composite(bg, im).convert("RGB")


def art_sheet() -> Image.Image:
    rows = []
    for code, text, _ in CHANGED:
        h = 300
        a, b = on_dark(old(code), h), on_dark(Image.open(ART / f"{code}.webp").convert("RGBA"), h)
        if code == "T_TU08_Lit":
            # A lâmpada antiga, na escala da nova (0,30 m contra 0,5 m de largura).
            a = on_dark(old(code), round(h * 0.45 / 1.6))
        rows.append((text, a, b))
    width = max(a.width + b.width for _, a, b in rows) + 3 * 24
    out = Image.new("RGB", (width, sum(320 + 50 for _ in rows) + 24), (22, 24, 28))
    d = ImageDraw.Draw(out)
    y = 24
    for text, a, b in rows:
        d.text((24, y), f"{text}: antes | depois", font=font(26), fill=(236, 226, 205))
        out.paste(a, (24, y + 40 + (300 - a.height)))
        out.paste(b, (48 + a.width, y + 40))
        y += 370
    return out


def main(before: str, after: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for shot, name, title in SHOTS:
        b = Image.open(Path(before) / f"{shot}.png").convert("RGB")
        a = Image.open(Path(after) / f"{shot}.png").convert("RGB")
        pair(b, f"Antes (o #224 que o Lucas viu): {title}", a, f"Depois: {title}").save(OUT / f"{name}.webp", quality=86, method=6)
        print(name)
    art_sheet().save(OUT / "art.webp", quality=88, method=6)


if __name__ == "__main__":
    main(*sys.argv[1:3])
