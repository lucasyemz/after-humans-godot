"""As poses do acampamento (#77) a partir do contrato do Codex (docs/design/camp/contract.json, #80 e #82).

Gera data/presentation/camp_poses.json, que o jogo lê (a pasta docs/ não entra no jogo): para cada fundador, a pose
sentada no chão (#82) e a deitada que já existe na Estação; para cada variação de recruta, a sentada e a deitada (#80).
Cada entrada é o payload oficial show_art do contrato (o canvas, a âncora e a referência do corpo originais do idle),
sem recalcular nada, mais o "visible": a caixa do corpo visível (o alfa acima de 24, a regra do clique do contrato) nas
coordenadas do canvas original, para a placa e a área do clique ficarem no corpo e não no canvas vazio de cima, e o
"support": a linha (no canvas original) onde o corpo apoia no chão, o quadril do sentado ou o tronco do deitado (#205),
de onde o acampamento tira a sombra e o ângulo da câmera. Os PNG
e as fontes pesadas não entram: os WebP já estão em art/camp/ na resolução de uso.

    python3 tools/build_camp_poses.py
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT / "docs/design/camp/contract.json"
OUT = ROOT / "data/presentation/camp_poses.json"
ALPHA_HIT = 24
## O apoio do corpo (#205): a faixa do meio do corpo visível (esta fração da largura) e o alfa que conta como corpo.
SUPPORT_BAND = 0.4
ALPHA_BODY = 128


def with_visible(art: dict) -> dict:
    """O payload show_art com a caixa do alfa visível, em pixels do canvas original (a textura está reduzida), e o apoio."""
    image = Image.open(ROOT / art["file"].removeprefix("res://")).convert("RGBA")
    alpha = image.getchannel("A")
    box = alpha.point(lambda a: 255 if a > ALPHA_HIT else 0).getbbox()
    scale = art["canvas"][0] / image.width
    out = dict(art)
    out["visible"] = [round(v * scale, 1) for v in box]
    out["support"] = round(support_row(alpha, box) * scale, 1)
    return out


def support_row(alpha: Image.Image, box: tuple) -> float:
    """A linha onde o corpo apoia no chão (#205): na faixa do meio do corpo visível (o quadril do sentado, o tronco do
    deitado), a mediana da última linha opaca de cada coluna. O pé, na ponta, fica mais abaixo: a âncora."""
    left, _, right, bottom = box
    width = right - left
    pixels = alpha.load()
    lows = []
    for x in range(int(left + width * (0.5 - SUPPORT_BAND / 2)), int(left + width * (0.5 + SUPPORT_BAND / 2))):
        for y in range(bottom - 1, -1, -1):
            if pixels[x, y] > ALPHA_BODY:
                lows.append(y + 1)
                break
    lows.sort()
    return lows[len(lows) // 2]


def main() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    heroes: dict = {}
    recruits: dict = {}
    for pose in contract["poses"]:
        art = pose["show_art"]
        if pose.get("hero_id"):
            # A sentada no chão da #82 (a única aprovada para a fogueira).
            heroes.setdefault(pose["hero_id"], {})["seat"] = with_visible(art)
        elif pose.get("recruit_id"):
            recruits.setdefault(pose["recruit_id"], {})[pose["state"]] = with_visible(art)
    for review in contract["founder_sleep_review"]:
        # As deitadas da Estação, reaproveitadas sem mudança (o contrato confere o SHA256 delas).
        heroes.setdefault(review["hero_id"], {})["sleep"] = with_visible(review["show_art"])
    out = {
        "source": "docs/design/camp/contract.json (tools/build_camp_poses.py)",
        "heroes": dict(sorted(heroes.items())),
        "recruits": dict(sorted(recruits.items())),
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(heroes)} fundadores, {len(recruits)} recrutas")


if __name__ == "__main__":
    main()
