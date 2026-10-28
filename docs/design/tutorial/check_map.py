"""Confere o mapa do tutorial (map/ContainmentCorridor.json) contra o contrato de tools/sync_scenarios.py, sem tocar em
data/: as mesmas chaves do topo que os mapas de hoje (data/scenarios/<Mapa>.json), em cada peça, luz, zona e prop só
chaves que algum mapa de hoje já usa (nos materiais, mais a chave "zone", que o jogo ignora), cada malha em
data/scenarios/meshes.json, cada material e cada peça de prop no lugar, e cada textura res:// existindo no repositório.
A prova de que o jogo monta o mapa é a captura (capture_map.gd), que o carrega pela cena da rua de verdade.

Uso (da raiz do repositório): python3 -B docs/design/tutorial/check_map.py
"""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
MAP = ROOT / "docs/design/tutorial/map/ContainmentCorridor.json"
SCENARIOS = ROOT / "data/scenarios"


def main() -> int:
    new = json.loads(MAP.read_text())
    # Os mapas de hoje, sem o próprio Corredor (o data/ dele já é este mapa com a camada de jogo por cima).
    today = [json.loads(p.read_text()) for p in sorted(SCENARIOS.glob("*.json")) if p.name not in ("meshes.json", "ContainmentCorridor.json")]
    meshes = len(json.loads((SCENARIOS / "meshes.json").read_text())["meshes"])
    errors = []
    top = set(today[0])
    if set(new) != top:
        errors.append(f"chaves do topo: {sorted(set(new) ^ top)}")
    for group in ("parts", "lights", "zones", "props", "materials"):
        known = {k for m in today for item in m[group] for k in item}
        if group == "materials":
            known.add("zone")
        extra = {k for item in new[group] for k in item} - known
        if extra:
            errors.append(f"{group}: chaves que nenhum mapa usa: {sorted(extra)}")
    for i, part in enumerate(new["parts"]):
        if not 0 <= part["mesh"] < meshes:
            errors.append(f"peça {i}: malha {part['mesh']} fora de meshes.json")
        if any(not 0 <= m < len(new["materials"]) for m in part["materials"]):
            errors.append(f"peça {i}: material fora da lista")
    for prop in new["props"]:
        if any(not 0 <= p < len(new["parts"]) for p in prop["parts"]) or not 0 <= prop["open"] < len(new["materials"]):
            errors.append(f"prop {prop['code']}: peça ou material aberto fora da lista")
    for material in new["materials"]:
        for key in ("albedo", "normal"):
            path = material.get(key, "")
            if path and not (ROOT / path.removeprefix("res://")).exists():
                errors.append(f"textura que não existe: {path}")
    for e in errors:
        print("ERRO:", e)
    print(f"{MAP.name}: {len(new['parts'])} peças, {len(new['materials'])} materiais, {len(new['lights'])} luzes, "
          f"{len(new['zones'])} zonas, {len(new['props'])} props; {'OK' if not errors else f'{len(errors)} erros'}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
