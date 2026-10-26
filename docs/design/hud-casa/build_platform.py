"""Os fundos da plataforma do lote 7, a partir da captura limpa da chegada (hud-v2/before/station-report_clean.webp):
- platform_empty_clean.webp: sem a Íris (ela foi para a Enfermaria): o lugar dela fica com a parede de azulejo e o banco
  da plataforma (a metade esquerda do outro banco, espelhada; o banco é simétrico);
- platform_team_clean.webp: o mesmo, com o Brasa (o recruta cão, art/combat/recruits/dog_recruit_01_idle.webp) de pé
  no lugar dela, na altura dos outros;
- platform_recruit_clean.webp e platform_nobody_clean.webp: a plataforma do trem (hud-v2/before/station-train_clean.webp)
  sem a Dora; com um recruta (a coruja, owl_recruit_01_idle.webp) esperando, e vazia.

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
    # A plataforma do trem sem a Dora (de x 455 a 730, do alto da cabeça, y 290, aos pés, 885): a parede e o piso vêm do
    # bloco logo à esquerda, na mesma altura (o piso tem perspectiva só na vertical). O banco por trás dela (de x 410 a
    # 820): as tábuas do meio (y 549 a 706) repetem a coluna de x 752, entre as pontas que ficaram à vista.
    train = Image.open(BEFORE / "station-train_clean.webp").convert("RGBA")
    source = train.copy()
    train.paste(source.crop((130, 290, 405, 772)), (455, 290))
    train.paste(source.crop((130, 772, 405, 890)), (455, 772))
    slat = source.crop((752, 549, 758, 706))
    for x in range(455, 730, 6):
        train.paste(slat, (x, 549))
    # A ponta da colher da Dora, que passava do pé direito do banco.
    train.paste(source.crop((830, 740, 846, 772)), (814, 740))
    train.convert("RGB").save(OUT / "platform_nobody_clean.webp", quality=88, method=6)
    recruit = train.copy()
    im, pos = sprite("art/combat/recruits/owl_recruit_01_idle.webp", 590, 884, 560)
    recruit.alpha_composite(im, pos)
    recruit.convert("RGB").save(OUT / "platform_recruit_clean.webp", quality=88, method=6)
    print("ok")


if __name__ == "__main__":
    main()
