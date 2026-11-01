"""Traz as roupas confortáveis do lobby (#249, a entrega da Awesomic no PR #267) para art/ e grava
data/presentation/lobby_outfits.json.

    python tools/sync_lobby_outfits.py --sources <pasta lobby_poses_awesomic_20261030>   (precisa do Pillow)

As fontes são os PNG encaixados da Release awesomic-249-lobby-originals (nunca na main):
    lobby_poses_awesomic_20261030.tar.gz, sha256 no contrato (docs/design/lobby_poses/contract.json).

O contrato diz, por arquivo, o hash, o canvas, a textura de destino, a âncora e a altura de referência; aqui cada fonte
confere o hash e vira WebP no tamanho da textura (quality 90, como o resto da arte). Entram só os modelos que o jogo
já tem na roupa de expedição: os quatro fundadores e os seis recrutas machos. As fêmeas esperam as poses de expedição
delas (#250): sem elas, a recruta de lobby não teria com que sair para a rua.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

PROTO = Path(__file__).resolve().parents[1]
CONTRACT = PROTO / "docs" / "design" / "lobby_poses" / "contract.json"
ART = PROTO / "art" / "station" / "lobby"
MANIFEST = PROTO / "data" / "presentation" / "lobby_outfits.json"
# O modelo do contrato → a variação de arte do recruta no manifesto da luta (combat_art.json, recruits).
RECRUITS = {
    "dog_male": "dog_recruit_01",
    "cat_male": "cat_recruit_01",
    "frog_male": "frog_recruit_01",
    "owl_male": "owl_recruit_01",
    "raccoon_male": "raccoon_recruit_01",
    "armadillo_male": "armadillo_recruit_01",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sources", type=Path, required=True)
    sources = parser.parse_args().sources.resolve()
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    out = {"heroes": {}, "recruits": {}}
    for actor, row in contract["actors"].items():
        if row["founder"]:
            section, key = "heroes", row["game_id"]
        elif actor in RECRUITS:
            section, key = "recruits", RECRUITS[actor]
        else:
            continue
        poses = {}
        for state, asset in sorted(row["assets"].items()):
            src = sources / asset["source_file"]
            digest = hashlib.sha256(src.read_bytes()).hexdigest()
            if digest != asset["source_sha256"]:
                raise SystemExit(f"{src}: hash diferente do contrato")
            dst = ART / actor / f"{state}.webp"
            dst.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(src) as image:
                if list(image.size) != asset["canvas"]:
                    raise SystemExit(f"{src}: canvas {image.size} fora do contrato")
                image.convert("RGBA").resize(tuple(asset["texture_canvas"]), Image.LANCZOS).save(dst, "WEBP", quality=90, method=6)
            pose = {"file": "res://" + dst.relative_to(PROTO).as_posix(), "canvas": asset["canvas"],
                    "anchor": asset["anchor"], "body_reference_pixels": asset["body_reference_pixels"]}
            if state == "seat":
                # De lado, como o banco da Cantina (#253).
                pose["facing"] = "side"
            poses[state] = pose
        out[section][key] = poses
    MANIFEST.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{sum(len(p) for s in out.values() for p in s.values())} poses em {MANIFEST.relative_to(PROTO)}")


if __name__ == "__main__":
    main()
