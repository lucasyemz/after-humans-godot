# Refaz os retratos do Guaxinim e do Tatu no padrão da #26 (olho em 144, 104 do PNG 256). Uso: python3 tools/crop_recruit_portraits.py <raiz do projeto> <pasta de saída>
import sys
from PIL import Image
root = sys.argv[1]; out = sys.argv[2]
SPEC = {"raccoon_recruit_01": ((405, 184), 256), "armadillo_recruit_01": ((426, 198), 220)}
for name, ((ex, ey), side) in SPEC.items():
    s = 256 / side
    x0 = round(ex - 144 / s); y0 = round(ey - 104 / s)
    box = (x0, y0, x0 + side, y0 + side)
    src = Image.open(f"{root}/art/combat/recruits/{name}/idle.webp").convert("RGBA")
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(src.crop((max(0, x0), max(0, y0), x0 + side, y0 + side)), (max(0, -x0), max(0, -y0)))
    canvas.resize((256, 256), Image.LANCZOS).save(f"{out}/{name}.png", optimize=True)
    print(name, box, "olho no PNG", ((ex - x0) * s, (ey - y0) * s))
