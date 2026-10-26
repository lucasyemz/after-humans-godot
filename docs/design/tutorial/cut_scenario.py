"""Recorta a arte do mapa do tutorial (#147) das folhas geradas no Nano Banana Pro (fora do Git, em images/tutorial/ do
projeto na Awesomic) para art/scenarios/, no contrato dos cenários de hoje (tools/sync_scenarios.py): T_<código>.webp,
WebP qualidade 88, até 1024 px no lado maior, opaco sem alfa e recortado com alfa (os cards "masked"). Os pares de busca e de porta (T_TUX*) saem com o mesmo tamanho, recortados pela mesma
caixa, como os _Open de hoje.

Uso: python3 -B docs/design/tutorial/cut_scenario.py <pasta images/tutorial>
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
SURFACES = {"T_TU01": ("tu-wall-corridor.png", 1024), "T_TU02": ("tu-floor.png", 1024), "T_TU03": ("tu-wall-platform.png", 1024),
            "T_TU09": ("tu-platform-floor.png", 1024)}
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


def main(src: str) -> None:
    src = Path(src)
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
