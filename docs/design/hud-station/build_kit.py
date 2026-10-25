"""Kit da Estação (relatório da volta e Sala dos Personagens): peças desenhadas por código, no idioma do kit da luta.

Aço grafite arranhado (o mesmo material de art/ui/kit/combat/steel_material.webp), bisel fino, cantos chanfrados e o
detalhe âmbar em dois cantos opostos. Nenhum texto nas imagens. Grava as peças em art/ui/kit/station/ e o manifesto
assets.json (tamanho, margens de 9-slice na ordem esquerda/cima/direita/baixo, área de conteúdo, âncora e sha256).

Uso: python3 docs/design/hud-station/build_kit.py    (só Pillow)
"""
import hashlib
import json
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


def plate(size, cut=12, rim=6, amber=True, inner="steel", seed=1, amber_len=None):
    """A chapa chanfrada: aro de aço com bisel, miolo de aço mais escuro e o âmbar nos cantos superior esquerdo e inferior
    direito. inner: "steel", "dark" (caixa de texto embutida) ou None (moldura vazada, o conteúdo aparece por baixo)."""
    w, h = size
    top = 0
    outer = chamfer(0, top, w - 1, h - 1, cut)
    ri = rim
    ic = max(3, round(cut - ri * 0.41))
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
