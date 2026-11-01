"""Recorta a arte nova do acabamento do Corredor de Contenção (#147) das imagens geradas no Nano Banana Pro (fora do
Git, em images/tutorial/v4/ do projeto na Awesomic) para art/scenarios/, no mesmo contrato e com as mesmas funções da
arte do mapa (docs/design/tutorial/cut_scenario.py):
  - T_TU25 e T_TU26: a face dos pilares (duas, para os pilares vizinhos não se repetirem), opacas;
  - T_TU27: o concreto molhado do lugar, sem emenda (a superfície projetada pelo mundo): os recuos atrás das aberturas,
    os lados dos pilares, os blocos que fecham as pontas das zonas e a beira e o fundo do fosso. Entra no lugar do
    concreto do Abrigo Lacrado (T_SH_rough_concrete);
  - T_TUX04_Security_Shutter (+ _Open): a segunda porta de segurança, a de enrolar, na passagem do corredor;
  - T_TU06 refeita da mesma imagem (images/tutorial/tu-ladder-2.png): a escada da rota do Nick com o alçapão do alto
    indo para o preto, como as paredes (no jogo, a laje clara do alçapão boiava no escuro do teto).

Uso: python3 -B docs/design/tutorial-acabamento/cut_art.py <pasta images/tutorial/v4>
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "docs/design/tutorial"))
from cut_scenario import OUT, cut, shrink, save  # noqa: E402

# A face de cada pilar e a largura dele no mapa (m): a pintura sobe até a altura inteira do pilar (PILLAR_H).
PILLARS = {"T_TU25": ("tu-pillar.png", 0.9), "T_TU26": ("tu-pillar-2.png", 1.0)}
# A T_TU26 sai espelhada: o eletroduto e o nicho da luminária trocam de lado (os dois pilares do corredor são vizinhos).
MIRROR = {"T_TU26"}
PILLAR_H = 4.44
# A paleta do lugar: a pintura nova puxa para a cor da parede do corredor (a metade de baixo, a parte iluminada).
PALETTE = ROOT / "art/scenarios/T_TU01.webp"
CONCRETE = ("T_TU27", "tu-wet-concrete.png", 1024)
SHUTTER = ("T_TUX04_Security_Shutter", "tu-shutter.png", "tu-shutter-open.png")


def dark_top(im: Image.Image, share: float) -> Image.Image:
    """O alto no escuro, como as paredes (keyed_wall): a fração de cima vai para o preto, devagar."""
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        k = min(1.0, y / (im.height * share)) ** 1.4
        if k >= 1.0:
            break
        for x in range(im.width):
            p = px[x, y]
            px[x, y] = (int(p[0] * k), int(p[1] * k), int(p[2] * k)) + tuple(p[3:])
    return im


def bbox(im: Image.Image):
    return im.getchannel("A").point(lambda v: 255 if v > 200 else 0).getbbox()


def match(im: Image.Image, ref: Image.Image, contrast=1.0) -> Image.Image:
    """A média e o contraste de cada canal iguais aos da referência (o verde da pintura nova vira o pardo da parede);
    `contrast` abaixo de 1 deixa a pintura mais lisa que a parede (o concreto que se repete)."""
    from PIL import ImageStat
    a, b = ImageStat.Stat(im), ImageStat.Stat(ref.convert("RGB"))
    bands = []
    for i, band in enumerate(im.split()):
        k = contrast * b.stddev[i] / max(1.0, a.stddev[i])
        bands.append(band.point(lambda v, i=i, k=k: max(0, min(255, int((v - a.mean[i]) * k + b.mean[i])))))
    return Image.merge("RGB", bands)


def palette() -> Image.Image:
    wall = Image.open(PALETTE).convert("RGBA")
    lower = wall.crop((0, wall.height // 2, wall.width, wall.height))
    keep = lower.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    return Image.composite(lower.convert("RGB"), Image.new("RGB", lower.size, (0, 0, 0)), keep).crop(keep.getbbox())


def pillar(im: Image.Image, width: float) -> Image.Image:
    """A face do pilar, opaca: o desenho sem o magenta, cortado 2% para dentro de cada lado (a borda fica no concreto), na
    cor da parede, e esticada para cima até a altura do pilar com o próprio alto espelhado (o concreto liso que sobe para
    o escuro, sem esticar a faixa de perigo); o último quinto vai para o preto, como as paredes."""
    piece = cut(im)
    x0, y0, x1, y1 = bbox(piece)
    inset = round((x1 - x0) * 0.02)
    face = match(piece.crop((x0 + inset, y0, x1 - inset, y1)).convert("RGB"), palette())
    w, h = face.size
    total = round(w * PILLAR_H / width)
    extra = max(0, total - h)
    if extra:
        # Acima da pintura, o concreto do lugar (T_TU27, já cortado), na largura do pilar e um pouco mais escuro, com uma
        # passagem macia para o alto da pintura.
        concrete = Image.open(OUT / "T_TU27.webp").convert("RGB")
        concrete = concrete.resize((w, round(concrete.height * w / concrete.width * 2.2))).point(lambda v: int(v * 0.75))
        fill = Image.new("RGB", (w, extra + h))
        for y in range(0, extra + h, concrete.height):
            fill.paste(concrete, (0, y))
        fade = h // 3
        mask = Image.new("L", (w, extra + h), 0)
        mask.paste(Image.linear_gradient("L").resize((w, fade)), (0, extra))
        mask.paste(255, (0, extra + fade, w, extra + h))
        tall = Image.new("RGB", (w, extra + h))
        tall.paste(face, (0, extra))
        face = Image.composite(tall, fill, mask)
    return dark_top(face, 0.2)


def seamless(im: Image.Image) -> Image.Image:
    """Sem emenda: a imagem deslocada meia volta (as bordas viram o meio, contínuas) por fora e a original no meio,
    com uma máscara macia entre as duas."""
    w, h = im.size
    shifted = ImageChops.offset(im, w // 2, h // 2)
    mask = Image.new("L", (w, h))
    px = mask.load()
    for y in range(h):
        for x in range(w):
            k = min(min(x, w - 1 - x) / (w * 0.25), min(y, h - 1 - y) / (h * 0.25), 1.0)
            px[x, y] = int(255 * k)
    return Image.composite(im, shifted, mask)


def main(src: str) -> None:
    src = Path(src)
    name, file, side = CONCRETE
    save(shrink(match(seamless(Image.open(src / file).convert("RGB")), palette(), 0.55), side), name)
    for name, (file, width) in PILLARS.items():
        face = pillar(Image.open(src / file), width)
        if name in MIRROR:
            face = face.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        save(shrink(face, 1024), name)
    name, closed, opened = SHUTTER
    c, o = cut(Image.open(src / closed)), cut(Image.open(src / opened))
    box = ImageChops.lighter(c.getchannel("A"), o.getchannel("A")).point(lambda v: 255 if v > 8 else 0).getbbox()
    # Um quinto mais escura que a pintura: o batente claro estourava sob a lâmpada de cima.
    for im, suffix in ((c, ""), (o, "_Open")):
        rgb = im.crop(box).convert("RGB").point(lambda v: int(v * 0.8))
        rgb.putalpha(im.crop(box).getchannel("A"))
        save(shrink(rgb, 1024), name + suffix)
    ladder = cut(Image.open(src.parent / "tu-ladder-2.png"))
    ladder = ladder.crop(ladder.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    save(shrink(dark_top(ladder, 0.3), 1024), "T_TU06")


if __name__ == "__main__":
    main(sys.argv[1])
