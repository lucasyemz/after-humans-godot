"""As provas do lote 7: o compose.py do kit (docs/design/hud-kit/compose.py), com o "antes" certo. O antes aqui é a tela
aprovada do lote anterior que o jogo segue hoje (hud-estacao, hud-station, hud-fluxo e hud-ajustes, já integradas na
main pelas #114 a #117). As capturas da Godot da Enfermaria nova ficam no antes e depois próprio dela
(infirmary_before_after.webp, de prepare_infirmary.py).

Uso (da raiz do repositório): python3 -B docs/design/hud-casa/compose.py
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "hud-kit"))
import compose  # noqa: E402

B = "docs/design"
PAIRS = [("infirmary_overview", f"{B}/hud-estacao/overview.webp"), ("infirmary", ""), ("report_fallen", f"{B}/hud-station/report.webp"),
         ("report_posts", f"{B}/hud-station/report_details.webp"), ("characters_fallen", f"{B}/hud-station/characters.webp"), ("characters_post", ""),
         ("room_workers", f"{B}/hud-estacao/forge.webp"), ("fight_fallen", f"{B}/hud-ajustes/fight_none.webp"), ("train_recruit", f"{B}/hud-estacao/train.webp"),
         ("train_full", ""), ("train_nobody", ""), ("go_map", ""), ("map_prepare", f"{B}/hud-fluxo/map.webp"),
         ("platform", f"{B}/hud-estacao/preparation.webp"), ("platform_confirm", "")]

_labeled = compose.labeled


def labeled(im, text, w, h):
    if text.startswith("Antes"):
        text = "Hoje: a tela aprovada do lote anterior (a que o jogo segue)"
    elif text.startswith("Depois"):
        text = "Proposta: o lote 7 (sobre a captura limpa ou a montagem de before/)"
    return _labeled(im, text, w, h)


compose.labeled = labeled

if __name__ == "__main__":
    compose.main("docs/design/hud-casa", PAIRS)
