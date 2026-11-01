"""O Corredor de Contenção sem as raízes (o Lucas, 28/10 no #224: são de outro bioma): as paredes do corredor (T_TU01),
da rota do Nick (T_TU12) e da plataforma (T_TU03), e o teto do vagão (T_TU10). A pintura de origem é a mesma da v2 (o
vagão, a de tu-train-sheet-2.png), com só o trecho das raízes repintado (fissura, concreto, vergalhão e cabos soltos;
na plataforma, o azulejo com as manchas; no vagão, o teto de metal); o recorte das aberturas e a redução são os de
docs/design/tutorial/cut_scenario.py. O vagão mantém o quadro de antes (o card dele tem 10 × 4,03 m).

Uso (da raiz do repositório): python3 -B docs/design/tutorial-acabamento/cut_walls.py <images/tutorial/v5/walls>
"""
import sys
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tutorial"))
from cut_scenario import cut, keyed_wall, save, shrink  # noqa: E402

WALLS = {"T_TU01": "tu2-wall-corridor_noroots.png", "T_TU12": "tu2-wall-route_noroots2.png",
         "T_TU03": "tu2-wall-platform_noroots.png"}
def bbox(im: Image.Image) -> tuple:
    """O recorte de cut_scenario.py (o alfa acima de 8)."""
    return im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()


TRAIN = ("tu-train-sheet-2.png", "tu-train-sheet-2_noroots.png")  # a origem (para o quadro) e a sem as raízes


def main(src: str) -> None:
    for name, file in WALLS.items():
        save(shrink(keyed_wall(Image.open(Path(src) / file)), 1024), name)
    # O vagão no mesmo quadro de antes: o musgo saía acima do teto, e sem ele o recorte ficaria mais baixo.
    box = bbox(cut(Image.open(Path(src) / TRAIN[0])))
    save(shrink(cut(Image.open(Path(src) / TRAIN[1])).crop(box), 1024), "T_TU10")


if __name__ == "__main__":
    main(sys.argv[1])
