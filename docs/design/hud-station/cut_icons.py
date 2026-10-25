"""Recorta as folhas de ícones geradas (fundo magenta #FF00FF) em WebP com alfa limpo.

Uso: python3 docs/design/hud-station/cut_icons.py <folha_dos_tracos.png> <folha_dos_glifos.png> [<segunda_folha_de_glifos.png>]
As folhas brutas ficam fora do Git. Os traços são pintados (cor própria); os glifos saem brancos, de um tom só, para o
jogo tingir. Sem numpy: só Pillow.
"""
import sys
from pathlib import Path
from PIL import Image, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "art/ui/kit/station/icons"
# Nomes de arquivo em snake_case; o id do traço em data/perks.json (machine-fear) fica no manifesto.
TRAITS = ["agile", "brave", "hopeful", "loyal", "sluggish", "anxious", "gloomy", "machine_fear"]
GLYPHS = ["guardian_defeated", "place_unlocked", "objective_done", "objective_failed", "bed", "station",
          "state_active", "state_light_wound", "state_wounded", "expeditions", "kills", "relic_empty",
          "train", "nav_overview", "nav_facilities", "nav_characters", "nav_research", "nav_hide"]
# Segunda folha (as outras telas da Estação e as Opções).
GLYPHS2 = ["room_quarters", "room_canteen", "room_bar", "room_forge", "room_depot", "room_research",
           "train_arrival", "sleep", "watch", "plan", "next_step", "route",
           "opt_sound", "opt_graphics", "opt_controls", "opt_language", "alert", "recruit"]


def unmix(src: Image.Image) -> Image.Image:
    """Alfa pela distância ao magenta e a cor sem o vazamento do fundo (C = (P - (1-a)M) / a)."""
    src = src.convert("RGB")
    out = Image.new("RGBA", src.size)
    sp, op = src.load(), out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b = sp[x, y]
            # Quanto de magenta o pixel tem: o vermelho e o azul acima do verde. Cinza, vermelho e verde ficam opacos.
            m = min(r, b) - g
            a = 1 - min(1.0, max(0.0, (m - 60) / 150))
            if a <= 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            rr = (r - (1 - a) * 255) / a
            gg = g / a
            bb = (b - (1 - a) * 255) / a
            op[x, y] = (int(min(255, max(0, rr))), int(min(255, max(0, gg))), int(min(255, max(0, bb))), int(a * 255))
    return out


def cells(im: Image.Image, cols: int, rows: int):
    w, h = im.size
    for j in range(rows):
        for i in range(cols):
            yield im.crop((i * w // cols, j * h // rows, (i + 1) * w // cols, (j + 1) * h // rows))


def fit(icon: Image.Image, size: int, pad: float) -> Image.Image:
    a = icon.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    box = a.getbbox()
    icon = icon.crop(box)
    inner = round(size * (1 - 2 * pad))
    scale = inner / max(icon.size)
    icon = icon.resize((max(1, round(icon.width * scale)), max(1, round(icon.height * scale))), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size))
    out.alpha_composite(icon, ((size - icon.width) // 2, (size - icon.height) // 2))
    return out


def despill_edges(im: Image.Image) -> Image.Image:
    """Na borda semitransparente, o que puxa para o magenta (vermelho e azul acima do verde) vira cinza do mesmo brilho:
    tira a rebarba rosada sem mexer no roxo pintado do miolo, que é opaco."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if 0 < a < 250 and r > g + 24 and b > g + 24:
                v = (r * 3 + g * 6 + b) // 10
                px[x, y] = (v, v, v, a)
    return im


def clean(im: Image.Image) -> Image.Image:
    """Zera a cor sob alfa 0 e apaga pixels soltos (alfa < 8)."""
    a = im.getchannel("A").point(lambda v: 0 if v < 8 else v)
    rgb = Image.composite(im.convert("RGB"), Image.new("RGB", im.size), a)
    rgb.putalpha(a)
    return rgb


# Glifos cujo traço na folha veio preto (o pontilhado da rota): usam a silhueta inteira, sem separar o branco do preto.
SILHOUETTE = {"route"}


def glyphs(sheet_path: str, names: list) -> None:
    sheet = Image.open(sheet_path)
    for name, cell in zip(names, cells(sheet, 6, 3)):
        mixed = unmix(cell)
        lum = mixed.convert("L")
        if name in SILHOUETTE:
            alpha = mixed.getchannel("A")
        else:
            alpha = ImageChops.multiply(mixed.getchannel("A"), lum.point(lambda v: min(255, max(0, (v - 70) * 255 // 150))))
        white = Image.new("RGBA", mixed.size, (255, 255, 255, 0))
        white.putalpha(alpha)
        clean(fit(white, 64, 0.06)).save(OUT / f"{name}.webp", lossless=True, method=6)


def main(traits_sheet: str, glyph_sheet: str, glyph_sheet2: str = "") -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(traits_sheet)
    for name, cell in zip(TRAITS, cells(sheet, 4, 2)):
        icon = unmix(cell)
        if name == "hopeful":
            # O halo da manhã vazou o magenta da folha: o rosa vira a luz quente pedida no prompt.
            px = icon.load()
            for y in range(icon.height):
                for x in range(icon.width):
                    r, g, b, a = px[x, y]
                    if b > g and r > g:
                        px[x, y] = (r, max(g, int(r * 0.86)), int(g * 0.7), a)
        icon = despill_edges(fit(icon, 128, 0.04))
        clean(icon).save(OUT / f"trait_{name}.webp", lossless=True, method=6)
    sheet = Image.open(glyph_sheet)
    for name, cell in zip(GLYPHS, cells(sheet, 6, 3)):
        mixed = unmix(cell)
        # Glifo de um tom: o branco é o traço; o contorno preto da folha vira transparente.
        lum = mixed.convert("L")
        alpha = ImageChops.multiply(mixed.getchannel("A"), lum.point(lambda v: min(255, max(0, (v - 70) * 255 // 150))))
        white = Image.new("RGBA", mixed.size, (255, 255, 255, 0))
        white.putalpha(alpha)
        icon = fit(white, 64, 0.06)
        clean(icon).save(OUT / f"{name}.webp", lossless=True, method=6)
    if glyph_sheet2:
        glyphs(glyph_sheet2, GLYPHS2)
    print("ícones:", len(TRAITS) + len(GLYPHS) + (len(GLYPHS2) if glyph_sheet2 else 0))


if __name__ == "__main__":
    main(*sys.argv[1:4])
