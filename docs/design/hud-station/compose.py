"""Monta as provas da entrega a partir das telas do render.mjs (em .render/): as telas em WebP, a comparação lado a lado
com o alvo (Normal, Maior, daltonismo), a comparação peça por peça, a redução a 40% e o cinza.

Uso (da raiz do repositório, depois do render.mjs): python3 docs/design/hud-station/compose.py
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
RENDER = HERE / ".render"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
TARGETS = {
    "report": ROOT / "docs/design/reference/hud-target-report-2026-10-25.webp",
    "characters": ROOT / "docs/design/reference/hud-target-characters-2026-10-25.webp",
}
SCREENS = ["report", "report_details", "characters", "characters_training", "characters_locked"]
PROFILES = ["normal", "large", "colorblind", "large_colorblind"]
LABEL = {"normal": "Normal", "large": "Maior (130%)", "colorblind": "Daltonismo", "large_colorblind": "Maior + daltonismo"}


def font(size):
    return ImageFont.truetype(str(FONT), size)


def save(im, name, quality=86):
    im.convert("RGB").save(HERE / name, quality=quality, method=6)


def target_1080(key):
    """O alvo na base 1920x1080 só para comparar: escala pela altura e centraliza (os alvos não são 16:9)."""
    t = Image.open(TARGETS[key]).convert("RGB")
    s = 1080 / t.height
    t = t.resize((round(t.width * s), 1080), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (1920, 1080), (12, 13, 14))
    out.paste(t, ((1920 - t.width) // 2, 0))
    return out, s, (1920 - t.width) // 2


def labeled(im, text, w, h):
    im = im.resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (w, h + 44), (16, 17, 19))
    out.paste(im, (0, 44))
    ImageDraw.Draw(out).text((14, 8), text, font=font(28), fill=(239, 230, 214))
    return out


def side_by_side(left, lt, right, rt):
    a = labeled(left, lt, 960, 540)
    b = labeled(right, rt, 960, 540)
    out = Image.new("RGB", (1928, a.height), (40, 42, 46))
    out.paste(a, (0, 0))
    out.paste(b, (968, 0))
    return out


# Peças: [nome, caixa no alvo (pixels do arquivo do alvo), caixa na entrega (1920x1080)].
PIECES = {
    "report": [
        ["Faixa: fase e conclusão", (30, 70, 560, 258), (36, 24, 690, 240)],
        ["Chips de resultado e a dica", (555, 100, 1160, 250), (690, 50, 1470, 216)],
        ["Recursos recuperados", (1175, 82, 1592, 258), (1478, 24, 1884, 240)],
        ["Carta do herói (Ativo)", (150, 662, 465, 922), (140, 606, 530, 944)],
        ["Carta do herói (Ferido)", (485, 662, 800, 922), (556, 606, 946, 944)],
        ["Botão principal e VER DETALHES", (610, 905, 1022, 972), (700, 986, 1500, 1074)],
    ],
    "characters": [
        ["Plaqueta da sala", (22, 0, 465, 92), (24, 8, 560, 118)],
        ["Chips de recursos e engrenagem", (828, 0, 1600, 92), (1000, 8, 1896, 118)],
        ["Abas dos heróis", (40, 128, 510, 250), (40, 140, 600, 300)],
        ["Lista de habilidades", (36, 255, 525, 558), (40, 306, 614, 640)],
        ["Detalhe da habilidade", (34, 565, 532, 772), (40, 640, 614, 870)],
        ["Painel PERSONAGEM", (1112, 138, 1598, 600), (1292, 128, 1896, 700)],
        ["Traços", (1112, 600, 1598, 862), (1292, 690, 1896, 980)],
        ["Rodapé: voltar, teclas e abas", (18, 812, 1110, 975), (18, 900, 1290, 1076)],
        ["Botão principal", (1312, 880, 1604, 972), (1396, 984, 1900, 1076)],
    ],
}


def piece_board(key, screen):
    target = Image.open(TARGETS[key]).convert("RGB")
    rows = []
    for name, tb, db in PIECES[key]:
        cells = [target.crop(tb)] + [Image.open(RENDER / f"{screen}_{p}.png").convert("RGB").crop(db) for p in ["normal", "colorblind"]]
        # Peças altas ganham mais altura, para o texto continuar legível na prancha.
        aspect = (db[2] - db[0]) / (db[3] - db[1])
        h = 420 if aspect < 1.6 else 300 if aspect < 3.5 else 170
        cells = [c.resize((max(1, round(c.width * h / c.height)), h), Image.Resampling.LANCZOS) for c in cells]
        w = sum(c.width for c in cells) + 12 * (len(cells) + 1)
        row = Image.new("RGB", (w, h + 92), (24, 26, 29))
        d = ImageDraw.Draw(row)
        d.text((12, 8), name, font=font(28), fill=(240, 160, 32))
        x = 12
        for c, lab in zip(cells, ["Alvo", "Entrega · Normal", "Entrega · Daltonismo"]):
            row.paste(c, (x, 50))
            # O rótulo embaixo do recorte, sem cobrir a peça.
            d.text((x + 2, 56 + h), lab, font=font(24), fill=(239, 230, 214))
            x += c.width + 12
        rows.append(row)
    w = max(r.width for r in rows)
    out = Image.new("RGB", (w, sum(r.height for r in rows) + 8 * len(rows)), (40, 42, 46))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height + 8
    if out.width > 3000:
        out = out.resize((3000, round(out.height * 3000 / out.width)), Image.Resampling.LANCZOS)
    return out


def main():
    checks = json.loads((RENDER / "checks.json").read_text())
    for screen in SCREENS:
        for p in PROFILES:
            suffix = "" if p == "normal" else f"_{p}"
            im = Image.open(RENDER / f"{screen}_{p}.png").convert("RGB")
            save(im, f"{screen}{suffix}.webp")
            save(im.resize((768, 432), Image.Resampling.LANCZOS), f"{screen}{suffix}_40.webp", 90)
            scrolled = RENDER / f"{screen}_{p}_scrolled.png"
            if scrolled.exists():
                save(Image.open(scrolled), f"{screen}{suffix}_scrolled.webp")
        save(ImageOps.grayscale(Image.open(RENDER / f"{screen}_normal.png")), f"{screen}_gray.webp")
    for key in TARGETS:
        target, _, _ = target_1080(key)
        for p in ["normal", "large", "colorblind"]:
            suffix = "" if p == "normal" else f"_{p}"
            ours = Image.open(RENDER / f"{key}_{p}.png")
            save(side_by_side(target, "Alvo do Lucas (escalado à altura de 1080)", ours, f"Entrega · {LABEL[p]} · captura real do jogo"),
                 f"comparison_{key}{suffix}.webp")
        save(piece_board(key, key), f"pieces_{key}.webp")
    summary = {k: {"ok": v["ok"], "problems": v["problems"], "overlaps": v["overlaps"], "pieces": v["pieces"], "scroll": v["scroll"],
                   "min_text_px": min(t["size"] for t in v["texts"]), "texts": v["texts"], "targets": v["hits"]} for k, v in checks.items()}
    (HERE / "checks.json").write_text(json.dumps(summary, ensure_ascii=False, separators=(",", ":")).replace('},{', '},\n{') + "\n")
    print("ok:", sum(v["ok"] for v in summary.values()), "de", len(summary))


if __name__ == "__main__":
    main()
