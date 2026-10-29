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
# Quantos px uma camada a 1 m anda no card quando a câmera passa de lado (exagerado, para a prova).
SHIFT = 34


def load(name: str) -> Image.Image:
    return Image.open(ART / f"{name}.webp").convert("RGBA")


def on_bg(im: Image.Image, bg=BG) -> Image.Image:
    b = Image.new("RGBA", im.size, bg + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")


def stack(base: str, side: float = 0.0) -> Image.Image:
    size = load(base).size
    out = Image.new("RGBA", size)
    for name, z in SETS[base]:
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
        print(base, "ok")


if __name__ == "__main__":
    main()
