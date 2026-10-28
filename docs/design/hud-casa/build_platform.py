"""Os fundos da plataforma do lote 7, a partir da captura limpa da chegada (hud-v2/before/station-report_clean.webp):
- platform_empty_clean.webp: sem a Íris (ela foi para a Enfermaria): o lugar dela fica com a parede de azulejo e o banco
  da plataforma (a metade esquerda do outro banco, espelhada; o banco é simétrico);
- platform_team_clean.webp: o mesmo, com o Brasa (o recruta cão, art/combat/recruits/dog_recruit_01_idle.webp) de pé
  no lugar dela, na altura dos outros;
- platform_train_clean.webp e platform_train_recruit_clean.webp: o trem na plataforma, sem ninguém (a volta vazia), e
  com quem chegou (o Sereno, a coruja recruta, owl_recruit_01_idle.webp) entre o trem e o banco.

Uso: python3 -B docs/design/hud-casa/build_platform.py
"""
import sys
from pathlib import Path
from PIL import Image, ImageOps

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BEFORE = ROOT / "docs/design/hud-v2/before"
OUT = ROOT / "docs/design/hud-casa/before"


def erase(im: Image.Image, box, strip_x: int) -> None:
    """Cobre a caixa com uma faixa vertical limpa da parede e do piso (strip_x), repetida na largura."""
    x0, y0, x1, y1 = box
    strip = im.crop((strip_x, y0, strip_x + 24, y1))
    for x in range(x0, x1, 24):
        im.paste(strip.crop((0, 0, min(24, x1 - x), y1 - y0)), (x, y0))


def sprite(path: str, feet_x: int, feet_y: int, height: int) -> Image.Image:
    im = Image.open(ROOT / path).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    im = im.crop(box)
    w = round(im.width * height / im.height)
    return im.resize((w, height), Image.Resampling.LANCZOS), (feet_x - w // 2, feet_y - height)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    arrival = Image.open(BEFORE / "station-report_clean.webp").convert("RGBA")
    # A Íris fica de x 862 a 966, do alto da cabeça (y 492) aos pés (648); a parede limpa logo à direita dela (x 968).
    erase(arrival, (858, 470, 968, 652), 968)
    # O banco por trás dela: a metade esquerda do outro banco (x 543 a 608, y 556 a 642), espelhada para fechar.
    half = arrival.crop((543, 556, 608, 642))
    bench = Image.new("RGBA", (half.width * 2, half.height))
    bench.paste(half, (0, 0))
    bench.paste(ImageOps.mirror(half), (half.width, 0))
    arrival.alpha_composite(bench, (820, 556))
    arrival.convert("RGB").save(OUT / "platform_empty_clean.webp", quality=88, method=6)
    # O Brasa no lugar dela: a mesma linha dos pés (y 644) e a altura do Bento (176 px, um cão como ele).
    team = arrival.copy()
    im, pos = sprite("art/combat/recruits/dog_recruit_01_idle.webp", 914, 646, 172)
    team.alpha_composite(im, pos)
    team.convert("RGB").save(OUT / "platform_team_clean.webp", quality=88, method=6)
    # O trem na plataforma, sem ninguém (#122: quem chega desce do trem): a plataforma da chegada sem a equipe, com o trem
    # à esquerda. O Bento (x 425 a 530) sai com a parede logo à esquerda dele (x 400). O Nick (x 645 a 748) estava na
    # frente da ponta do banco, do pilar e da parede: o pilar repete o trecho dele logo acima da cabeça do Nick (é concreto
    # liso na vertical), a parede vem de x 755 e a ponta do banco é a metade esquerda dele, espelhada. A Véspera (x 1077 a
    # 1190) sai com a parede de x 1200, e o caixote que ela tapava pela metade (x 1055 a 1115) sai junto.
    empty = arrival.copy()
    erase(empty, (425, 455, 530, 648), 400)
    erase(empty, (705, 488, 750, 648), 755)
    erase(empty, (620, 488, 666, 557), 596)
    pillar = arrival.crop((665, 456, 705, 488))
    for y in range(488, 648, pillar.height):
        empty.paste(pillar.crop((0, 0, pillar.width, min(pillar.height, 648 - y))), (665, y))
    erase(empty, (607, 557, 666, 648), 596)
    empty.paste(ImageOps.mirror(arrival.crop((542, 557, 607, 646))), (607, 557))
    erase(empty, (1050, 465, 1196, 648), 1200)
    empty.convert("RGB").save(OUT / "platform_train_clean.webp", quality=88, method=6)
    # Quem chegou: o Sereno (a coruja recruta) de pé entre o trem e o banco, na linha dos pés da equipe (y 646) e na
    # altura da Véspera (170 px, uma coruja como ela).
    arrived = empty.copy()
    im, pos = sprite("art/combat/recruits/owl_recruit_01_idle.webp", 470, 646, 170)
    arrived.alpha_composite(im, pos)
    arrived.convert("RGB").save(OUT / "platform_train_recruit_clean.webp", quality=88, method=6)
    print("ok")


if __name__ == "__main__":
    main()
