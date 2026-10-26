"""As telas do lote A: o antes e o depois do relatório, da barra do alto da Estação e da exploração.

Uso: python3 -B docs/design/hud-recursos/compose.py <pasta das capturas>
A pasta tem:
- before/ui/{report,bar}.png e before/explore/explore.png: o jogo como está na main (capture.gd e tools/capture_106.gd);
- after/ui_<perfil>/{report,bar}.png: com os ícones novos e o código de hoje, nos quatro perfis;
- after_int/ui{,_large}/bar.png e after_int/explore{,_large}/explore.png: com a troca de código sugerida na página
  (feita só para a foto, numa cópia que não entra no PR).
Grava em docs/design/hud-recursos/: report_<perfil>.webp, bar_<perfil>.webp, explore_integration{,_large}.webp e os
três before_after_*.webp.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL = (13, 16, 18)
TEXT = (239, 230, 214)
PROFILES = ["normal", "large", "colorblind", "large_colorblind"]


def save(im: Image.Image, name: str) -> None:
    im.convert("RGB").save(HERE / f"{name}.webp", quality=82, method=6)


def stack(rows: list, scale: float = 1.0) -> Image.Image:
    """Faixas uma embaixo da outra, cada uma com o rótulo em cima."""
    f = ImageFont.truetype(FONT, 28)
    rows = [(label, im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)) for label, im in rows]
    w = max(im.width for _, im in rows) + 40
    h = sum(im.height + 56 for _, im in rows) + 20
    out = Image.new("RGB", (w, h), PANEL)
    d = ImageDraw.Draw(out)
    y = 16
    for label, im in rows:
        d.text((20, y), label, font=f, fill=TEXT)
        out.paste(im.convert("RGB"), (20, y + 40))
        y += im.height + 56
    return out


def main(src: str) -> None:
    s = Path(src)
    load = lambda p: Image.open(s / p).convert("RGB")
    for p in PROFILES:
        save(load(f"after/ui_{p}/report.png"), f"report_{p}")
        save(load(f"after/ui_{p}/bar.png").crop((0, 0, 1920, 130)), f"bar_{p}")
    save(load("after_int/explore/explore.png"), "explore_integration")
    save(load("after_int/explore_large/explore.png"), "explore_integration_large")
    band = (0, 0, 1920, 250)
    save(stack([("Antes (a main)", load("before/ui/report.png").crop(band)),
                ("Depois (os ícones novos; o código de hoje já os usa)", load("after/ui_normal/report.png").crop(band))]),
         "before_after_report")
    bar = (0, 0, 1920, 130)
    save(stack([("Antes (a main)", load("before/ui/bar.png").crop(bar)),
                ("Depois, com o código de hoje: Comida, Água e Energia pintadas; os materiais ainda nos glifos",
                 load("after/ui_normal/bar.png").crop(bar)),
                ("Depois, com a troca sugerida no station_frame.gd: os materiais também pintados",
                 load("after_int/ui/bar.png").crop(bar))]), "before_after_bar")
    top = (1180, 0, 1920, 150)
    save(stack([("Antes (a main; com os ícones novos e o código de hoje fica igual)", load("before/explore/explore.png").crop(top)),
                ("Depois, com a troca sugerida no exploration_hud.gd", load("after_int/explore/explore.png").crop(top))], 1.5),
         "before_after_explore")


if __name__ == "__main__":
    main(sys.argv[1])
