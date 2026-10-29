"""As pranchas da página cais-camadas.md (#164): as camadas separadas, a montagem sobre a pintura de hoje (a diferença,
para conferir o encaixe) e a câmera passando de lado (cada camada desloca pela profundidade, como no jogo), para ver que
nenhum buraco abre.

Uso: python3 -B docs/design/cais-camadas/preview.py
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/scenarios"
HERE = Path(__file__).resolve().parent
BG = (52, 56, 64)
# As camadas de trás para a frente, com a profundidade sugerida (m atrás do plano do card de hoje).
SETS = {
    "T_CD14": [("Mast", 0.7), ("Cabin", 0.5), ("Deck", 0.15), ("HullBow", 0.25), ("HullStern", 0.25), ("HullMid", 0.0)],
    "T_CD15": [("Interior", 1.6), ("Sides", 0.5), ("Roof", 0.17), ("Front", 0.0)],
}
# Quantos px uma camada a 1 m anda no card quando a câmera da exploração passa de lado (meia abertura de 15°, o card a
# 18,3 m: uns 26 px por metro).
SHIFT = 26
# As emendas para conferir de perto (a caixa na pintura), com a câmera dos dois lados.
SEAMS = {
    "T_CD14": [(110, 340, 260, 470), (520, 330, 700, 470), (820, 400, 960, 540), (360, 260, 480, 380)],
    "T_CD15": [(60, 0, 260, 220), (700, 40, 880, 320), (250, 250, 360, 450), (700, 420, 820, 660)],
}


def load(name: str) -> Image.Image:
    return Image.open(ART / f"{name}.webp").convert("RGBA")


def on_bg(im: Image.Image, bg=BG) -> Image.Image:
    b = Image.new("RGBA", im.size, bg + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


def stack(base: str, side: float = 0.0) -> Image.Image:
    size = load(base).size
    out = Image.new("RGBA", size)
    for name, z in sorted(SETS[base], key=lambda layer: -layer[1]):
        out.alpha_composite(load(f"{base}_{name}"), (round(side * z * SHIFT), 0))
    return out


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 * len(text) + 12, 22), fill=(20, 20, 24))
    d.text((6, 5), text, fill=(240, 230, 200))
    return im


def grid(ims, cols: int, k: float = 0.6) -> Image.Image:
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols - 1) * 8, rows * h + (rows - 1) * 8), (16, 16, 20))
    for i, im in enumerate(ims):
        out.paste(im, ((i % cols) * (w + 8), (i // cols) * (h + 8)))
    return out.resize((round(out.width * k), round(out.height * k)), Image.Resampling.LANCZOS)


def main() -> None:
    for base, layers in SETS.items():
        art = load(base)
        # As camadas, uma por quadro.
        tiles = [label(on_bg(load(f"{base}_{n}")), f"{base}_{n}") for n, _ in reversed(layers)]
        grid(tiles, 2).save(HERE / f"{base}_layers.webp", quality=82)
        # O encaixe: a pintura de hoje, as camadas empilhadas e a diferença (x4).
        stacked = stack(base)
        diff = ImageChops.difference(on_bg(art, (0, 0, 0)), on_bg(stacked, (0, 0, 0))).point(lambda v: min(255, v * 4))
        grid([label(on_bg(art), "hoje"), label(on_bg(stacked), "camadas empilhadas"),
              label(diff, "diferenca x4")], 3).save(HERE / f"{base}_fit.webp", quality=82)
        # A câmera de lado: o card chapado de hoje desloca inteiro; as camadas, cada uma pela profundidade.
        grid([label(on_bg(stack(base, -1.0)), "camera a esquerda"), label(on_bg(stacked), "de frente"),
              label(on_bg(stack(base, 1.0)), "camera a direita")], 3).save(HERE / f"{base}_parallax.webp", quality=82)
        # As emendas de perto (x2), com a câmera à esquerda e à direita.
        tiles = []
        for box in SEAMS[base]:
            for side in (-1.0, 1.0):
                crop = on_bg(stack(base, side)).crop(box)
                tiles.append(crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.LANCZOS))
        w = max(t.width for t in tiles)
        h = max(t.height for t in tiles)
        tiles = [t.resize((w, h)) for t in tiles]
        grid(tiles, 4, 0.75).save(HERE / f"{base}_seams.webp", quality=82)
        print(base, "ok")


if __name__ == "__main__":
    main()
