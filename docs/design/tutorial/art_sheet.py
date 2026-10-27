"""A prancha da arte do mapa do tutorial (#147): cada peça de art/scenarios/T_TU* com a medida em que o mapa a usa
(build_map.py), o tamanho do arquivo e o uso. As zonas em si são capturas da Godot (capture_map.gd e compose_map.py).

Uso: python3 -B docs/design/tutorial/art_sheet.py   (grava docs/design/tutorial/art_sheet.webp)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/scenarios"
OUT = Path(__file__).resolve().parent
# A largura em metros de cada peça no mapa (a altura sai da proporção do arquivo); a tabela da página repete estes números.
SIZES = {"T_TU01": 10.2, "T_TU11": 10.2, "T_TU12": 10.2, "T_TU03": 14.6, "T_TU02": 10.6, "T_TU13": 10.6, "T_TU24": 10.6,
         "T_TU09": 12.0,
         "T_TU04": 1.73, "T_TU05": 1.9, "T_TU06": 3.32, "T_TU07": 1.15, "T_TU08": 0.3, "T_TU08_Lit": 0.3, "T_TU10": 10.0,
         "T_TU14": 1.45, "T_TU15": 0.95, "T_TU16": 0.95, "T_TU17": 1.5, "T_TU19": 0.8,
         "T_TU20": 3.3, "T_TU21": 2.9, "T_TU22": 0.3,
         "T_TUX01_Security_Door": 2.44, "T_TUX01_Security_Door_Open": 2.44, "T_TUX02_Maintenance_Locker": 1.25,
         "T_TUX02_Maintenance_Locker_Open": 1.25, "T_TUX03_Door_Panel": 0.55, "T_TUX03_Door_Panel_Open": 0.55}
# As peças que o mapa não usa na proporção do arquivo: os pisos (a amostra projetada, 10,6 m por 10,6, e a faixa da
# plataforma, de 4,8 m de fundo) e as grades (estreitadas para a abertura da cela).
HEIGHTS = {"T_TU02": 10.6, "T_TU13": 10.6, "T_TU24": 10.6, "T_TU09": 4.8, "T_TU04": 2.39}
USES = {"T_TU01": "Parede do corredor (a passagem em alfa)", "T_TU11": "Parede das celas (as duas celas em alfa)",
        "T_TU12": "Parede da rota do Nick (a porta em alfa)", "T_TU03": "Parede da plataforma (o túnel em alfa)",
        "T_TU02": "Piso do corredor e da frente da plataforma", "T_TU13": "Piso das celas, visto de cima",
        "T_TU24": "Piso da rota do Nick (o T_TU02 espelhado)",
        "T_TU09": "Piso da plataforma, a faixa amarela na beira", "T_TU04": "Grades da cela", "T_TU05": "Raízes no piso",
        "T_TU06": "Escada até o alçapão (rota do Nick)", "T_TU07": "Duto com a grade arrancada", "T_TU08": "Lâmpada apagada (pisca)",
        "T_TU08_Lit": "Lâmpada acesa", "T_TU10": "O vagão (luz fria por dentro)", "T_TU14": "Caixas de suprimento",
        "T_TU15": "Tambores", "T_TU16": "Carrinho de manutenção", "T_TU17": "Grade solta e entulho", "T_TU19": "Rolo de cabo", "T_TU20": "Canos (primeiro plano)", "T_TU21": "Cabos pendurados (primeiro plano)",
        "T_TU22": "Cano quebrado (primeiro plano)",
        "T_TUX01_Security_Door": "Porta de segurança fechada", "T_TUX01_Security_Door_Open": "Porta de segurança aberta",
        "T_TUX02_Maintenance_Locker": "Armário (busca), fechado", "T_TUX02_Maintenance_Locker_Open": "Armário (busca), aberto",
        "T_TUX03_Door_Panel": "Painel das portas", "T_TUX03_Door_Panel_Open": "Painel acionado"}


def sheet() -> Image.Image:
    font = ImageFont.truetype(str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf"), 24)
    small = ImageFont.truetype(str(ROOT / "art/ui/fonts/barlow_condensed_medium.ttf"), 20)
    cols, cw, ch = 5, 380, 330
    names = list(USES)
    out = Image.new("RGB", (cols * cw + 20, ((len(names) + cols - 1) // cols) * ch + 20), (20, 22, 24))
    d = ImageDraw.Draw(out)
    for i, name in enumerate(names):
        x, y = 20 + (i % cols) * cw, 20 + (i // cols) * ch
        im = Image.open(ART / f"{name}.webp").convert("RGBA")
        w_m = SIZES[name]
        h_m = HEIGHTS.get(name, w_m * im.height / im.width)
        box = Image.new("RGB", (cw - 30, 220), (40, 43, 47))
        for yy in range(0, 220, 20):
            for xx in range(0, cw - 30, 20):
                if (xx // 20 + yy // 20) % 2:
                    ImageDraw.Draw(box).rectangle((xx, yy, xx + 19, yy + 19), fill=(120, 123, 128))
        im.thumbnail((cw - 40, 210))
        box.paste(im, ((cw - 30 - im.width) // 2, (220 - im.height) // 2), im)
        out.paste(box, (x, y))
        d.text((x, y + 228), name, font=font, fill=(239, 230, 214))
        d.text((x, y + 258), f"{w_m:g} × {h_m:.2f} m · {Image.open(ART / f'{name}.webp').size[0]} × {Image.open(ART / f'{name}.webp').size[1]} px", font=small, fill=(240, 160, 32))
        d.text((x, y + 284), USES[name], font=small, fill=(169, 162, 148))
    return out


def main() -> None:
    sheet().save(OUT / "art_sheet.webp", quality=86, method=6)


if __name__ == "__main__":
    main()
