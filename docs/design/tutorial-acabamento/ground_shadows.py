"""A sombra de contato dos objetos do chão, pintada no piso do Corredor de Contenção (#147, o pedido do Lucas de 28/10
no #224: os props apoiados no chão, sem flutuar). O piso é projetado pelo mundo (station_surface, uma amostra de 10,6 m
por zona, de Z = -2,6 na parede até Z = 8 na frente), então cada ponto do mapa cai num pixel certo da pintura: a sombra
fica embaixo de cada objeto, no Compatibility e no Forward+, sem depender da sombra das luzes.

As posições saem do mapa (docs/design/tutorial/map/ContainmentCorridor.json, rode build_map.py antes): cada card de
objeto com a base no piso, atrás da faixa. A largura da sombra é a da base pintada do objeto (o alfa das linhas de
baixo da textura). A plataforma (T_TU09, mapeada pela malha) fica de fora. A pintura limpa do piso vem do Git (BASE).

Uso (da raiz do repositório): python3 -B docs/design/tutorial-acabamento/ground_shadows.py
"""
import io
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
MAP = ROOT / "docs/design/tutorial/map/ContainmentCorridor.json"
ART = ROOT / "art/scenarios"
BASE = "a6224cb"  # o piso como estava no #224, sem sombra
TILE = 10.6
DZ = -8.0
WALL_Z = -2.6
FLOORS = {0: "T_TU02", 1: "T_TU13", 2: "T_TU24"}
# Os objetos que ganham sombra: os soltos no chão e os de pé encostados na parede (o armário, a escada).
GROUNDED = ("T_TU14", "T_TU15", "T_TU16", "T_TU17", "T_TU19", "T_TUX02_Maintenance_Locker", "T_TU06")
CORE = 0.62  # o escuro bem embaixo da base (o piso vezes 1 - CORE)
BACK, FRONT = 0.14, 0.55  # m da sombra atrás e à frente do card (as luzes ficam na parede: ela cai para a frente)
SOFT = 0.16  # m da borda macia dos lados


def base_extent(code: str) -> tuple:
    """A parte da largura (0 a 1) que a base pintada ocupa: o alfa das 12% de linhas de baixo."""
    im = Image.open(ART / f"{code}.webp").convert("RGBA")
    w, h = im.size
    box = im.getchannel("A").crop((0, int(h * 0.88), w, h)).point(lambda v: 255 if v > 85 else 0).getbbox()
    return (box[0] / w, box[2] / w) if box else (0.1, 0.9)


def main() -> None:
    data = json.loads(MAP.read_text())
    zones = data["zones"]
    floors = {}
    for code in FLOORS.values():
        raw = subprocess.run(["git", "show", f"{BASE}:art/scenarios/{code}.webp"], cwd=ROOT, capture_output=True, check=True).stdout
        floors[code] = Image.open(io.BytesIO(raw)).convert("RGB")
    count = 0
    for part in data["parts"]:
        albedo = data["materials"][part["materials"][0]].get("albedo", "")
        code = albedo.rsplit("/", 1)[-1].removesuffix(".webp")
        if part["mesh"] != 1 or code not in GROUNDED:
            continue
        x, y, z = part["origin"]
        width, height = part["basis"][0], -part["basis"][7]
        z -= DZ
        if y - height * 0.5 > 0.05 or z > 0:
            continue
        zone = next((i for i, zn in enumerate(zones) if zn["x0"] - 0.5 <= x <= zn["x1"] + 0.5), None)
        if zone not in FLOORS:
            continue
        floor = floors[FLOORS[zone]]
        px = floor.load()
        fw, fh = floor.size
        e0, e1 = base_extent(code)
        left, right = x - width * 0.5 + e0 * width, x - width * 0.5 + e1 * width
        for row in range(fh):
            zz = WALL_Z + (row + 0.5) / fh * TILE
            d = zz - z
            if not -BACK - 0.05 <= d <= FRONT + 0.05:
                continue
            # Na frente, o escuro cai em curva até FRONT; atrás, até a parede (o card encosta nela ou quase).
            along = max(0.0, 1 - d / FRONT) ** 1.6 if d >= 0 else max(0.0, 1 + d / BACK) * 0.8
            for col in range(fw):
                xx = (col + 0.5) / fw * TILE + zones[zone]["x0"]
                edge = max(left - xx, xx - right, 0.0)
                # O lado da sombra encolhe com a distância da base (a forma de um pé de objeto, não de caixa).
                edge += max(0.0, d) * 0.25
                side = max(0.0, 1 - edge / SOFT) if edge > 0 else 1.0
                side = side * side * (3 - 2 * side)
                k = CORE * along * side
                if k > 0.004:
                    r, g, b = px[col, row]
                    px[col, row] = (round(r * (1 - k)), round(g * (1 - k)), round(b * (1 - k * 0.95)))
        count += 1
    for code, im in floors.items():
        im.save(ART / f"{code}.webp", quality=92, method=6)
    print(f"{count} sombras de contato em {', '.join(floors)}")


if __name__ == "__main__":
    main()
