"""Os efeitos de impacto e de estados da luta (#41, integração #84).

Converte as folhas PNG de art/combat/effects/ (Codex, PR #43) para WebP na mesma resolução (cada quadro 256x256: os
efeitos aparecem com 64 a 192 px na tela de 1080, e a metade da resolução borraria os loops de estado) e grava
data/presentation/combat_effects.json com as medidas de docs/design/combat-effects.md: os quadros, a âncora local, o
FPS e se toca uma vez ou em loop. Depois de converter, os PNG saem (com os .import).

    python3 tools/build_combat_effects.py
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "art/combat/effects"
OUT = ROOT / "data/presentation/combat_effects.json"
CELL = 256
QUALITY = 90
# A tabela de docs/design/combat-effects.md: quadros, âncora local (px), FPS, loop.
SHEETS = {
    "hit_metal": (6, [128, 128], 12, False),
    "hit_dust": (6, [128, 208], 12, False),
    "critical": (6, [128, 128], 12, False),
    "healing": (6, [128, 128], 12, False),
    "block": (6, [128, 128], 12, False),
    "dodge": (6, [128, 192], 12, False),
    "status_bleeding_organic": (4, [128, 128], 4, True),
    "status_bleeding_robot": (4, [128, 128], 4, True),
    "status_poison": (4, [128, 128], 4, True),
    "status_stunned": (4, [128, 128], 4, True),
    "status_marked": (4, [128, 128], 4, True),
}


def main() -> None:
    effects = {}
    for name, (count, anchor, fps, loop) in SHEETS.items():
        png = FOLDER / f"{name}.png"
        webp = FOLDER / f"{name}.webp"
        if png.exists():
            image = Image.open(png).convert("RGBA")
            assert image.size == (CELL * count, CELL), f"{png.name}: {image.size}"
            image.save(webp, "WEBP", quality=QUALITY, method=6, exact=False)
            png.unlink()
            png.with_suffix(".png.import").unlink(missing_ok=True)
        image = Image.open(webp)
        assert image.size == (CELL * count, CELL), f"{webp.name}: {image.size}"
        effects[name] = {
            "file": f"res://{webp.relative_to(ROOT).as_posix()}",
            "canvas": [CELL, CELL],
            "anchor": anchor,
            "body_reference_pixels": CELL,
            "frames": [[i * CELL, 0, CELL, CELL] for i in range(count)],
            "fps": fps,
            "loop": loop,
        }
    out = {"source": "docs/design/combat-effects.md (tools/build_combat_effects.py)", "effects": effects}
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(effects)} efeitos")


if __name__ == "__main__":
    main()
