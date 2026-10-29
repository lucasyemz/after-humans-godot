"""Os fundos do lote 8 que nenhuma captura tem (a cena 3D da Estação não abre no xvfb sem placa de vídeo), montados só
com as capturas do jogo:
- station_markers_clean.webp: a Visão geral num dia antes da volta do lote 7 (o Dia 2), com a Enfermaria (#121) ainda
  vazia: o cômodo de x 440 a 620 com as paredes do Centro de Pesquisa e sem móveis, na penumbra (o cômodo vazio fica
  com a luz a 0,3, station.gd), e o Bar e o Dormitório na penumbra também (os dois começam no nível 0 e chegam numa
  próxima fase; os beliches do Dormitório ficam, como no jogo). A Forja já está vazia na captura;
- station_night_clean.webp: a Visão geral do lote 7 com a Enfermaria (hud-casa/before/station_infirmary_clean.webp) à
  noite: as luzes dos cômodos apagadas (a captura a 0,3, puxada para o azul), a luz baixa do Dormitório e da
  Enfermaria, quem dorme deitado nos beliches e a Véspera de pé no Depósito, de vigia; a Forja apagada e vazia;

Uso: python3 -B docs/design/hud-ajustes2/build_bg.py
"""
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
V2 = ROOT / "docs/design/hud-v2/before"
CASA = ROOT / "docs/design/hud-casa/before"
OUT = ROOT / "docs/design/hud-ajustes2/before"

# Na Visão geral: x = 812 + 0,3 * x_cm. O Bar (760 a 1560 cm, subsolo 1) de x 1040 a 1280, y 525 a 628; o Dormitório
# (−1240 a −40) de x 440 a 800; a Enfermaria (−1240 a −640, subsolo 2) de x 440 a 620, y 652 a 754.
BAR = (1046, 527, 1282, 628)
DORMITORY = (444, 527, 800, 628)
INFIRMARY = (440, 652, 620, 756)
# A Preparação (2160 a 2760 cm, subsolo 2) de x 1460 a 1650.
PREPARATION = (1462, 655, 1650, 756)
# Os beliches do Dormitório na Visão geral: de x 512 a 582 e de 610 a 680, com o colchão de baixo em y 594 e o de cima
# em 570. Quem dorme: o Bento e o Nick, com a pose de dormir (art/station/poses). Os recrutas (a Lupa e o Brasa) não têm
# pose de dormir e ficam fora do corte nesta montagem (a integração precisa da pose deles).
SLEEPERS = [("bento", 516, 594, "art/station/poses/hero_cao_bento_sleep.webp"), ("nick", 614, 594, "art/station/poses/hero_gato_nick_sleep.webp")]


def dim(im: Image.Image, box, factor: float) -> None:
    im.paste(ImageEnhance.Brightness(im.crop(box)).enhance(factor), box[:2])


def empty_infirmary() -> Image.Image:
    """O cômodo sem móveis, na mesma montagem de hud-casa/build_room.py (as paredes do Centro de Pesquisa, a porta do
    fundo), na escala da Visão geral e na penumbra."""
    research = Image.open(V2 / "station-research_clean.webp").convert("RGBA")
    top, floor, x0, x1 = 440, 635, 54, 420
    w, h = x1 - x0, floor - top + 12
    layer = Image.new("RGBA", (w, h))
    side = research.crop((482, top, 532, floor + 12))
    layer.paste(research.crop((560, top, 560 + w - side.width, floor + 12)), (side.width, 0))
    layer.paste(side, (0, 0))
    door = research.crop((1030, 478, 1100, 596))
    layer.paste(door, (w - door.width - 10, 478 - top))
    scale = 0.3 / 0.61
    small = layer.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)
    return ImageEnhance.Brightness(small).enhance(0.36)


def sleeper(name: str, x: int, mattress: int, art: str):
    """A pose deitada com 58 px de comprido, a cabeça no travesseiro (à esquerda) e o corpo no colchão, como o
    build_room.py do lote 7 deita a Íris no leito (80% da altura acima da linha do colchão)."""
    im = Image.open(ROOT / art).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    w = 58
    im = im.resize((w, round(im.height * w / im.width)), Image.Resampling.LANCZOS)
    return im, (x, mattress - round(im.height * 0.8))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    markers = Image.open(V2 / "station_clean.webp").convert("RGBA")
    markers.alpha_composite(empty_infirmary(), (440, 652))
    markers.paste(markers.crop((618, 650, 628, 760)), (432, 650))
    dim(markers, BAR, 0.42)
    dim(markers, DORMITORY, 0.42)
    markers.convert("RGB").save(OUT / "station_markers_clean.webp", quality=88, method=6)
    # A noite: a Visão geral com a Enfermaria (a Forja apagada e vazia: quem trabalha nela está dormindo). Quem estava
    # de pé no Dormitório (o Nick, de x 530 a 565) sai com o mesmo trecho do outro beliche (98 px à direita); quem dorme
    # deita nos beliches, e quem estava na Preparação (a Íris e o Bento) fica no escuro da sala apagada.
    night = Image.open(CASA / "station_infirmary_clean.webp").convert("RGBA")
    night.paste(night.crop((628, 556, 663, 620)), (530, 556))
    for name, x, y, art in SLEEPERS:
        night.alpha_composite(*sleeper(name, x, y, art))
    lit = {box: night.crop(box).convert("RGB") for box in (DORMITORY, INFIRMARY)}
    r, g, b = ImageEnhance.Brightness(night.convert("RGB")).enhance(0.3).split()
    night = Image.merge("RGB", (r.point(lambda v: int(v * 0.8)), g.point(lambda v: int(v * 0.9)), b.point(lambda v: min(255, int(v * 1.25) + 6))))
    for box, crop in lit.items():
        night.paste(ImageEnhance.Brightness(crop).enhance(0.55), box[:2])
    dim(night, PREPARATION, 0.35)
    night.save(OUT / "station_night_clean.webp", quality=88, method=6)
    print("ok")


if __name__ == "__main__":
    main()
