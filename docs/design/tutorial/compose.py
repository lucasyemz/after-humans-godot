"""As provas do tutorial (#146): o compose.py do kit (docs/design/hud-kit/compose.py), com o "antes" certo. O antes é a
tela aprovada que o jogo segue hoje (o cartão de passagem, a exploração, a luta, a Visão geral e a escolha do espaço);
as telas sem par (o quadro da tirinha, o alvo, o fim da visita) não têm antes.

Uso (da raiz do repositório): python3 -B docs/design/tutorial/compose.py
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "hud-kit"))
import compose  # noqa: E402

B = "docs/design"
PAIRS = [("opening_card", f"{B}/hud-fluxo/passage.webp"), ("opening_frame", ""), ("tutorial_explore", f"{B}/hud-exploracao/explore.webp"),
         ("tutorial_combat", f"{B}/hud-luta/combat.webp"), ("tutorial_target", ""), ("tour_room", f"{B}/hud-estacao/overview.webp"),
         ("tour_end", ""), ("new_campaign", f"{B}/hud-fluxo/slots_new.webp")]

_labeled = compose.labeled


def labeled(im, text, w, h):
    if text.startswith("Antes"):
        text = "Hoje: a tela aprovada que o jogo segue"
    elif text.startswith("Depois"):
        text = "Proposta: o tutorial (sobre a captura limpa)"
    return _labeled(im, text, w, h)


compose.labeled = labeled

if __name__ == "__main__":
    compose.main("docs/design/tutorial", PAIRS)
