"""O Armazém (T_CD15) e o Navio (T_CD14) do Cais do Rio em camadas (#164), para a #141.

Cada camada é um WebP com alfa no MESMO quadro da pintura de hoje (1024 × 576 no Navio, 1024 × 683 no Armazém): as
camadas empilhadas, da de trás para a da frente, devolvem a pintura de hoje pixel a pixel. Onde uma camada da frente
cobre a de trás, a de trás vem pintada por inteiro (o pedaço escondido sai das edições do Nano Banana Pro, fora do Git,
em images/cais-camadas/ do projeto na Awesomic), para não abrir buraco quando a câmera passa de lado.

Como se monta cada camada:
  1. cada pixel da pintura de hoje vai para uma camada só (a dona dele), pelas regiões abaixo, da frente para trás;
  2. a camada de trás ganha, onde a da frente a cobre, o pedaço pintado da edição (alinhada à pintura de hoje), dentro
     da forma inteira dela.

Uso: python3 -B docs/design/cais-camadas/cut_layers.py <pasta images/cais-camadas>
Sem numpy: só Pillow.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "art/scenarios"
HERE = Path(__file__).resolve().parent


def poly(size, *polys) -> Image.Image:
    m = Image.new("L", size)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon(p, fill=255)
    return m


def rect(size, *boxes) -> Image.Image:
    return poly(size, *[[(b[0], b[1]), (b[2], b[1]), (b[2], b[3]), (b[0], b[3])] for b in boxes])


def opaque(im: Image.Image, cut: int = 128) -> Image.Image:
    return im.getchannel("A").point(lambda v: 255 if v > cut else 0)


def not_magenta(im: Image.Image) -> Image.Image:
    """O que não é o fundo magenta de uma edição (o vermelho e o azul altos com o verde baixo)."""
    r, g, b = im.convert("RGB").split()
    rb = ImageChops.darker(r, b)
    key = ImageChops.subtract(rb, g).point(lambda v: 255 if v > 90 else 0)
    return ImageChops.invert(key).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))


def gold(im: Image.Image) -> Image.Image:
    """O latão das amuradas (o amarelo do corrimão): o vermelho e o verde acima do azul."""
    r, g, b = im.convert("RGB").split()
    rg = ImageChops.darker(r, g)
    return ImageChops.subtract(rg, b).point(lambda v: 255 if v > 55 else 0).filter(ImageFilter.MaxFilter(5))


def minus(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.subtract(a, b)


def edit(src: Path, size) -> Image.Image:
    """Uma edição alinhada à pintura de hoje (as edições saem no mesmo quadro, em outra resolução)."""
    return Image.open(src).convert("RGB").resize(size, Image.Resampling.LANCZOS)


def layer(art: Image.Image, own: Image.Image, fill: Image.Image = None, fill_mask: Image.Image = None) -> Image.Image:
    """A camada: a pintura de hoje onde ela é a dona; a edição onde está escondida (fill_mask), sem o fundo magenta."""
    out = Image.new("RGBA", art.size)
    out.paste(art, (0, 0), ImageChops.multiply(own, art.getchannel("A")))
    if fill is not None:
        hidden = minus(fill_mask, own)
        piece = fill.convert("RGBA")
        piece.putalpha(255)
        out.paste(piece, (0, 0), hidden)
    return out


def save(im: Image.Image, name: str, manifest: dict) -> None:
    im.save(OUT / f"{name}.webp", "WEBP", quality=88, method=6)
    box = im.getchannel("A").point(lambda v: 255 if v > 85 else 0).getbbox()
    manifest[name] = {"size": list(im.size), "bbox": list(box) if box else None}
    print(name, im.size, box)


def ship(src: Path, manifest: dict) -> None:
    art = Image.open(OUT / "T_CD14.webp").convert("RGBA")
    S = art.size
    # 1. O casco, com a prancha e as correntes (penduradas nele): tudo abaixo da borda do casco.
    hull = poly(S, [(0, 360), (30, 367), (100, 382), (150, 389), (200, 395), (250, 403), (300, 407), (400, 409),
                    (500, 411), (556, 414), (560, 452), (665, 452), (668, 438), (1024, 436), (1024, 576), (0, 576)],
                [(345, 528), (350, 505), (415, 440), (500, 393), (580, 383), (580, 470), (560, 492), (470, 532)])
    # 3. A cabine: a forma inteira dela na edição só com a cabine.
    cabin_edit = edit(src / "ship-cabin-only.png", S)
    cabin_full = ImageChops.multiply(not_magenta(cabin_edit), rect(S, (540, 120, 1024, 456)))
    # 2. O convés: a faixa da amurada e das caixas acima do casco, e o latão da amurada na frente da cabine.
    deck_band = rect(S, (0, 312, 590, 420))
    front_rail = ImageChops.multiply(gold(art), rect(S, (548, 380, 1024, 450)))
    # 4. O mastro e o guindaste (com o gancho, os cabos e o mastro da proa); o pé do guindaste fica atrás das caixas.
    crane = poly(S, [(255, 150), (335, 150), (460, 290), (460, 352), (370, 352), (330, 300), (300, 305), (255, 305)])
    bow_mast = rect(S, (40, 255, 100, 348))
    mast = poly(S, [(700, 0), (900, 0), (900, 152), (810, 152), (810, 200), (735, 200), (735, 152), (700, 152)])
    alpha = opaque(art, 0)

    own_hull = ImageChops.multiply(hull, alpha)
    rest = minus(alpha, own_hull)
    own_rail = ImageChops.multiply(front_rail, rest)
    rest = minus(rest, own_rail)
    own_crane = ImageChops.multiply(ImageChops.lighter(crane, bow_mast), rest)
    rest = minus(rest, own_crane)
    own_cabin = ImageChops.multiply(cabin_full, rest)
    rest = minus(rest, own_cabin)
    own_deck = ImageChops.lighter(own_rail, ImageChops.multiply(deck_band, rest))
    rest = minus(rest, own_deck)
    # O que sobra: o mastro alto e os cabos; na popa, abaixo do mastro, a amurada e as plantas da cabine.
    stern_rest = ImageChops.multiply(rest, minus(rect(S, (540, 140, 1024, 456)), mast))
    own_cabin = ImageChops.lighter(own_cabin, stern_rest)
    own_mast = ImageChops.lighter(own_crane, minus(rest, stern_rest))

    # O casco em três (a proa e a popa recuadas na curva), cada um com 16 px a mais por baixo do vizinho.
    hull_layer = layer(art, own_hull)
    for name, (x0, x1) in (("HullBow", (0, 246)), ("HullMid", (214, 886)), ("HullStern", (854, 1024))):
        piece = Image.new("RGBA", S)
        piece.paste(hull_layer.crop((x0, 0, x1, S[1])), (x0, 0))
        save(piece, "T_CD14_" + name, manifest)
    fills = {}
    for name in ("deck", "mast"):
        f = src / f"ship-{name}-fill.png"
        fills[name] = edit(f, S) if f.exists() else None
    # O que fica escondido: o convés atrás da prancha; o pé do guindaste atrás das caixas; o mastro atrás da amurada
    # da casa do leme (as máscaras das edições, em images/cais-camadas/ship-*-fill-mask.png).
    deck_hidden = rect(S, (480, 380, 590, 470))
    mast_hidden = ImageChops.lighter(rect(S, (370, 330, 460, 400)), ImageChops.lighter(rect(S, (740, 150, 805, 200)),
                                                                                     rect(S, (50, 330, 95, 380))))
    # As máscaras para as edições do que fica escondido (branco: o que se pinta).
    deck_hidden.save(src / "ship-deck-fill-mask.png")
    mast_hidden.save(src / "ship-mast-fill-mask.png")
    if fills["deck"] is not None:
        deck_hidden = ImageChops.multiply(deck_hidden, not_magenta(fills["deck"]))
    if fills["mast"] is not None:
        mast_hidden = ImageChops.multiply(mast_hidden, not_magenta(fills["mast"]))
    save(layer(art, own_deck, fills["deck"], deck_hidden if fills["deck"] else None), "T_CD14_Deck", manifest)
    save(layer(art, own_cabin, cabin_edit, cabin_full), "T_CD14_Cabin", manifest)
    save(layer(art, own_mast, fills["mast"], mast_hidden if fills["mast"] else None), "T_CD14_Mast", manifest)


def warehouse(src: Path, manifest: dict) -> None:
    art = Image.open(OUT / "T_CD15.webp").convert("RGBA")
    S = art.size
    alpha = opaque(art, 0)
    # 1. A frente: o pilar da esquerda (a coluna alta e a treliça), o da direita (o canto e a treliça) e a soleira.
    front = poly(S, [(148, 0), (206, 0), (206, 228), (300, 228), (300, 614), (745, 614),
                     (745, 70), (782, 70), (782, 290), (874, 290), (874, 683), (148, 683)])
    # 4. As laterais em perspectiva: a da esquerda e a da direita (com a quina do telhado descendo).
    sides = ImageChops.lighter(rect(S, (0, 0, 148, 683)), minus(rect(S, (782, 0, 1024, 683)), front))
    # 3. O interior: o vão, sem a moldura.
    interior = rect(S, (300, 298, 745, 614))
    # 2. O telhado e a viga: o resto, em cima.
    own_front = ImageChops.multiply(front, alpha)
    own_sides = ImageChops.multiply(minus(sides, front), alpha)
    own_interior = ImageChops.multiply(minus(interior, front), alpha)
    own_roof = minus(minus(minus(alpha, own_front), own_sides), own_interior)
    # O que fica escondido atrás da frente (as máscaras das edições, em images/cais-camadas/warehouse-*-fill-mask.png).
    hidden = {
        "Interior": minus(rect(S, (240, 236, 812, 650)), interior),
        "Roof": ImageChops.multiply(ImageChops.lighter(rect(S, (148, 20, 206, 300)), rect(S, (745, 60, 782, 300))),
                                    front),
        "Sides": ImageChops.multiply(ImageChops.lighter(rect(S, (148, 170, 200, 660)), rect(S, (830, 140, 874, 660))),
                                     front),
    }
    for name, own in (("Front", own_front), ("Roof", own_roof), ("Interior", own_interior), ("Sides", own_sides)):
        fill = None
        mask = hidden.get(name)
        if mask is not None:
            mask.save(src / f"warehouse-{name.lower()}-fill-mask.png")
            f = src / f"warehouse-{name.lower()}-fill.png"
            if f.exists():
                fill = edit(f, S)
                mask = ImageChops.multiply(mask, not_magenta(fill))
        save(layer(art, own, fill, mask if fill is not None else None), "T_CD15_" + name, manifest)


def main(src: str) -> None:
    src = Path(src)
    manifest = {}
    ship(src, manifest)
    warehouse(src, manifest)
    (HERE / "layers.json").write_text(json.dumps(manifest, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
