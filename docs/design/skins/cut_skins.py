"""As três propostas de skin do Bento (#137): recorta o idle e o retrato de cada uma (geradas sobre magenta #FF00FF, fora
do Git) e grava a prancha que o Lucas usa para escolher.

- O idle sai no canvas do idle de hoje (art/combat/heroes/bento/idle.webp, 543 × 724), na mesma altura de corpo (a
  caixa do alfa), com o pé na mesma linha e a cabeça no mesmo x (o centro da caixa da cara, a faixa de 20 a 70 px abaixo
  do alto do corpo, acima do capuz e da gola: a capa ou a mangueira alargam a caixa inteira só de um lado): encaixa sem mexer na âncora
  (data/presentation/combat_art.json, [473, 1429] no original, x 236,5 e y 714,5 neste canvas).
- O retrato sai no canvas do retrato de hoje (art/ui/portraits/bento.png, 256 × 256), no mesmo enquadramento.
- A prancha (proposals.webp): o Bento de hoje e as três propostas, na mesma escala e na mesma linha do pé, com o retrato
  de cada um embaixo; e a redução a 40%, em cor e em cinza (proposals_40.webp e proposals_gray_40.webp), para a
  leitura pequena.

Uso (da raiz do repositório): python3 -B docs/design/skins/cut_skins.py <pasta das imagens geradas>
     (a pasta images/skins do projeto na Awesomic: skin-<id>-idle.png e skin-<id>-portrait.png)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "docs/design/hud-station"))
from cut_icons import unmix, despill_edges  # noqa: E402

HERE = ROOT / "docs/design/skins"
IDLE = ROOT / "art/combat/heroes/bento/idle.webp"
PORTRAIT = ROOT / "art/ui/portraits/bento.png"
FONT = ROOT / "art/ui/fonts/barlow_condensed_semibold.ttf"
# O id de cada proposta (a pasta art/skins/bento/<id>/ depois da escolha) e o nome na prancha.
SKINS = [("diver", "Mergulhador da Ponte"), ("watch", "Ronda da Estação"), ("mechanic", "Mecânico dos trilhos")]
# A faixa da cabeça (y, no canvas do idle de hoje), que acerta o x.
HEAD = (20, 70)


def cut(path: Path) -> Image.Image:
    im = despill_edges(unmix(Image.open(path)))
    a = im.getchannel("A")
    # Só o desenho: some o grão solto longe de um pedaço com alfa forte.
    near = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MaxFilter(9))
    a = ImageChops.multiply(a, near).point(lambda v: 0 if v < 8 else v)
    rgb = Image.composite(im.convert("RGB"), Image.new("RGB", im.size), a.point(lambda v: 255 if v else 0))
    rgb.putalpha(a)
    return rgb


def body_box(im: Image.Image):
    return im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()


def head_x(im: Image.Image, top: int, scale: float = 1.0) -> float:
    """O centro em x da cabeça: a caixa do alfa na faixa HEAD, medida a partir do alto do corpo."""
    band = im.crop((0, top + round(HEAD[0] * scale), im.width, top + round(HEAD[1] * scale)))
    box = body_box(band)
    return (box[0] + box[2]) / 2


def idle(src: Path) -> Image.Image:
    today = Image.open(IDLE).convert("RGBA")
    tb = body_box(today)
    im = cut(src)
    box = body_box(im)
    im = im.crop(box)
    scale = (tb[3] - tb[1]) / im.height
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", today.size)
    x = round(head_x(today, tb[1]) - head_x(im, 0))
    if x < 0 or x + im.width > today.width:
        raise SystemExit(f"{src.name}: a skin não cabe no canvas com a cabeça no lugar (x {x}, largura {im.width})")
    out.alpha_composite(im, (x, tb[3] - im.height))
    return out


def portrait(src: Path) -> Image.Image:
    return cut(src).resize(Image.open(PORTRAIT).size, Image.Resampling.LANCZOS)


def sheet(cards: list) -> Image.Image:
    """Quatro colunas (o de hoje e as propostas): o idle na escala do jogo (o canvas inteiro) e o retrato embaixo."""
    font = ImageFont.truetype(str(FONT), 34)
    w, h = Image.open(IDLE).size
    col = w + 40
    out = Image.new("RGB", (col * len(cards), h + 256 + 120), (22, 24, 27))
    d = ImageDraw.Draw(out)
    for i, (title, im, face) in enumerate(cards):
        x = i * col + 20
        d.text((x, 14), title, font=font, fill=(236, 226, 205))
        # A linha do pé, igual nas quatro colunas.
        foot = 60 + body_box(Image.open(IDLE).convert("RGBA"))[3]
        d.line((x, foot, x + w, foot), fill=(80, 84, 90), width=2)
        out.paste(im, (x, 60), im)
        out.paste(face, (x + (w - 256) // 2, h + 90), face)
    return out


def main(src: str) -> None:
    src = Path(src)
    cards = [("Hoje: o Bento", Image.open(IDLE).convert("RGBA"), Image.open(PORTRAIT).convert("RGBA"))]
    for skin_id, title in SKINS:
        folder = HERE / skin_id
        folder.mkdir(parents=True, exist_ok=True)
        im = idle(src / f"skin-{skin_id}-idle.png")
        im.save(folder / "idle.webp", "WEBP", quality=90, method=6)
        face = portrait(src / f"skin-{skin_id}-portrait.png")
        face.save(folder / "portrait.webp", "WEBP", quality=90, method=6)
        cards.append((title, im, face))
        print(skin_id, im.size, face.size)
    board = sheet(cards)
    board.save(HERE / "proposals.webp", quality=88, method=6)
    small = board.resize((round(board.width * 0.4), round(board.height * 0.4)), Image.Resampling.LANCZOS)
    small.save(HERE / "proposals_40.webp", quality=90, method=6)
    small.convert("L").save(HERE / "proposals_gray_40.webp", quality=90, method=6)
    print("prancha", board.size)


if __name__ == "__main__":
    main(sys.argv[1])
