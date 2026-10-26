"""Recorta as folhas dos glifos da luta, do corredor e dos marcadores (fundo magenta #FF00FF) em WebP branco de um tom,
para o jogo tingir, no mesmo recorte dos glifos do kit (docs/design/hud-station/cut_icons.py).

Uso: python3 -B docs/design/hud-icones/cut_icons.py <combate_a.png> <combate_b.png> <mapa_a.png> <correcoes.png> \
       <correcoes_mapa.png> <correcoes_2.png> <correcoes_2_variante.png> [<pasta de saída>]
As folhas brutas (grade 4x3; as das correções, 2x2) ficam fora do Git. As correções refizeram o que sumia pequeno: a
Esquiva (a seta fina e a bolinha preta), o Sangra (o corte apagava meia gota) e o Ataque em área (as setas finas), e,
na faixa do corredor (cerca de 20 px), a Luta (os facões finos sumiam), o Início (a bandeira com o
monte virava mancha), o Guardião e o Achado (detalhe demais). A segunda rodada de correções (4x2) refez o que a QA
achou fraco a 16-22 px: a Luta (espadas com guarda e pomo, para não ler como o X de fechar), a Guarda (dois escudos, e
não a pata, que virava mancha), o Vulnerável (o vão largo), o Marcado (a mira fina, que não lê como engrenagem), o
Mover e o Ataque (seta e espada: os inimigos são quase todos máquinas e raízes, não bichos), o Descanso e o Visitado.
O Ataque é a espada sozinha da variante da mesma folha (o arco do golpe da principal lia como a lua do `sleep`); a
Guarda sai espelhada (o escudo de trás à esquerda, longe da seta do bom) e o Marcado, com o traço 1 px mais grosso. Cada glifo sai da folha em que ficou mais limpo; as legendas que o
gerador escreveu embaixo de alguns são pretas e somem no recorte (o preto vira transparente).

Os nomes são os dos SVG antigos de art/ui/icons/ (status-*, intent-*, node-*, marker-*), em art/ui/kit/station/icons/:
o jogo troca só a pasta e a extensão, como o inventory_panel.gd já faz (AHKit.icon(nome) se existir no kit).

Os estados: o mesmo símbolo nos dois, e a forma diz bom ou ruim para quem tem, sem depender da cor (daltonismo):
- _good: o símbolo com uma seta cheia para cima no canto de cima, à direita;
- _bad: o símbolo com uma seta cheia para baixo no canto de baixo, à direita.
A seta abre um vão de 3 px no símbolo, para não grudar nele a 24 px, e fica a 2 px da borda.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hud-station"))
from cut_icons import OUT, unmix, cells, fit  # noqa: E402

SIDE = 64
# (folha, célula na grade 4x3, contando da esquerda para a direita e de cima para baixo)
STATUS = {"bleeding": ("f", 2), "poison": ("b", 1), "block": ("a", 2), "dodge": ("f", 0), "marked": ("h", 3),
          "stunned": ("b", 5), "vulnerable": ("h", 2), "protection": ("h", 1)}
PLAIN = {"intent-attack": ("i", 0), "intent-attack_area": ("f", 3), "intent-block": ("b", 10), "intent-heal": ("b", 11),
         "intent-stunned": ("b", 5), "intent-move": ("h", 4), "intent-unknown": ("m", 2),
         "node-boss": ("g", 2), "node-combat": ("h", 0), "node-event": ("m", 5), "node-loot": ("g", 3),
         "node-rest": ("h", 6), "node-start": ("g", 1),
         "marker-available": ("m", 9), "marker-here": ("m", 10), "marker-visited": ("h", 7)}


# A folha das correções 2 (4x2): alguns desenhos passam da linha da grade (o pomo das espadas desce na célula de baixo),
# então cada um sai de uma caixa medida na folha (x0, y0, x1, y1), e não da célula.
BOXES_I = [(470, 525, 690, 735)]
BOXES_H = [(30, 45, 390, 400), (410, 45, 680, 350), (712, 45, 1003, 366), (1040, 57, 1344, 365),
           (50, 412, 370, 690), (377, 410, 712, 733), (740, 409, 975, 726), (1040, 410, 1340, 724)]


def white(cell: Image.Image) -> Image.Image:
    """Glifo de um tom: o branco é o traço; o contorno preto da folha (e as legendas) viram transparentes."""
    mixed = unmix(cell)
    lum = mixed.convert("L")
    alpha = ImageChops.multiply(mixed.getchannel("A"), lum.point(lambda v: min(255, max(0, (v - 70) * 255 // 150))))
    out = Image.new("RGBA", mixed.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def clean(im: Image.Image) -> Image.Image:
    """Branco de um tom com alfa reto: RGB 255 onde há alfa (sem escurecer a borda), 0 onde não há; e sem grão solto
    (o que não fica a até 2 px de um traço com alfa acima de 40 some, e o alfa abaixo de 24 também)."""
    a = im.getchannel("A")
    near = a.point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(5))
    # Abaixo de 24 de alfa (menos de 10% de cobertura) é grão ou resto de contorno: some.
    a = ImageChops.multiply(a, near).point(lambda v: 0 if v < 24 else v)
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(a)
    rgb = Image.composite(Image.new("RGB", im.size, (255, 255, 255)), Image.new("RGB", im.size), a.point(lambda v: 255 if v else 0))
    rgb.putalpha(a)
    return rgb


def arrow(up: bool) -> Image.Image:
    """A seta do bom (para cima, no alto) ou do ruim (para baixo, embaixo), desenhada a 4x e reduzida."""
    k = 4
    big = Image.new("L", (SIDE * k, SIDE * k), 0)
    d = ImageDraw.Draw(big)
    # Caixa de 24x24 no canto direito: cabeça de 24 de largura e haste de 10.
    x0, x1 = 38 * k, 62 * k
    if up:
        y0 = 2 * k
        d.polygon([(x0, y0 + 13 * k), ((x0 + x1) / 2, y0), (x1, y0 + 13 * k)], fill=255)
        d.rectangle(((x0 + x1) / 2 - 5 * k, y0 + 12 * k, (x0 + x1) / 2 + 5 * k, y0 + 22 * k), fill=255)
    else:
        y1 = 62 * k
        d.polygon([(x0, y1 - 13 * k), ((x0 + x1) / 2, y1), (x1, y1 - 13 * k)], fill=255)
        d.rectangle(((x0 + x1) / 2 - 5 * k, y1 - 22 * k, (x0 + x1) / 2 + 5 * k, y1 - 12 * k), fill=255)
    return big.resize((SIDE, SIDE), Image.Resampling.LANCZOS)


def badge(glyph: Image.Image, up: bool) -> Image.Image:
    mark = arrow(up)
    gap = mark.point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(7))
    a = ImageChops.subtract(glyph.getchannel("A"), gap)
    a = ImageChops.lighter(a, mark)
    out = Image.new("RGBA", glyph.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def main(sheet_a: str, sheet_b: str, sheet_m: str, sheet_f: str, sheet_g: str, sheet_h: str, sheet_i: str,
         out: Path = OUT) -> None:
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    grids = {k: list(cells(Image.open(p), 4, 3)) for k, p in (("a", sheet_a), ("b", sheet_b), ("m", sheet_m))}
    grids["f"] = list(cells(Image.open(sheet_f), 2, 2))
    grids["g"] = list(cells(Image.open(sheet_g), 2, 2))
    grids["h"] = [Image.open(sheet_h).crop(box) for box in BOXES_H]
    grids["i"] = [Image.open(sheet_i).crop(box) for box in BOXES_I]
    count = 0
    part = lambda sheet, i: white(grids[sheet][i])
    # A Guarda espelhada: o escudo de trás fica à esquerda, longe da seta do bom (no alto, à direita).
    MIRROR = {"protection"}
    # O Marcado (a mira fina) com o traço 1 px mais grosso de cada lado.
    THICKER = {"marked"}
    for name, (sheet, i) in PLAIN.items():
        clean(fit(part(sheet, i), SIDE, 0.06)).save(out / f"{name}.webp", lossless=True, exact=True, method=6)
        count += 1
    for name, (sheet, i) in STATUS.items():
        # O símbolo um pouco menor e para a esquerda, para a seta caber no canto sem cobrir o miolo.
        glyph = fit(part(sheet, i), 56, 0.04)
        if name in MIRROR:
            glyph = ImageOps.mirror(glyph)
        if name in THICKER:
            glyph.putalpha(glyph.getchannel("A").filter(ImageFilter.MaxFilter(3)))
        base = Image.new("RGBA", (SIDE, SIDE), (255, 255, 255, 0))
        base.alpha_composite(glyph, (0, 4))
        for suffix, up in (("good", True), ("bad", False)):
            clean(badge(base, up)).save(out / f"status-{name}_{suffix}.webp", lossless=True, exact=True, method=6)
            count += 1
    print("glifos:", count)


if __name__ == "__main__":
    main(*sys.argv[1:9])
