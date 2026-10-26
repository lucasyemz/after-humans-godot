"""As provas do lote 8: o compose.py do kit (docs/design/hud-kit/compose.py), com o "antes" certo. O antes aqui é a tela
aprovada que o jogo segue hoje (hud-luta, hud-ajustes, hud-estacao e hud-exploracao), não uma captura da Godot: a cena
3D da Estação não abre no xvfb sem placa de vídeo. As telas novas (a barra de Admin, a confirmação, o foco na placa, o
popup parado e a troca escolhida) não têm antes.

Uso (da raiz do repositório): python3 -B docs/design/hud-ajustes2/compose.py
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "hud-kit"))
import compose  # noqa: E402

B = "docs/design"
PAIRS = [("fight_intent", f"{B}/hud-luta/combat.webp"), ("fight_inspect_hero", f"{B}/hud-luta/combat.webp"), ("fight_inspect_machine", ""),
         ("fight_popup", f"{B}/hud-ajustes/fight_loot.webp"), ("fight_popup_hold", ""),
         ("admin_maps", ""), ("admin_weather", ""), ("admin_settings", ""), ("admin_resources", ""), ("admin_heroes", ""), ("admin_combat", ""),
         ("admin_journey", ""), ("station_markers", f"{B}/hud-estacao/overview.webp"), ("station_markers_focus", ""),
         ("night_card", f"{B}/hud-estacao/night.webp"), ("dawn_event", f"{B}/hud-estacao/night.webp"), ("dawn_quiet", ""),
         ("explore_formation", f"{B}/hud-exploracao/explore.webp"), ("explore_formation_pick", "")]

_labeled = compose.labeled


def labeled(im, text, w, h):
    if text.startswith("Antes"):
        text = "Hoje: a tela aprovada que o jogo segue"
    elif text.startswith("Depois"):
        text = "Proposta: o lote 8 (sobre a captura limpa ou a montagem de before/)"
    return _labeled(im, text, w, h)


compose.labeled = labeled

if __name__ == "__main__":
    compose.main("docs/design/hud-ajustes2", PAIRS)
