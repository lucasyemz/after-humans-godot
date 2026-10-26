"""Recorta a arte nova do lote 7 (as folhas geradas sobre magenta #FF00FF, fora do Git):
- os cards da Enfermaria (art/station/cards/Infirmary_*.webp), como os outros cards da Estação: recorte pelo alfa, até
  1024 px no lado maior, WebP qualidade 90 (o mesmo de tools/sync_assets.py, station_cards);
- 12 glifos brancos de um tom (art/ui/kit/station/icons/), no recorte dos glifos do kit, com alfa reto (RGB 255 onde
  há alfa) e sem grão.

Uso: python3 -B docs/design/hud-casa/cut_art.py <folha_dos_moveis.png> <folha_dos_glifos.png>
     (as do lote: images/hud-casa/infirmary-props-sheet-2.png e images/hud-casa/casa-glyphs-sheet.png)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hud-station"))
from cut_icons import unmix, cells, fit, despill_edges  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CARDS = ROOT / "art/station/cards"
ICONS = ROOT / "art/ui/kit/station/icons"
# Os móveis na folha (1264 x 848): a cama passa da linha da grade 3x2, então cada um sai de uma caixa medida na folha.
PROPS = {"Infirmary_Bed": (6, 8, 498, 426), "Infirmary_Cabinet": (550, 8, 894, 426), "Infirmary_Drip": (982, 8, 1128, 426),
         "Infirmary_Screen": (34, 438, 472, 846), "Infirmary_Washstand": (556, 438, 838, 846), "Infirmary_Trolley": (900, 438, 1244, 846)}
# A folha 4x3 dos glifos, na ordem.
GLYPHS = ["state_fallen", "state_recovering", "job_research", "job_forge",
          "job_canteen", "job_dormitory", "job_infirmary", "room_infirmary",
          "inspect", "helpers", "formation_swap", "dawn"]


def main_body(im: Image.Image) -> Image.Image:
    """Só o desenho: some o que não fica a até 6 px de um pedaço com alfa forte (grão e restos de outra célula)."""
    a = im.getchannel("A")
    near = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MaxFilter(13))
    im.putalpha(ImageChops.multiply(a, near).point(lambda v: 0 if v < 8 else v))
    return im


def clean_rgb(im: Image.Image) -> Image.Image:
    a = im.getchannel("A")
    rgb = Image.composite(im.convert("RGB"), Image.new("RGB", im.size), a.point(lambda v: 255 if v else 0))
    rgb.putalpha(a)
    return rgb


def card(cell: Image.Image) -> Image.Image:
    im = main_body(despill_edges(unmix(cell)))
    # O que ainda puxa para o magenta (vermelho e azul acima do verde) perde o azul: o metal e o pano não têm roxo.
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and r > g + 30 and b > g + 30:
                g2 = max(g, int(r * 0.7))
                px[x, y] = (r, g2, g2 + (b - g2) // 4 if b > g2 else b, a)
            elif a and r > g + 15 and b > g + 8:
                # O vidro do soro e os arames do carrinho deixavam ver o magenta: viram cinza-azulado, como vidro e
                # metal. A ferrugem (azul abaixo do verde) e o vermelho da cruz (azul igual ao verde) não entram.
                v = (r * 3 + g * 6 + b) // 10
                px[x, y] = (v, v + 4, v + 12, a)
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop(box)
    scale = min(1.0, 1024.0 / max(im.size))
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.Resampling.LANCZOS)
    return clean_rgb(im)


def glyph(cell: Image.Image) -> Image.Image:
    mixed = unmix(cell)
    lum = mixed.convert("L")
    alpha = ImageChops.multiply(mixed.getchannel("A"), lum.point(lambda v: min(255, max(0, (v - 70) * 255 // 150))))
    white = Image.new("RGBA", mixed.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    icon = fit(white, 64, 0.06)
    a = icon.getchannel("A")
    near = a.point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(5))
    a = ImageChops.multiply(a, near).point(lambda v: 0 if v < 24 else v)
    out = Image.composite(Image.new("RGB", icon.size, (255, 255, 255)), Image.new("RGB", icon.size), a.point(lambda v: 255 if v else 0))
    out.putalpha(a)
    return out


def main(props_sheet: str, glyph_sheet: str) -> None:
    sheet = Image.open(props_sheet)
    for name, box in PROPS.items():
        im = card(sheet.crop(box))
        im.save(CARDS / f"{name}.webp", "WEBP", quality=90, method=4)
        print(name, im.size)
    for name, cell in zip(GLYPHS, cells(Image.open(glyph_sheet), 4, 3)):
        glyph(cell).save(ICONS / f"{name}.webp", lossless=True, exact=True, method=6)
    print("glifos:", len(GLYPHS))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
