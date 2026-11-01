"""Traz da referência Unreal a arte e os sons do combate e grava data/presentation/combat_art.json.

    python tools/sync_combat_art.py        (precisa do Pillow: pip install pillow)

- Heróis: a pose parada (SourceArt/HeroStatics), as três fases de cada ação aprovada (preparação, execução e efeito,
  SourceArt/AllyActions/Approved20261013) e as reações atuais (ferido e derrotado, SourceArt/AllyActions/Reactions20261020;
  por enquanto só Bento e Nick). As medidas (âncora no pé e altura do corpo em pixels) vêm dos manifestos de origem.
- Inimigos das patrulhas da rua: parado e poses (SourceArt/Legacy); a âncora e a altura do corpo são medidas pelo alfa.
- Ícones das habilidades (SourceArt/ApprovedActionIcons) e os sons do combate (SourceArt/Audio/manifest.json).
- Recrutas (#32, a entrega #14 do Codex): a variação parada de cada classe, da fonte 2x que já está neste repositório
  (art/combat/source/recruits); o id é o nome do arquivo (dog_recruit_01) e não um id de herói. Cada parado (fundador
  ou recruta) leva o retrato recortado da entrega #26 (art/ui/portraits), quando existe. O Guaxinim e o Tatu (#187), sem fundador, vêm da arte aprovada da web antiga
  (SourceArt/Legacy) com as poses de luta e os ícones das habilidades.
- O dano e a queda ajoelhada da Íris e da Véspera (Codex, #13): pelo contrato docs/design/combat_reactions_contract.json
  e as fontes da tag codex-pr54-originals. Sem a pasta da Unreal, só esta parte:
      git archive codex-pr54-originals art/combat/source/reactions | tar -x
      python tools/sync_combat_art.py --codex-reactions
- O Guaxinim e o Tatu redesenhados (#225, a arte do Codex no PR #229): todas as poses que o jogo usa (o parado, um
  golpe por habilidade, o dano, a queda, a esquiva, o bloqueio e o item) e o retrato, pelo contrato
  docs/design/recruits_redraw/contract.json e as fontes da tag codex-pr229-originals, no lugar da arte da web antiga.
  Os ícones das habilidades continuam os da web antiga. Sem a pasta da Unreal, só esta parte:
      git archive codex-pr229-originals art/combat/source/recruits_redraw_20261028 | tar -x
      python tools/sync_combat_art.py --recruits-redraw
- As poses de combate (#221, a arte do Codex no PR #231): a guarda com as armas na mão de cada fundador e da skin
  Bento Ronda (combat_idle.webp, ao lado do idle, na mesma tela e com a mesma âncora), pelo contrato
  docs/design/stances/contract.json e as fontes da tag codex-pr231-originals; a guarda do Guaxinim e a exploração do
  Tatu (com as mãos livres; a guarda dele é o parado do redesenho da #225), também. Depois do redesenho, sem a pasta
  da Unreal, só esta parte:
      git archive codex-pr231-originals art/combat/source/stances_20261028 | tar -x
      python tools/sync_combat_art.py --stances
- O Mercador (#182, parte 2; a arte do Codex na #218, PR #222): as poses de pé, de passada e de oferta e o retrato já
  estão no repositório em WebP, na escala do jogo (os originais ficam na tag codex-pr222-originals). As medidas vêm do
  contrato docs/design/merchant/contract.json: a âncora na bota de apoio de cada pose e a altura do corpo (1,72 m, como
  o Bento). Sem a pasta da Unreal, só esta parte:
      python tools/sync_combat_art.py --npcs

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
# As quedas ajoelhadas e os danos da Íris e da Véspera (Codex, #13, PR #54): o contrato fica na main; os PNG de origem
# ficam na tag codex-pr54-originals (git archive codex-pr54-originals art/combat/source/reactions | tar -x).
CODEX_REACTIONS = PROTO / "docs" / "design" / "combat_reactions_contract.json"
CODEX_REACTIONS_SOURCE = PROTO / "art" / "combat" / "source" / "reactions" / "kneeling_20261023"
# O Guaxinim e o Tatu redesenhados (#225, PR #229): o contrato fica na main; os PNG, na tag codex-pr229-originals.
REDRAW_CONTRACT = PROTO / "docs" / "design" / "recruits_redraw" / "contract.json"
REDRAW_SOURCE = PROTO / "art" / "combat" / "source" / "recruits_redraw_20261028"
# As reações do redesenho com o nome do jogo e a pose de usar item.
REDRAW_REACTIONS = ("hurt", "death", "dodge", "defense", "item")
# As poses de combate (#221, PR #231): o contrato fica na main; os PNG, na tag codex-pr231-originals.
STANCES_CONTRACT = PROTO / "docs" / "design" / "stances" / "contract.json"
STANCES_SOURCE = PROTO / "art" / "combat" / "source" / "stances_20261028"
# O contrato da arte do Mercador (#218): os arquivos e as medidas de cada pose, em pixels do original.
MERCHANT_CONTRACT = PROTO / "docs" / "design" / "merchant" / "contract.json"
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
# Recrutas: a variação e a classe; a fonte 2x fica no próprio repositório, não na Unreal.
RECRUITS = {
    "dog_recruit_01": "cao",
    "cat_recruit_01": "gato",
    "frog_recruit_01": "sapo",
    "owl_recruit_01": "coruja",
}
# O Guaxinim e o Tatu (#187): classes sem fundador. As poses vêm do redesenho da #225 (redraw_recruits); da web antiga
# (SourceArt/Legacy) ficam só os ícones das habilidades (ability-<habilidade>).
LEGACY_RECRUITS = {
    "raccoon_recruit_01": "rato",
    "armadillo_recruit_01": "tatu",
}
PORTRAITS = PROTO / "art" / "ui" / "portraits"
# Vilões do John (conceitos de 09/10/2026, idles de SourceArt/CharacterGallery/EnemyHelperIdles20261010): só a pose
# parada, voltada à direita como os outros. Entram os que a distribuição dele põe num cenário (Lucas, 22/10/2026).
GALLERY = REPO / "SourceArt" / "CharacterGallery" / "EnemyHelperIdles20261010"
GALLERY_ENEMIES = ["recreador", "pipoco", "enraizado", "broto", "carrasco_industrial", "faisca"]
# As poses de luta deles (Codex, #44) e, para os ajudantes, a versão mais legível nos cenários escuros (#45, -readable).
GALLERY_POSES = REPO / "SourceArt" / "CharacterGallery" / "JohnCombatPoses20261022"
GALLERY_HELPERS = {"pipoco", "broto", "faisca"}
POSES = ["attack1", "attack2", "defense", "hurt", "dodge", "support", "death"]
AUDIO_CUES = ["BentoAction", "NickAction", "IrisAction", "VesperaAction", "Dodge", "RobotDodge", "RobotHeal", "RobotPunch"]


def res(path: Path) -> str:
    return "res://" + path.relative_to(PROTO).as_posix()


def convert(src: Path, dst: Path, scale: float = SCALE, force: bool = False) -> Image.Image:
    """Grava src em WebP (com alfa) na escala dada e devolve a imagem original. Sem force, só se src for mais nova."""
    image = Image.open(src).convert("RGBA")
    dst.parent.mkdir(parents=True, exist_ok=True)
    if force or not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image.resize(size, Image.LANCZOS).save(dst, "WEBP", quality=90, method=6)
    return image


def measured(image: Image.Image) -> dict:
    """Âncora no pé (centro da base do que é visível), altura e largura do corpo, pelo alfa. A largura afasta na fila
    quem é mais largo que a posição (o escudo do Tatu, #187)."""
    left, top, right, bottom = image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    return {"anchor": [(left + right) / 2, bottom], "body_reference_pixels": bottom - top, "body_width_pixels": right - left,
            "canvas": [image.width, image.height]}


def with_portrait(idle: dict, name: str) -> dict:
    """Acrescenta ao parado o retrato da entrega #26, se ele existe."""
    portrait = PORTRAITS / f"{name}.png"
    if portrait.exists():
        idle["portrait"] = res(portrait)
    return idle


def recruits() -> dict:
    out = {}
    for variant, class_id in RECRUITS.items():
        src = PROTO / "art" / "combat" / "source" / "recruits" / f"{variant}_idle.png"
        dst = ART / "recruits" / f"{variant}_idle.webp"
        image = convert(src, dst)
        out[variant] = {"class_id": class_id, "idle": with_portrait({"file": res(dst), **measured(image)}, variant)}
    # O Guaxinim e o Tatu: o redesenho da #225 (antes, a arte da web antiga).
    out.update(redraw_recruits())
    return out


def redraw_recruits(source: Path = REDRAW_SOURCE) -> dict:
    """O Guaxinim e o Tatu redesenhados (#225) pelo contrato do Codex: todas as poses com a tela, a âncora no pé e a
    altura do corpo do parado (o registro fixo do contrato: o pé no mesmo ponto em todas e a queda ajoelhada sem
    crescer), em WebP na metade; o retrato de 256 px copiado 1:1. Sempre reconverte (as fontes saem do git archive com a
    data da tag). As poses de acampamento (seat, sleep, #210) ficam de fora: o acampamento ainda não os mostra."""
    if not source.exists():
        raise SystemExit(f"Faltam as fontes em {source}. Extraia na raiz do projeto com:\n"
                         "  git archive codex-pr229-originals art/combat/source/recruits_redraw_20261028 | tar -x")
    contract = json.loads(REDRAW_CONTRACT.read_text(encoding="utf-8"))
    out = {}
    for key, actor in contract["actors"].items():
        variant, class_id, assets = actor["id"], actor["class_id"], actor["assets"]
        folder = ART / "recruits" / variant
        idle = assets["idle"]
        measures = {"canvas": idle["canvas"], "anchor": idle["anchor"], "body_reference_pixels": idle["body_reference_pixels"],
                    "body_width_pixels": idle["body_width_pixels"]}
        convert(source / idle["source_file"], folder / "idle.webp", force=True)
        portrait = contract["portraits"].get(key)
        if portrait:
            PORTRAITS.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / portrait["source_file"], PORTRAITS / f"{variant}.png")
        entry = {"class_id": class_id, "idle": with_portrait({"file": res(folder / "idle.webp"), **measures}, variant),
                 "actions": {}, "reactions": {}}
        for pose, spec in sorted(assets.items()):
            if pose.startswith(f"{class_id}_"):
                convert(source / spec["source_file"], folder / f"{pose}.webp", force=True)
                entry["actions"][pose] = {"execucao": {"file": res(folder / f"{pose}.webp"), **measures}}
            elif pose in REDRAW_REACTIONS:
                convert(source / spec["source_file"], folder / f"{pose}.webp", force=True)
                entry["reactions"][pose] = {"file": res(folder / f"{pose}.webp"), **measures}
        out[variant] = entry
        print(f"{key}: {len(entry['actions'])} golpes, {', '.join(entry['reactions'])}")
    return out


def redraw_recruits_only(source: Path) -> None:
    """Sem a pasta da Unreal: só o Guaxinim e o Tatu redesenhados, no manifesto que já existe."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["recruits"].update(redraw_recruits(source))
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")


def heroes() -> dict:
    actions = json.loads((REPO / "Data/Presentation/ally-actions.json").read_text(encoding="utf-8"))["actions"]
    sources = json.loads((REPO / "SourceArt/AllyActions/Approved20261013/manifest.json").read_text(encoding="utf-8"))["assets"]
    reactions = json.loads((REPO / "SourceArt/AllyActions/Reactions20261020/manifest.json").read_text(encoding="utf-8"))["poses"]
    item_use = json.loads((REPO / "SourceArt/AllyActions/ItemUse/manifest.json").read_text(encoding="utf-8"))["poses"]
    out = {}
    for hero_id, spec in HEROES.items():
        idle_src = REPO / spec["idle"]
        idle = convert(idle_src, ART / "heroes" / spec["name"].lower() / "idle.webp")
        idle_entry = with_portrait({"file": res(ART / "heroes" / spec["name"].lower() / "idle.webp"), **measured(idle)}, spec["name"].lower())
        entry = {"name": spec["name"], "idle": idle_entry,
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
        entry["reactions"].update(codex_reactions().get(hero_id, {}))
        out[hero_id] = entry
    return out


def codex_reactions(source: Path = CODEX_REACTIONS_SOURCE) -> dict:
    """O dano e a queda ajoelhada da Íris e da Véspera pelo contrato do Codex: a tela, a âncora e a altura do corpo do
    contrato (iguais às do parado), em WebP na metade. Sempre reconverte: as fontes saem do git archive com a data do
    commit da tag, mais velha que o WebP de um clone novo. Sem as fontes, para com a instrução (a conversão completa
    reescreve o manifesto do zero e perderia as poses)."""
    if not source.exists():
        raise SystemExit(f"Faltam as fontes em {source}. Extraia na raiz do projeto com:\n"
                         "  git archive codex-pr54-originals art/combat/source/reactions | tar -x")
    out = {}
    for pose in json.loads(CODEX_REACTIONS.read_text(encoding="utf-8"))["poses"]:
        src = source / Path(pose["file"]).name
        name = HEROES[pose["hero_id"]]["name"].lower()
        dst = ART / "heroes" / name / f"{pose['state']}.webp"
        convert(src, dst, force=True)
        out.setdefault(pose["hero_id"], {})[pose["state"]] = {"file": res(dst), "canvas": pose["canvas"],
                                                              "anchor": pose["anchor"],
                                                              "body_reference_pixels": pose["body_reference_pixels"]}
    return out


def stances(source: Path = STANCES_SOURCE, redraw: Path = REDRAW_SOURCE) -> dict:
    """As duas poses paradas (#221) pelo contrato do Codex: a de combate vira combat_idle.webp ao lado do idle e, quando
    o contrato traz uma de exploração nova (o Tatu, com as mãos livres), ela vira o idle.webp. A tela, a âncora e a
    altura do corpo são as do idle (a escala não muda pela guarda flexionada). A pose reaproveitada do redesenho da
    #225 (a guarda do Tatu é o parado dele de lá) vem das fontes daquela tag. A da skin (skin_id) vai para a pasta dela,
    com o mesmo nome. Devolve {id do herói ou do recruta: {"combat_idle": entrada}}. Sempre reconverte."""
    if not source.exists():
        raise SystemExit(f"Faltam as fontes em {source}. Extraia na raiz do projeto com:\n"
                         "  git archive codex-pr231-originals art/combat/source/stances_20261028 | tar -x")
    out = {}
    for key, actor in json.loads(STANCES_CONTRACT.read_text(encoding="utf-8"))["actors"].items():
        folder = (PROTO / actor["baseline"]["file"].removeprefix("res://")).parent
        if actor["baseline"]["file"].startswith("tag://"):
            folder = ART / "recruits" / actor["id"]
        entry = {}
        for state, name in (("exploration", "idle.webp"), ("combat", "combat_idle.webp")):
            spec = actor["states"][state]
            if not spec.get("source_file"):
                continue
            src = source / spec["source_file"]
            if not src.exists():
                # Reaproveitada do redesenho da #225 (a pasta do personagem lá tem o mesmo nome).
                src = redraw / spec["source_file"]
                if not src.exists():
                    raise SystemExit(f"Falta {spec['source_file']} nas fontes da #221 e do redesenho da #225.")
            dst = folder / name
            convert(src, dst, force=True)
            if state == "combat":
                entry["combat_idle"] = {"file": res(dst), "canvas": spec["canvas"], "anchor": spec["anchor"],
                                        "body_reference_pixels": spec["body_reference_pixels"]}
                # A largura do corpo fica a do idle, de propósito: a fila da luta se espaça pela pose da rua (o
                # _half_widths sai antes da troca para a guarda), e a guarda cabe no mesmo lugar (a QA de design da #221
                # recolheu armas e capa).
                if "body_width_pixels" in actor["baseline"]:
                    entry["combat_idle"]["body_width_pixels"] = actor["baseline"]["body_width_pixels"]
            print(f"{key}: {res(dst)}" + (f" (skin {actor['skin_id']})" if actor.get("skin_id") else ""))
        if entry and not actor.get("skin_id"):
            out[actor["id"]] = entry
    return out


def apply_stances(manifest: dict, source: Path = STANCES_SOURCE) -> None:
    """Põe a guarda de cada herói e de cada recruta no manifesto (depois dos parados: o do Tatu muda)."""
    for actor_id, entry in stances(source).items():
        group = "heroes" if actor_id in manifest["heroes"] else "recruits"
        manifest[group][actor_id].update(entry)


def stances_only(source: Path) -> None:
    """Sem a pasta da Unreal: só as poses de combate, no manifesto que já existe."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    apply_stances(manifest, source)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")


def codex_reactions_only(source: Path) -> None:
    """Sem a pasta da Unreal: só as poses do Codex, no manifesto que já existe."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for hero_id, states in codex_reactions(source).items():
        manifest["heroes"][hero_id]["reactions"].update(states)
        print(hero_id, ", ".join(states))
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")


def npcs() -> dict:
    """Os personagens que não lutam nem entram no elenco: o Mercador (#182). Cada pose leva a âncora medida na bota de
    apoio dela (não a do parado: a passada e a oferta mudam o pé), e o retrato é o WebP dedicado."""
    contract = json.loads(MERCHANT_CONTRACT.read_text(encoding="utf-8"))
    entry = {}
    for pose in ("idle", "walk", "trade"):
        spec = contract["assets"][pose]
        if not (PROTO / spec["file"].removeprefix("res://")).exists():
            raise SystemExit(f"Falta a arte {spec['file']} do contrato do Mercador.")
        entry[pose] = {"file": spec["file"], "canvas": spec["canvas"], "anchor": spec["anchor"],
                       "body_reference_pixels": spec["body_reference_pixels"]}
    entry["portrait"] = contract["assets"]["portrait"]["file"]
    return {"merchant": entry}


def npcs_only() -> None:
    """Sem a pasta da Unreal: só os personagens de fora da luta, no manifesto que já existe."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["npcs"] = npcs()
    print("npcs:", ", ".join(manifest["npcs"]))
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")


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


def gallery_enemies() -> dict:
    """Os vilões do John: a pose parada e as poses de luta (a mesma tela, o pé no mesmo ponto); a âncora e a altura do
    corpo de todas vêm do idle no manifesto da galeria (body_alpha_bounds), porque as imagens têm faíscas e sombra
    soltas fora do corpo, e a derrota deitada não pode crescer."""
    manifest = {e["id"]: e for e in json.loads((GALLERY / "manifest.json").read_text(encoding="utf-8"))["entries"]}
    out = {}
    for enemy_id in GALLERY_ENEMIES:
        entry = manifest[enemy_id]
        folder = ART / "enemies" / enemy_id
        readable = GALLERY_POSES / f"{enemy_id}-idle-readable.png"
        idle_src = readable if enemy_id in GALLERY_HELPERS and readable.exists() else GALLERY / entry["file"]
        image = convert(idle_src, folder / "idle.webp")
        left, top, right, bottom = entry["body_alpha_bounds"]
        measures = {"anchor": [(left + right) / 2, bottom], "body_reference_pixels": bottom - top, "canvas": [image.width, image.height]}
        poses = {}
        for pose in POSES:
            src = GALLERY_POSES / f"{enemy_id}-{pose}{'-readable' if enemy_id in GALLERY_HELPERS else ''}.png"
            if src.exists():
                convert(src, folder / f"{pose}.webp")
                poses[pose] = {"file": res(folder / f"{pose}.webp"), **measures}
        out[enemy_id] = {"poses": poses, "idle": {"file": res(folder / "idle.webp"), **measures}}
    return out


def icons() -> dict:
    out = {}
    for src in sorted((REPO / "SourceArt/ApprovedActionIcons").glob("*.png")):
        dst = ART / "icons" / f"{src.stem}.webp"
        image = Image.open(src)
        convert(src, dst, ICON_SIZE / image.width)
        out[src.stem] = res(dst)
    for class_id in LEGACY_RECRUITS.values():
        for src in sorted((LEGACY / "public" / "characters" / "approved" / class_id).glob(f"{class_id}-ability-*.png")):
            ability = src.stem.split("-", 2)[2]
            dst = ART / "icons" / f"{ability}.webp"
            convert(src, dst, ICON_SIZE / Image.open(src).width)
            out[ability] = res(dst)
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
                "heroes": heroes(), "recruits": recruits(), "enemies": {**enemies(), **gallery_enemies()}, "icons": icons(),
                "audio": audio(), "npcs": npcs()}
    apply_stances(manifest)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t"), encoding="utf-8", newline="\n")
    size = sum(f.stat().st_size for f in ART.rglob("*") if f.is_file()) + sum(f.stat().st_size for f in AUDIO.rglob("*") if f.is_file())
    print(f"heróis: {len(manifest['heroes'])}, inimigos: {len(manifest['enemies'])}, ícones: {len(manifest['icons'])}, "
          f"sons: {len(manifest['audio'])}; {size / 1e6:.1f} MB em art/combat e audio/combat")


if __name__ == "__main__":
    import sys
    if "--codex-reactions" in sys.argv:
        # python tools/sync_combat_art.py --codex-reactions [pasta das fontes]
        rest = sys.argv[sys.argv.index("--codex-reactions") + 1:]
        codex_reactions_only(Path(rest[0]) if rest else CODEX_REACTIONS_SOURCE)
    elif "--npcs" in sys.argv:
        npcs_only()
    elif "--recruits-redraw" in sys.argv:
        # python tools/sync_combat_art.py --recruits-redraw [pasta das fontes]
        rest = sys.argv[sys.argv.index("--recruits-redraw") + 1:]
        redraw_recruits_only(Path(rest[0]) if rest else REDRAW_SOURCE)
    elif "--stances" in sys.argv:
        # python tools/sync_combat_art.py --stances [pasta das fontes]
        rest = sys.argv[sys.argv.index("--stances") + 1:]
        stances_only(Path(rest[0]) if rest else STANCES_SOURCE)
    else:
        main()
