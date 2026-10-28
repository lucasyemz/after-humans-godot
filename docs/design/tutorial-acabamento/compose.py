"""As provas do acabamento do Corredor de Contenção (#147), das capturas de capture_game.gd: o antes (a main) e o
depois (esta branch), os dois do jogo, na mesma câmera, com a mesma equipe e no mesmo ponto; o depois inteiro, em
1920 × 1080; a proposta de luz do código ao lado do depois; e a prancha da arte nova.

Uso: python3 -B docs/design/tutorial-acabamento/compose.py <antes> <depois> <proposta>
     (cada pasta com zone0..zone3, exit e fight, .png, como capture_game.gd grava)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/design/tutorial-acabamento"
ART = ROOT / "art/scenarios"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
SHOTS = [("zone0", "corridor", "1. O corredor"), ("zone1", "cells", "2. A sala das celas"),
         ("zone2", "nick_route", "3. A rota do Nick"), ("zone3", "platform", "4. A plataforma"),
         ("exit", "platform_exit", "O embarque no vagão"), ("fight", "fight", "A primeira luta, no corredor")]
# A proposta de luz, com a referência aprovada no #173 (as capturas daquele PR, sem a lanterna do líder).
PROTO = {"zone0": "docs/design/tutorial/zone_corridor.webp", "zone3": "docs/design/tutorial/zone_platform.webp",
         "fight": "docs/design/tutorial/before/fight_two_clean.webp"}
NEW_ART = [("T_TU25", "Face do pilar"), ("T_TU26", "Face do pilar (2)"), ("T_TU27", "Concreto molhado (sem emenda)"),
           ("T_TUX04_Security_Shutter", "Porta de enrolar, baixada"), ("T_TUX04_Security_Shutter_Open", "Porta de enrolar, erguida"),
           ("T_TU06", "Escada: o alçapão no escuro")]


def font(size: int):
    return ImageFont.truetype(str(FONT), size)


def label(im: Image.Image, text: str) -> Image.Image:
    d = ImageDraw.Draw(im)
    f = font(30)
    w = d.textlength(text, font=f)
    d.rectangle((0, 0, w + 28, 46), fill=(12, 12, 14))
    d.text((14, 6), text, font=f, fill=(236, 226, 205))
    return im


def pair(left: Image.Image, left_text: str, right: Image.Image, right_text: str) -> Image.Image:
    out = Image.new("RGB", (1920 + 12, 540), (12, 12, 14))
    out.paste(label(left.resize((960, 540), Image.Resampling.LANCZOS), left_text), (0, 0))
    out.paste(label(right.resize((960, 540), Image.Resampling.LANCZOS), right_text), (972, 0))
    return out


def triple(panels) -> Image.Image:
    out = Image.new("RGB", (3 * 640 + 2 * 12, 360), (12, 12, 14))
    for i, (im, text) in enumerate(panels):
        out.paste(label(im.resize((640, 360), Image.Resampling.LANCZOS), text), (i * 652, 0))
    return out


def sheet() -> Image.Image:
    cell, gap = 300, 24
    out = Image.new("RGB", (len(NEW_ART) * (cell + gap) + gap, cell + 90), (22, 24, 28))
    d = ImageDraw.Draw(out)
    for i, (code, text) in enumerate(NEW_ART):
        im = Image.open(ART / f"{code}.webp").convert("RGBA")
        k = min(cell / im.width, cell / im.height)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.Resampling.LANCZOS)
        x = gap + i * (cell + gap)
        check = Image.new("RGBA", im.size, (70, 72, 78, 255))
        cd = ImageDraw.Draw(check)
        for cy in range(0, im.height, 16):
            for cx in range(0, im.width, 16):
                if (cx // 16 + cy // 16) % 2:
                    cd.rectangle((cx, cy, cx + 15, cy + 15), fill=(96, 98, 104, 255))
        out.paste(Image.alpha_composite(check, im).convert("RGB"), (x + (cell - im.width) // 2, gap // 2 + (cell - im.height) // 2))
        d.text((x, cell + 20), code, font=font(22), fill=(236, 226, 205))
        d.text((x, cell + 50), text, font=font(20), fill=(170, 165, 155))
    return out


def main(before: str, after: str, proto: str) -> None:
    before, after, proto = Path(before), Path(after), Path(proto)
    for shot, name, title in SHOTS:
        b = Image.open(before / f"{shot}.png").convert("RGB")
        a = Image.open(after / f"{shot}.png").convert("RGB")
        a.save(OUT / f"{name}.webp", quality=86, method=6)
        pair(b, f"Antes (main): {title}", a, f"Depois: {title}").save(OUT / f"before_after_{name}.webp", quality=86, method=6)
        if shot in PROTO:
            ref = Image.open(ROOT / PROTO[shot]).convert("RGB")
            p = Image.open(proto / f"{shot}.png").convert("RGB")
            triple([(ref, "Aprovada (#173)"), (a, "Depois, no jogo"), (p, "Proposta: a lanterna a 30%")]).save(
                OUT / f"light_{name}.webp", quality=86, method=6)
        print(name)
    sheet().save(OUT / "art_sheet.webp", quality=88, method=6)


if __name__ == "__main__":
    main(*sys.argv[1:4])
