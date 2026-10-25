"""Monta as provas de um lote de telas a partir do que o render.mjs do lote gravou em <pasta>/.render/: as telas em WebP
nos quatro perfis, a redução a 40%, o cinza, o painel rolado, o antes (a HUD de hoje, capturada no jogo) e depois de cada
tela, e o checks.json resumido.

Uso (da raiz do repositório): python3 docs/design/hud-kit/compose.py <pasta-do-lote> <tela>=<captura-de-antes> ...
Exemplo: python3 docs/design/hud-kit/compose.py docs/design/hud-estacao overview=docs/design/hud-v2/before/station.jpg
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
PROFILES = ["normal", "large", "colorblind", "large_colorblind"]


def font(size):
    return ImageFont.truetype(str(FONT), size)


def labeled(im, text, w, h):
    im = im.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (w, h + 44), (16, 17, 19))
    out.paste(im, (0, 44))
    ImageDraw.Draw(out).text((14, 8), text, font=font(28), fill=(239, 230, 214))
    return out


def main(folder, pairs):
    here = ROOT / folder
    render = here / ".render"
    checks = json.loads((render / "checks.json").read_text())
    for screen, before in pairs:
        for p in PROFILES:
            suffix = "" if p == "normal" else f"_{p}"
            im = Image.open(render / f"{screen}_{p}.png").convert("RGB")
            im.save(here / f"{screen}{suffix}.webp", quality=86, method=6)
            im.resize((768, 432), Image.Resampling.LANCZOS).save(here / f"{screen}{suffix}_40.webp", quality=90, method=6)
            scrolled = render / f"{screen}_{p}_scrolled.png"
            if scrolled.exists():
                Image.open(scrolled).convert("RGB").save(here / f"{screen}{suffix}_scrolled.webp", quality=86, method=6)
        ImageOps.grayscale(Image.open(render / f"{screen}_normal.png")).save(here / f"{screen}_gray.webp", quality=86, method=6)
        if before:
            a = labeled(Image.open(ROOT / before), "Antes: a HUD de hoje (captura do jogo)", 960, 540)
            b = labeled(Image.open(render / f"{screen}_normal.png"), "Depois: no idioma do kit (sobre a captura limpa)", 960, 540)
            out = Image.new("RGB", (1928, a.height), (40, 42, 46))
            out.paste(a, (0, 0))
            out.paste(b, (968, 0))
            out.save(here / f"before_after_{screen}.webp", quality=86, method=6)
    summary = {k: {"ok": v["ok"], "problems": v["problems"], "overlaps": v["overlaps"], "pieces": v["pieces"], "scroll": v["scroll"],
                   "min_text_px": min(t["size"] for t in v["texts"]), "texts": v["texts"], "targets": v["hits"]} for k, v in checks.items()}
    (here / "checks.json").write_text(json.dumps(summary, ensure_ascii=False, separators=(",", ":")).replace("},{", "},\n{") + "\n")
    print("ok:", sum(v["ok"] for v in summary.values()), "de", len(summary), "· menor texto:", min(v["min_text_px"] for v in summary.values()))


if __name__ == "__main__":
    main(sys.argv[1], [arg.split("=", 1) if "=" in arg else (arg, "") for arg in sys.argv[2:]])
