"""Traz da referência Unreal a arte e os sons do combate e grava data/presentation/combat_art.json.

    python tools/sync_combat_art.py        (precisa do Pillow: pip install pillow)

- Heróis: a pose parada (SourceArt/HeroStatics), as três fases de cada ação aprovada (preparação, execução e efeito,
  SourceArt/AllyActions/Approved20261013) e as reações atuais (ferido e derrotado, SourceArt/AllyActions/Reactions20261020;
  por enquanto só Bento e Nick). As medidas (âncora no pé e altura do corpo em pixels) vêm dos manifestos de origem.
- Inimigos das patrulhas da rua: parado e poses (SourceArt/Legacy); a âncora e a altura do corpo são medidas pelo alfa.
- Ícones das habilidades (SourceArt/ApprovedActionIcons) e os sons do combate (SourceArt/Audio/manifest.json).

As imagens viram WebP com metade da resolução (o jogo nunca mostra mais que isso); as medidas no manifesto ficam nos
pixels originais e o jogo converte pela largura real da textura.
"""
import json
import shutil
from pathlib import Path

from PIL import Image

PROTO = Path(__file__).resolve().parents[1]
REPO = PROTO.parent
ART = PROTO / "art" / "combat"
AUDIO = PROTO / "audio" / "combat"
MANIFEST = PROTO / "data" / "presentation" / "combat_art.json"
LEGACY = REPO / "SourceArt" / "Legacy"
SCALE = 0.5
ICON_SIZE = 160

HEROES = {
    "hero_cao_bento": {"name": "Bento", "idle": "SourceArt/HeroStatics/bento-idle-v2.png"},
    "hero_gato_nick": {"name": "Nick", "idle": "SourceArt/HeroStatics/nick-idle-v2.png"},
    "hero_sapo_iris": {"name": "Iris", "idle": "SourceArt/HeroStatics/sapo-iris-static.png"},
    "hero_coruja_vespera": {"name": "Vespera", "idle": "SourceArt/HeroStatics/coruja-vespera-static.png"},
}
# Inimigos da patrulha da rua. idle: imagem única ou folha de quadros (com o .json da folha).
ENEMIES = {
    "robot": {"idle_sheet": "assets/idle/robot-idle.png", "poses": "public/characters/overrides.json"},
    "robot_fungo": {"idle_sheet": "assets/idle/robot-fungo-idle.png", "poses": "public/characters/approved/robot_fungo"},
    "vigia_enferrujado": {"idle": "public/characters/approved/vigia_enferrujado/vigia_enferrujado-idle.png",
                          "poses": "public/characters/approved/vigia_enferrujado"},
}
# Os outros inimigos das patrulhas e o Porteiro (chefe da fase 5): parado e poses da arte aprovada.
for _enemy in ("cao_eco", "condutor_raiz", "sussurrador", "rastejante_raiz", "ninho_errante", "carcaca_colonizada", "porteiro"):
    ENEMIES[_enemy] = {"idle": f"public/characters/approved/{_enemy}/{_enemy}-idle.png", "poses": f"public/characters/approved/{_enemy}"}
POSES = ["attack1", "attack2", "defense", "hurt", "dodge", "support", "death"]
AUDIO_CUES = ["BentoAction", "NickAction", "IrisAction", "VesperaAction", "Dodge", "RobotDodge", "RobotHeal", "RobotPunch"]


def res(path: Path) -> str:
    return "res://" + path.relative_to(PROTO).as_posix()


def convert(src: Path, dst: Path, scale: float = SCALE) -> Image.Image:
    """Grava src em WebP (com alfa) na escala dada e devolve a imagem original."""
    image = Image.open(src).convert("RGBA")
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image.resize(size, Image.LANCZOS).save(dst, "WEBP", quality=90, method=6)
    return image


def measured(image: Image.Image) -> dict:
    """Âncora no pé (centro da base do que é visível) e altura do corpo, pelo alfa."""
    left, top, right, bottom = image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    return {"anchor": [(left + right) / 2, bottom], "body_reference_pixels": bottom - top, "canvas": [image.width, image.height]}


def heroes() -> dict:
    actions = json.loads((REPO / "Data/Presentation/ally-actions.json").read_text(encoding="utf-8"))["actions"]
    sources = json.loads((REPO / "SourceArt/AllyActions/Approved20261013/manifest.json").read_text(encoding="utf-8"))["assets"]
    reactions = json.loads((REPO / "SourceArt/AllyActions/Reactions20261020/manifest.json").read_text(encoding="utf-8"))["poses"]
    item_use = json.loads((REPO / "SourceArt/AllyActions/ItemUse/manifest.json").read_text(encoding="utf-8"))["poses"]
    out = {}
    for hero_id, spec in HEROES.items():
        idle_src = REPO / spec["idle"]
        idle = convert(idle_src, ART / "heroes" / spec["name"].lower() / "idle.webp")
        entry = {"name": spec["name"], "idle": {"file": res(ART / "heroes" / spec["name"].lower() / "idle.webp"), **measured(idle)},
                 "actions": {}, "reactions": {}}
        for action in (a for a in actions if a["hero_id"] == hero_id):
            ability = action["ability_id"]
            phases = {}
            for phase in ("preparacao", "execucao", "vfx"):
                src = next(REPO / s["path"] for s in sources if s["ability_id"] == ability and s["phase"] == phase)
                dst = ART / "heroes" / spec["name"].lower() / f"{ability}_{phase}.webp"
                convert(src, dst)
                phases[phase] = {"file": res(dst), **action[phase]}
            entry["actions"][ability] = phases
        for pose in (p for p in reactions if p["hero"] == spec["name"] and p["pose"] in ("hurt", "death")):
            dst = ART / "heroes" / spec["name"].lower() / f"{pose['pose']}.webp"
            convert(REPO / pose["source"], dst)
            entry["reactions"][pose["pose"]] = {"file": res(dst), "canvas": pose["canvas"], "anchor": pose["anchor"],
                                                "body_reference_pixels": pose["body_reference_pixels"]}
        # Usar item da Mochila (SourceArt/AllyActions/ItemUse): a pose de todos os quatro, com o pé e o topo medidos lá.
        for pose in (p for p in item_use if p["hero"] == spec["name"]):
            dst = ART / "heroes" / spec["name"].lower() / "item.webp"
            convert(REPO / pose["source"], dst)
            entry["reactions"]["item"] = {"file": res(dst), "canvas": [pose["width"], pose["height"]],
                                          "anchor": [pose["foot_x"], pose["foot_y"]],
                                          "body_reference_pixels": pose["foot_y"] - pose["top"]}
        out[hero_id] = entry
    return out


def enemy_pose_files(spec: dict) -> dict:
    source = LEGACY / spec["poses"]
    if source.suffix == ".json":
        overrides = json.loads(source.read_text(encoding="utf-8"))
        return {pose: LEGACY / "public" / url.lstrip("/") for key, url in overrides.items()
                for character, pose in [key.split("/")] if character == "robot" and pose in POSES}
    enemy = source.name
    return {pose: source / f"{enemy}-{pose}.png" for pose in POSES if (source / f"{enemy}-{pose}.png").exists()}


def enemies() -> dict:
    out = {}
    for enemy_id, spec in ENEMIES.items():
        folder = ART / "enemies" / enemy_id
        entry = {"poses": {}}
        poses = {pose: convert(src, folder / f"{pose}.webp") for pose, src in enemy_pose_files(spec).items()}
        # Poses na mesma tela da defesa (de pé) usam a altura do corpo dela; assim a morte deitada não cresce.
        reference = measured(poses["defense"])
        for pose, image in poses.items():
            m = measured(image)
            if m["canvas"] == reference["canvas"]:
                m["body_reference_pixels"] = reference["body_reference_pixels"]
            entry["poses"][pose] = {"file": res(folder / f"{pose}.webp"), **m}
        if "idle_sheet" in spec:
            src = LEGACY / spec["idle_sheet"]
            frames_json = json.loads(src.with_name(src.stem + "-v1.json").read_text(encoding="utf-8"))["frames"]
            frames = [[f["x"], f["y"], f["w"], f["h"]] for _, f in sorted(frames_json.items(), key=lambda kv: int(kv[0]))]
            sheet = convert(src, folder / "idle_sheet.webp", 1.0)
            # Quadros vazios saem (a folha do robô tem dois no fim, e ele sumia neles). Medidas pela união dos que
            # sobram (o corpo respira; a âncora não pode pular).
            boxes = [sheet.crop((x, y, x + w, y + h)).getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox() for x, y, w, h in frames]
            frames = [frame for frame, box in zip(frames, boxes) if box]
            boxes = [b for b in boxes if b]
            left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
            right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
            entry["idle"] = {"file": res(folder / "idle_sheet.webp"), "frames": frames, "fps": 10,
                             "anchor": [(left + right) / 2, bottom], "body_reference_pixels": bottom - top,
                             "canvas": [frames[0][2], frames[0][3]]}
        else:
            image = convert(LEGACY / spec["idle"], folder / "idle.webp")
            entry["idle"] = {"file": res(folder / "idle.webp"), **measured(image)}
        out[enemy_id] = entry
    return out


def icons() -> dict:
    out = {}
    for src in sorted((REPO / "SourceArt/ApprovedActionIcons").glob("*.png")):
        dst = ART / "icons" / f"{src.stem}.webp"
        image = Image.open(src)
        convert(src, dst, ICON_SIZE / image.width)
        out[src.stem] = res(dst)
    return out


def audio() -> dict:
    entries = json.loads((REPO / "SourceArt/Audio/manifest.json").read_text(encoding="utf-8"))["entries"]
    out = {}
    for entry in entries:
        if not any(entry["cue"].startswith(prefix) for prefix in AUDIO_CUES):
            continue
        src = REPO / entry["source"]
        dst = AUDIO / f"{entry['cue']}{src.suffix}"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        out[entry["cue"]] = res(dst)
    click = REPO / "SourceArt/Audio/Synth/SFX_UI_Click.wav"
    shutil.copy2(click, AUDIO / "UIClick.wav")
    out["UIClick"] = res(AUDIO / "UIClick.wav")
    return out


def main() -> None:
    manifest = {"schema_version": 1, "scale_note": "Medidas em pixels da imagem original; a textura pode ser menor.",
                "heroes": heroes(), "enemies": enemies(), "icons": icons(), "audio": audio()}
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")
    size = sum(f.stat().st_size for f in ART.rglob("*") if f.is_file()) + sum(f.stat().st_size for f in AUDIO.rglob("*") if f.is_file())
    print(f"heróis: {len(manifest['heroes'])}, inimigos: {len(manifest['enemies'])}, ícones: {len(manifest['icons'])}, "
          f"sons: {len(manifest['audio'])}; {size / 1e6:.1f} MB em art/combat e audio/combat")


if __name__ == "__main__":
    main()
