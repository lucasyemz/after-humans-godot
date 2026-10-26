"""Leva a captura do capture.gd para before/: os PNG em WebP (qualidade 88, com _clean no nome), o fight_two.json como
saiu, e o fight_two_hud.json, o mesmo DTO no formato que hud-luta/render.mjs lê (loop-screens/before/<nome>.json): as
unidades, quem age e os textos que ele usa (a plaquinha do nome sob cada um, a faixa da rodada e o alcance das
habilidades de quem age, de data/abilities.json).

Uso: python3 -B docs/design/tutorial/prepare_before.py <pasta da captura>
"""
import json
import sys
from pathlib import Path
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/design/tutorial/before"


def main(src: str) -> None:
    src = Path(src)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("explore_two", "fight_two"):
        Image.open(src / f"{name}.png").convert("RGB").save(OUT / f"{name}_clean.webp", quality=88, method=6)
    d = json.loads((src / "fight_two.json").read_text())
    (OUT / "fight_two.json").write_text(json.dumps(d, ensure_ascii=False, indent=1))
    abilities = json.loads((ROOT / "data/abilities.json").read_text())
    units, texts = [], []
    for u in d["units"]:
        units.append({"block": 0, "class_id": u["class_id"], "dodge": 0, "enemy_id": u["enemy_id"], "guard": 0, "hp": u["hp"], "id": u["id"],
                      "instinct": u["instinct"] if u["player"] else 0, "max_hp": u["max_hp"], "name": u["name"], "player": u["player"],
                      "rank": u["rank"], "speed": u["speed"], "stun": 0})
        texts.append({"text": u["name"], "rect": [u["feet"][0] - 80, 720, 160, 22]})
    short = {u["id"]: u["name"].split(" ")[0] for u in d["units"]}
    texts.append({"text": "RODADA %d" % d["round"], "rect": [0, 0, 0, 0]})
    for i, uid in enumerate(d["order"]):
        texts.append({"text": short[uid] + (" · agora" if i == 0 else ""), "rect": [0, 0, 0, 0]})
    actor = next(u for u in d["units"] if u["id"] == d["actor"])
    for a in abilities:
        if a["ClassId"] == actor["class_id"]:
            r = a.get("DamageRange")
            texts.append({"text": a["DisplayName"], "rect": [0, 0, 0, 0]})
            texts.append({"text": f"{r['Min']}–{r['Max']}" if r else "", "rect": [0, 0, 0, 0]})
    (OUT / "fight_two_hud.json").write_text(json.dumps({"actor": d["actor"], "name": "fight_two", "texts": texts, "units": units}, ensure_ascii=False, indent=1))
    print("ok", len(texts))


if __name__ == "__main__":
    main(sys.argv[1])
