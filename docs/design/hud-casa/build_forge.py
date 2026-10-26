"""A Forja recuperada, com quem trabalha nela, para "Quem trabalha aqui" (#119). A captura do jogo
(hud-v2/before/station-forge_clean.webp) é a da Forja vazia, no nível 0: a cena 3D da Estação não abre no xvfb sem placa
de vídeo, então a Forja de nível 1 é uma montagem na mesma câmera, com o que station_build.gd (_forge) põe no cômodo:
- a luz: o pendente sobre a bigorna (room_lights["forge"], NEUTRAL) acende o cômodo, mais forte no meio e no fundo;
- os cards: a bancada pintada (Forge_Workbay, 460 cm, no fundo em x 1670) e a prateleira de ferramentas (Forge_ToolRack,
  150 cm, em x 1600, na prateleira alta), na escala da parede do fundo; a caixa de ferramentas e os lingotes (55 cm) no
  chão, nas laterais, na escala do corte (os armários baixos e a bigorna são caixas 3D e ficam para a cena);
- quem trabalha: o Brasa (o recruta cão, art/combat/recruits/dog_recruit_01_idle.webp) junto da bancada e o Otto
  (art/civilians/civil_otto.webp) mais à frente, na altura dos heróis dos cômodos vizinhos (cerca de 100 px).

Uso: python3 -B docs/design/hud-casa/build_forge.py   (grava before/station-forge-workers_clean.webp)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BEFORE = ROOT / "docs/design/hud-v2/before"
OUT = ROOT / "docs/design/hud-casa/before"
CARDS = ROOT / "art/station/cards"

# O cômodo na captura: o corte vai de x 437 a 1150 e de y 348 (teto) a 655 (piso da frente).
ROOM = (437, 348, 1150, 655)
# A parede do fundo: a porta (x 1280 a 1408 cm) cai de x 618 a 673, com o pé em y 600; 0,43 px por cm.
BACK_PX, BACK_X0, BACK_FLOOR = 0.43, 618 - 0.43 * 1280, 600
# O corte, na frente: 0,71 px por cm (1000 cm de x 437 a 1150), com o piso em y 650.
FRONT_PX, FRONT_X0, FRONT_FLOOR = 0.71, 437 - 0.71 * 1160, 650


def card(name: str, width_px: int) -> Image.Image:
    im = Image.open(CARDS / f"{name}.webp").convert("RGBA")
    return im.resize((width_px, round(im.height * width_px / im.width)), Image.Resampling.LANCZOS)


def sprite(path: str, height: int) -> Image.Image:
    im = Image.open(ROOT / path).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    return im.resize((round(im.width * height / im.height), height), Image.Resampling.LANCZOS)


def light(room: Image.Image) -> Image.Image:
    """O cômodo aceso: o vazio fica na penumbra (luz a 0,3, station.gd); aceso, cerca de 2,6 vezes, com o centro mais
    claro (o pendente) e as bordas do corte um pouco mais escuras."""
    w, h = room.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((int(w * 0.08), int(-h * 0.35), int(w * 0.92), int(h * 1.15)), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(90))
    lit = room.point(lambda v: min(255, int(v * 2.6)))
    soft = room.point(lambda v: min(255, int(v * 1.7)))
    return Image.composite(lit, soft, mask)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.open(BEFORE / "station-forge_clean.webp").convert("RGBA")
    room = light(im.crop(ROOM).convert("RGB")).convert("RGBA")
    x0, y0 = ROOM[0], ROOM[1]
    at = lambda img, x, y: room.alpha_composite(img, (round(x - x0), round(y - y0)))
    # A prateleira alta (a 289 cm do piso) com as ferramentas, e a bancada encostada na parede do fundo.
    rack = card("Forge_ToolRack", round(150 * BACK_PX))
    at(rack, BACK_X0 + 1600 * BACK_PX - rack.width / 2, BACK_FLOOR - 289 * BACK_PX - rack.height)
    bench = card("Forge_Workbay", round(460 * BACK_PX))
    at(bench, BACK_X0 + 1670 * BACK_PX - bench.width / 2, BACK_FLOOR - bench.height)
    # A prateleira alta (de x 1440 a 1910 cm), a tábua de aço sob as ferramentas.
    shelf = Image.new("RGBA", (round(470 * BACK_PX), 3), (74, 72, 62, 255))
    at(shelf, BACK_X0 + 1440 * BACK_PX, BACK_FLOOR - 289 * BACK_PX)
    # A caixa de ferramentas e os lingotes no chão, nas laterais do corte (55 cm), na escala da frente.
    for name, cx in (("Forge_Ingots", 1250), ("Forge_Toolbox", 2070)):
        piece = card(name, round(55 * FRONT_PX))
        at(piece, FRONT_X0 + cx * FRONT_PX - piece.width / 2, FRONT_FLOOR - piece.height)
    # Quem trabalha: o Brasa junto da bancada, o Otto mais à frente e menor (o castor é mais baixo que o cão).
    brasa = sprite("art/combat/recruits/dog_recruit_01_idle.webp", 104)
    at(brasa, 760 - brasa.width / 2, 628 - brasa.height)
    otto = sprite("art/civilians/civil_otto.webp", 88)
    at(otto, 930 - otto.width / 2, 640 - otto.height)
    im.alpha_composite(room, (x0, y0))
    im.convert("RGB").save(OUT / "station-forge-workers_clean.webp", quality=88, method=6)
    print("forja", room.size)


if __name__ == "__main__":
    main()
