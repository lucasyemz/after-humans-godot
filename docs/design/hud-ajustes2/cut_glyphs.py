"""Recorta os glifos novos do lote 8 (a folha gerada sobre magenta #FF00FF, fora do Git): 7 glifos brancos de um tom em
art/ui/kit/station/icons/, no mesmo recorte dos glifos do lote 7 (hud-casa/cut_art.py: alfa reto, RGB 255 onde há alfa).

Uso: python3 -B docs/design/hud-ajustes2/cut_glyphs.py <folha.png>   (a do lote: images/hud-ajustes2/ajustes-glyphs-sheet.png)
"""
import sys
from pathlib import Path
from PIL import Image

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "hud-casa"))
sys.path.insert(0, str(HERE.parent / "hud-station"))
from cut_art import glyph, ICONS  # noqa: E402
from cut_icons import cells  # noqa: E402

# A folha 4x2, na ordem: o cadeado do cômodo bloqueado, o clima e as ferramentas do Admin, pular; e os da noite: o rato
# na despensa, a conversa e a noite. A última célula (a goteira) não entra: o cano fino some a 32 px, e o evento da
# goteira usa o recurso pintado da água (resource_water).
GLYPHS = ["lock", "weather", "admin", "skip", "night_rat", "night_talk", "night", None]


def main(sheet: str) -> None:
    for name, cell in zip(GLYPHS, cells(Image.open(sheet), 4, 2)):
        if name is None:
            continue
        glyph(cell).save(ICONS / f"{name}.webp", lossless=True, exact=True, method=6)
    print("glifos:", len([n for n in GLYPHS if n]))


if __name__ == "__main__":
    main(sys.argv[1])
