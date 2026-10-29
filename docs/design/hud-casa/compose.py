"""As provas do lote 7: o compose.py do kit (docs/design/hud-kit/compose.py), com o "antes" certo. O antes de cada tela
é uma foto do jogo de hoje (a main), com a interface: before/game/, de prepare_infirmary.py (capture_infirmary.gd sem o
pacote, no mesmo Dia 5 das telas) e de game_before.py (as ferramentas de captura do jogo, de outra volta: a legenda diz
o que difere). As telas novas, sem um momento igual no jogo, ficam sem antes. O antes e depois do cenário da
Enfermaria, os dois no jogo, sai de prepare_infirmary.py.

Uso (da raiz do repositório): python3 -B docs/design/hud-casa/compose.py
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "hud-kit"))
import compose  # noqa: E402

G = "docs/design/hud-casa/before/game"
SCREENS = ["infirmary_overview", "infirmary", "report_fallen", "report_posts", "characters_fallen", "characters_post",
           "room_workers", "fight_fallen", "train_recruit", "train_full", "train_nobody", "go_map", "map_prepare",
           "platform", "platform_confirm"]
# A legenda de cada lado: de onde vem o antes (e o que difere do momento da proposta, quando a foto do jogo é de outra
# volta) e sobre qual captura a proposta foi montada.
SAME = "Hoje, no jogo (a main), no mesmo estado das telas"
NOW = {"infirmary_overview": SAME, "infirmary": SAME, "characters_fallen": SAME, "characters_post": SAME,
       "room_workers": SAME,
       "report_fallen": "Hoje, no jogo (a main) · outra volta: Íris e Nick caídos",
       "report_posts": "Hoje, no jogo (a main) · outra volta: ninguém caiu",
       "fight_fallen": "Hoje, no jogo (a main) · outra luta, a Íris caída",
       "train_recruit": "Hoje, no jogo (a main) · outro candidato no trem",
       "map_prepare": "Hoje, no jogo (a main) · outro lugar e outra equipe",
       "platform": "Hoje, no jogo (a main) · outro lugar e outra equipe",
       "platform_confirm": "Hoje, no jogo (a main) · outro lugar e outra equipe"}
GODOT = "Proposta (sobre a captura da Godot com o pacote)"
NEW = {"infirmary_overview": GODOT, "infirmary": GODOT, "room_workers": GODOT,
       "report_fallen": "Proposta (sobre a captura da plataforma, montada)",
       "report_posts": "Proposta (sobre a captura da plataforma, montada)",
       "characters_fallen": "Proposta (sobre a captura da Sala, hud-v2)",
       "characters_post": "Proposta (sobre a captura da Sala, hud-v2)",
       "fight_fallen": "Proposta (sobre a luta capturada, capture.gd)",
       "train_recruit": "Proposta (sobre a captura da plataforma, montada)",
       "map_prepare": "Proposta (o Mapa da Rede no kit)",
       "platform": "Proposta (sobre a captura da plataforma, montada)",
       "platform_confirm": "Proposta (sobre a captura da plataforma, montada)"}


def before_after(screen: str) -> None:
    here = compose.ROOT / "docs/design/hud-casa"
    before = compose.ROOT / G / f"{screen}.webp"
    if not before.exists():
        return
    a = compose.labeled(compose.Image.open(before), NOW[screen], 960, 540)
    b = compose.labeled(compose.Image.open(here / ".render" / f"{screen}_normal.png"), NEW[screen], 960, 540)
    out = compose.Image.new("RGB", (1928, a.height), (40, 42, 46))
    out.paste(a, (0, 0))
    out.paste(b, (968, 0))
    out.save(here / f"before_after_{screen}.webp", quality=86, method=6)


if __name__ == "__main__":
    compose.main("docs/design/hud-casa", [(s, "") for s in SCREENS])
    for screen in SCREENS:
        before_after(screen)
