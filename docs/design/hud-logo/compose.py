"""As propostas de logo sobre a tela do título do jogo (before/title_clean.webp, a captura sem a logo).

Uso: python3 docs/design/hud-logo/compose.py
Para a proposta: title_<id>.webp (a tela 1920x1080 com a logo grande), title_<id>_40.webp (a tela a 40%, o celular),
small_<id>.webp (a logo pequena: 320 e 200 px de largura sobre três trechos da arte e sobre o painel), o _gray
dessas duas; portrait_<id>.webp (o retrato 1080x1920 a 50%, só o fundo e a logo: a Godot não abre em pé no xvfb, então
sem os botões); e choices.webp, a de hoje e a proposta lado a lado.

A logo grande ocupa a caixa da logo de hoje (x 65, y 160, 880x241, a de title_screen.gd), alinhada à esquerda em x 100
(a borda dos botões) e com a altura inteira da caixa; quando a logo fica mais larga que 845 px, a largura manda.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
FONT = str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf")
PANEL = (13, 16, 18)
TEXT = (239, 230, 214)
MUTED = (169, 162, 148)
PROPOSALS = [("stone", "Pedra tomada pelo mato")]
LEFT = 100
MAX_H = 210


def save(im: Image.Image, name: str, gray: bool = True) -> None:
    im.convert("RGB").save(HERE / f"{name}.webp", quality=82, method=6)
    if gray:
        im.convert("L").convert("RGB").save(HERE / f"{name}_gray.webp", quality=82, method=6)


def place(bg: Image.Image, logo: Image.Image, box: list) -> tuple:
    x, y, w, h = box
    # A logo em duas linhas a 241 px de altura chegava a 28 px dos botões (a de hoje deixa 88): fica com 210.
    h_max = min(h, MAX_H)
    scale = min(h_max / logo.height, (x + w - LEFT) / logo.width)
    size = (round(logo.width * scale), round(logo.height * scale))
    scaled = logo.resize(size, Image.Resampling.LANCZOS)
    top = round(y + (h - size[1]) / 2)
    bg.alpha_composite(scaled, (LEFT, top))
    # O que se vê (sem a margem transparente), em coordenadas da tela.
    x0, y0, x1, y1 = scaled.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    return (LEFT + x0, top + y0, x1 - x0, y1 - y0)


def portrait(key: str) -> Image.Image:
    """O retrato do title_screen.gd (PORTRAIT): o fundo em pé e a logo em (80, 190), na caixa de 920 x 252."""
    bg = Image.open(ROOT / "art/ui/title/title_background_portrait.png").convert("RGBA")
    logo = Image.open(HERE / f"logo_{key}.webp").convert("RGBA")
    scale = min(920 / logo.width, 920 * 560 / 2048 / logo.height)
    size = (round(logo.width * scale), round(logo.height * scale))
    bg.alpha_composite(logo.resize(size, Image.Resampling.LANCZOS), (80, 190))
    return bg.resize((540, 960), Image.Resampling.LANCZOS)


def small_board(key: str, label: str, clean: Image.Image) -> Image.Image:
    logo = Image.open(HERE / f"logo_{key}_small.webp").convert("RGBA")
    f = ImageFont.truetype(FONT, 24)
    # Três trechos da arte do título: o canto escuro onde a logo fica, o céu claro e a equipe (o fundo mais cheio); e o painel do kit.
    spots = [("canto escuro", (40, 60)), ("céu claro", (1060, 60)), ("a equipe", (980, 560))]
    cw, ch = 420, 300
    im = Image.new("RGBA", (40 + (len(spots) + 1) * (cw + 20), ch * 2 + 120), PANEL + (255,))
    d = ImageDraw.Draw(im)
    d.text((40, 20), f"{label}: a logo pequena a 320 e a 200 px de largura", font=f, fill=TEXT)
    for row, width in enumerate((320, 200)):
        small = logo.resize((width, round(logo.height * width / logo.width)), Image.Resampling.LANCZOS)
        for i, (name, (sx, sy)) in enumerate(spots + [("painel", (None, None))]):
            x0, y0 = 40 + i * (cw + 20), 70 + row * (ch + 20)
            tile = clean.crop((sx, sy, sx + cw, sy + ch)) if sy is not None else Image.new("RGBA", (cw, ch), PANEL + (255,))
            tile = tile.copy()
            tile.alpha_composite(small, ((cw - small.width) // 2, (ch - small.height) // 2))
            im.alpha_composite(tile, (x0, y0))
            if row == 1:
                d.text((x0, y0 + ch + 4), name, font=f, fill=MUTED)
    return im


def main() -> None:
    box = json.loads((HERE / "before/title.json").read_text())["logo"]
    clean = Image.open(HERE / "before/title_clean.webp").convert("RGBA")
    today = Image.open(HERE / "before/title.webp").convert("RGBA")
    shots = [("Hoje", today)]
    for key, label in PROPOSALS:
        screen = clean.copy()
        size = place(screen, Image.open(HERE / f"logo_{key}.webp").convert("RGBA"), box)
        print(key, "visível na tela (x, y, l, a):", size)
        save(screen, f"title_{key}", False)
        save(screen.resize((768, 432), Image.Resampling.LANCZOS), f"title_{key}_40")
        save(small_board(key, label, clean), f"small_{key}")
        save(portrait(key), f"portrait_{key}", False)
        shots.append((label, screen))
    f = ImageFont.truetype(FONT, 30)
    w, h = 960, 540
    board = Image.new("RGBA", (w * len(shots) + 20 * (len(shots) + 1), h + 84), PANEL + (255,))
    d = ImageDraw.Draw(board)
    for i, (label, shot) in enumerate(shots):
        x, y = 20 + i * (w + 20), 20
        d.text((x, y), label, font=f, fill=TEXT)
        board.alpha_composite(shot.resize((w, h), Image.Resampling.LANCZOS), (x, y + 44))
    save(board, "choices", False)


if __name__ == "__main__":
    main()
