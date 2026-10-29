"""As provas do mapa do tutorial (#147), das capturas na Godot (capture_map.gd): cada zona do Corredor de Contenção em
1920 × 1080 (zone_<nome>.webp, sem a interface, e zone_<nome>_hud.webp, com a HUD da exploração; o embarque no fim, em
zone_platform_exit.webp) e o lado a lado com
um cenário que já existe, na mesma câmera, com a mesma equipe e no mesmo ponto da zona (compare_<nome>.webp).

Uso: python3 -B docs/design/tutorial/compose_map.py <captura do mapa> <pasta das capturas de referência>
     (a pasta das referências tem SealedShelter/, SewerDucts/ e TriageGate/, cada uma com <Mapa>-<zona>.png)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/design/tutorial"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
# A zona do mapa novo, o nome da prova e o cenário de hoje ao lado (o que mais se parece: o interior fechado do Abrigo,
# os Dutos no subsolo, o Portão com a luz de fora).
ZONES = [(0, "corridor", "1. O corredor de contenção", "SealedShelter", 0, "Abrigo Lacrado, zona 1"),
         (1, "cells", "2. A sala das celas", "SealedShelter", 1, "Abrigo Lacrado, zona 2"),
         (2, "nick_route", "3. A rota do Nick", "SewerDucts", 0, "Dutos de Esgoto, zona 1"),
         (3, "platform", "4. A plataforma e o trem", "TriageGate", 0, "Portão de Triagem, zona 1")]


def font(size: int):
    return ImageFont.truetype(str(FONT), size)


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    f = font(30)
    w = d.textlength(text, font=f)
    d.rectangle((0, 0, w + 28, 46), fill=(12, 12, 14))
    d.text((14, 6), text, font=f, fill=(236, 226, 205))
    return im


def main(src: str, refs: str) -> None:
    src, refs = Path(src), Path(refs)
    for zone, name, title, ref_map, ref_zone, ref_title in ZONES:
        shot = Image.open(src / f"TU-{zone}.png").convert("RGB")
        shot.save(OUT / f"zone_{name}.webp", quality=86, method=6)
        Image.open(src / f"TU-{zone}-hud.png").convert("RGB").save(OUT / f"zone_{name}_hud.webp", quality=86, method=6)
        ref = Image.open(refs / ref_map / f"{ref_map}-{ref_zone}.png").convert("RGB")
        pair = Image.new("RGB", (1920 + 12, 540), (12, 12, 14))
        pair.paste(label(shot.resize((960, 540), Image.Resampling.LANCZOS), f"Novo: {title}"), (0, 0))
        pair.paste(label(ref.resize((960, 540), Image.Resampling.LANCZOS), f"Hoje: {ref_title}"), (972, 0))
        pair.save(OUT / f"compare_{name}.webp", quality=86, method=6)
        print(name)
    # O fim do mapa: a equipe na porta aberta do vagão (o embarque).
    Image.open(src / "TU-exit.png").convert("RGB").save(OUT / "zone_platform_exit.webp", quality=86, method=6)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
