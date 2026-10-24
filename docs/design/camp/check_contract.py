"""QA de documentação das #80/#82. Não altera manifesto, arte, saves ou código."""
import argparse
import itertools
import json
import hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--contract", type=Path, default=Path(__file__).with_name("contract.json"))
args = parser.parse_args()
contract = json.loads(args.contract.read_text())
manifest = json.loads((ROOT / "data/presentation/combat_art.json").read_text())
errors = []
for pose in contract["poses"]:
    collection, actor = ("heroes", pose["hero_id"]) if "hero_id" in pose else ("recruits", pose["recruit_id"])
    idle = manifest[collection][actor]["idle"]
    official = pose["show_art"]
    for field in ("canvas", "anchor", "body_reference_pixels"):
        if official[field] != idle[field]:
            errors.append(f"{pose['file']}: show_art.{field} difere do idle atual")
    if official["file"] != "res://" + pose["file"] or pose["use"] != "show_art":
        errors.append(f"{pose['file']}: payload oficial ambíguo")
    with Image.open(ROOT / pose["file"]) as texture, Image.open(ROOT / idle["file"].removeprefix("res://")) as base:
        if texture.size != base.size or list(texture.size) != pose["texture_canvas"]:
            errors.append(f"{pose['file']}: tamanho diverge do idle/contrato")
        ratio = texture.width / idle["canvas"][0]
    expected_anchor = [v * ratio for v in idle["anchor"]]
    if expected_anchor != pose["texture_anchor"]:
        errors.append(f"{pose['file']}: âncora diagnóstica desatualizada")
    if idle["body_reference_pixels"] * ratio != pose["texture_body_reference_pixels"]:
        errors.append(f"{pose['file']}: referência diagnóstica desatualizada")
    if pose["manifest_anchor"] != idle["anchor"] or pose["manifest_canvas"] != idle["canvas"]:
        errors.append(f"{pose['file']}: cópia diagnóstica do manifesto desatualizada")
for a, b in itertools.combinations(contract["camp_slots"], 2):
    aa, bb = a["texture_screen_rect"], b["texture_screen_rect"]
    if not (aa[2] <= bb[0] or bb[2] <= aa[0] or aa[3] <= bb[1] or bb[3] <= aa[1]):
        errors.append(f"{a['recruit_example']}/{b['recruit_example']}: retângulos sobrepostos")
if errors:
    raise SystemExit("\n".join(errors))
for name, layout in contract.get("founder_layouts", {}).items():
    for a, b in itertools.combinations(layout["slots"], 2):
        aa, bb = a["texture_screen_rect"], b["texture_screen_rect"]
        if not (aa[2] <= bb[0] or bb[2] <= aa[0] or aa[3] <= bb[1] or bb[3] <= aa[1]):
            errors.append(f"{name}: {a['actor_id']}/{b['actor_id']}: retângulos sobrepostos")
station = json.loads((ROOT / "data/presentation/station_poses.json").read_text())
for review in contract.get("founder_sleep_review", []):
    source = station[review["hero_id"] + "_sleep"]
    if review["show_art"] != source or hashlib.sha256((ROOT / source["file"].removeprefix("res://")).read_bytes()).hexdigest() != review["sha256"]:
        errors.append(f"{review['hero_id']}: sleep original mudou")
if errors:
    raise SystemExit("\n".join(errors))
print(f"PASS: {len(contract['poses'])} payloads iguais ao idle e 3 composições sem sobreposição.")
