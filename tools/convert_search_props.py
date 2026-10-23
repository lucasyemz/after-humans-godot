"""Converte os props vasculháveis do Codex (#49, PR #53) para o jogo (#50): os 24 PNGs de 1024 x 1024 de
art/street/source/search_props/ viram WebP de 512 x 512 em art/street/search_props/ (metade da resolução, a tela
inteira: nada é recortado, e a âncora no pé continua no mesmo ponto nos dois estados), e o contrato de cada um vai para
data/presentation/search_props.json no espaço da textura (âncora, altura de referência e medidas em metros).
Precisa do Pillow.
  python tools/convert_search_props.py [pasta das fontes] [contrato.json]
Sem argumentos, lê as fontes de art/street/source/search_props/ e o contrato de docs/design/street_props_contract.json.
"""
import json
import sys
from pathlib import Path

from PIL import Image

PROTO = Path(__file__).resolve().parents[1]
SOURCE = PROTO / "art/street/source/search_props"
CONTRACT = PROTO / "docs/design/street_props_contract.json"
TARGET = PROTO / "art/street/search_props"
TABLE = PROTO / "data/presentation/search_props.json"
SCALE = 0.5
QUALITY = 90


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE
    contract = json.loads((Path(sys.argv[2]) if len(sys.argv) > 2 else CONTRACT).read_text(encoding="utf-8"))
    TARGET.mkdir(parents=True, exist_ok=True)
    table = {}
    for name, spec in contract["props"].items():
        files = {}
        for state in ("closed", "open"):
            image = Image.open(source / f"{name}_{state}.png").convert("RGBA")
            size = (round(image.width * SCALE), round(image.height * SCALE))
            image = image.resize(size, Image.LANCZOS)
            path = TARGET / f"{name}_{state}.webp"
            image.save(path, "WEBP", quality=QUALITY, method=6, exact=True)
            files[state] = "res://" + str(path.relative_to(PROTO))
        cm = spec["dimensions_cm"]
        table[name] = {
            "group": spec["group"],
            "closed": files["closed"], "open": files["open"],
            "canvas": [round(spec["canvas"][0] * SCALE), round(spec["canvas"][1] * SCALE)],
            "anchor": [spec["anchor"][0] * SCALE, spec["anchor"][1] * SCALE],
            "body_reference_pixels": spec["body_reference_pixels"] * SCALE,
            "height_m": cm["height"] / 100.0, "width_m": cm["width"] / 100.0, "depth_m": cm["depth"] / 100.0,
        }
        print(f"{name}: {files['closed']}, {files['open']}")
    TABLE.write_text(json.dumps(table, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{TABLE.relative_to(PROTO)}: {len(table)} props")


if __name__ == "__main__":
    main()
