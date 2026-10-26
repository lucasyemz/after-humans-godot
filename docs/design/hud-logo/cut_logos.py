"""Recorta as três propostas de logo (geradas sobre magenta #FF00FF) em WebP sem perda com alfa, grande e pequena.

Uso: python3 -B docs/design/hud-logo/cut_logos.py <raizes.png> <sucata_vigia.png> <placa_alagada.png>
As imagens brutas ficam fora do Git (images/hud-logo/ do projeto na Awesomic: logo-roots-2.png, logo-scrap-vigia.png e
logo-flooded-sign-3.png, a placa com as garras tiradas de cima do S). As propostas ficam em docs/design/hud-logo/ e não
entram em art/: a logo do jogo (art/ui/title/after_humans_logo.png) não muda até o Lucas escolher.
Saída: logo_<id>.webp (no tamanho do recorte) e logo_<id>_small.webp (640 de largura, como
after_humans_logo_small.png), com 8 px de margem transparente em volta e o RGB zerado onde o alfa é 0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageFilter

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hud-station"))
from cut_icons import unmix, despill_edges, clean  # noqa: E402

OUT = Path(__file__).parent
IDS = ["roots", "scrap", "sign"]
PAD = 8


def cut(path: str) -> Image.Image:
    src = Image.open(path).convert("RGB")
    # A borda da imagem gerada não é magenta puro em alguns pixels (o canto de baixo à direita): zera 6 px em volta.
    border = Image.new("RGB", src.size, (255, 0, 255))
    border.paste(src.crop((6, 6, src.width - 6, src.height - 6)), (6, 6))
    logo = unmix(border)
    # O recorte pela logo, não por grão solto: o alfa erodido (5x5) some com pontos pequenos antes da caixa.
    mask = logo.getchannel("A").point(lambda v: 255 if v > 24 else 0).filter(ImageFilter.MinFilter(5))
    x0, y0, x1, y1 = mask.getbbox()
    logo = logo.crop((max(0, x0 - 3), max(0, y0 - 3), min(logo.width, x1 + 3), min(logo.height, y1 + 3)))
    # Fora da logo (longe mais de 6 px do alfa erodido), nada.
    keep = mask.crop((max(0, x0 - 3), max(0, y0 - 3), min(mask.width, x1 + 3), min(mask.height, y1 + 3))).filter(ImageFilter.MaxFilter(13))
    alpha = Image.composite(logo.getchannel("A"), Image.new("L", logo.size, 0), keep)
    logo.putalpha(alpha)
    return despill_edges(logo)


def framed(logo: Image.Image, width: int) -> Image.Image:
    """A logo com a largura pedida (sem aumentar), a margem em volta e o alfa limpo depois de reduzir."""
    w = min(width - 2 * PAD, logo.width)
    im = logo.resize((w, round(logo.height * w / logo.width)), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (im.width + 2 * PAD, im.height + 2 * PAD))
    out.alpha_composite(im, (PAD, PAD))
    return clean(despill_edges(out))


def main(*paths: str) -> None:
    for key, path in zip(IDS, paths):
        logo = cut(path)
        for suffix, width in (("", logo.width + 2 * PAD), ("_small", 640)):
            framed(logo, width).save(OUT / f"logo_{key}{suffix}.webp", lossless=True, exact=True, method=6)
        print(key, logo.size)


if __name__ == "__main__":
    main(*sys.argv[1:4])
