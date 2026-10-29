"""A luz prática da Rua refeita no estilo das fachadas (#170): o tambor com fogo (T_LP03 e o fogo), a emergência
(T_LP06) e o lampião (T_LP02), das folhas geradas no Nano Banana Pro (fora do Git, em images/luz-pratica-2/ do projeto
na Awesomic), para art/scenarios/, no mesmo contrato de cut_lights.py.

O jogo (scripts/world/practical_light.gd, na #154) lê a origem da luz e a boca do tambor como fração do card. Por isso
cada peça nova entra no MESMO quadro da antiga (o mesmo tamanho em px), com a âncora no mesmo lugar: a boca do tambor
em y = 95, a cúpula da emergência em (88, 118), a alça do lampião no topo e o pé embaixo. Assim a troca não mexe no
código.

Uso: python3 -B docs/design/luz-pratica/cut_lights_rua.py <pasta images/luz-pratica-2>
Sem numpy: só Pillow.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from cut_lights import (FIRE_SEAT, alpha_of, components, despill_edges, finish, fire_frames, gain_mask, halo,  # noqa: E402
                        offset, shrink, unmix, anchors)

# As peças na ordem da folha (da esquerda para a direita) e o quadro de cada uma no jogo (px).
NAMES = ["T_LP03", "T_LP06", "T_LP02"]
CARD = {"T_LP03": (232, 398), "T_LP06": (207, 279), "T_LP02": (185, 406)}
# A emergência: a cúpula em (88, 118) e a chapa com esta largura (px no card).
EMERGENCY_LIGHT = (88, 118)
EMERGENCY_PLATE = 170
# O lampião: o meio da alça em x.
LANTERN_X = 89


def resize(im: Image.Image, k: float) -> Image.Image:
    size = (max(1, round(im.width * k)), max(1, round(im.height * k)))
    return im.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def rim_row(a: Image.Image) -> int:
    """A boca do tambor: a primeira linha, de cima, em que o corpo já tem a largura cheia (as tábuas são estreitas)."""
    px = a.load()
    widths = []
    for y in range(a.height):
        xs = [x for x in range(a.width) if px[x, y] > 128]
        widths.append(xs[-1] - xs[0] if xs else 0)
    body = sorted(widths[a.height // 2:])[len(widths[a.height // 2:]) // 2]
    return next(y for y, w in enumerate(widths) if w >= body * 0.93)


def warm_red(im: Image.Image) -> Image.Image:
    """A cúpula acesa sem o rosa: a geração pintou o miolo puxando para o magenta, que no jogo lê como o fundo de
    recorte. O azul desce até o verde (o vermelho fica, e o miolo vira um branco quente)."""
    r, g, b = im.convert("RGB").split()
    b = ImageChops.darker(b, g.point(lambda v: min(255, v + 6)))
    return Image.merge("RGB", (r, g, b)).convert("RGBA")


def place(name: str, off: Image.Image, lit: Image.Image, gain: Image.Image):
    """O apagado, o aceso e o ganho no quadro do jogo, com a âncora no lugar."""
    a = off.getchannel("A")
    box = a.point(lambda v: 255 if v > 85 else 0).getbbox()
    W, H = CARD[name]
    if name == "T_LP03":
        rim = rim_row(a)
        k = (H - FIRE_SEAT["bottom_y"]) / (box[3] - rim)
        x = W / 2 - (box[0] + box[2]) / 2 * k
        y = FIRE_SEAT["bottom_y"] - rim * k
    elif name == "T_LP06":
        g = gain.point(lambda v: 255 if v else 0)
        pts = [(px, py) for py in range(g.height) for px in range(g.width) if g.getpixel((px, py))]
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        k = EMERGENCY_PLATE / (box[2] - box[0])
        x = EMERGENCY_LIGHT[0] - cx * k
        y = EMERGENCY_LIGHT[1] - cy * k
    else:
        k = H / (box[3] - box[1])
        x = LANTERN_X - (box[0] + box[2]) / 2 * k
        y = -box[1] * k
    out = []
    for im in (off, lit, gain.convert("RGBA")):
        canvas = Image.new("RGBA", (W, H))
        canvas.alpha_composite(resize(im, k), (round(x), round(y)))
        out.append(canvas)
    placed = [round(x), round(y), round(k, 4)]
    return out[0], out[1], out[2].convert("L"), placed


def fire_sheet(src: Path) -> Image.Image:
    """A folha do fogo sem o bloco marrom que a geração pôs embaixo de cada quadro: tudo da borda dele para baixo vira
    preto (o pé do fogo fica reto, na boca do tambor)."""
    sheet = Image.open(src).convert("RGB")
    w, h = sheet.size
    px = sheet.load()
    cols = 4
    for i in range(cols):
        x0, x1 = i * w // cols, (i + 1) * w // cols
        top = h
        for y in range(h // 2, h):
            n = sum(1 for x in range(x0, x1) if 25 < px[x, y][0] < 110 and px[x, y][2] < 60 and px[x, y][0] > px[x, y][1])
            if n > (x1 - x0) * 0.6:
                top = y
                break
        # A borda de cima do bloco tem uma faixa clara (a boca): ela sai junto.
        for y in range(max(0, top - 14), h):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0)
    return sheet


def save(im: Image.Image, name: str, manifest: dict, out: Path) -> None:
    im.save(out / f"{name}.webp", "WEBP", quality=88, method=6)
    manifest[name] = list(im.size)
    print(name, im.size, im.mode)


def tight(frames):
    """Os quadros na largura da base das chamas, com o ar quente em volta (a união dos quatro, na faixa de baixo): as fagulhas soltas dos lados
    alargavam o quadro, e o fogo, com 85% da largura do card, saía mais estreito que a boca do tambor. As laterais
    somem em 10 px de novo (o quad somado não mostra o corte)."""
    x0, x1 = None, None
    for f in frames:
        h = f.height
        band = f.convert("L").crop((0, int(h * 0.7), f.width, int(h * 0.9))).point(lambda v: 255 if v > 60 else 0)
        b = band.getbbox()
        if b:
            x0 = b[0] if x0 is None else min(x0, b[0])
            x1 = b[2] if x1 is None else max(x1, b[2])
    out = []
    for f in frames:
        c = f.crop((max(0, x0 - 4), 0, min(f.width, x1 + 4), f.height))
        fade = Image.new("L", c.size, 255)
        ramp = Image.linear_gradient("L").rotate(90).resize((10, c.height))
        fade.paste(ramp.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (0, 0))
        fade.paste(ramp, (c.width - 10, 0))
        # O ar quente em volta das chamas (o fogo de antes tinha esse brilho, e o glow do jogo pega nele).
        glow = c.filter(ImageFilter.GaussianBlur(16)).point(lambda v: int(v * 0.55))
        c = ImageChops.add(c, glow)
        out.append(ImageChops.multiply(c, Image.merge("RGB", (fade, fade, fade))))
    return out


def with_fire(lit: Image.Image, mask: Image.Image, frame: Image.Image):
    """O tambor aceso com o fogo por cima, só para o halo: o fogo é a luz principal, e o halo sai dele também (o pé do
    fogo na boca do tambor, com 85% da largura do card, como no jogo; o que passa do topo do card fica de fora)."""
    W, H = lit.size
    fw = round(W * FIRE_SEAT["width"])
    fh = round(fw * frame.height / frame.width)
    layer = Image.new("RGB", lit.size)
    layer.paste(frame.resize((fw, fh), Image.Resampling.LANCZOS), ((W - fw) // 2, FIRE_SEAT["bottom_y"] - fh))
    rgb = ImageChops.add(lit.convert("RGB"), layer)
    out = rgb.convert("RGBA")
    out.putalpha(255)
    return out, ImageChops.lighter(mask, layer.convert("L").point(lambda v: 255 if v > 50 else 0))


def main(src: str) -> None:
    src = Path(src)
    out = Path(__file__).resolve().parents[3] / "art/scenarios"
    assert out.is_dir()
    manifest, pieces = {}, {}
    off_raw = Image.open(src / "lp2-off.png").convert("RGB")
    on_raw = Image.open(src / "lp2-on.png").convert("RGB").resize(off_raw.size, Image.Resampling.LANCZOS)
    off = despill_edges(unmix(off_raw))
    on = despill_edges(unmix(on_raw))
    a_off = alpha_of(off, 128)
    boxes = components(a_off, 1, grow=3)
    assert len(boxes) == len(NAMES), boxes
    a_on = alpha_of(on, 128)
    fire = tight(fire_frames(fire_sheet(src / "lp2-fire.png")))
    for name, (box, region) in zip(NAMES, boxes):
        dx, dy = offset(a_off, a_on, box)
        pad = 12
        big = (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)
        own = region.crop(big)
        o = off.crop(big)
        alpha = ImageChops.multiply(o.getchannel("A"), own)
        o.putalpha(alpha)
        # O aceso com o alfa do apagado; o RGB do aceso vem da folha crua dentro do recorte (a cúpula acesa tem um miolo
        # rosado, que o unmix confundiria com o magenta do fundo).
        l = on_raw.crop((big[0] + dx, big[1] + dy, big[2] + dx, big[3] + dy)).convert("RGBA")
        edge = alpha.point(lambda v: 255 if v > 250 else 0).filter(ImageFilter.MinFilter(7))
        l = Image.composite(l, on.crop((big[0] + dx, big[1] + dy, big[2] + dx, big[3] + dy)), edge)
        if name == "T_LP06":
            l = warm_red(l)
        l.putalpha(alpha)
        gain = ImageChops.multiply(gain_mask(on_raw.crop((big[0] + dx, big[1] + dy, big[2] + dx, big[3] + dy)),
                                             off_raw.crop(big)), alpha.point(lambda v: 255 if v > 85 else 0))
        o, l, g, placed = place(name, o, l, gain)
        a = o.getchannel("A")
        lit_mask = ImageChops.multiply(g.point(lambda v: 255 if v > 128 else 0).filter(ImageFilter.MaxFilter(5)),
                                       a.point(lambda v: 255 if v > 85 else 0))
        save(finish(o), name, manifest, out)
        save(finish(l), name + "_Lit", manifest, out)
        hl, hm = l, lit_mask
        if name == "T_LP03":
            hl, hm = with_fire(l, lit_mask, fire[0])
        h = halo(hl, hm, l.size)
        if name == "T_LP03":
            # Com o fogo, o halo cheio apagava o tambor pintado no escuro: fica em 60%.
            h = h.point(lambda v: int(v * 0.6))
        save(shrink(h, 1024), name + "_Halo", manifest, out)
        pieces[name] = {"box_in_sheet": list(big), "lit_offset": [dx, dy], "placed": placed, **anchors(lit_mask, a)}
    for i, frame in enumerate(fire):
        save(shrink(frame, 512), f"T_LP03_Fire_{i}", manifest, out)
    pieces["T_LP03"]["fire_seat"] = FIRE_SEAT
    (HERE / "cut_manifest_rua.json").write_text(json.dumps({"sizes": manifest, "pieces": pieces}, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
