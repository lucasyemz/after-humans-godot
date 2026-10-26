"""As pranchas do lote B: a antiga (os SVG de art/ui/icons/) ao lado da nova (os glifos do kit), e a dos estados no
daltonismo e em cinza.

Uso: OLD_PNG=<pasta dos PNG do docs/design/hud-kit/render_svg.mjs, a 24, 32 e 64> python3 -B docs/design/hud-icones/sheet.py
Grava old_new.webp (antigo x novo, a 64, 32 e 24 px, na cor que o jogo usa), states.webp (os pares bom e ruim a 24 e
32 px no Normal, no daltonismo e em cinza) e o _gray de cada uma.
"""
import os
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
NEW = Path(os.environ.get("NEW_ICONS", ROOT / "art/ui/kit/station/icons"))
OLD = Path(os.environ.get("OLD_PNG", "/tmp/old"))
OUT = Path(__file__).parent
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL = (13, 16, 18)
TEXT = (239, 230, 214)
MUTED = (169, 162, 148)
AMBER = (240, 160, 32)
ENEMY = (217, 137, 61)
GOOD, BAD = (134, 201, 143), (226, 103, 91)
GOOD_CB, BAD_CB = (86, 180, 233), (213, 94, 0)

STATES = [("bleeding", "Sangra"), ("poison", "Contaminado"), ("block", "Bloqueio"), ("dodge", "Esquiva"),
          ("marked", "Marcado"), ("stunned", "Atordoado"), ("vulnerable", "Vulnerável"), ("protection", "Guarda")]
GROUPS = [
    ("Estados da luta (bom para quem tem / ruim)", [(f"status-{k}_{s}", f"{label} ({'bom' if s == 'good' else 'ruim'})",
     GOOD if s == "good" else BAD) for k, label in STATES for s in ("good", "bad")]),
    ("Intenções dos inimigos", [("intent-attack", "Ataque", ENEMY), ("intent-attack_area", "Ataque em área", ENEMY),
     ("intent-block", "Bloqueio", ENEMY), ("intent-heal", "Cura", ENEMY), ("intent-move", "Mover", ENEMY),
     ("intent-stunned", "Atordoado", ENEMY), ("intent-unknown", "Sem plano claro", ENEMY)]),
    ("Pontos do corredor", [("node-start", "Início", AMBER), ("node-combat", "Luta", AMBER), ("node-event", "Evento", AMBER),
     ("node-loot", "Achado", AMBER), ("node-rest", "Descanso", AMBER), ("node-boss", "Guardião", AMBER)]),
    ("Marcadores", [("marker-here", "Você está aqui", AMBER), ("marker-available", "Disponível", AMBER),
     ("marker-visited", "Visitado", AMBER)]),
]


def tinted(im: Image.Image, color: tuple) -> Image.Image:
    """Como o modulate da Godot: a cor vezes o RGB do ícone, com o alfa dele."""
    out = ImageChops.multiply(im.convert("RGB"), Image.new("RGB", im.size, color))
    out.putalpha(im.getchannel("A"))
    return out


def old(name: str, side: int) -> Image.Image:
    return Image.open(OLD / f"{name}_{side}.png").convert("RGBA")


def new(name: str, side: int) -> Image.Image:
    return Image.open(NEW / f"{name}.webp").convert("RGBA").resize((side, side), Image.Resampling.LANCZOS)


def old_new() -> None:
    f = ImageFont.truetype(FONT, 24)
    head = ImageFont.truetype(FONT, 28)
    small = ImageFont.truetype(FONT, 20)
    cols, cw, rh = 2, 900, 84
    rows = []
    for title, items in GROUPS:
        rows.append(("head", title))
        for i in range(0, len(items), cols):
            rows.append(("items", items[i:i + cols]))
    h = 90 + sum(56 if r[0] == "head" else rh for r in rows) + 20
    im = Image.new("RGBA", (cols * cw + 40, h), PANEL + (255,))
    d = ImageDraw.Draw(im)
    for c in range(cols):
        x = 30 + c * cw
        d.text((x + 250, 30), "antes (SVG)", font=small, fill=MUTED)
        d.text((x + 560, 30), "depois (kit)", font=small, fill=MUTED)
    y = 70
    for kind, data in rows:
        if kind == "head":
            d.text((30, y + 16), data, font=head, fill=TEXT)
            y += 56
            continue
        for c, (name, label, color) in enumerate(data):
            x = 30 + c * cw
            d.text((x, y + 26), label, font=f, fill=TEXT)
            for j, (src, x0) in enumerate(((old, x + 250), (new, x + 560))):
                xx = x0
                for side in (64, 32, 24):
                    im.alpha_composite(tinted(src(name, side), color), (xx, y + 10 + (64 - side) // 2))
                    xx += side + 22
            d.line((x + 500, y + 42, x + 530, y + 42), fill=MUTED, width=3)
            d.polygon([(x + 532, y + 42), (x + 522, y + 35), (x + 522, y + 49)], fill=MUTED)
        y += rh
    im.convert("RGB").save(OUT / "old_new.webp", quality=92, method=6)
    im.convert("L").convert("RGB").save(OUT / "old_new_gray.webp", quality=92, method=6)


def states() -> None:
    f = ImageFont.truetype(FONT, 24)
    small = ImageFont.truetype(FONT, 20)
    profiles = [("Normal", GOOD, BAD), ("Daltonismo", GOOD_CB, BAD_CB), ("Cinza", (200, 200, 200), (200, 200, 200))]
    cw, rh = 330, 64
    w = 240 + len(profiles) * cw
    h = 80 + len(STATES) * rh + 20
    im = Image.new("RGBA", (w, h), PANEL + (255,))
    d = ImageDraw.Draw(im)
    for p, (title, _, _) in enumerate(profiles):
        d.text((240 + p * cw, 20), title, font=f, fill=TEXT)
        d.text((240 + p * cw, 50), "bom 32 · 24     ruim 32 · 24", font=small, fill=MUTED)
    for r, (key, label) in enumerate(STATES):
        y = 84 + r * rh
        d.text((30, y + 14), label, font=f, fill=TEXT)
        for p, (_, good, bad) in enumerate(profiles):
            x = 240 + p * cw
            for s, color in (("good", good), ("bad", bad)):
                for side in (32, 24):
                    icon = tinted(new(f"status-{key}_{s}", side), color)
                    if p == 2:
                        icon = icon.convert("LA").convert("RGBA")
                    im.alpha_composite(icon, (x, y + 8 + (32 - side) // 2))
                    x += side + 18
                x += 40
    im.convert("RGB").save(OUT / "states.webp", quality=92, method=6)
    im.convert("L").convert("RGB").save(OUT / "states_gray.webp", quality=92, method=6)


if __name__ == "__main__":
    old_new()
    states()
