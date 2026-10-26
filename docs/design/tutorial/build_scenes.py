"""As prévias do mapa do tutorial (#147): cada zona montada em 2D com a arte de art/scenarios/T_TU*, nas medidas em metros
da tabela de tutorial.md (SIZES), a 130 px por metro (a altura do Bento e do Nick na exploração), com a luz pintada por
cima. Não é a cena 3D: é a prova de que as peças fecham um lugar, para o Lucas aprovar e o Claude montar o
data/scenarios/<Mapa>.json com as mesmas medidas.

Uso: python3 -B docs/design/tutorial/build_scenes.py   (grava docs/design/tutorial/zone_*.webp)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/scenarios"
OUT = Path(__file__).resolve().parent
W, H, PPM, FLOOR = 1920, 1080, 130, 820
# Largura em metros de cada peça (a altura sai da proporção do arquivo); a tabela da página repete estes números.
SIZES = {"T_TU01": 8.2, "T_TU02": 2.0, "T_TU03": 8.2, "T_TU04": 4.0, "T_TU05": 3.0, "T_TU06": 3.54, "T_TU07": 1.4,
         "T_TU08": 0.3, "T_TU08_Lit": 0.3, "T_TU09": 4.5, "T_TU10": 10.0, "T_TUX01_Security_Door": 2.4,
         "T_TUX01_Security_Door_Open": 2.4, "T_TUX02_Maintenance_Locker": 1.45, "T_TUX02_Maintenance_Locker_Open": 1.45,
         "T_TUX03_Door_Panel": 0.62, "T_TUX03_Door_Panel_Open": 0.62}
HEROES = {"bento": 1.75, "nick": 1.6}


def piece(name: str, scale: float = 1.0) -> Image.Image:
    im = Image.open(ART / f"{name}.webp").convert("RGBA")
    w = round(SIZES[name] * PPM * scale)
    return im.resize((w, round(im.height * w / im.width)), Image.Resampling.LANCZOS)


def hero(name: str) -> Image.Image:
    im = Image.open(ROOT / f"art/combat/heroes/{name}/idle.webp").convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    h = round(HEROES[name] * PPM)
    return im.resize((round(im.width * h / im.height), h), Image.Resampling.LANCZOS)


def floor_band(im: Image.Image, name: str) -> None:
    """O piso na faixa de andar, repetido, um pouco mais escuro que a parede."""
    floor = piece(name)
    band = Image.new("RGBA", (W, H - FLOOR))
    for y in range(0, H - FLOOR, floor.height):
        for x in range(0, W, floor.width):
            band.alpha_composite(floor.crop((0, 0, floor.width, min(floor.height, H - FLOOR - y))), (x, y))
    im.alpha_composite(ImageEnhance.Brightness(band).enhance(0.7), (0, FLOOR))


def base(wall: str, floor_name: str = "T_TU02") -> Image.Image:
    """A parede do fundo repetida (do piso até 4,6 m), o teto escuro e o piso molhado na faixa de andar."""
    im = Image.new("RGBA", (W, H), (14, 15, 17, 255))
    tile = piece(wall)
    top = FLOOR - tile.height
    for x in range(-tile.width // 3, W, tile.width):
        im.alpha_composite(tile, (x, top))
    floor_band(im, floor_name)
    # A sombra no pé da parede e o teto sem detalhe.
    d = ImageDraw.Draw(im)
    for i in range(24):
        d.line((0, FLOOR + i, W, FLOOR + i), fill=(0, 0, 0, 140 - i * 5))
    d.rectangle((0, 0, W, top), fill=(10, 11, 13, 255))
    return im


def at(im: Image.Image, card: Image.Image, cx: float, bottom: float) -> None:
    im.alpha_composite(card, (round(cx - card.width / 2), round(bottom - card.height)))


def light(im: Image.Image, spots, ambient: float, tint) -> Image.Image:
    """A luz: o lugar escurecido (ambient), e cada foco [x, y, raio, (r, g, b), força] somado por cima."""
    dark = ImageEnhance.Brightness(im.convert("RGB")).enhance(ambient)
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    for x, y, r, color, power in spots:
        layer = Image.new("RGB", (W, H), (0, 0, 0))
        ImageDraw.Draw(layer).ellipse((x - r, y - r, x + r, y + r), fill=tuple(int(c * power) for c in color))
        glow = ImageChops.add(glow, layer.filter(ImageFilter.GaussianBlur(r * 0.45)))
    lit = ImageChops.add(dark, ImageChops.multiply(im.convert("RGB"), glow))
    return Image.blend(lit, Image.new("RGB", (W, H), tint), 0.06)


def red_lamps(xs, on=True):
    return [(x, 300, 520, (255, 70, 50), 0.95 if on else 0.25) for x in xs]


def corridor(lamps_on=True) -> Image.Image:
    """1. O corredor de contenção: a parede com a faixa de perigo, as lâmpadas vermelhas, a porta de segurança aberta
    à frente (a equipe passa) e as raízes que entram pelo piso."""
    im = base("T_TU01")
    lamp = piece("T_TU08_Lit" if lamps_on else "T_TU08")
    for x in (420, 1300):
        at(im, lamp, x, 330)
    at(im, piece("T_TUX01_Security_Door_Open"), 1650, FLOOR + 4)
    at(im, piece("T_TU05"), 260, FLOOR + 40)
    at(im, hero("bento"), 820, FLOOR + 30)
    at(im, hero("nick"), 1040, FLOOR + 30)
    return light(im, red_lamps((420, 1300), lamps_on), 0.42, (120, 20, 20))


def cells() -> Image.Image:
    """2. A sala com grades: duas celas no fundo, o armário de manutenção (a busca) e o painel das portas."""
    im = base("T_TU01")
    bars = piece("T_TU04")
    for cx in (520, 1080):
        # O fundo da cela, escuro, atrás das grades (o card das grades é vazado).
        x0, y0 = round(cx - bars.width / 2) + 14, FLOOR - 2 - bars.height + 14
        cell = im.crop((x0, y0, x0 + bars.width - 28, FLOOR - 16))
        im.paste(ImageEnhance.Brightness(cell).enhance(0.28), (x0, y0))
        at(im, bars, cx, FLOOR - 2)
    at(im, piece("T_TUX02_Maintenance_Locker"), 1520, FLOOR + 6)
    at(im, piece("T_TUX03_Door_Panel"), 1760, FLOOR - 120)
    at(im, piece("T_TU08_Lit"), 800, 330)
    at(im, hero("nick"), 1300, FLOOR + 30)
    return light(im, red_lamps((800,)) + [(1520, 640, 300, (255, 220, 170), 0.35)], 0.42, (120, 20, 20))


def nick_route() -> Image.Image:
    """3. A rota alternativa do Nick: a porta de segurança baixada (fechou atrás da equipe), o duto com a grade
    arrancada e a escada de manutenção até a grade aberta no teto, por onde o Nick sai na frente."""
    im = base("T_TU01")
    at(im, piece("T_TUX01_Security_Door"), 300, FLOOR + 4)
    at(im, piece("T_TU07"), 900, FLOOR - 150)
    at(im, piece("T_TU06"), 1380, FLOOR + 6)
    at(im, piece("T_TU08_Lit"), 640, 330)
    at(im, hero("bento"), 650, FLOOR + 30)
    at(im, hero("nick"), 1240, FLOOR + 30)
    return light(im, red_lamps((640,)) + [(1380, 420, 260, (200, 220, 255), 0.4)], 0.42, (110, 20, 20))


def platform() -> Image.Image:
    """4. A plataforma no fim: a parede de azulejo da estação esquecida, o trem parado no fosso dos trilhos, com a luz
    fria por dentro e as portas abertas, e a equipe sobre a plataforma. O piso da plataforma (T_TU09) tem a faixa
    amarela na beira do lado do trem; a queda para os trilhos não aparece (fica do lado do trem), e o piso tapa as rodas:
    o chão do vagão fica na altura da plataforma, para embarcar."""
    im = base("T_TU03", "T_TU09")
    train = piece("T_TU10")
    # O chão do vagão (o pé das portas, a 72% da altura do card) na linha do piso.
    at(im, train, 1150, FLOOR + round(train.height * 0.28))
    floor_band(im, "T_TU09")
    at(im, hero("bento"), 600, FLOOR + 60)
    at(im, hero("nick"), 820, FLOOR + 60)
    spots = [(1150, 560, 520, (190, 215, 255), 0.85), (300, 300, 380, (255, 70, 50), 0.4)]
    return light(im, spots, 0.4, (40, 60, 90))


def doors() -> Image.Image:
    """As portas fechando atrás da equipe: a mesma porta aberta, descendo e fechada, com o painel ao lado."""
    out = Image.new("RGB", (W, H), (14, 15, 17))
    shots = []
    for state in ("open", "half", "closed"):
        im = base("T_TU01")
        door = piece("T_TUX01_Security_Door_Open" if state == "open" else "T_TUX01_Security_Door")
        if state == "half":
            shut = piece("T_TUX01_Security_Door")
            opened = piece("T_TUX01_Security_Door_Open").copy()
            mid = shut.crop((0, 0, shut.width, round(shut.height * 0.6)))
            opened.alpha_composite(mid, (0, 0))
            door = opened
        at(im, door, 960, FLOOR + 4)
        at(im, piece("T_TUX03_Door_Panel_Open" if state != "open" else "T_TUX03_Door_Panel"), 1330, FLOOR - 120)
        at(im, piece("T_TU08_Lit"), 960, 300)
        shots.append(light(im, red_lamps((960,)), 0.45, (120, 20, 20)).crop((560, 200, 1460, 1080)))
    for i, shot in enumerate(shots):
        out.paste(shot.resize((620, 606)), (12 + i * 636, 237))
    return out


# A prancha da arte: cada peça com o nome, a medida em metros e o uso, sobre o aço escuro (as recortadas sobre um
# xadrez claro e escuro, para ver o alfa).
USES = {"T_TU01": "Parede do corredor (repete na horizontal)", "T_TU02": "Piso molhado (repete)", "T_TU03": "Parede da plataforma (repete)",
        "T_TU04": "Grades da cela", "T_TU05": "Raízes no piso", "T_TU06": "Escada até o alçapão no teto (rota do Nick)",
        "T_TU07": "Duto com a grade arrancada (rota do Nick)", "T_TU08": "Lâmpada de emergência apagada", "T_TU08_Lit": "A mesma, acesa (pisca)",
        "T_TU09": "Piso da plataforma, a faixa amarela na beira (repete)", "T_TU10": "O vagão (luz fria por dentro)", "T_TUX01_Security_Door": "Porta de segurança fechada",
        "T_TUX01_Security_Door_Open": "Porta de segurança aberta", "T_TUX02_Maintenance_Locker": "Armário (busca), fechado",
        "T_TUX02_Maintenance_Locker_Open": "Armário (busca), aberto", "T_TUX03_Door_Panel": "Painel das portas", "T_TUX03_Door_Panel_Open": "Painel acionado"}


def sheet() -> Image.Image:
    font = ImageFont.truetype(str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf"), 24)
    small = ImageFont.truetype(str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf"), 20)
    cols, cw, ch = 5, 380, 330
    names = list(USES)
    out = Image.new("RGB", (cols * cw + 20, ((len(names) + cols - 1) // cols) * ch + 20), (20, 22, 24))
    d = ImageDraw.Draw(out)
    for i, name in enumerate(names):
        x, y = 20 + (i % cols) * cw, 20 + (i // cols) * ch
        im = Image.open(ART / f"{name}.webp").convert("RGBA")
        w_m = SIZES[name]
        h_m = w_m * im.height / im.width
        box = Image.new("RGB", (cw - 30, 220), (40, 43, 47))
        for yy in range(0, 220, 20):
            for xx in range(0, cw - 30, 20):
                if (xx // 20 + yy // 20) % 2:
                    ImageDraw.Draw(box).rectangle((xx, yy, xx + 19, yy + 19), fill=(120, 123, 128))
        im.thumbnail((cw - 40, 210))
        box.paste(im, ((cw - 30 - im.width) // 2, (220 - im.height) // 2), im)
        out.paste(box, (x, y))
        d.text((x, y + 228), name, font=font, fill=(239, 230, 214))
        d.text((x, y + 258), f"{w_m:g} × {h_m:.2f} m · {Image.open(ART / f'{name}.webp').size[0]} × {Image.open(ART / f'{name}.webp').size[1]} px", font=small, fill=(240, 160, 32))
        d.text((x, y + 284), USES[name], font=small, fill=(169, 162, 148))
    return out


def main() -> None:
    sheet().save(OUT / "art_sheet.webp", quality=90, method=6)
    for name, im in (("zone_corridor", corridor()), ("zone_corridor_dark", corridor(False)), ("zone_cells", cells()),
                     ("zone_nick_route", nick_route()), ("zone_platform", platform()), ("zone_doors", doors())):
        im.convert("RGB").save(OUT / f"{name}.webp", quality=88, method=6)
        print(name)


if __name__ == "__main__":
    main()
