"""Kit da Estação (relatório da volta e Sala dos Personagens): peças desenhadas por código, no idioma do kit da luta.

Aço grafite arranhado (o mesmo material de art/ui/kit/combat/steel_material.webp), bisel fino, cantos chanfrados e o
detalhe âmbar em dois cantos opostos. Nenhum texto nas imagens. Grava as peças em art/ui/kit/station/ e o manifesto
assets.json (tamanho, margens de 9-slice na ordem esquerda/cima/direita/baixo, área de conteúdo, âncora e sha256).

Uso: python3 docs/design/hud-station/build_kit.py    (só Pillow)
"""
import hashlib
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "art/ui/kit/station"
S = 4  # supersample das linhas e máscaras

AMBER = (240, 160, 32)
AMBER_HOT = (255, 228, 161)
BEVEL = (58, 62, 68)
EDGE = (8, 9, 10)

STEEL = Image.open(ROOT / "art/ui/kit/combat/steel_material.webp").convert("RGB")
ROWS = {}


def tile(size, tint, amount):
    """O aço repetido no tamanho pedido, misturado a uma cor (como o kit da luta: #191c1f a 42%)."""
    w, h = size
    out = Image.new("RGB", size)
    for x in range(0, w, STEEL.width):
        for y in range(0, h, STEEL.height):
            out.paste(STEEL, (x, y))
    return Image.blend(out, Image.new("RGB", size, tint), amount).convert("RGBA")


def chamfer(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def mask(size, poly):
    w, h = size
    m = Image.new("L", (w * S, h * S))
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in poly], fill=255)
    return m.resize(size, Image.Resampling.LANCZOS)


def lines(size, strokes):
    """Linhas finas com antisserrilhado: [(pontos, cor RGBA, largura em px)]."""
    w, h = size
    layer = Image.new("RGBA", (w * S, h * S))
    d = ImageDraw.Draw(layer)
    for pts, color, width in strokes:
        d.line([(x * S, y * S) for x, y in pts], fill=color, width=max(1, round(width * S)), joint="curve")
    return layer.resize(size, Image.Resampling.LANCZOS)


def wear(im, region, seed, amount=0.05):
    """Desgaste: pontos de ferrugem e riscos claros só no aro."""
    rng = random.Random(seed)
    w, h = im.size
    layer = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(layer)
    px = region.load()
    for _ in range(int(w * h * amount)):
        x, y = rng.randrange(w), rng.randrange(h)
        if px[x, y] < 128:
            continue
        if rng.random() < 0.65:
            r = rng.choice([1, 1, 1, 2])
            d.ellipse((x, y, x + r, y + r), fill=(rng.randrange(120, 170), rng.randrange(70, 96), 38, rng.randrange(70, 170)))
        else:
            d.line((x, y, x + rng.randrange(2, 7), y + rng.randrange(-1, 2)), fill=(150, 150, 142, rng.randrange(30, 80)))
    im.alpha_composite(layer)


def tab_poly(x0, y0, x1, y1, c):
    """A aba: chanfro só nos cantos de cima; embaixo ela encosta reta na peça de baixo."""
    return [(x0, y1), (x0, y0 + c), (x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1)]


def plate(size, cut=12, rim=6, amber=True, inner="steel", seed=1, amber_len=None, shape="octagon"):
    """A chapa chanfrada: aro de aço com bisel, miolo de aço mais escuro e o âmbar nos cantos superior esquerdo e inferior
    direito. inner: "steel", "dark" (caixa de texto embutida) ou None (moldura vazada, o conteúdo aparece por baixo).
    shape "tab": chanfro só em cima (a aba que encosta numa barra); o âmbar vai para os dois cantos de cima."""
    w, h = size
    top = 0
    ri = rim
    ic = max(3, round(cut - ri * 0.41))
    if shape == "tab":
        outer = tab_poly(0, top, w - 1, h - 1, cut)
        inner_poly = tab_poly(ri, top + ri, w - 1 - ri, h - 1 - ri, ic)
    else:
        outer = chamfer(0, top, w - 1, h - 1, cut)
        inner_poly = chamfer(ri, top + ri, w - 1 - ri, h - 1 - ri, ic)
    outer_m = mask(size, outer)
    inner_m = mask(size, inner_poly)
    rim_m = Image.composite(Image.new("L", size, 0), outer_m, inner_m)

    im = Image.new("RGBA", size)
    body = tile(size, (58, 48, 40), 0.42)
    im.paste(body, (0, 0), outer_m)
    if inner == "steel":
        im.paste(tile(size, (25, 28, 31), 0.45), (0, 0), inner_m)
    elif inner == "dark":
        im.paste(tile(size, (14, 16, 18), 0.72), (0, 0), inner_m)
    else:
        a = im.getchannel("A")
        im.putalpha(Image.composite(Image.new("L", size, 0), a, inner_m))
    wear(im, rim_m, seed)

    # Luz de cima: o aro claro no alto e escuro embaixo.
    shade = Image.new("RGBA", size)
    sd = ImageDraw.Draw(shade)
    for y in range(h):
        k = y / max(1, h - 1)
        sd.line((0, y, w, y), fill=(255, 255, 255, int(26 * (1 - k))) if k < 0.5 else (0, 0, 0, int(60 * (k - 0.5))))
    im.alpha_composite(Image.composite(shade, Image.new("RGBA", size), rim_m))

    strokes = [
        (outer + [outer[0]], (*EDGE, 255), 1.6),
        ([(x + (1 if x < w / 2 else -1), y + (1 if y < h / 2 else -1)) for x, y in outer] + [outer[0]], (168, 164, 152, 190), 1.2),
        (inner_poly + [inner_poly[0]], (*EDGE, 235), 2.2),
        ([(x + (1.6 if x < w / 2 else -1.6), y + (1.6 if y < h / 2 else -1.6)) for x, y in inner_poly] + [inner_poly[0]], (*BEVEL, 255), 1.0),
    ]
    im.alpha_composite(lines(size, strokes))
    if amber:
        n = amber_len or max(10, round(cut * 1.15))
        o = ri * 0.5 + 1.5
        a1 = [(o + 1, top + cut + o - 1 + n * 0.0), (cut + o - 1, top + o + 1)]
        a2 = [(w - 1 - cut - o + 1, h - 1 - o - 1), (w - 1 - o - 1, h - 1 - cut - o + 1)]
        if shape == "tab":
            a2 = [(w - 1 - cut - o + 1, top + o + 1), (w - 1 - o - 1, top + cut + o - 1)]
        glow = lines(size, [(a1, (*AMBER, 255), 3.4), (a2, (*AMBER, 255), 3.4)]).filter(ImageFilter.GaussianBlur(1.6))
        im.alpha_composite(glow)
        im.alpha_composite(lines(size, [(a1, (*AMBER, 255), 2.6), (a2, (*AMBER, 255), 2.6), (a1, (*AMBER_HOT, 200), 0.8), (a2, (*AMBER_HOT, 200), 0.8)]))
    # Nada fora da silhueta.
    alpha = Image.composite(im.getchannel("A"), Image.new("L", size, 0), outer_m)
    im.putalpha(alpha)
    return im


def amber_frame(size, cut=10, width=3.0, inner_glow=True):
    """Moldura de seleção âmbar inteira (aba de herói escolhida, linha escolhida, cartão de melhoria escolhido)."""
    w, h = size
    poly = chamfer(1.5, 1.5, w - 2.5, h - 2.5, cut)
    layer = lines(size, [(poly + [poly[0]], (*AMBER, 255), width)])
    glow = layer.filter(ImageFilter.GaussianBlur(3))
    glow.putalpha(glow.getchannel("A").point(lambda v: min(255, v * 2)))
    out = Image.new("RGBA", size)
    out.alpha_composite(glow)
    out.alpha_composite(layer)
    out.alpha_composite(lines(size, [(poly + [poly[0]], (*AMBER_HOT, 210), 0.9)]))
    return out


def amber_button(size, cut=14, state="normal"):
    """O botão principal âmbar: chapa âmbar riscada com aro escuro e as divisas ‹ › nas pontas."""
    w, h = size
    out = Image.new("RGBA", size)
    outer = chamfer(0, 0, w - 1, h - 1, cut)
    rim = 5
    inner = chamfer(rim, rim, w - 1 - rim, h - 1 - rim, max(4, round(cut - rim * 0.41)))
    out.paste(tile(size, (52, 54, 58), 0.35), (0, 0), mask(size, outer))
    face = Image.new("RGBA", size)
    fd = ImageDraw.Draw(face)
    top_c, bottom_c = ((245, 178, 52), (214, 132, 16)) if state != "disabled" else ((112, 104, 90), (84, 78, 68))
    if state == "pressed":
        top_c, bottom_c = (222, 146, 24), (196, 120, 14)
    for y in range(h):
        k = y / max(1, h - 1)
        fd.line((0, y, w, y), fill=tuple(round(top_c[i] + (bottom_c[i] - top_c[i]) * k) for i in range(3)) + (255,))
    scratches = tile(size, (0, 0, 0), 0.0).convert("L").point(lambda v: 255 - v)
    face = Image.composite(face, Image.blend(face, Image.new("RGBA", size, (90, 50, 0, 255)), 0.18), scratches.point(lambda v: 255 if v > 150 else 0))
    out.paste(face, (0, 0), mask(size, inner))
    # Divisas escuras nas pontas, como no alvo.
    chev = []
    # As divisas apontam para dentro (› … ‹), como no alvo.
    for x, sgn in [(rim + 12, 1), (w - 1 - rim - 12, -1)]:
        chev.append(([(x, h / 2 - 9), (x + sgn * 6, h / 2), (x, h / 2 + 9)], (40, 26, 6, 230), 2.6))
    hi = [((inner[0][0], inner[0][1] + 1), (inner[1][0], inner[1][1] + 1)), ]
    out.alpha_composite(lines(size, chev + [(list(hi[0]), (255, 236, 180, 170), 1.2),
                                       (outer + [outer[0]], (*EDGE, 255), 1.6),
                                       (inner + [inner[0]], (60, 36, 4, 255), 1.4)]))
    if state == "focus":
        ring = chamfer(1.5, 1.5, w - 2.5, h - 2.5, cut)
        layer = lines(size, [(ring + [ring[0]], (*AMBER_HOT, 255), 2.4)])
        out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2.2)))
        out.alpha_composite(layer)
    out.putalpha(Image.composite(out.getchannel("A"), Image.new("L", size, 0), mask(size, outer)))
    return out


def pill(size, cut=8):
    """Pílula de estado neutra e clara, para o jogo tingir (modulate) com a cor do estado."""
    w, h = size
    outer = chamfer(0, 0, w - 1, h - 1, cut)
    im = Image.new("RGBA", size)
    face = Image.new("RGBA", size)
    fd = ImageDraw.Draw(face)
    for y in range(h):
        k = y / max(1, h - 1)
        v = round(250 - 34 * k)
        fd.line((0, y, w, y), fill=(v, v, v, 255))
    grain = tile(size, (0, 0, 0), 0.0).convert("L").point(lambda v: 255 if v > 150 else 0)
    face = Image.composite(Image.blend(face, Image.new("RGBA", size, (170, 170, 170, 255)), 0.25), face, grain)
    im.paste(face, (0, 0), mask(size, outer))
    inner = chamfer(2, 2, w - 3, h - 3, cut - 1)
    im.alpha_composite(lines(size, [(outer + [outer[0]], (20, 20, 20, 255), 1.6), (inner[:4], (255, 255, 255, 140), 1.0)]))
    im.putalpha(Image.composite(im.getchannel("A"), Image.new("L", size, 0), mask(size, outer)))
    return im


def fill_tintable(size, cut=4):
    """Preenchimento de barra neutro (vida, instinto, XP): o jogo tinge; brilho em cima, sombra embaixo."""
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        k = y / max(1, h - 1)
        v = round(255 * (0.78 + 0.32 * (1 - abs(k - 0.3) / 0.8)))
        d.line((0, y, w, y), fill=(min(255, v), min(255, v), min(255, v), 255))
    d.line((2, 1, w - 3, 1), fill=(255, 255, 255, 255))
    im.putalpha(mask(size, chamfer(0, 0, w - 1, h - 1, cut)))
    return im


def groove(size, vertical=True):
    """Divisão da faixa: o sulco escuro com o fio claro do lado da luz."""
    w, h = size
    if vertical:
        strokes = [([(w / 2 - 1, 4), (w / 2 - 1, h - 5)], (*EDGE, 255), 2.4), ([(w / 2 + 1.2, 4), (w / 2 + 1.2, h - 5)], (96, 98, 96, 200), 1.0),
                   ([(w / 2 - 3, 0), (w / 2 + 3, 0)], (*AMBER, 255), 2.0), ([(w / 2 - 3, h - 1), (w / 2 + 3, h - 1)], (*AMBER, 255), 2.0)]
    else:
        strokes = [([(4, h / 2 - 1), (w - 5, h / 2 - 1)], (*EDGE, 255), 2.4), ([(4, h / 2 + 1.2), (w - 5, h / 2 + 1.2)], (96, 98, 96, 200), 1.0)]
    return lines(size, strokes)


def medal(size):
    """Medalhão do nível: octógono de aço com o aro âmbar; o número é da Godot."""
    w, h = size
    c = round(w * 0.29)
    im = plate(size, cut=c, rim=6, amber=False, inner="dark", seed=31)
    ring = chamfer(3, 3, w - 4, h - 4, c - 1)
    ring2 = chamfer(7.5, 7.5, w - 8.5, h - 8.5, c - 3)
    im.alpha_composite(lines(size, [(ring + [ring[0]], (*AMBER, 255), 2.2), (ring2 + [ring2[0]], (*AMBER, 140), 1.0)]))
    return im


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name, im, slices=None, content=None, note="", anchor=(0, 0), tint=None):
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < 3 else v)
    rgb = Image.composite(im.convert("RGB"), Image.new("RGB", im.size), a)
    rgb.putalpha(a)
    path = OUT / f"{name}.webp"
    rgb.save(path, lossless=True, method=6)
    row = {"file": f"art/ui/kit/station/{name}.webp", "size": list(im.size), "nine_slice_ltrb": slices,
           "content_xywh": content, "anchor": list(anchor), "note": note, "sha256": sha(path)}
    if tint:
        row["tint"] = tint
    ROWS[name] = row

def round_strip(size=(720, 64)):
    """A ordem da rodada numa faixa só: o bolso escuro do nome (RODADA 1) à esquerda, o sulco, o elo âmbar com o ponto e,
    daí em diante, a calha dos retratos. O bolso e o elo ficam dentro da margem esquerda do 9-slice."""
    w, h = size
    im = plate(size, cut=14, rim=5, seed=51, amber_len=14)
    pocket = plate((196, h - 12), cut=10, rim=3, amber=False, inner="dark", seed=52)
    im.alpha_composite(pocket, (6, 6))
    im.alpha_composite(groove((12, h - 12)), (200, 6))
    y = h / 2
    link = lines(size, [([(212, y), (240, y)], (*AMBER, 255), 2.2)])
    im.alpha_composite(link.filter(ImageFilter.GaussianBlur(1.4)))
    im.alpha_composite(link)
    im.alpha_composite(mask_fill(size, [(226, y - 5), (231, y), (226, y + 5), (221, y)], AMBER))
    return im


def mask_fill(size, poly, color, alpha=255):
    layer = Image.new("RGBA", size, (*color, 0))
    layer.putalpha(mask(size, poly).point(lambda v: v * alpha // 255))
    return layer


def ability_header(size=(624, 56)):
    """A barra da habilidade: o bolso do ícone à esquerda, o nome no meio e, depois do sulco, a casa do dano (4–6)."""
    w, h = size
    im = plate(size, cut=12, rim=5, seed=53, amber_len=12)
    im.alpha_composite(plate((48, 46), cut=8, rim=3, amber=False, inner="dark", seed=54), (5, 5))
    im.alpha_composite(groove((12, h - 10)), (w - 122, 5))
    im.alpha_composite(plate((106, 46), cut=8, rim=3, amber=False, inner="dark", seed=55), (w - 112, 5))
    return im


def ability_slot(state="normal", size=(132, 132)):
    """O quadrado da habilidade: moldura vazada (o ícone pintado aparece por baixo, 116 px), com um bolso no canto de
    baixo à direita para a tecla. Pressionado: aro mais escuro e sombra por dentro (o ícone desce 2 px no jogo).
    Desabilitado: aro apagado e riscas nos cantos (o ícone fica cinza no jogo e o motivo aparece no foco)."""
    w, h = size
    im = plate(size, cut=12, rim=7, amber=state != "disabled", inner=None, seed=56 if state == "normal" else 57, amber_len=12)
    if state == "pressed":
        shade = Image.new("RGBA", size, (0, 0, 0, 0))
        inner = mask(size, chamfer(7, 7, w - 8, h - 8, 8))
        sh = Image.new("L", size, 0)
        ImageDraw.Draw(sh).rectangle((7, 7, w - 8, 20), fill=150)
        sh = sh.filter(ImageFilter.GaussianBlur(5))
        shade.putalpha(Image.composite(sh, Image.new("L", size, 0), inner))
        dark = Image.new("RGBA", size, (0, 0, 0, 120))
        dark.putalpha(Image.composite(Image.new("L", size, 120), Image.new("L", size, 0), mask(size, chamfer(0, 0, w - 1, h - 1, 12))))
        im.alpha_composite(dark)
        im.alpha_composite(shade)
    if state == "disabled":
        a = im.getchannel("A")
        gray = im.convert("L").point(lambda v: round(v * 0.7)).convert("RGBA")
        gray.putalpha(a)
        im = gray
        # O véu escuro por dentro (o ícone aparece apagado mesmo quando já é cinza) e a faixa diagonal de riscas.
        veil = Image.new("RGBA", size, (10, 11, 12, 0))
        veil.putalpha(mask(size, chamfer(7, 7, w - 8, h - 8, 8)).point(lambda v: v * 150 // 255))
        im.alpha_composite(veil)
        band = Image.new("L", size, 0)
        bd = ImageDraw.Draw(band)
        for i in range(-24, 25, 8):
            bd.line([(i + 4, h + 4), (w + 4 + i, -4 + 0)], fill=255, width=3)
        bandmask = Image.new("L", size, 0)
        ImageDraw.Draw(bandmask).polygon([(0, h - 1 - 40), (w - 1 - 40, 0), (w - 1, 0), (w - 1, 40), (40, h - 1), (0, h - 1)], fill=255)
        stripes = Image.new("RGBA", size, (176, 170, 156, 0))
        stripes.putalpha(Image.composite(band, Image.new("L", size, 0), Image.composite(bandmask, Image.new("L", size, 0), mask(size, chamfer(7, 7, w - 8, h - 8, 8)))).point(lambda v: v * 120 // 255))
        im.alpha_composite(stripes)
    return im


def selected_corners(size=(132, 132), cut=10, arm=22):
    """A escolha persistente nos cantos (habilidade escolhida, barra de quem age): cantoneiras âmbar grossas que seguem o
    chanfro, com o núcleo claro e um fio âmbar fino ligando tudo. O foco de navegação (focus_frame) vai por cima."""
    w, h = size
    o = 2.5
    corners = []
    for sx, sy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
        x0 = o if sx > 0 else w - 1 - o
        y0 = o if sy > 0 else h - 1 - o
        corners.append([(x0, y0 + sy * arm), (x0, y0 + sy * cut), (x0 + sx * cut, y0), (x0 + sx * arm, y0)])
    thick = lines(size, [(c, (*AMBER, 255), 5.0) for c in corners])
    out = Image.new("RGBA", size)
    glow = thick.filter(ImageFilter.GaussianBlur(3))
    glow.putalpha(glow.getchannel("A").point(lambda v: min(255, v * 2)))
    out.alpha_composite(glow)
    ring = chamfer(o, o, w - 1 - o, h - 1 - o, cut)
    out.alpha_composite(lines(size, [(ring + [ring[0]], (*AMBER, 200), 1.4)]))
    out.alpha_composite(thick)
    out.alpha_composite(lines(size, [(c, (*AMBER_HOT, 230), 1.4) for c in corners]))
    return out


def actor_ring(size=(256, 80)):
    """O anel no chão de quem age: um octógono chanfrado (o mesmo chanfro do kit) visto em perspectiva, âmbar com o núcleo
    claro e o halo, as divisas ‹ › apontando para fora nos lados e a marca na frente. Sem fatiar; âncora no centro (os pés)."""
    w, h = size
    cx, cy = w / 2, h / 2
    rx, ry = 98, 24

    def octo(rx, ry):
        pts = []
        for i in range(8):
            a = math.radians(i * 45)
            pts.append((cx + rx * 1.04 * math.cos(a), cy + ry * 1.04 * math.sin(a)))
        return pts
    ring = octo(rx, ry)
    inner = octo(rx - 10, ry - 4)
    out = Image.new("RGBA", size)
    floor = Image.new("RGBA", size, (*AMBER, 0))
    floor.putalpha(mask(size, ring).point(lambda v: v * 22 // 255).filter(ImageFilter.GaussianBlur(6)))
    out.alpha_composite(floor)
    main = lines(size, [(ring + [ring[0]], (*AMBER, 255), 3.2), (inner + [inner[0]], (*AMBER, 90), 1.0)])
    halo = main.filter(ImageFilter.GaussianBlur(5))
    halo.putalpha(halo.getchannel("A").point(lambda v: min(255, v * 3)))
    bloom = main.filter(ImageFilter.GaussianBlur(9))
    bloom.putalpha(bloom.getchannel("A").point(lambda v: min(255, v * 2)))
    out.alpha_composite(bloom)
    out.alpha_composite(halo)
    out.alpha_composite(main)
    chev = []
    for sgn in (-1, 1):
        x = cx + sgn * (rx * 1.04 + 10)
        chev.append(([(x - sgn * 4, cy - 8), (x + sgn * 6, cy), (x - sgn * 4, cy + 8)], (*AMBER, 255), 3.0))
        chev.append(([(x - sgn * 12, cy - 6), (x - sgn * 3, cy), (x - sgn * 12, cy + 6)], (*AMBER, 200), 2.0))
    front = [(cx - 9, cy + ry * 1.04 + 1), (cx, cy + ry * 1.04 + 7), (cx + 9, cy + ry * 1.04 + 1)]
    chev.append((front, (*AMBER, 255), 2.6))
    c = lines(size, chev)
    out.alpha_composite(c.filter(ImageFilter.GaussianBlur(2)))
    out.alpha_composite(c)
    out.alpha_composite(lines(size, [(ring + [ring[0]], (*AMBER_HOT, 255), 2.0)] + [(pts, (*AMBER_HOT, 220), 1.0) for pts, _, _ in chev]))
    return out


def faction_mark(side, size=(28, 56)):
    """A forma que diz o lado sem depender da cor (daltonismo e cinza): uma tampa de aço na ponta esquerda da barra.
    Herói: a aba que sobe 12 px acima da barra. Inimigo: dois dentes que descem 12 px abaixo dela."""
    w, h = size
    bar_top = 12 if side == "ally" else 0
    bar_bottom = bar_top + 44
    if side == "ally":
        poly = [(0, bar_top + 8), (4, bar_top + 4), (4, 4), (8, 0), (w - 5, 0), (w - 1, 4), (w - 1, bar_bottom - 1), (8, bar_bottom - 1), (0, bar_bottom - 9)]
    else:
        poly = [(0, 8), (8, 0), (w - 1, 0), (w - 1, bar_bottom - 1), (w - 2, bar_bottom - 1), (w - 8, h - 1), (w - 14, bar_bottom - 1),
                (w - 15, bar_bottom - 1), (w - 21, h - 1), (w - 27, bar_bottom - 1), (8, bar_bottom - 1), (0, bar_bottom - 9)]
    m = mask(size, poly)
    im = Image.new("RGBA", size)
    im.paste(tile(size, (58, 48, 40), 0.42), (0, 0), m)
    shade = Image.new("RGBA", size)
    sd = ImageDraw.Draw(shade)
    for y in range(h):
        k = y / max(1, h - 1)
        sd.line((0, y, w, y), fill=(255, 255, 255, int(40 * (1 - k))) if k < 0.5 else (0, 0, 0, int(70 * (k - 0.5))))
    im.alpha_composite(Image.composite(shade, Image.new("RGBA", size), m))
    wear(im, m, 61 if side == "ally" else 62, amount=0.015)
    # A marca gravada: a divisa para cima (herói) ou o X (inimigo), clara, legível também em cinza.
    mid = (bar_top + bar_bottom) / 2
    if side == "ally":
        mark = [([(7, mid + 4), (14, mid - 4), (21, mid + 4)], (225, 220, 205, 255), 2.8)]
    else:
        mark = [([(8, mid - 6), (20, mid + 6)], (225, 220, 205, 255), 2.8), ([(20, mid - 6), (8, mid + 6)], (225, 220, 205, 255), 2.8)]
    im.alpha_composite(lines(size, [(poly + [poly[0]], (*EDGE, 255), 1.8),
                                    ([(x + (1 if x < w / 2 else -1), y + (1 if y < h / 2 else -1)) for x, y in poly[:5]], (168, 164, 152, 190), 1.1)] + mark))
    im.putalpha(Image.composite(im.getchannel("A"), Image.new("L", size, 0), m))
    return im


def combat_pieces():
    save("corridor_strip", plate((720, 72), cut=14, rim=5, seed=64, amber_len=14), [24, 16, 24, 16], [24, 8, 672, 56],
         "O corredor da exploração (o nome do trecho em cima e as dez casas): a faixa lisa, sem o bolso do nome da ordem da "
         "rodada. Centro em TILE_FIT. Mesmas medidas da faixa do Codex que o corredor usava.")
    save("round_strip", round_strip(), [244, 20, 24, 20], [18, 2, 688, 60],
         "A ordem da rodada (720x64 em x 636, y 30): o nome RODADA 1 (30, Maior 39) no bolso escuro (desenho de x 6 a 202, texto de 18 a 196), o elo âmbar "
         "desenhado em x 212-240 e, a partir de x 244, os retratos em square_portrait 60 com passo 68 (fundo #192026 nos heróis, "
         "#421b1b nas máquinas). Quem age: selected_frame por cima do retrato. Quem já agiu sai da fila. Esticar só o miolo.")
    save("ability_header", ability_header(), [60, 16, 124, 16], [8, 6, 608, 44],
         "A barra da habilidade (624x56): ícone 40 no bolso de x 9-49, o nome (32, Maior 42) de x 64 e a casa do dano à direita "
         "(4–6, 28, Maior 36) no bolso de x 512-618. As duas pontas ficam fora do esticar.")
    save("target_tab", plate((336, 40), cut=10, rim=4, amber=True, inner="dark", seed=58, amber_len=10, shape="tab"),
         [16, 12, 16, 4], [14, 4, 308, 36],
         "A aba ESCOLHA UM ALVO (26, Maior 34) em cima da barra da habilidade, encostada nela (a base é reta). Habilidade sem "
         "alvo: o texto do motivo na cor de perigo, na mesma aba.")
    slot_notes = {
        "normal": "O quadrado da habilidade (132x132, passo 160): o ícone pintado 116 por baixo, a tecla em key_tab 42 em x+90, "
                  "y+90. Escolhida: selected_corners; foco: focus_frame. Usos e recarga: cost_chip no canto de cima.",
        "pressed": "Pressionado: aro escuro e sombra por dentro; o ícone desce 2 px e o alvo de toque não muda.",
        "disabled": "Sem uso: aro apagado sem âmbar, véu escuro por dentro e faixa diagonal de riscas (lê-se sobre qualquer "
                    "ícone). O ícone fica cinza, a key_tab apaga (opacidade 0,55) e o motivo da sessão aparece no foco.",
    }
    for state in ["normal", "pressed", "disabled"]:
        suffix = "" if state == "normal" else f"_{state}"
        save(f"ability_slot{suffix}", ability_slot(state), [20, 20, 20, 20], [8, 8, 116, 116], slot_notes[state])
    save("selected_corners", selected_corners(), [24, 22, 24, 22], None,
         "A escolha persistente em cantoneiras âmbar (a habilidade escolhida e a barra de 44 de quem age). O foco de navegação "
         "(focus_frame) é outra camada e pode somar.")
    save("actor_ring", actor_ring(), None, None,
         "O anel no chão de quem age (256x80 sem escala, centro nos pés: x do ator, y 748 na captura). Decalque sob a unidade, com depth test. Reduzir efeitos: "
         "sem pulso. Não fatiar.", anchor=(128, 40))
    save("ally_mark", faction_mark("ally"), None, [0, 12, 28, 44],
         "A forma do herói: tampa de aço na ponta esquerda da barra de vida no mundo (main_bar 200x44; no Maior, 200x46 e a tampa "
         "escala por igual, 46/44), com a aba que sobe 12 px "
         "e a divisa para cima. Entra no daltonismo, quando a cor sozinha não basta. Âncora: o canto da barra.",
         anchor=(0, 12))
    save("enemy_mark", faction_mark("enemy"), None, [0, 0, 28, 44],
         "A forma do inimigo: tampa de aço na ponta esquerda da barra, com o X e dois dentes que descem 12 px. Entra nos "
         "perfis com daltonismo, quando a cor sozinha não basta. Âncora: o canto da barra.", anchor=(0, 0))
    badge = plate((22, 22), cut=5, rim=2, amber=False, inner="dark", seed=63)
    badge.alpha_composite(lines((22, 22), [([(7, 7), (15, 15)], (225, 220, 205, 255), 2.4), ([(15, 7), (7, 15)], (225, 220, 205, 255), 2.4)]))
    save("enemy_badge", badge, None, None,
         "O X do inimigo no canto de baixo à direita do retrato da ordem da rodada, nos perfis com daltonismo (o fundo vermelho "
         "das máquinas some no cinza). Não fatiar.", anchor=(22, 22))


def star_icon(filled=True, size=64):
    """A estrela das notas (1 a 3): glifo branco de um tom, tingido pelo jogo. A vazia é o contorno, para a nota se ler
    também no cinza e no daltonismo (forma, não só cor)."""
    k = S
    cx, cy, ro, ri = size * k / 2, size * k * 0.53, size * k * 0.47, size * k * 0.19
    pts = [(cx + (ro if i % 2 == 0 else ri) * math.sin(i * math.pi / 5), cy - (ro if i % 2 == 0 else ri) * math.cos(i * math.pi / 5)) for i in range(10)]
    big = Image.new("L", (size * k, size * k), 0)
    d = ImageDraw.Draw(big)
    if filled:
        d.polygon(pts, fill=255)
    else:
        d.line(pts + [pts[0], pts[1]], fill=255, width=round(5 * k), joint="curve")
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    im.putalpha(big.resize((size, size), Image.Resampling.LANCZOS))
    return im


def adjust_pieces():
    """Lote 5 (#109): a vida prevista do acampamento e as estrelas do popup de fim de luta."""
    # Sem o chanfro dos lados: a peça continua o bar_fill e se repete na largura (TILE), para as riscas manterem o passo
    # em qualquer tamanho (a prévia da Ração tem cerca de 20 px; a de um curativo, 50).
    stripes = fill_tintable((64, 16))
    stripes.putalpha(Image.new("L", (64, 16), 255))
    # Riscas diagonais de 4 px, a cada 8: a vida prevista se separa da vida de agora também pela forma (cinza e daltonismo).
    a = stripes.getchannel("A")
    band = Image.new("L", (64, 16), 0)
    d = ImageDraw.Draw(band)
    for x in range(-16, 80, 8):
        d.polygon([(x, 16), (x + 4, 16), (x + 20, 0), (x + 16, 0)], fill=255)
    stripes.putalpha(Image.composite(a, a.point(lambda v: v * 150 // 255), band))
    save("bar_preview", stripes, [0, 4, 0, 4], [0, 0, 64, 16],
         "A vida prevista (acampamento, com o foco num cuidado): por cima do bar_fill, do fim da vida de agora até a "
         "prevista, tingida de verde claro (#a6e3ae; azul claro #a9d8f5 no daltonismo). Riscas: forma, além da cor. "
         "Na largura, TILE (axis_stretch_horizontal), com a altura da barra: as riscas mantêm o passo de 8 px.",
         tint={"normal": "#a6e3ae", "colorblind": "#a9d8f5"})
    ROWS["bar_preview"]["axis_stretch_horizontal"] = "TILE"
    (OUT / "icons").mkdir(exist_ok=True)
    for name, filled in [("star", True), ("star_empty", False)]:
        icon = star_icon(filled)
        icon.save(OUT / "icons" / f"{name}.webp", lossless=True, method=6)


def stroke_icon(strokes, size=64, width=6):
    """Glifo branco de um tom desenhado em linhas (strokes: listas de pontos na grade de 64), tingido pelo jogo."""
    k = S
    big = Image.new("L", (size * k, size * k), 0)
    d = ImageDraw.Draw(big)
    for kind, pts in strokes:
        sp = [(x * k, y * k) for x, y in pts]
        if kind == "line":
            d.line(sp, fill=255, width=round(width * k), joint="curve")
            for x, y in (sp[0], sp[-1]):
                r = width * k / 2
                d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        elif kind == "ring":
            (cx, cy), (r, _) = sp[0], sp[1]
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=round(width * k))
        elif kind == "poly":
            d.polygon(sp, fill=255)
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    im.putalpha(big.resize((size, size), Image.Resampling.LANCZOS))
    return im


def cargo_hatch(opened=False, size=(200, 168)):
    """O compartimento da carga do guardião (#91): a escotilha de aço lacrada, com rebites, duas cintas e o lacre âmbar
    no meio. Aberta: o vão escuro e a tampa erguida no alto; o jogo desenha o que havia no vão."""
    w, h = size
    im = plate(size, cut=16, rim=7, amber=False, inner="dark" if opened else "steel", seed=51)
    x0, y0, x1, y1 = 22, 20, w - 23, h - 21
    door = chamfer(x0, y0, x1, y1, 8)
    if opened:
        # O vão: mais escuro no alto (a tampa faz sombra) e a tampa erguida, vista de quina, presa às dobradiças.
        pit = Image.new("RGBA", size)
        pd = ImageDraw.Draw(pit)
        for y in range(y0, y1):
            k = (y - y0) / max(1, y1 - y0)
            pd.line((x0, y, x1, y), fill=(4, 5, 6, round(235 - 120 * k)))
        pit.putalpha(Image.composite(pit.getchannel("A"), Image.new("L", size, 0), mask(size, door)))
        im.alpha_composite(pit)
        lid_poly = [(x0 - 4, y0 - 2), (x1 + 4, y0 - 2), (x1 - 14, y0 + 26), (x0 + 14, y0 + 26)]
        lid = tile(size, (70, 74, 78), 0.38)
        lid.putalpha(mask(size, lid_poly))
        im.alpha_composite(lid)
        im.alpha_composite(lines(size, [(lid_poly + [lid_poly[0]], (*EDGE, 255), 1.6),
                                        ([(x0 + 16, y0 + 23), (x1 - 16, y0 + 23)], (150, 150, 142, 220), 1.2),
                                        ([(x0 + 30, y0 + 6), (x0 + 30, y0 + 18)], (*EDGE, 255), 1.4), ([(x1 - 30, y0 + 6), (x1 - 30, y0 + 18)], (*EDGE, 255), 1.4),
                                        (door + [door[0]], (*EDGE, 255), 2.0)]))
        return im
    face = tile(size, (32, 35, 38), 0.42)
    face.putalpha(mask(size, door))
    im.alpha_composite(face)
    strokes = [(door + [door[0]], (*EDGE, 255), 2.0),
               ([(x + (1.4 if x < w / 2 else -1.4), y + (1.4 if y < h / 2 else -1.4)) for x, y in door] + [door[0]], (*BEVEL, 255), 1.0)]
    # As duas cintas.
    for y in (y0 + (y1 - y0) * 0.28, y0 + (y1 - y0) * 0.72):
        strokes += [([(x0 + 4, y - 4), (x1 - 4, y - 4)], (*EDGE, 255), 1.4), ([(x0 + 4, y + 4), (x1 - 4, y + 4)], (*EDGE, 255), 1.4),
                    ([(x0 + 4, y - 3), (x1 - 4, y - 3)], (120, 122, 118, 160), 0.8)]
    im.alpha_composite(lines(size, strokes))
    rivets = Image.new("RGBA", size)
    rd = ImageDraw.Draw(rivets)
    for x, y in [(x0 + 9, y0 + 9), (x1 - 9, y0 + 9), (x0 + 9, y1 - 9), (x1 - 9, y1 - 9)]:
        rd.ellipse((x - 3.5, y - 3.5, x + 3.5, y + 3.5), fill=(150, 150, 142, 255), outline=(*EDGE, 255))
    im.alpha_composite(rivets)
    # O lacre: o octógono âmbar no meio, por cima das cintas.
    cx, cy, r = w / 2, (y0 + y1) / 2, 15
    seal = chamfer(cx - r, cy - r, cx + r, cy + r, 6)
    disc = Image.new("RGBA", size, (*AMBER, 255))
    disc.putalpha(mask(size, seal))
    im.alpha_composite(disc)
    inner_seal = chamfer(cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5, 3)
    im.alpha_composite(lines(size, [(seal + [seal[0]], (*EDGE, 255), 1.6), (inner_seal + [inner_seal[0]], (90, 58, 12, 255), 1.4)]))
    return im


def loop_pieces():
    """Lote 6 (#96): a carga recuperada do guardião e os laços entre heróis."""
    save("cargo_hatch", cargo_hatch(False), None, [22, 20, 155, 127],
         "Compartimento lacrado da carga do guardião (#91), 200x168, sem fatiar. Escolha: selected_frame por cima; foco: focus_frame.")
    save("cargo_hatch_open", cargo_hatch(True), None, [22, 48, 155, 99],
         "O compartimento aberto: o ícone do que havia (48) no meio do vão e o texto embaixo, fora da peça. Os outros cinco "
         "abrem apagados (o texto no tom apagado); o escolhido fica com selected_frame e o texto em âmbar.")
    (OUT / "icons").mkdir(exist_ok=True)
    # Amizade: dois elos encaixados. Rivalidade: duas pontas, uma contra a outra, com a fenda no meio (forma, não só cor).
    stroke_icon([("ring", [(24, 32), (14, 0)]), ("ring", [(40, 32), (14, 0)])], width=6).save(OUT / "icons" / "bond_friend.webp", lossless=True, method=6)
    stroke_icon([("line", [(8, 18), (24, 32), (8, 46)]), ("line", [(56, 18), (40, 32), (56, 46)]),
                 ("line", [(32, 10), (29, 24), (35, 40), (32, 54)])], width=6).save(OUT / "icons" / "bond_rival.webp", lossless=True, method=6)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # ---------------------------------------------------------------- relatório da volta
    save("report_band", plate((480, 216), cut=18, rim=8, seed=2, amber_len=22), [40, 40, 40, 40], [20, 18, 440, 180],
         "Faixa do alto, de ponta a ponta (1848 em 1920). Centro em TILE_FIT. Divisões: band_divider por cima.")
    save("band_divider", groove((12, 176)), None, None, "Divisão vertical da faixa; esticar só na altura (176 = faixa 216 - 2x20).",
         anchor=(6, 0))
    save("result_chip", plate((232, 88), cut=10, rim=5, amber=False, inner="dark", seed=3), [18, 18, 18, 18], [12, 10, 208, 68],
         "Chip de resultado: ícone 44 à esquerda (x 16) e duas linhas. Objetivo não cumprido: ícone e texto na cor de perigo.")
    save("resource_tile", plate((112, 96), cut=10, rim=5, inner="dark", seed=4, amber_len=10), [16, 16, 16, 16], [8, 8, 96, 80],
         "Quadrado de recurso recuperado: ícone 56 no meio; número âmbar e nome embaixo, fora da peça.")
    save("hero_card", plate((380, 256), cut=16, rim=7, seed=5), [32, 32, 32, 32], [20, 18, 340, 220],
         "Carta do herói na plataforma. Retrato 92 em square_portrait (kit da luta).")
    save("card_tab", plate((244, 40), cut=10, rim=4, amber=False, inner="dark", seed=6), [16, 12, 16, 12], [12, 6, 220, 28],
         "Aba no alto da carta (Melhoria · N frag.): ícone 22 âmbar e texto 22. Encosta no topo da carta (sobrepõe 6 px).")
    save("status_pill", pill((176, 34)), [12, 10, 12, 10], [36, 4, 132, 26],
         "Pílula de estado clara; o jogo tinge com modulate (cores em hud-station.md). Ícone 22 em x 10.",
         tint={"active": "#56b468", "light_wound": "#f0a020", "wounded": "#d23a2e",
               "colorblind": {"active": "#56b4e9", "light_wound": "#f0e442", "wounded": "#d55e00"}})
    save("bar_fill", fill_tintable((64, 16)), [6, 4, 6, 4], [0, 0, 64, 16],
         "Preenchimento de barra (vida, instinto, XP), tingido pelo jogo; o miolo de main_bar (kit da luta) é a calha.")
    for state in ["normal", "focus", "pressed", "disabled"]:
        suffix = "" if state == "normal" else f"_{state}"
        save(f"primary_button{suffix}", amber_button((480, 72), state=state), [40, 22, 40, 22], [36, 10, 408, 52],
             "Botão principal âmbar (ENTRAR NO ABRIGO, PREPARAR EXPEDIÇÃO): ícone 36 escuro, texto escuro #1a1206, a tecla em "
             "button_key à direita. Pressionado desloca o desenho 2 px; o alvo de toque não muda.")
    save("button_key", plate((128, 44), cut=8, rim=3, amber=False, inner="dark", seed=7), [12, 12, 12, 12], [8, 6, 112, 32],
         "A tecla dentro do botão principal (Enter / A), texto 24 creme.")
    save("secondary_button", plate((240, 64), cut=12, rim=5, seed=8, amber_len=12), [24, 20, 24, 20], [18, 10, 204, 44],
         "Botão de aço (VOLTAR, VER DETALHES, X). Foco: focus_frame por cima.")
    save("focus_frame", amber_frame((240, 64), cut=12), [24, 20, 24, 20], None,
         "Foco do teclado ou controle sobre qualquer chapa: o âmbar inteiro com o núcleo claro.")
    # ---------------------------------------------------------------- Sala dos Personagens
    save("room_plaque", plate((520, 96), cut=16, rim=6, seed=9, amber_len=18), [40, 28, 40, 28], [20, 12, 480, 72],
         "Plaqueta da sala no alto à esquerda: ícone 52, ESTAÇÃO RAIZ 40 e o nome da sala 24.")
    save("resource_chip", plate((248, 96), cut=14, rim=6, amber=False, seed=10), [28, 24, 28, 24], [18, 12, 212, 72],
         "Chip de Comida, Água e Energia: ícone 40, rótulo 20, valor âmbar 28 e a linha de baixo 20.")
    save("icon_button", plate((92, 92), cut=14, rim=6, seed=11, amber_len=12), [24, 24, 24, 24], [16, 16, 60, 60],
         "Botão quadrado (engrenagem 48; X do painel em 52x52).")
    save("panel_large", plate((320, 320), cut=22, rim=9, seed=12, amber_len=26), [44, 44, 44, 44], [24, 22, 272, 276],
         "Painel grande: a coluna da esquerda e o painel PERSONAGEM. Centro em TILE_FIT.")
    save("panel_inset", plate((240, 160), cut=14, rim=5, amber=False, inner="dark", seed=13), [24, 24, 24, 24], [16, 14, 208, 132],
         "Caixa embutida do detalhe da habilidade e dos números.")
    save("hero_tab", plate((116, 132), cut=10, rim=5, amber=False, inner=None, seed=14), [16, 16, 16, 16], [6, 6, 104, 120],
         "Aba do herói: moldura vazada; o retrato 104x92 por baixo e o nome numa faixa escura de 28 embaixo.")
    save("hero_tab_selected", amber_frame((116, 132), cut=10), [16, 16, 16, 16], None, "A aba escolhida: o âmbar por cima.")
    save("list_row", plate((560, 60), cut=10, rim=4, amber=False, inner="dark", seed=15), [20, 16, 20, 16], [10, 6, 540, 48],
         "Linha da lista (HABILIDADES): ícone 44 da habilidade em square_portrait e o nome 28.")
    save("list_row_selected", amber_frame((560, 60), cut=10, width=3.2), [20, 16, 20, 16], None,
         "A linha escolhida: o âmbar por cima de list_row.")
    save("divider", groove((240, 8), vertical=False), [8, 0, 8, 0], None, "Divisor horizontal entre seções.")
    save("trait_tile", plate((88, 88), cut=10, rim=5, amber=False, inner="dark", seed=16), [16, 16, 16, 16], [8, 8, 72, 72],
         "Quadrado do traço: ícone pintado 72 (art/ui/kit/station/icons/trait_*.webp).")
    save("level_medal", medal((72, 72)), None, [14, 14, 44, 44], "Medalhão do nível: número 34 SemiBold âmbar no centro. Não fatiar.",
         anchor=(36, 36))
    save("train_button", plate((240, 56), cut=10, rim=4, amber=True, inner="steel", seed=17, amber_len=12), [20, 16, 20, 16],
         [16, 8, 208, 40], "TREINAR: ícone train 28 âmbar e o custo à direita. Bloqueado: ícone e texto apagados e o motivo ao focar.")
    save("upgrade_card", plate((300, 200), cut=14, rim=6, amber=False, seed=18), [28, 28, 28, 28], [20, 18, 260, 164],
         "Cartão de uma das duas melhorias do Treino: nome 30, efeito 22, quantas já tem.")
    save("upgrade_card_selected", amber_frame((300, 200), cut=14, width=3.4), [28, 28, 28, 28], None,
         "O cartão escolhido (foco ou clique): o âmbar por cima.")
    save("nav_tab", plate((216, 72), cut=12, rim=5, amber=False, seed=19), [24, 20, 24, 20], [16, 10, 184, 52],
         "Aba de navegação (VISÃO GERAL, INSTALAÇÕES...): ícone 32 e texto 26.")
    under = Image.new("RGBA", (216, 72))
    under.alpha_composite(lines((216, 72), [([(22, 64), (194, 64)], (*AMBER, 255), 4.0)]).filter(ImageFilter.GaussianBlur(3)))
    under.alpha_composite(lines((216, 72), [([(22, 64), (194, 64)], (*AMBER, 255), 3.2), ([(24, 64), (192, 64)], (*AMBER_HOT, 220), 1.0)]))
    save("nav_tab_active", under, [24, 20, 24, 20], None, "A aba ativa: o sublinhado âmbar por cima de nav_tab; texto e ícone em âmbar.")
    save("keys_bar", plate((320, 56), cut=12, rim=4, amber=False, inner="dark", seed=20), [24, 16, 24, 16], [16, 8, 288, 40],
         "A barra das teclas: key_tab (kit da luta) 36 e o rótulo 22.")

    # ---------------------------------------------------------------- lote 1: as outras telas da Estação
    save("selected_frame", amber_frame((120, 60), cut=10, width=3.0), [16, 16, 16, 16], None,
         "Escolha persistente sobre qualquer chapa (opção marcada, cômodo escolhido, aba de foco da rota).")
    save("chip_button", plate((160, 48), cut=8, rim=4, amber=False, inner="dark", seed=21), [14, 14, 14, 14], [12, 6, 136, 36],
         "Botão pequeno de opção (Rota básica, Água, 1x, Baixo...). Marcado: selected_frame por cima e texto âmbar.")
    save("cost_chip", plate((120, 40), cut=7, rim=3, amber=False, inner="dark", seed=22), [12, 12, 12, 12], [8, 4, 104, 32],
         "Custo ou quantidade: ícone de recurso 24 e o número 22. Falta: número na cor de alerta.")
    track = Image.new("RGBA", (240, 20))
    track.alpha_composite(plate((240, 20), cut=5, rim=3, amber=False, inner="dark", seed=23))
    save("slider_track", track, [10, 6, 10, 6], [4, 4, 232, 12], "Calha do controle deslizante; o preenchimento é bar_fill tingido de âmbar.")
    knob = plate((28, 36), cut=6, rim=3, amber=False, inner="steel", seed=24)
    knob.alpha_composite(lines((28, 36), [([(14, 10), (14, 26)], (*AMBER, 255), 2.4)]))
    save("slider_knob", knob, None, None, "Pegador do controle deslizante, centrado no valor.", anchor=(14, 18))
    for state in ["off", "on"]:
        t = plate((64, 32), cut=6, rim=3, amber=False, inner="dark", seed=25)
        x = 6 if state == "off" else 34
        dot = plate((24, 22), cut=5, rim=2, amber=False, inner="steel", seed=26)
        # Desligado: o pegador de aço claro (acima de 3:1 contra a calha); ligado: âmbar.
        face = Image.new("RGBA", (24, 22), (*AMBER, 255) if state == "on" else (156, 158, 154, 255))
        face.putalpha(mask((24, 22), chamfer(2, 2, 21, 19, 4)))
        dot.alpha_composite(face)
        t.alpha_composite(dot, (x, 5))
        t.alpha_composite(lines((64, 32), [(chamfer(0.8, 0.8, 63.2, 31.2, 6) + [chamfer(0.8, 0.8, 63.2, 31.2, 6)[0]], (150, 150, 144, 230), 1.2)]))
        save(f"toggle_{state}", t, None, None, "Liga e desliga. Ligado: o pegador âmbar à direita; desligado: aço à esquerda.")
    tag = Image.new("RGBA", (200, 52))
    body = plate((200, 42), cut=8, rim=4, amber=True, inner="dark", seed=27, amber_len=8)
    tag.alpha_composite(body)
    point = Image.new("RGBA", (200, 52))
    ImageDraw.Draw(point).polygon([(92, 40), (108, 40), (100, 51)], fill=(*EDGE, 255))
    ImageDraw.Draw(point).polygon([(94, 40), (106, 40), (100, 48)], fill=(*AMBER, 255))
    tag.alpha_composite(point)
    save("room_tag", tag, [16, 12, 16, 20], [12, 6, 176, 30],
         "Etiqueta do cômodo no corte da Estação, com a ponta para baixo no centro (âncora 100,52). Esticar só na largura.",
         anchor=(100, 52))
    # ---------------------------------------------------------------- lote 2: os controles de toque da exploração
    # Octógonos de aço (a chapa chanfrada do kit, com o aro e a textura), meio transparentes para a cena aparecer.
    def see_through(im, alpha):
        a = im.getchannel("A").point(lambda v: v * alpha // 255)
        im.putalpha(a)
        return im
    ring = plate((240, 240), cut=70, rim=7, amber=False, inner=None, seed=41)
    fill = see_through(tile((240, 240), (14, 16, 18), 0.6), 110)
    fill.putalpha(Image.composite(fill.getchannel("A"), Image.new("L", (240, 240), 0), mask((240, 240), chamfer(7, 7, 232, 232, 66))))
    fill.alpha_composite(ring)
    save("touch_ring", fill, None, None, "Área do analógico de toque: octógono de aço meio transparente (aparece onde o dedo encosta; até a borda corre). Não fatiar.", anchor=(120, 120))
    knob = plate((84, 84), cut=24, rim=5, amber=False, inner="steel", seed=42)
    knob.alpha_composite(lines((84, 84), [([(30, 42), (54, 42)], (*AMBER, 255), 2.6), ([(42, 30), (42, 54)], (*AMBER, 255), 2.6)]))
    save("touch_knob", knob, None, None, "O pegador do analógico, com a cruz âmbar. Não fatiar.", anchor=(42, 42))
    save("touch_button", see_through(plate((170, 170), cut=50, rim=6, amber=False, inner="dark", seed=43), 225), None, None,
         "O botão Usar, apagado (nada por perto). Não fatiar.", anchor=(85, 85))
    save("touch_button_active", amber_frame((170, 170), cut=50, width=3.6), None, None,
         "Por cima de touch_button quando há o que usar: o âmbar inteiro com o núcleo claro.", anchor=(85, 85))

    # ---------------------------------------------------------------- lote 4: as peças só de luta (decisão do Lucas, 25/10)
    # Redesenho, no mesmo padrão, das peças de art/ui/kit/combat que não tinham equivalente: as medidas e a estrutura do
    # alvo aprovado (docs/design/hud-target.md); o desenho, os estados e as conferências deste kit.
    combat_pieces()
    # ---------------------------------------------------------------- lote 5: os ajustes da #109 (acampamento, fim de luta)
    adjust_pieces()
    # ---------------------------------------------------------------- lote 6: o laço (#96: a carga, os laços)
    loop_pieces()

    manifest = {
        "revision": "station_2026_10_25",
        "direction": "Alvos aprovados da Estação (25/10/2026), no idioma do kit da luta",
        "source_references": {
            "report": "docs/design/reference/hud-target-report-2026-10-25.webp",
            "characters": "docs/design/reference/hud-target-characters-2026-10-25.webp",
        },
        "canvas": [1920, 1080],
        "material": "art/ui/kit/combat/steel_material.webp",
        "reuses_combat_kit": ["square_portrait", "key_tab", "main_bar", "selected_slot", "steel_material"],
        # A luta no padrão deste kit (decisão do Lucas, 25/10; docs/design/hud-luta.md): a peça do Codex e o que a substitui.
        "replaces_combat_kit": {
            "panel": "panel_large / panel_inset", "hero_panel": "panel_large + square_portrait", "register": "room_plaque",
            "action_button": "icon_button + key_tab", "health_ally": "main_bar + bar_fill (+ ally_mark no daltonismo)",
            "health_enemy": "main_bar + bar_fill (+ enemy_mark no daltonismo)", "active_health": "selected_corners",
            "round_strip": "round_strip (+ enemy_badge no daltonismo)", "ability_header": "ability_header",
            "ability_slot": "ability_slot, ability_slot_pressed, ability_slot_disabled", "target_tab": "target_tab",
            "actor_ring": "actor_ring",
        },
        "axis_stretch": "TILE_FIT nas peças grandes (report_band, panel_large); STRETCH nas pequenas",
        "assets": ROWS,
        "trait_ids": {"agile": "trait_agile", "brave": "trait_brave", "hopeful": "trait_hopeful", "loyal": "trait_loyal",
                      "sluggish": "trait_sluggish", "anxious": "trait_anxious", "gloomy": "trait_gloomy", "machine-fear": "trait_machine_fear"},
        "icons": {p.stem: {"file": f"art/ui/kit/station/icons/{p.name}", "size": list(Image.open(p).size), "sha256": sha(p),
                           "kind": "painted" if p.stem.startswith("trait_") else "glyph_white_tintable"}
                  for p in sorted((OUT / "icons").glob("*.webp"))},
        "font": {"file": "art/ui/fonts/barlow_condensed_medium.ttf", "emphasis_file": "art/ui/fonts/barlow_condensed_semibold.ttf",
                 "license": "art/ui/fonts/OFL-BarlowCondensed.txt"},
        "originals": "Folhas de ícones geradas (Nano Banana Pro) fora do Git; o recorte é cut_icons.py",
    }
    text = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    (OUT / "assets.json").write_text(text)
    (HERE / "assets.json").write_text(text)
    print("peças:", len(ROWS), "ícones:", len(manifest["icons"]))


if __name__ == "__main__":
    main()
