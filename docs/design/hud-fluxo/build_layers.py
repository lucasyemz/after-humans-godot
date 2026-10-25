"""As rotas que faltam do Mapa da Rede (#86) numa camada que se lê sobre a pintura: o traço do Codex engrossado, com
contorno escuro por baixo e o miolo claro por cima. Grava docs/design/hud-fluxo/layers/route_<lugar>_remaining.webp.

Uso (da raiz do repositório): python3 docs/design/hud-fluxo/build_layers.py
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / "layers"
CONTRACT = json.loads((ROOT / "docs/design/phase-map/contract.json").read_text())


def main():
    OUT.mkdir(exist_ok=True)
    for key, routes in CONTRACT["routes"].items():
        alpha = Image.open(ROOT / routes["remaining"]).convert("RGBA").getchannel("A").point(lambda v: 255 if v > 40 else 0)
        core = alpha.filter(ImageFilter.MaxFilter(3))
        outline = alpha.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(0.8))
        out = Image.new("RGBA", alpha.size)
        out.paste((12, 13, 14, 255), (0, 0), outline)
        out.paste((244, 234, 216, 255), (0, 0), core)
        out.save(OUT / f"route_{key}_remaining.webp", lossless=True, method=6)
    print("rotas:", len(CONTRACT["routes"]))


if __name__ == "__main__":
    main()
