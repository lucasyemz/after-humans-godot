"""Leva as capturas da Enfermaria nova (capture_infirmary.gd) para a página e para before/ (os ajustes do Lucas de 26/10):
- before/station-infirmary_clean.webp: a câmera do cômodo no nível 1 (o fundo do painel da Enfermaria);
- before/station_day5_clean.webp: a Visão geral na câmera da HUD, no nível 1, com a Forja de nível 1 acesa (o fundo da
  Visão geral, de IR AO MAPA e das telas do Dia 5);
- before/station-forge-workers_clean.webp: a Forja de nível 1 com o Brasa e o Otto (o fundo de "Quem trabalha aqui");
- infirmary_room_1.webp e infirmary_room_2.webp: o cômodo nos dois níveis, e infirmary_station.webp: a Estação
  inteira, sem a HUD, no nível 1;
- infirmary_before_after.webp: a montagem que o PR tinha (antes) e a captura do jogo (depois), o cômodo recortado.

Uso (da raiz do repositório): python3 -B docs/design/hud-casa/prepare_infirmary.py <pasta da captura> <montagem antiga.webp>
     (a montagem antiga é o before/station-infirmary_clean.webp do commit 05a6b3c, tirado com git show)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = ROOT / "docs/design/hud-casa"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
# O recorte do cômodo para o antes e depois: na montagem antiga (a Enfermaria de 6 m à esquerda da Pesquisa) e na
# captura (a de 12 m), do armário ao pilar da direita, com o andar de cima cortado.
CROP_OLD = (60, 420, 470, 660)
CROP_NEW = (440, 400, 1200, 680)


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(str(FONT), 30)
    w = d.textlength(text, font=f)
    d.rectangle((0, 0, w + 28, 46), fill=(12, 12, 14))
    d.text((14, 6), text, font=f, fill=(236, 226, 205))
    return im


def main(src: str, old: str) -> None:
    src = Path(src)
    shot = lambda name: Image.open(src / f"{name}.png").convert("RGB")
    shot("infirmary_room_1").save(HERE / "before/station-infirmary_clean.webp", quality=88, method=6)
    shot("infirmary_hud_1").save(HERE / "before/station_day5_clean.webp", quality=88, method=6)
    shot("infirmary_overview_1").save(HERE / "infirmary_station.webp", quality=86, method=6)
    shot("forge_workers").save(HERE / "before/station-forge-workers_clean.webp", quality=88, method=6)
    for level in (1, 2):
        shot(f"infirmary_room_{level}").save(HERE / f"infirmary_room_{level}.webp", quality=86, method=6)
    a = Image.open(old).convert("RGB").crop(CROP_OLD)
    b = shot("infirmary_room_1").crop(CROP_NEW)
    h = 400
    a = label(a.resize((round(a.width * h / a.height), h), Image.Resampling.LANCZOS), "Antes: a montagem do PR (6 m)")
    b = label(b.resize((round(b.width * h / b.height), h), Image.Resampling.LANCZOS), "Depois: a captura do jogo (12 m)")
    out = Image.new("RGB", (a.width + b.width + 12, h), (12, 12, 14))
    out.paste(a, (0, 0))
    out.paste(b, (a.width + 12, 0))
    out.save(HERE / "infirmary_before_after.webp", quality=86, method=6)
    print("ok", out.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
