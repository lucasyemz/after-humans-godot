"""A Enfermaria na Estação em corte, montada na linguagem dos outros cômodos (proposta para a #121; a Godot monta o
cômodo de verdade em station_build.gd, com caixas, superfícies e cards):
- o lugar: no subsolo 2, de x -1240 a -640 (600 cm, como o Depósito), embaixo do Dormitório e à esquerda do Centro de
  Pesquisa, com o piso e o teto do subsolo 2 (B2_FLOOR -940, B2_CEILING -620);
- as paredes, o lambri de azulejo, o piso e a luminária são os do Centro de Pesquisa (painted_plaster_wall,
  long_white_tiles, concrete_floor_painted, luz COOL), recortados da própria captura do jogo;
- os móveis são os cards novos (art/station/cards/Infirmary_*.webp), na escala da câmera do cômodo (0,61 px/cm);
- quem está em recuperação deita num leito, com a pose de dormir que já existe (art/station/poses/*_sleep.webp).

Uso: python3 -B docs/design/hud-casa/build_room.py
Grava em docs/design/hud-casa/before/: station-infirmary_clean.webp (a câmera do cômodo, a da Pesquisa com a Enfermaria
à esquerda), station_infirmary_clean.webp (a Visão geral com a Enfermaria) e infirmary_layer.webp (só o cômodo).
"""
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BEFORE = ROOT / "docs/design/hud-v2/before"
OUT = ROOT / "docs/design/hud-casa/before"
CARDS = ROOT / "art/station/cards"
POSES = ROOT / "art/station/poses"

# A câmera do cômodo (station-research_clean.webp): x = 420 + 0,61 * (x_cm + 640); o subsolo 2 vai de y 440 (teto) a
# 635 (piso). A Enfermaria (x -1240 a -640) cai de x 54 a 420.
PX_PER_CM = 0.61
ROOM_X0, ROOM_X1 = 54, 420
TOP, FLOOR = 440, 635
# Na Visão geral (station_clean.webp): x = 812 + 0,3 * x_cm; o subsolo 2 vai de y 655 a 752.
OV_X0, OV_TOP, OV_SCALE = 440, 652, 0.3 / 0.61


def card(name: str, width_cm: float) -> Image.Image:
    im = Image.open(CARDS / f"{name}.webp").convert("RGBA")
    w = round(width_cm * PX_PER_CM)
    return im.resize((w, round(im.height * w / im.width)), Image.Resampling.LANCZOS)


def put(layer: Image.Image, im: Image.Image, x: int, floor: int = FLOOR - TOP - 4) -> None:
    """O card com o pé no piso do cômodo (as coordenadas são as da camada)."""
    layer.alpha_composite(im, (x, floor - im.height))


def room_layer(research: Image.Image) -> Image.Image:
    w, h = ROOM_X1 - ROOM_X0, FLOOR - TOP + 12
    layer = Image.new("RGBA", (w, h))
    # Uma faixa da parede lateral (o trapézio iluminado à esquerda do Centro de Pesquisa) e a parede do fundo com o
    # lambri e a luminária, recortadas da mesma câmera.
    side = research.crop((482, TOP, 532, FLOOR + 12))
    back = research.crop((560, TOP, 560 + w - side.width, FLOOR + 12))
    layer.paste(back, (side.width, 0))
    layer.paste(side, (0, 0))
    # A porta do fundo (a do Centro de Pesquisa), à direita, atrás do segundo leito: como no 3D o leito fica à frente
    # da parede, a porta aparece por cima dele.
    door = research.crop((1030, 478, 1100, 596))
    layer.paste(door, (w - door.width - 10, 478 - TOP))
    # Os móveis: o armário de remédios no canto, os dois leitos e o soro entre eles. O biombo, o lavatório e o carrinho
    # ficam para o nível 2 (os leitos 3 e 4), com o cômodo mais cheio.
    # As larguras (cm) dão a altura pela proporção do card: o armário com 150 cm e o soro com 171, perto dos heróis (cerca
    # de 150 cm nesta câmera); o leito com 79.
    bed = card("Infirmary_Bed", 172)
    x_bed = 136
    put(layer, card("Infirmary_Cabinet", 124), 54)
    put(layer, bed, x_bed)
    put(layer, card("Infirmary_Drip", 55), x_bed + bed.width - 4)
    put(layer, bed, x_bed + bed.width + 16)
    # A Íris em recuperação no primeiro leito: a pose de dormir, com a cabeça no travesseiro (à esquerda) e o corpo no
    # colchão (a linha medida no card: 30 px de 220 abaixo do alto, a cerca de 68 cm do piso).
    pose = Image.open(POSES / "hero_sapo_iris_sleep.webp").convert("RGBA")
    pw = round(bed.width * 0.92)
    pose = pose.resize((pw, round(pose.height * pw / pose.width)), Image.Resampling.LANCZOS)
    mattress = (FLOOR - TOP - 4) - bed.height + round(bed.height * 30 / 220)
    layer.alpha_composite(pose, (x_bed + 2, mattress - round(pose.height * 0.80)))
    return layer


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    research = Image.open(BEFORE / "station-research_clean.webp").convert("RGBA")
    layer = room_layer(research)
    layer.save(OUT / "infirmary_layer.webp", lossless=True)
    room = research.copy()
    # O pilar da esquerda e a laje do piso fecham o cômodo, como nos vizinhos.
    pillar = research.crop((413, TOP - 18, 432, FLOOR + 14))
    room.alpha_composite(layer, (ROOM_X0, TOP))
    room.paste(pillar, (ROOM_X0 - 18, TOP - 18))
    slab = research.crop((440, FLOOR, 440 + (ROOM_X1 - ROOM_X0), FLOOR + 14))
    room.paste(slab, (ROOM_X0, FLOOR))
    room.convert("RGB").save(OUT / "station-infirmary_clean.webp", quality=88, method=6)
    overview = Image.open(BEFORE / "station_clean.webp").convert("RGBA")
    small = layer.resize((round(layer.width * OV_SCALE), round(layer.height * OV_SCALE)), Image.Resampling.LANCZOS)
    small = ImageEnhance.Brightness(small).enhance(0.92)
    overview.alpha_composite(small, (OV_X0, OV_TOP))
    pillar_ov = overview.crop((618, 650, 628, 760))
    overview.paste(pillar_ov, (OV_X0 - 8, 650))
    overview.convert("RGB").save(OUT / "station_infirmary_clean.webp", quality=88, method=6)
    print("camada", layer.size, "na Visão geral", small.size)


if __name__ == "__main__":
    main()
