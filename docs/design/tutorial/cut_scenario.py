"""Recorta a arte do mapa do tutorial (#147) das folhas geradas no Nano Banana Pro (fora do Git, em images/tutorial/ do
projeto na Awesomic) para art/scenarios/, no contrato dos cenários de hoje (tools/sync_scenarios.py): T_<código>.webp,
WebP qualidade 88, até 1024 px no lado maior, opaco sem alfa e recortado com alfa (os cards "masked"). Os pares de busca e de porta (T_TUX*) saem com o mesmo tamanho, recortados pela mesma
caixa, como os _Open de hoje.

Uso: python3 -B docs/design/tutorial/cut_scenario.py <pasta images/tutorial>  (a segunda versão em <pasta>/v2)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "docs/design/hud-station"))
from cut_icons import unmix, despill_edges  # noqa: E402

OUT = ROOT / "art/scenarios"
# As superfícies opacas (paredes e piso): a imagem inteira, reduzida.
SURFACES = {"T_TU09": ("tu-platform-floor.png", 1024)}
# Os elementos recortados, um por imagem (a folha 3x2, tu-props-sheet.png, foi a referência deles); a lâmpada sai
# recortada da própria folha (ela é pequena na cena). A escada é a segunda versão (tu-ladder-2.png: de lado, até o
# alçapão no teto).
PROPS = {"T_TU04": "tu-bars.png", "T_TU05": "tu-roots.png", "T_TU06": "tu-ladder-2.png", "T_TU07": "tu-duct.png"}
# Os interativos: o fechado e o aberto (o aberto é uma edição do fechado, no mesmo quadro).
PAIRS = {"T_TUX01_Security_Door": "tu-door", "T_TUX02_Maintenance_Locker": "tu-locker", "T_TUX03_Door_Panel": "tu-panel"}

def main_body(im: Image.Image) -> Image.Image:
    """Só o desenho: some o grão e o resto de outra célula longe de um pedaço com alfa forte."""
    a = im.getchannel("A")
    near = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MaxFilter(13))
    im.putalpha(ImageChops.multiply(a, near).point(lambda v: 0 if v < 8 else v))
    return im


def clean(im: Image.Image) -> Image.Image:
    """O RGB zerado onde o alfa é 0 e o que ainda puxa para o magenta sem o azul (o metal e o concreto não têm roxo)."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            elif a < 250 and g > max(r, b):
                # A borda puxando para o verde (a sobra de quando o magenta sai): o verde não passa do maior dos outros.
                px[x, y] = (r, max(r, b), b, a)
            elif min(r, b) - g > 12:
                # Concreto e metal com um véu rosado (o reflexo do fundo na pintura): viram cinza, um pouco quente.
                v = (r * 3 + g * 6 + b) // 10
                px[x, y] = (min(255, v + 4), v, max(0, v - 2), a)
    return im


def cut(cell: Image.Image) -> Image.Image:
    return clean(main_body(despill_edges(unmix(cell))))


def shrink(im: Image.Image, side: int) -> Image.Image:
    k = min(1.0, side / max(im.size))
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.Resampling.LANCZOS)


def save(im: Image.Image, name: str) -> None:
    if im.mode == "RGBA":
        im = clean(im)
    im.save(OUT / f"{name}.webp", "WEBP", quality=88, method=6)
    print(name, im.size, im.mode)


def lit_lamp(lamp: Image.Image) -> Image.Image:
    """A lâmpada de emergência acesa (para piscar, como o _Open troca o material): só o vidro vermelho mais claro, no
    mesmo quadro da apagada. O brilho em volta é a luz pontual da cena: o jogo corta o alfa em 0,333 nos cenários, e um
    halo em degradê viraria um disco chapado."""
    on = lamp.copy()
    px = on.load()
    for y in range(on.height):
        for x in range(on.width):
            r, g, b, a = px[x, y]
            if a and r > g + 50 and r > b + 50:
                px[x, y] = (min(255, int(r * 1.35) + 40), min(255, int(g * 1.1) + 25), min(255, int(b * 1.1) + 18), a)
    return on


# A segunda versão (os ajustes do Lucas de 26/10, em images/tutorial/v2): uma parede por zona, sem repetição, com o alto
# no escuro e a sujeira na base; as aberturas (portas, celas, o túnel) vêm em magenta e viram alfa, para o escuro mais
# fundo atrás delas ser uma caixa de verdade na cena. Os pisos vistos de cima (o fundo em cima: a sujeira e a água do pé
# da parede), os objetos do chão e as silhuetas do primeiro plano (escuras e um pouco desfocadas).
WALLS = {"T_TU01": "tu2-wall-corridor.png", "T_TU11": "tu2-wall-cells.png", "T_TU12": "tu2-wall-route.png",
         "T_TU03": "tu2-wall-platform.png"}
FLOORS = {"T_TU02": "tu2-floor-corridor.png", "T_TU13": "tu2-floor-corridor-2.png"}
# As caixas (px) de cada peça nas folhas, medidas pelos pedaços conexos fora do magenta.
SHEET_PROPS = {"T_TU14": (40, 72, 420, 356), "T_TU15": (504, 44, 860, 368), "T_TU16": (960, 40, 1304, 380),
               "T_TU17": (48, 436, 452, 700), "T_TU19": (1012, 464, 1344, 696)}
# (A raiz caída da folha, em 504, 420, 984, 732, saiu igual à T_TU05 e ficou de fora.)
SHEET_FRONT = {"T_TU20": (48, 24, 1184, 232), "T_TU21": (52, 268, 836, 544), "T_TU22": (1196, 80, 1316, 740)}
# (A grade de proteção da folha, em 452, 548, 1136, 744, ficou de fora: no chão perto da câmera ela sai do quadro.)


def keyed_wall(im: Image.Image) -> Image.Image:
    """A parede com as aberturas em alfa: o magenta (e o halo rosado em volta) sai; a borda fica dura (o jogo corta o
    alfa em 0,333)."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            if r > 150 and b > 150 and g < 120 and min(r, b) - g > 70:
                px[x, y] = (0, 0, 0, 0)
    hole = im.getchannel("A").point(lambda v: 255 if v == 0 else 0).filter(ImageFilter.MaxFilter(5))
    a = ImageChops.subtract(im.getchannel("A"), hole)
    im.putalpha(a)
    # O alto no escuro, igual nas quatro: o terço de cima vai para o preto (a pintura do corredor quase não escurecia).
    px = im.load()
    for y in range(im.height):
        k = min(1.0, y / (im.height * 0.36)) ** 1.4
        if k >= 1.0:
            break
        for x in range(im.width):
            r, g, b, al = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), al)
    return clean(im)


def front(im: Image.Image) -> Image.Image:
    """A peça do primeiro plano: um pouco mais escura (a luz da cena a recorta) e desfocada, com o alfa macio. No jogo de
    hoje o alfa é cortado em 0,333 (a silhueta fica um pouco mais larga); com o card em alpha blend, que é do código, o
    desfoque aparece inteiro."""
    rgb = im.convert("RGB").point(lambda v: int(v * 0.85)).filter(ImageFilter.GaussianBlur(4))
    a = im.getchannel("A").filter(ImageFilter.GaussianBlur(4))
    rgb.putalpha(a)
    return rgb


def rework(src: Path) -> None:
    for name, file in WALLS.items():
        save(shrink(keyed_wall(Image.open(src / file)), 1024), name)
    for name, file in FLOORS.items():
        save(shrink(Image.open(src / file).convert("RGB"), 1024), name)
    # O piso da rota do Nick: o do corredor espelhado (as zonas a cada duas amostras repetiam as mesmas poças).
    save(shrink(Image.open(src / FLOORS["T_TU02"]).convert("RGB").transpose(Image.Transpose.FLIP_LEFT_RIGHT), 1024), "T_TU24")
    bbox = lambda im: im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    for sheet, boxes, finish in (("tu2-props-sheet.png", SHEET_PROPS, None), ("tu2-foreground-sheet.png", SHEET_FRONT, front)):
        whole = Image.open(src / sheet)
        for name, (x0, y0, x1, y1) in boxes.items():
            piece = cut(whole.crop((max(0, x0 - 12), max(0, y0 - 12), x1 + 12, y1 + 12)))
            piece = piece.crop(bbox(piece))
            save(shrink(finish(piece) if finish else piece, 1024), name)


def main(src: str) -> None:
    src = Path(src)
    rework(src / "v2")
    for name, (file, side) in SURFACES.items():
        save(shrink(Image.open(src / file).convert("RGB"), side), name)
    bbox = lambda im: im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    for name, file in PROPS.items():
        im = cut(Image.open(src / file))
        save(shrink(im.crop(bbox(im)), 1024), name)
    # A lâmpada na folha 3x2 (1264 x 848), pela caixa medida: a célula pega uma ponta da plataforma ao lado.
    lamp = cut(Image.open(src / "tu-props-sheet.png").crop((468, 505, 640, 760)))
    lamp = lamp.crop(bbox(lamp))
    save(lamp, "T_TU08")
    save(lit_lamp(lamp), "T_TU08_Lit")
    train = cut(Image.open(src / "tu-train-sheet-2.png"))
    save(shrink(train.crop(bbox(train)), 1024), "T_TU10")
    for name, stem in PAIRS.items():
        c, o = cut(Image.open(src / f"{stem}-closed.png")), cut(Image.open(src / f"{stem}-open.png"))
        box = ImageChops.lighter(c.getchannel("A"), o.getchannel("A")).point(lambda v: 255 if v > 8 else 0).getbbox()
        save(shrink(c.crop(box), 1024), name)
        save(shrink(o.crop(box), 1024), f"{name}_Open")

if __name__ == "__main__":
    main(sys.argv[1])
