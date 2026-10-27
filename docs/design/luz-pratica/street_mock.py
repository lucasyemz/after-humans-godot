"""A prova do piloto na Rua das Vitrines (#154): uma captura de noite com chuva da Rua (hud-v2/before), com as fontes do
kit montadas por cima em 2D, na escala dos heróis (cerca de 135 px por metro na faixa de andar), acesas com o halo
somado (blend_add) e a poça no chão. É uma montagem para a direção de luz, não a cena 3D: a luz de verdade nas paredes
e no chão molhado é do motor (as OmniLight e o reflexo), e a integração é do Claude 2.

Uso (da raiz do repositório, depois de cut_lights.py): python3 -B docs/design/luz-pratica/street_mock.py
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/scenarios"
HERE = Path(__file__).resolve().parent
BG = ROOT / "docs/design/hud-v2/before/explore-patrol_clean.webp"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
PX_M = 135
HALO_SCALE = 2.0
MANIFEST = json.loads((HERE / "cut_manifest.json").read_text())["pieces"]
# código, altura (m), x do meio e y da base (px na captura), energia do halo, cor da poça, poça (largura em m, y), mais
# escuro (o longe)
PIECES = [
    ("T_LP01", 1.05, 1065, 470, 1.0, (255, 190, 140), (3.4, 790), 1.0),   # a gambiarra atravessando o beco
    ("T_LP03", 0.92, 1010, 772, 1.25, (255, 140, 60), (3.2, 800), 1.0),   # o tambor com fogo no pé do beco
    ("T_LP02", 0.42, 735, 772, 1.0, (255, 160, 90), (1.6, 790), 1.0),     # o lampião de alguém, junto ao carro
    ("T_LP06", 0.34, 845, 560, 1.4, (255, 60, 40), (2.2, 772), 1.0),      # a luz de emergência na quina
    ("T_LP05", 0.95, 205, 610, 0.9, (110, 255, 210), (2.6, 770), 1.0),   # o letreiro velho na fachada da esquerda
    ("T_LP04", 0.62, 1715, 560, 1.1, (255, 225, 170), (2.8, 770), 1.0),  # a luminária sob o toldo
    ("T_LP09", 0.42, 1300, 470, 0.8, (90, 230, 255), None, 1.0),          # o sensor na parede
    ("T_LP08", 1.25, 1790, 752, 0.9, (90, 230, 255), (1.8, 760), 1.0),   # o robô de serviço parado na porta
    ("T_LP07", 0.55, 1530, 170, 0.9, None, None, 0.8),                    # o drone ao longe
]


def tint(im, color):
    return ImageChops.multiply(im, Image.new("RGB", im.size, color))


def add(base, layer, at):
    canvas = Image.new("RGB", base.size)
    canvas.paste(layer, at)
    return ImageChops.add(base, canvas)


def spill(size, pieces):
    """A luz das fontes na pintura (o que a OmniLight faz na parede e no chão): um mapa de luz somado em volta de cada
    fonte, que multiplica a cena (clareia o que está pintado, sem véu no preto)."""
    light = Image.new("RGB", size)
    for code, h, x, y, e, color, pool, far in pieces:
        if not color:
            continue
        r = int((1.7 if pool else 0.9) * PX_M)
        blob = Image.new("L", (r * 2, r * 2))
        ImageDraw.Draw(blob).ellipse((r * 0.25, r * 0.25, r * 1.75, r * 1.75), fill=150)
        blob = blob.filter(ImageFilter.GaussianBlur(r * 0.35))
        cy = y - int(h * PX_M / 2)
        light = add(light, tint(blob.convert("RGB"), color), (x - r, cy - r))
    return light


def compose(lit: bool) -> Image.Image:
    scene = Image.open(BG).convert("RGB")
    if lit:
        light = spill(scene.size, PIECES)
        scene = ImageChops.add(scene, ImageChops.multiply(scene, light).point(lambda v: min(255, int(v * 2.2))))
        # As poças primeiro (no chão, achatadas pela câmera), depois o cone do drone.
        for code, h, x, y, e, color, pool, far in PIECES:
            if pool:
                w = int(pool[0] * PX_M)
                p = Image.open(ART / "T_LP_Pool.webp").convert("RGB").resize((w, w // 5))
                scene = add(scene, tint(p, tuple(int(c * 0.55) for c in color)), (x - w // 2, pool[1] - w // 10))
        # O cone sai da lente do drone (a âncora "light" do card), girado em volta dela.
        code, h, x, y = PIECES[-1][:4]
        card = Image.open(ART / f"{code}.webp")
        k = h * PX_M / card.height
        lx = x - round(card.width * k) // 2 + round(MANIFEST[code]["light"][0] * k)
        ly = y - round(card.height * k) + round(MANIFEST[code]["light"][1] * k)
        beam = Image.open(ART / "T_LP_Beam.webp").convert("RGB").resize((230, 600))
        pivot = Image.new("RGB", (1280, 1280))
        pivot.paste(beam, (640 - 115, 640))
        pivot = pivot.rotate(-14, center=(640, 640))
        scene = add(scene, tint(pivot, (120, 190, 205)), (lx - 640, ly - 640))
    scene = scene.convert("RGBA")
    halos = []
    for code, h, x, y, e, color, pool, far in PIECES:
        im = Image.open(ART / f"{code}{'_Lit' if lit else ''}.webp").convert("RGBA")
        k = h * PX_M / im.height
        size = (round(im.width * k), round(im.height * k))
        im = im.resize(size, Image.Resampling.LANCZOS)
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v > 85 else 0))
        # A luz da noite na pintura: o objeto apagado fica no escuro da cena.
        rgb = ImageEnhance.Brightness(im.convert("RGB")).enhance(0.5 * far if not lit else 0.62 * far)
        if lit:
            glow = ImageChops.subtract(im.convert("RGB"), ImageEnhance.Brightness(im.convert("RGB")).enhance(0.75))
            rgb = ImageChops.add(rgb, ImageChops.multiply(glow, glow).point(lambda v: min(255, v * 3)))
        rgb.putalpha(im.getchannel("A"))
        at = (x - size[0] // 2, y - size[1])
        scene.alpha_composite(rgb, at)
        if lit and code == "T_LP03":
            seat = MANIFEST[code]["fire_seat"]
            f = Image.open(ART / "T_LP03_Fire_0.webp").convert("RGB")
            fw = round(size[0] * seat["width"])
            f = f.resize((fw, round(f.height * fw / f.width)), Image.Resampling.LANCZOS)
            base = scene.convert("RGB")
            base = add(base, f, (at[0] + (size[0] - fw) // 2, at[1] + round(seat["bottom_y"] * k) - f.height))
            scene = base.convert("RGBA")
        if lit:
            halo = Image.open(ART / f"{code}_Halo.webp").convert("RGB")
            hs = halo.resize((round(size[0] * HALO_SCALE), round(size[1] * HALO_SCALE)), Image.Resampling.LANCZOS)
            hs = hs.point(lambda v: min(255, int(v * e)))
            halos.append((hs, (x - hs.width // 2, y - size[1] // 2 - hs.height // 2)))
    scene = scene.convert("RGB")
    for hs, at in halos:
        scene = add(scene, hs, at)
    return scene


def label(im, text):
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(str(FONT), 34)
    w = d.textlength(text, font=font)
    d.rectangle((0, 0, w + 28, 52), fill=(13, 16, 18))
    d.text((14, 6), text, font=font, fill=(239, 229, 209))
    return im


def main():
    off, on = compose(False), compose(True)
    on.save(HERE / "street_night_lit.webp", "WEBP", quality=88, method=6)
    off.save(HERE / "street_night_off.webp", "WEBP", quality=88, method=6)
    pair = Image.new("RGB", (1920, 1080 + 8 + 1080), (10, 11, 13))
    pair.paste(label(off.copy(), "Apagadas: as fontes no lugar, de noite e na chuva"), (0, 0))
    pair.paste(label(on.copy(), "Acesas: o halo, a poça e o cone do drone (montagem 2D sobre a captura)"), (0, 1088))
    pair.save(HERE / "street_night_compare.webp", "WEBP", quality=86, method=6)
    on.resize((768, 432), Image.Resampling.LANCZOS).save(HERE / "street_night_lit_40.webp", "WEBP", quality=88)
    on.convert("L").save(HERE / "street_night_lit_gray.webp", "WEBP", quality=88)


if __name__ == "__main__":
    main()
