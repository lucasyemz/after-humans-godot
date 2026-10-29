"""A luminária de emergência nova do Corredor de Contenção (#147, o pedido do Lucas de 28/10 no #224): a caixa de aço
blindada, a lente vermelha com a grade e a faixa de perigo, com o eletroduto subindo para o escuro. Sai nos mesmos
nomes da lâmpada antiga (T_TU08_Lit acesa e T_TU08 apagada, para o pisca), então o mapa e a camada de jogo de
tools/build_containment_corridor.py continuam iguais.

Uso (da raiz do repositório): python3 -B docs/design/tutorial-acabamento/cut_lamp.py <images/tutorial/v5/emergency-light-red.png>
A pintura de origem (1024 × 1024, fundo branco) fica fora do Git, na pasta do projeto da Awesomic.
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "art/scenarios"
WIDTH = 256  # px; o card tem 0,5 m de largura no mapa (build_map.py, LAMP_W)
CONDUIT = 1860  # px da origem: o eletroduto que sobe acima da caixa, sumindo no escuro
FADE = 0.3  # a parte de cima que vai para o transparente


def is_lens(r, g, b):
    return r > 140 and r - g > 35 and r - b > 60


def main(src: str) -> None:
    im = Image.open(src).convert("RGB")
    # O recorte do fundo branco: a distância ao branco vira o alfa; os buracos de dentro (a grade) ficam cheios.
    diff = ImageChops.difference(im, Image.new("RGB", im.size, "white"))
    r, g, b = diff.split()
    alpha = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: max(0, min(255, (v - 14) * 8)))
    mask = alpha.point(lambda v: 255 if v > 128 else 0)
    flood = mask.copy()
    ImageDraw.floodfill(flood, (0, 0), 128)
    alpha = ImageChops.lighter(alpha, flood.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.MinFilter(5)))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    x0, y0, x1, y1 = mask.getbbox()
    rgba = im.copy()
    rgba.putalpha(alpha)
    cut = rgba.crop((x0 - 3, y0, x1 + 3, y1 + 3))
    w, h = cut.size
    # O eletroduto: o corpo do cano (sem a boca) repetido para cima.
    lamp = Image.new("RGBA", (w, h + CONDUIT), (0, 0, 0, 0))
    lamp.paste(cut, (0, CONDUIT))
    pipe = cut.crop((365, 40, 475, 110))
    y = CONDUIT + 40
    while y > 0:
        y -= pipe.size[1]
        lamp.alpha_composite(pipe.crop((0, max(0, -y), pipe.size[0], pipe.size[1])), (365, max(0, y)))
    px = lamp.load()
    top = int(lamp.size[1] * FADE)
    for yy in range(lamp.size[1]):
        f = min(1.0, (yy / top) ** 1.6)
        for xx in range(w):
            r_, g_, b_, a = px[xx, yy]
            lens = is_lens(r_, g_, b_)
            # O card é aceso por inteiro (sem a luz da cena): a caixa fica mais escura que a pintura e tingida do vermelho
            # da própria lente, como o aço perto dela; só a lente brilha.
            # O centro da lente, quase amarelo, desce um pouco: a luminária não é o ponto mais claro da parede.
            k = ((0.86, 0.8, 0.8) if r_ > 235 and g_ > 150 else (1.0, 1.0, 1.0)) if lens else (0.74, 0.5, 0.46)
            px[xx, yy] = (int(r_ * k[0]), int(g_ * k[1]), int(b_ * k[2]), int(a * f))
    off = lamp.copy()
    po = off.load()
    for yy in range(CONDUIT + 250, CONDUIT + 730):
        for xx in range(170, 800):
            r_, g_, b_, a = po[xx, yy]
            if is_lens(r_, g_, b_):
                po[xx, yy] = (int(r_ * 0.3), int(g_ * 0.18), int(b_ * 0.18), a)
    size = (WIDTH, round(lamp.size[1] * WIDTH / w))
    lamp.resize(size, Image.LANCZOS).save(OUT / "T_TU08_Lit.webp", quality=90, method=6)
    off.resize(size, Image.LANCZOS).save(OUT / "T_TU08.webp", quality=90, method=6)
    print(f"T_TU08_Lit e T_TU08: {size[0]} × {size[1]} px")


if __name__ == "__main__":
    main(sys.argv[1])
