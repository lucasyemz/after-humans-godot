"""Provas extras do lote 5 (#109): o acampamento novo lado a lado com a referência da Unreal, nos quatro perfis, e a
importação das capturas do jogo (capture.gd) para before/ (os fundos limpos em WebP e os antes de hoje reduzidos).

Uso (da raiz do repositório):
  python3 docs/design/hud-ajustes/compare.py import <pasta-das-capturas>   # depois do capture.gd
  python3 docs/design/hud-ajustes/compare.py                               # depois do render.mjs e do compose.py
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
CLEAN = ["camp", "camp_nick", "fight_patrol", "fight_level", "fight_boss", "fight_fled", "fight_defeat"]
TODAY = ["today_camp", "today_pause", "today_result"]


def labeled(im, text, w, h):
    im = im.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (w, h + 44), (16, 17, 19))
    out.paste(im, (0, 44))
    ImageDraw.Draw(out).text((14, 8), text, font=ImageFont.truetype(str(FONT), 28), fill=(239, 230, 214))
    return out


def import_captures(src):
    src = Path(src)
    before = HERE / "before"
    before.mkdir(exist_ok=True)
    for name in CLEAN:
        Image.open(src / f"{name}.png").convert("RGB").save(before / f"{name}_clean.webp", quality=84, method=6)
        if (src / f"{name}.json").exists():
            shutil.copy(src / f"{name}.json", before / f"{name}.json")
    # Os antes de hoje só entram nas comparações (960x540): a metade da resolução basta.
    for name in TODAY:
        if (src / f"{name}.png").exists():
            Image.open(src / f"{name}.png").convert("RGB").resize((960, 540), Image.Resampling.LANCZOS).save(before / f"{name}.jpg", quality=86)


def main():
    unreal = Image.open(ROOT / "docs/design/reference/unreal-camp-hud.jpg")
    for p in ["normal", "large", "colorblind", "large_colorblind"]:
        suffix = "" if p == "normal" else f"_{p}"
        a = labeled(unreal, "Referência: o acampamento da Unreal", 960, 540)
        b = labeled(Image.open(HERE / ".render" / f"camp_preview_{p}.png"), "Agora: a mesma estrutura no kit (captura do jogo)", 960, 540)
        out = Image.new("RGB", (1928, a.height), (40, 42, 46))
        out.paste(a, (0, 0))
        out.paste(b, (968, 0))
        out.save(HERE / f"camp_unreal{suffix}.webp", quality=86, method=6)
    print("ok: camp_unreal nos quatro perfis")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "import":
        import_captures(sys.argv[2])
    else:
        main()
