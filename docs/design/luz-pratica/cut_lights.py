"""Recorta a arte da luz prática (#154) das folhas geradas no Nano Banana Pro (fora do Git, em images/luz-pratica/ do
projeto na Awesomic) para art/scenarios/, no contrato dos cenários (tools/sync_scenarios.py): T_<código>.webp, WebP
qualidade 88, até 1024 px no lado maior.

Cada fonte sai em três arquivos, no mesmo quadro (o card troca de textura, como o _Open dos interativos):
  T_LPnn       o objeto apagado, recortado com alfa (o jogo corta em 0,333: a borda é dura);
  T_LPnn_Lit   o mesmo objeto aceso, do mesmo tamanho e no mesmo lugar (só a parte que acende muda; o fogo sobe acima
               da borda do tambor e entra no alfa);
  T_LPnn_Halo  o halo, colorido sobre preto, sem alfa: é para somar (blend_add), não para recortar. O quadro do halo tem
               o mesmo centro do card e HALO_SCALE vezes a largura e a altura dele. Sai da própria luz da peça (o que
               acende entre o apagado e o aceso, desfocado), então tem a forma e a cor dela: uma fileira de pontos na
               gambiarra, o retângulo do neon no letreiro, a faixa do visor.
E duas peças comuns, em cinza sobre preto, para tingir: T_LP_Pool (a poça no chão, vista de cima) e
T_LP_Beam (o cone do farol do drone na névoa). E o fogo do tambor, à parte e somado como o halo: T_LP03_Fire_0 a _3,
quatro quadros do mesmo fogo, colorido sobre preto, para tremular.
A poça é vista de cima: vai num quad deitado no piso, e a câmera da exploração achata.

Uso: python3 -B docs/design/luz-pratica/cut_lights.py <pasta images/luz-pratica>
Sem numpy: só Pillow.
"""
import json
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "docs/design/hud-station"))
from cut_icons import unmix, despill_edges  # noqa: E402

OUT = ROOT / "art/scenarios"
HERE = Path(__file__).resolve().parent
HALO_SCALE = 2.0
# As peças cujo aceso cresce para fora do apagado. Vazio: o fogo do tambor é uma peça à parte, somada (T_LP03_Fire_n),
# porque as chamas da edição acesa saíram translúcidas sobre o magenta, e o corte do alfa em 0,333 as picotava.
FIRE = set()
# O fogo: a folha sobre preto com quatro quadros do mesmo fogo (lp-fire-frames.png), o pé reto na borda do tambor.
FIRE_FRAMES = 4
# Onde o fogo assenta no tambor (px no card T_LP03): o pé do quadro na boca do tambor, com 85% da largura do card.
FIRE_SEAT = {"bottom_y": 95, "width": 0.85}
# As folhas (o apagado e a edição acesa dele) e as peças na ordem de leitura (de cima para baixo, da esquerda para a
# direita).
SHEETS = [
    ("lp-sources-off.png", "lp-sources-on.png",
     ["T_LP01", "T_LP02", "T_LP03", "T_LP04", "T_LP05", "T_LP06"]),
    ("lp-machines-off.png", "lp-machines-on.png", ["T_LP07", "T_LP08", "T_LP09"]),
]


def alpha_of(im: Image.Image, cut: int) -> Image.Image:
    return im.getchannel("A").point(lambda v: 255 if v > cut else 0)


def components(mask: Image.Image, rows: int, k: int = 4, grow: int = 9):
    """As caixas (px) das peças: os pedaços conexos da máscara, numa cópia reduzida e engordada (a gambiarra e os fios
    ficam inteiros); pedaços pequenos (sujeira) ficam de fora."""
    small = mask.resize((mask.width // k, mask.height // k), Image.Resampling.BOX).point(lambda v: 255 if v > 40 else 0)
    small = small.filter(ImageFilter.MaxFilter(grow))
    w, h = small.size
    px = small.load()
    seen = set()
    boxes = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and (x, y) not in seen:
                stack, n = [(x, y)], 0
                x0 = x1 = x
                y0 = y1 = y
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    n += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and (nx, ny) not in seen:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                if n > 400:
                    boxes.append(((x0 * k, y0 * k, (x1 + 1) * k, (y1 + 1) * k), set(seen_piece(px, seen, x, y, w, h))))
    # A linha da folha pelo meio da peça, depois da esquerda para a direita.
    boxes.sort(key=lambda b: (int((b[0][1] + b[0][3]) / 2 / (mask.height / rows)), b[0][0]))
    out = []
    for box, cells in boxes:
        # A região da peça em tamanho cheio (os pixels da cópia reduzida que são dela), para nada da vizinha entrar.
        region = Image.new("L", mask.size)
        draw = ImageDraw.Draw(region)
        for cx, cy in cells:
            draw.rectangle((cx * k, cy * k, cx * k + k - 1, cy * k + k - 1), fill=255)
        out.append((box, region))
    return out


def seen_piece(px, seen, x, y, w, h):
    """Os pixels conexos a (x, y) na máscara reduzida (a mesma busca de components, devolvendo a lista)."""
    stack, piece, local = [(x, y)], [], {(x, y)}
    while stack:
        cx, cy = stack.pop()
        piece.append((cx, cy))
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and (nx, ny) not in local:
                local.add((nx, ny))
                stack.append((nx, ny))
    return piece


def offset(a: Image.Image, b: Image.Image, box, r: int = 8):
    """O deslocamento (dx, dy) de b que melhor cobre a na caixa (a edição acesa às vezes anda alguns pixels)."""
    ca = a.crop(box).resize(((box[2] - box[0]) // 2, (box[3] - box[1]) // 2))
    best = None
    for dy in range(-r, r + 1, 1):
        for dx in range(-r, r + 1, 1):
            cb = b.crop((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy)).resize(ca.size)
            d = sum(ImageChops.difference(ca, cb).getdata())
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best[1], best[2]


def lum(im: Image.Image) -> Image.Image:
    return im.convert("RGB").convert("L")


def finish(im: Image.Image) -> Image.Image:
    """O RGB zerado onde o alfa é 0, sem pixels soltos, e a faixa da borda sem o magenta que sobra: onde o
    vermelho e o azul passam do verde, os dois descem até ele. A faixa vai 4 px para dentro do corte do jogo; o miolo,
    com o rosa da seta do letreiro, fica como está."""
    a = im.getchannel("A").point(lambda v: 0 if v < 8 else v)
    rgb = Image.composite(im.convert("RGB"), Image.new("RGB", im.size), a)
    band = a.point(lambda v: 255 if v > 85 else 0).filter(ImageFilter.MinFilter(9)).point(lambda v: 0 if v else 255)
    px, bp = rgb.load(), band.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            if bp[x, y]:
                r, g, b = px[x, y]
                # Três níveis além do verde: o WebP com perda devolve um pouco do tom.
                d = min(r, b) - g + 3
                if d > 0:
                    px[x, y] = (max(0, r - d), g, max(0, b - d))
    rgb.putalpha(a)
    return rgb


def blobs(mask: Image.Image):
    """Os pedaços conexos da máscara (listas de pixels)."""
    w, h = mask.size
    px = mask.load()
    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and (x, y) not in seen:
                seen.add((x, y))
                stack, piece = [(x, y)], []
                while stack:
                    cx, cy = stack.pop()
                    piece.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and (nx, ny) not in seen:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                out.append(piece)
    return out


def gain_mask(lit_raw: Image.Image, off_raw: Image.Image) -> Image.Image:
    """O que acendeu: o maior ganho entre os canais (as lâmpadas frias ganham pouco brilho, mas muito azul ou verde)."""
    r, g, b = ImageChops.subtract(lit_raw.convert("RGB"), off_raw.convert("RGB")).split()
    return ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: 255 if v > 38 else 0).filter(ImageFilter.MinFilter(3))


def halo(lit: Image.Image, mask: Image.Image, size) -> Image.Image:
    """O halo: o que acendeu (a máscara do ganho), na cor do aceso, com cada luz levada ao mesmo pico (as lâmpadas da
    gambiarra, a lente e o ponto do sensor acendem por igual), num quadro HALO_SCALE vezes maior, desfocado em duas
    escalas (o miolo e o ar em volta) e normalizado para o pico em branco da cor."""
    w, h = size
    src = Image.composite(lit.convert("RGB"), Image.new("RGB", lit.size), mask)
    px = src.load()
    for piece in blobs(mask):
        peak = max(max(px[x, y]) for x, y in piece) or 1
        k = 255 / peak
        for x, y in piece:
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))
    W, H = round(w * HALO_SCALE), round(h * HALO_SCALE)
    canvas = Image.new("RGB", (W, H))
    canvas.paste(src, ((W - w) // 2, (H - h) // 2))
    side = max(w, h)
    near = canvas.filter(ImageFilter.GaussianBlur(side * 0.05))
    far = canvas.filter(ImageFilter.GaussianBlur(side * 0.16))
    out = ImageChops.add(near, ImageChops.multiply(far, Image.new("RGB", far.size, (255, 255, 255))), 1.0)
    out = ImageChops.add(out, far, 1.0)
    peak = max(max(c) for c in [b for b in out.getextrema()]) or 1
    k = 235 / peak
    out = out.point(lambda v: min(255, int(v * k)))
    # O halo some antes da borda do quadro (um quad somado nunca mostra o corte).
    fade = Image.new("L", (W, H))
    d = ImageDraw.Draw(fade)
    for i in range(40):
        t = i / 39
        d.ellipse((W * 0.5 * t, H * 0.5 * t, W - W * 0.5 * t, H - H * 0.5 * t), fill=int(255 * min(1, t * 2.2)))
    fade = fade.filter(ImageFilter.GaussianBlur(min(W, H) * 0.04))
    return ImageChops.multiply(out, Image.merge("RGB", (fade, fade, fade)))


def anchors(lit_mask: Image.Image, alpha: Image.Image) -> dict:
    """As âncoras em px no card: a origem da luz (o meio do que acende, onde ficam a OmniLight, o centro do halo de
    verdade e o da poça), o ponto mais alto (onde se pendura) e as pontas de cima à esquerda e à direita (onde se prende
    a gambiarra)."""
    px = lit_mask.load()
    pts = [(x, y) for y in range(lit_mask.height) for x in range(lit_mask.width) if px[x, y]]
    light = [round(sum(p[0] for p in pts) / len(pts)), round(sum(p[1] for p in pts) / len(pts))]
    ap = alpha.load()
    solid = [(x, y) for y in range(alpha.height) for x in range(alpha.width) if ap[x, y] > 85]
    top = min(solid, key=lambda p: (p[1], p[0]))
    left = min(solid, key=lambda p: (p[0], p[1]))
    right = max(solid, key=lambda p: (p[0], -p[1]))
    return {"light": light, "top": list(top), "left_end": list(left), "right_end": list(right)}


def shrink(im: Image.Image, side: int) -> Image.Image:
    k = min(1.0, side / max(im.size))
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.Resampling.LANCZOS)


def save(im: Image.Image, name: str, manifest: dict) -> None:
    im.save(OUT / f"{name}.webp", "WEBP", quality=88, method=6)
    manifest[name] = list(im.size)
    print(name, im.size, im.mode)


def pool() -> Image.Image:
    """A poça de luz no chão, vista de cima (o quad deitado no piso; a perspectiva da câmera achata), mais forte no
    meio e sumindo antes da borda."""
    W, H = 512, 512
    im = Image.new("L", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - W / 2) / (W / 2), (y - H / 2) / (H / 2))
            px[x, y] = int(255 * max(0.0, 1 - d) ** 1.8)
    return im.convert("RGB")


def beam() -> Image.Image:
    """O cone do farol: da lente (no alto, no meio) para baixo, abrindo e sumindo com a distância; a borda é macia."""
    W, H = 512, 1024
    im = Image.new("L", (W, H))
    px = im.load()
    for y in range(H):
        t = y / (H - 1)
        half = 18 + t * (W / 2 - 30)
        for x in range(W):
            e = abs(x - W / 2) / half
            if e < 1:
                px[x, y] = int(255 * (1 - e) ** 1.4 * (1 - t) ** 0.9 * min(1, t * 12 + 0.25))
    im = im.filter(ImageFilter.GaussianBlur(6))
    # O topo some em 24 px (a lente cobre a ponta, mas o quad não pode mostrar uma aresta).
    fade = Image.linear_gradient("L").resize((W, 24))
    im.paste(ImageChops.multiply(im.crop((0, 0, W, 24)), fade), (0, 0))
    return im.convert("RGB")


def fire_frames(sheet: Image.Image):
    """Os quatro quadros do fogo, do mesmo tamanho e com o pé no mesmo lugar: cada quarto da folha, sem a linha do pé
    (a borda pintada embaixo das chamas), recortado pela caixa da união dos quatro; o pé some em 12% da altura (a cinza
    do tambor cobre) e as laterais em 12 px, e o resto é preto (soma nada)."""
    sheet = sheet.convert("RGB")
    w, h = sheet.size
    cells = [sheet.crop((i * w // FIRE_FRAMES, 0, (i + 1) * w // FIRE_FRAMES, h)) for i in range(FIRE_FRAMES)]
    # A linha do pé: a última fileira clara de baixo para cima; o fogo acaba um pouco acima dela.
    lum0 = cells[0].convert("L")
    rows = [max(lum0.crop((0, y, lum0.width, y + 1)).getdata()) for y in range(h)]
    foot = max(y for y in range(h) if rows[y] > 60)
    base = foot - 10
    while base > 0 and rows[base] > 60 and rows[base] < 200:
        base -= 1
    cells = [c.crop((0, 0, c.width, base)) for c in cells]
    box = None
    for c in cells:
        b = c.convert("L").point(lambda v: 255 if v > 24 else 0).getbbox()
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    out = []
    for c in cells:
        c = c.crop((box[0] - 8, box[1] - 8, box[2] + 8, box[3]))
        fade = Image.new("L", c.size, 255)
        n = int(c.height * 0.12)
        fade.paste(Image.linear_gradient("L").rotate(180).resize((c.width, n)), (0, c.height - n))
        # As laterais somem em 12 px (a base larga das chamas encosta nelas, e o quad somado não pode mostrar o corte).
        side = Image.linear_gradient("L").rotate(90).resize((12, c.height))
        fade = ImageChops.multiply(fade, Image.new("L", c.size, 255))
        fade.paste(ImageChops.multiply(fade.crop((0, 0, 12, c.height)), side.transpose(Image.Transpose.FLIP_LEFT_RIGHT)), (0, 0))
        fade.paste(ImageChops.multiply(fade.crop((c.width - 12, 0, c.width, c.height)), side), (c.width - 12, 0))
        out.append(ImageChops.multiply(c, Image.merge("RGB", (fade, fade, fade))))
    return out


def main(src: str) -> None:
    src = Path(src)
    manifest = {}
    pieces = {}
    for off_file, on_file, names in SHEETS:
        off_raw = Image.open(src / off_file).convert("RGB")
        on_raw = Image.open(src / on_file).convert("RGB").resize(off_raw.size, Image.Resampling.LANCZOS)
        off = despill_edges(unmix(off_raw))
        on = despill_edges(unmix(on_raw))
        a_off = alpha_of(off, 128)
        boxes = components(a_off, 2 if len(names) > 3 else 1)
        assert len(boxes) == len(names), (off_file, boxes)
        a_on = alpha_of(on, 128)
        for name, (box, region) in zip(names, boxes):
            dx, dy = offset(a_off, a_on, box)
            # O aceso no quadro do apagado, com o alfa do apagado; no tambor, o fogo que sobe acima da borda entra no
            # alfa (o que acendeu, numa região que cresce só para cima, na largura da peça).
            pad, rise = 40, 96
            big = (box[0] - pad, box[1] - rise, box[2] + pad, box[3] + pad)
            o = off.crop(big)
            own = region.crop(big)
            l = on.crop((big[0] + dx, big[1] + dy, big[2] + dx, big[3] + dy))
            lo = off_raw.crop(big)
            ll = on_raw.crop((big[0] + dx, big[1] + dy, big[2] + dx, big[3] + dy))
            gain = gain_mask(ll, lo)
            o_alpha = ImageChops.multiply(o.getchannel("A"), own)
            extra = Image.new("L", o.size)
            if name in FIRE:
                up = own.copy()
                for i in range(4, rise + 1, 4):
                    shifted = Image.new("L", own.size)
                    shifted.paste(own, (0, -i))
                    up = ImageChops.lighter(up, shifted)
                visible = l.getchannel("A").point(lambda v: 255 if v > 85 else 0)
                extra = ImageChops.multiply(ImageChops.multiply(gain, visible), up)
                extra = extra.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
            a = ImageChops.lighter(o_alpha, extra)
            l = l.copy()
            l.putalpha(a)
            o_full = o.copy()
            o_full.putalpha(o_alpha)
            # O quadro comum é a caixa da união: o apagado ganha o espaço transparente do fogo, e os dois ficam iguais.
            crop = a.point(lambda v: 255 if v > 8 else 0).getbbox()
            o_full, l, gain = o_full.crop(crop), l.crop(crop), gain.crop(crop)
            # A luz é a peça de vidro inteira em volta do que acendeu (cada lâmpada da gambiarra vira um pedaço do mesmo
            # tamanho), dentro do recorte.
            lit_mask = ImageChops.multiply(gain.filter(ImageFilter.MaxFilter(11)),
                                           a.crop(crop).point(lambda v: 255 if v > 85 else 0))
            save(finish(o_full), name, manifest)
            save(finish(l), name + "_Lit", manifest)
            save(shrink(halo(l, lit_mask, l.size), 1024), name + "_Halo", manifest)
            pieces[name] = {"box_in_sheet": [big[0] + crop[0], big[1] + crop[1], big[0] + crop[2], big[1] + crop[3]],
                            "lit_offset": [dx, dy], "sheet": off_file, **anchors(lit_mask, a.crop(crop))}
    for i, frame in enumerate(fire_frames(Image.open(src / "lp-fire-frames.png"))):
        save(shrink(frame, 512), f"T_LP03_Fire_{i}", manifest)
    pieces["T_LP03"]["fire_seat"] = FIRE_SEAT
    save(pool(), "T_LP_Pool", manifest)
    save(beam(), "T_LP_Beam", manifest)
    (HERE / "cut_manifest.json").write_text(json.dumps({"sizes": manifest, "pieces": pieces}, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
