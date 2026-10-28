"""Leva as capturas da Enfermaria (capture_infirmary.gd) para a página e para before/ (os ajustes do Lucas de 26/10).
O antes e o depois saem os dois do jogo, na mesma câmera, com as mesmas pessoas: o antes é a Estação de hoje (a main,
sem o pacote) e o depois, a Estação com o pacote de infirmary_proto.py.
- before/station-infirmary_clean.webp: a câmera do cômodo no nível 1 (o fundo do painel da Enfermaria);
- before/station_day5_clean.webp: a Visão geral na câmera da HUD, no nível 1, com a Forja de nível 1 acesa (o fundo da
  Visão geral, de IR AO MAPA e das telas do Dia 5);
- before/station-forge-workers_clean.webp: a Forja de nível 1 com o Brasa e o Otto (o fundo de "Quem trabalha aqui");
- infirmary_room_1.webp e infirmary_room_2.webp: o cômodo nos dois níveis, e infirmary_station.webp: a Estação
  inteira, sem a HUD, no nível 1;
- before/game/: o jogo de hoje, com a interface, no mesmo Dia 5 (o "antes" da Visão geral, do painel da Enfermaria, da
  Sala com a Íris e com a Lupa e da Forja);
- infirmary_before_after.webp, infirmary_before_after_2.webp e infirmary_before_after_station.webp: o cômodo nos
  níveis 1 e 2 e a Estação inteira, hoje no jogo e com a proposta no jogo.

Uso (da raiz do repositório):
  python3 -B docs/design/hud-casa/prepare_infirmary.py <captura com o pacote> <captura sem o pacote>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = ROOT / "docs/design/hud-casa"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
GAME = HERE / "before/game"
NOW = "Hoje, no jogo (captura da Godot, a main)"
NEW = "Com a proposta, no jogo (captura da Godot com o pacote)"


def label(im: Image.Image, text: str, w: int = 960, h: int = 540) -> Image.Image:
    im = im.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (w, h + 44), (16, 17, 19))
    out.paste(im, (0, 44))
    ImageDraw.Draw(out).text((14, 8), text, font=ImageFont.truetype(str(FONT), 28), fill=(239, 230, 214))
    return out


def pair(a: Image.Image, b: Image.Image, name: str) -> None:
    a, b = label(a, NOW), label(b, NEW)
    out = Image.new("RGB", (a.width + b.width + 8, a.height), (40, 42, 46))
    out.paste(a, (0, 0))
    out.paste(b, (a.width + 8, 0))
    out.save(HERE / name, quality=86, method=6)
    print("ok", name, out.size)


def main(src: str, today: str) -> None:
    src, today = Path(src), Path(today)
    shot = lambda name: Image.open(src / f"{name}.png").convert("RGB")
    now = lambda name: Image.open(today / f"{name}.png").convert("RGB")
    shot("infirmary_room_1").save(HERE / "before/station-infirmary_clean.webp", quality=88, method=6)
    shot("infirmary_hud_1").save(HERE / "before/station_day5_clean.webp", quality=88, method=6)
    shot("infirmary_overview_1").save(HERE / "infirmary_station.webp", quality=86, method=6)
    shot("forge_workers").save(HERE / "before/station-forge-workers_clean.webp", quality=88, method=6)
    for level in (1, 2):
        shot(f"infirmary_room_{level}").save(HERE / f"infirmary_room_{level}.webp", quality=86, method=6)
    GAME.mkdir(exist_ok=True)
    for name, screen in [("overview", "infirmary_overview"), ("room", "infirmary"), ("characters_fallen", "characters_fallen"),
                         ("characters_post", "characters_post"), ("forge", "room_workers")]:
        now(f"infirmary_ui_{name}").save(GAME / f"{screen}.webp", quality=86, method=6)
    pair(now("infirmary_room_1"), shot("infirmary_room_1"), "infirmary_before_after.webp")
    pair(now("infirmary_room_2"), shot("infirmary_room_2"), "infirmary_before_after_2.webp")
    pair(now("infirmary_overview_1"), shot("infirmary_overview_1"), "infirmary_before_after_station.webp")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
