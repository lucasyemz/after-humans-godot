"""Recorta a arte nova do lote 7 (as folhas geradas sobre magenta #FF00FF, fora do Git):
- os cards da Enfermaria (art/station/cards/Infirmary_*.webp), como os outros cards da Estação: recorte pelo alfa, até
  1024 px no lado maior, WebP qualidade 90 (o mesmo de tools/sync_assets.py, station_cards);
- 12 glifos brancos de um tom (art/ui/kit/station/icons/), no recorte dos glifos do kit, com alfa reto (RGB 255 onde
  há alfa) e sem grão.

Uso: python3 -B docs/design/hud-casa/cut_art.py <folha_dos_moveis.png> <folha_dos_glifos.png> <folha_refeita.png> \
       [<folha_dos_leitos.png>]
     (as do lote: images/hud-casa/infirmary-props-sheet-2.png, images/hud-casa/casa-glyphs-sheet.png,
     images/hud-casa/casa-glyphs-sheet-3.png e images/hud-casa/infirmary-bed-broken-covered-2.png)
A folha dos leitos (os ajustes do Lucas de 26/10) é uma edição do próprio Infirmary_Bed, ampliado de 477 para 620 px:
o leito quebrado e o coberto com a lona, que esperam a melhoria no nível 1. Eles voltam para a escala do leito.
A folha refeita (2x1) traz de novo o Caído e o Amanhecer: na primeira, as pernas da maca e o horizonte eram traço preto, e
o recorte (o alfa vem da luminância) os perdia. Na nova, tudo é traço branco grosso.
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
# Os leitos que esperam a melhoria, na folha dos leitos (1376 x 768), e a escala de volta para a do Infirmary_Bed.
BEDS = {"Infirmary_Bed_Broken": (0, 180, 688, 560), "Infirmary_Bed_Covered": (688, 180, 1376, 560)}
BED_SCALE = 477 / 620
# A folha 4x3 dos glifos, na ordem.
GLYPHS = ["state_fallen", "state_recovering", "job_research", "job_forge",
          "job_canteen", "job_dormitory", "job_infirmary", "room_infirmary",
          "inspect", "helpers", "formation_swap", "dawn"]
# A folha refeita, 2x1, na ordem; as células perdem 24 px de cada lado (a folha veio com a linha da grade em rosa claro).
REDONE = ["state_fallen", "dawn"]


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


def beds(sheet_path: str) -> None:
    sheet = Image.open(sheet_path)
    for name, box in BEDS.items():
        im = card(sheet.crop(box))
        im = im.resize((round(im.width * BED_SCALE), round(im.height * BED_SCALE)), Image.Resampling.LANCZOS)
        im.save(CARDS / f"{name}.webp", "WEBP", quality=90, method=4)
        print(name, im.size)


def main(props_sheet: str, glyph_sheet: str, redone_sheet: str) -> None:
    sheet = Image.open(props_sheet)
    for name, box in PROPS.items():
        im = card(sheet.crop(box))
        im.save(CARDS / f"{name}.webp", "WEBP", quality=90, method=4)
        print(name, im.size)
    for name, cell in zip(GLYPHS, cells(Image.open(glyph_sheet), 4, 3)):
        glyph(cell).save(ICONS / f"{name}.webp", lossless=True, exact=True, method=6)
    for name, cell in zip(REDONE, cells(Image.open(redone_sheet), 2, 1)):
        glyph(cell.crop((24, 24, cell.width - 24, cell.height - 24))).save(ICONS / f"{name}.webp", lossless=True, exact=True, method=6)
    print("glifos:", len(GLYPHS), "· refeitos:", ", ".join(REDONE))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
    if len(sys.argv) > 4:
        beds(sys.argv[4])
