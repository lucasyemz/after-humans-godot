"""O "antes" das telas do lote 7, tirado do jogo de hoje: leva para before/game/ as fotos das ferramentas de captura do
próprio jogo (tools/), rodadas na main, com a interface. As da Enfermaria (a Visão geral e o cômodo aberto) vêm de
capture_infirmary.gd sem o pacote (prepare_infirmary.py), como a Sala e a Forja: essas saem no mesmo Dia 5 das telas.
Estas são de outra volta (a legenda de compose.py diz o que difere):
- tools/capture_118.gd: o popup da luta com "Íris caiu" e o relatório da volta;
- tools/capture_119.gd: o relatório com o que os postos renderam;
(O trem, tools/capture_122.gd, fica pendente: a chegada dele não termina sem placa de vídeo.)
- tools/capture_123.gd: o Mapa com o lugar escolhido, a equipe na plataforma e a confirmação.

Uso (da raiz do repositório):
  python3 -B docs/design/hud-casa/game_before.py <saída da 118> <saída da 119> <saída da 123>
"""
import sys
from pathlib import Path
from PIL import Image

sys.dont_write_bytecode = True
GAME = Path(__file__).resolve().parent / "before/game"
# A tela do lote 7 e a foto do jogo de hoje mais próxima dela (de outra volta): (a ferramenta, a foto).
SHOTS = {"fight_fallen": (0, "popup"), "report_fallen": (0, "report"), "report_posts": (1, "report"),
         "map_prepare": (2, "map"), "platform": (2, "platform"), "platform_confirm": (2, "confirm")}


def main(folders: list[str]) -> None:
    GAME.mkdir(parents=True, exist_ok=True)
    for screen, (tool, name) in SHOTS.items():
        shot = Path(folders[tool]) / f"{name}.png"
        if not shot.exists():
            print("sem a foto:", screen, shot)
            continue
        Image.open(shot).convert("RGB").save(GAME / f"{screen}.webp", quality=86, method=6)
        print("ok", screen)


if __name__ == "__main__":
    main(sys.argv[1:4])
