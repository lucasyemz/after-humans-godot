"""Traz da referência Unreal (a pasta acima deste repositório) os dados e a arte que o projeto usa, para data/ e art/.

Os arquivos copiados ficam versionados aqui: o projeto roda e exporta sozinho, sem a pasta da Unreal. Só rode isto ao
portar mais conteúdo ou ao atualizar um JSON de produção vindo de lá:  python tools/sync_assets.py

A arte da rua é a mesma que a Unreal importou: as pinturas da versão web (tag alphaweb, public/corridor/assets) e os
PNG de SourceArt. Os heróis e os inimigos vêm de tools/sync_combat_art.py.
"""
import shutil
import subprocess
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
# Referência Unreal: o repositório antigo, onde esta pasta mora.
REPO = PROTO.parent

DATA = [
    *sorted((REPO / "Data").glob("*.json")),
    REPO / "Data" / "combat-parity.txt",
]
# Dados que passaram a ser da Godot: não voltam da Unreal (encounters.json tem as patrulhas de cada fase e de cada loja,
# com os vilões do John, desde 22/10/2026).
GODOT_OWNED_DATA = {"encounters.json"}
LEGACY_KITS = sorted((REPO / "Tests" / "Fixtures" / "LegacyKits").glob("*.json"))

WEB_TAG = "alphaweb"
WEB_STREET = [f"public/corridor/assets/street-3d/{name}.webp" for name in (
    "grocery-v1", "workshop-v1", "cinema-v1", "side-windows-v1", "side-stairs-v1", "alley-props-v1",
    "props-street-v1", "props-storefront-v1", "props-service-v1", "vehicles-profile-v2",
    "asphalt-v1", "plaster-v1", "alley-brick-v1",
)] + [f"public/corridor/assets/{name}.png" for name in ("lamp", "background0", "background1", "background2")]

SOURCE_ART = [
    "SourceArt/side-long-fire-escape.png",
    "SourceArt/side-long-plain.png",
    "SourceArt/door-open-grocery-crop.png",
    "SourceArt/door-open-workshop-crop.png",
    "SourceArt/door-open-cinema-crop.png",
    "SourceArt/ShopfrontStreet/Campfire/campfire-v1.png",
]


# Interiores das lojas (AHHouseRoom): chão, parede do fundo repetida, rodapé e os itens presos na parede. Viram WebP.
ROOM_SHOPS = ["grocery", "workshop", "cinema"]
ROOM_PARTS = ["floor", "walltile-seamless", "trim-cut", *[f"item{i}" for i in range(6)]]


def rooms() -> int:
    from PIL import Image  # só para os interiores: pip install pillow
    count = 0
    for shop in ROOM_SHOPS:
        for part in ROOM_PARTS:
            src = REPO / "SourceArt" / f"room-{shop}-{part}.png"
            if not src.exists():
                continue
            dst = PROTO / "art" / "rooms" / f"{shop}-{part}.webp"
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
                image = Image.open(src).convert("RGBA")
                scale = 0.6 if part in ("floor", "walltile-seamless", "trim-cut") else 1.0
                image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS).save(dst, "WEBP", quality=88, method=4)
            count += 1
    return count


# Estação Raiz: as superfícies dos cômodos (Poly Haven e ambientCG, CC0). A cor e a normal em 1K e o tamanho real de
# cada amostra (TileSize da Unreal: as dimensões da Poly Haven em mm, ou o ajuste do import-ambientcg-surfaces.py).
POLYHAVEN_SHELTER = "SourceArt/ThirdParty/PolyHaven/Shelter"
AMBIENTCG = {"DiamondPlate008A": (80.0, 0.65), "CorrugatedSteel009": (120.0, 0.45), "Metal021": (200.0, 0.65),
             "MetalPlates006": (240.0, 0.7)}


def station() -> int:
    import json
    from PIL import Image, ImageOps
    manifest = json.loads((REPO / POLYHAVEN_SHELTER / "manifest.json").read_text(encoding="utf-8"))
    sources = {}
    for entry in manifest:
        if entry["kind"] != "texture":
            continue
        files = entry["files"]
        size = entry.get("dimensions_mm") or [2000]
        sources[entry["id"]] = {"color": files["base_color"]["file"], "normal": files.get("normal", {}).get("file"),
                                "root": POLYHAVEN_SHELTER, "tile": max(50.0, float(size[0]) / 10.0), "tint": 1.0}
    for name, (tile, tint) in AMBIENTCG.items():
        sources[name] = {"color": f"{name}_1K-PNG_Color.png", "normal": f"{name}_1K-PNG_NormalGL.png",
                         "root": f"SourceArt/ThirdParty/AmbientCG/{name}", "tile": tile, "tint": tint}
    table = {}
    for name, info in sources.items():
        for kind, suffix in (("color", ""), ("normal", "_n")):
            if not info[kind]:
                continue
            src = REPO / info["root"] / info[kind]
            if not src.exists():
                print(f"  falta {src}")
                continue
            dst = PROTO / "art" / "station" / f"{name}{suffix}.webp"
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
                image = Image.open(src).convert("RGB").resize((1024, 1024), Image.LANCZOS)
                if kind == "normal" and "_nor_dx" in src.name:
                    r, g, b = image.split()
                    image = Image.merge("RGB", (r, ImageOps.invert(g), b))
                image.save(dst, "WEBP", quality=86, method=4)
        table[name] = {"tile_cm": info["tile"], "tint": info["tint"], "normal": bool(info["normal"])}
    target = PROTO / "data" / "presentation" / "station_surfaces.json"
    target.write_text(json.dumps(table, ensure_ascii=False, indent=2) + chr(10), encoding="utf-8")
    return len(table)


# Os modelos da Poly Haven (CC0) que a Estação da Unreal usa: o FBX como veio e as texturas em 512 px, com o mesmo nome
# (o FBX as procura pelo nome). Os que só existem como .uasset na Unreal (cadeira do bar, binóculo, kit de química,
# sofá) ficam de fora; a Estação usa uma peça parecida no lugar deles.
STATION_MODELS = [
    "Barrel_02", "brass_pan_01", "brass_pot_01", "caged_hanging_light", "cardboard_box_01", "carved_wooden_plate",
    "electric_stove", "folding_wooden_stool", "food_apple_01", "hanging_industrial_lamp", "industrial_storage_cart",
    "industrial_wall_lamp", "korean_fire_extinguisher_01", "long_life_food", "metal_jerrycan_green", "metal_tool_chest",
    "metal_trash_can", "mounted_fluorescent_lights", "painted_wooden_bench", "painted_wooden_cabinet",
    "painted_wooden_shelves", "painted_wooden_table", "plastic_bottle_gallon", "plastic_container", "plastic_crate_01",
    "pot_enamel_01", "power_box_01", "russian_food_cans_01", "security_light", "sledgehammer_01", "steel_frame_shelves_01",
    "steel_frame_shelves_02", "sweet_potato", "tool_cart", "utility_box_02", "vintage_electric_kettle", "wall_clock",
    "wicker_basket_01", "wooden_bowl_01", "wooden_bucket_01", "wooden_crate_02", "wooden_cutting_board",
    "wooden_military_crate",
]


def station_models() -> int:
    from PIL import Image
    count = 0
    for model in STATION_MODELS:
        src_dir = REPO / "SourceArt/ThirdParty/PolyHaven/Shelter" / model
        if not src_dir.exists():
            print(f"  falta o modelo {model}")
            continue
        dst_dir = PROTO / "art" / "station" / "models" / model
        dst_dir.mkdir(parents=True, exist_ok=True)
        for src in src_dir.iterdir():
            dst = dst_dir / src.name
            if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
                continue
            if src.suffix.lower() == ".fbx":
                shutil.copy2(src, dst)
            elif src.suffix.lower() in (".jpg", ".png"):
                image = Image.open(src)
                image = image.convert("RGBA" if image.mode in ("RGBA", "LA") else "RGB")
                image = image.resize((min(512, image.width), min(512, image.height)), Image.LANCZOS)
                if "_nor_dx" in src.name:
                    # Normal no padrão DirectX: a Godot usa o do OpenGL (o verde invertido).
                    from PIL import ImageOps
                    r, g, b, *rest = image.convert("RGB").split()
                    image = Image.merge("RGB", (r, ImageOps.invert(g), b))
                if src.suffix.lower() == ".jpg":
                    image.convert("RGB").save(dst, "JPEG", quality=84)
                else:
                    image.save(dst, "PNG", optimize=True)
        count += 1
    return count


# Os cards pintados da Estação (os M_<Sala>_<Nome> da Unreal): recortados no alfa visível, como o material M_AHCard
# recorta pela UV, e na metade da resolução. O nome é o da Unreal (Cantina_Front, Depot_Crate...).
STATION_CARDS = {
    "Door": "SourceArt/RootStation/Doors/Proposals/V2/DOOR01_Station_Wood_Closed.png",
    "Cantina_Front": "SourceArt/RootStation/Cantina/Prepared/Front.png",
    "Cantina_Pantry": "SourceArt/RootStation/Cantina/Prepared/Pantry.png",
    "Cantina_Utensils": "SourceArt/RootStation/Cantina/Prepared/Utensils.png",
    "Depot_Crate": "SourceArt/RootStation/Depot/Issue58/DP01_Provisions_Crate.png",
    "Depot_Sack": "SourceArt/RootStation/Depot/Issue58/DP02_Sack.png",
    "Depot_Container": "SourceArt/RootStation/Depot/Issue58/DP03_Metal_Container.png",
    "Forge_Workbay": "SourceArt/RootStation/Forge/Proposals/V2/forge-workbay-v2.png",
    "Forge_BenchFront": "SourceArt/RootStation/Forge/Proposals/V1/FG01_Workbench_Front.png",
    "Forge_ToolRack": "SourceArt/RootStation/Forge/Issue58/FG02_Tool_Rack.png",
    "Forge_Toolbox": "SourceArt/RootStation/Forge/Issue58/FG03_Toolbox_Open.png",
    "Forge_Ingots": "SourceArt/RootStation/Forge/Issue58/FG04_Ingots.png",
    "Bar_Front": "SourceArt/RootStation/Bar/Prepared/Front.png",
    **{f"Bar_Bottle{i}": f"SourceArt/RootStation/Bar/Prepared/Bottle{i}.png" for i in range(4)},
    "CharactersRoom_Sofa": "SourceArt/RootStation/CharactersRoom/CR01_Community_Sofa_D.png",
    "CharactersRoom_Notice": "SourceArt/StationCards/T_Station_Prop_waiting_notice.png",
    "Research_Bookshelf": "SourceArt/StationCards/T_Station_Prop_research_bookshelf.png",
    "Research_RadioDesk": "SourceArt/StationCards/T_Station_Prop_research_desk.png",
    "Research_SampleShelves": "SourceArt/RootStation/Research/Proposals/V1/research-sample-cabinet-v1.png",
    "Research_Notes": "SourceArt/RootStation/Research/notes.png",
    "Dormitory_BedLinen": "SourceArt/RootStation/Dormitory/DM01_Bed_Linen_D.png",
    "Dormitory_PersonalPegs": "SourceArt/RootStation/Dormitory/DM02_Personal_Pegs_D.png",
    "Preparation_Backpack": "SourceArt/RootStation/Preparation/PR01_Expedition_Backpack_D.png",
    "Preparation_Crate": "SourceArt/StationCards/T_Station_Prop_depot_crate.png",
    "Preparation_Routes": "SourceArt/RootStation/Preparation/routes.png",
    "Preparation_Checklist": "SourceArt/RootStation/Preparation/checklist.png",
    "Terminal_Bench": "SourceArt/StationCards/T_Station_Prop_waiting_bench.png",
}


def station_cards() -> int:
    from PIL import Image
    count = 0
    for name, path in STATION_CARDS.items():
        src = REPO / path
        if not src.exists():
            print(f"  falta o card {path}")
            continue
        dst = PROTO / "art" / "station" / "cards" / f"{name}.webp"
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            image = Image.open(src).convert("RGBA")
            box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            if box:
                image = image.crop(box)
            scale = min(1.0, 1024.0 / max(image.width, image.height))
            image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.LANCZOS)
            image.save(dst, "WEBP", quality=90, method=4)
        count += 1
    return count


# Poses dos moradores na Estação (#80): trabalho por sala e sentado no banco da Cantina, com os pés e o topo da Unreal.
# Sentado: o contorno ocupa "seated" da altura de pé (FSeatPose.Scale); o pé mais baixo é a base.
STATION_POSES = {
    "hero_cao_bento_work": ("Forge/Poses/bento-repair-component-v1.png", 605, 1433, 17, 1.0),
    "hero_gato_nick_work": ("Depot/Poses/nick-inspect-equipment-v1.png", 610, 1289, 29, 1.0),
    "hero_sapo_iris_work": ("Research/Poses/iris-analyze-sample-v1.png", 750, 1268, 46, 1.0),
    "hero_coruja_vespera_work": ("Research/Poses/vespera-read-records-v1.png", 605, 1302, 25, 1.0),
    "hero_cao_bento_seat": ("CharactersRoom/Poses/bento-seat-v1.png", (47 + 1085) // 2, 1420, 55, 0.72),
    "hero_gato_nick_seat": ("CharactersRoom/Poses/nick-seat-v1.png", (73 + 1136) // 2, 1278, 56, 0.76),
    "hero_sapo_iris_seat": ("CharactersRoom/Poses/iris-seat-v1.png", (13 + 1079) // 2, 1372, 78, 0.70),
    "hero_coruja_vespera_seat": ("CharactersRoom/Poses/vespera-seat-v1.png", (58 + 1126) // 2, 1246, 55, 0.76),
}


def station_poses() -> int:
    import json
    from PIL import Image
    manifest = json.loads((REPO / "SourceArt/RootStation/Civilians/art-manifest.json").read_text(encoding="utf-8"))
    poses = dict(STATION_POSES)
    # Trabalho dos civis: a mesma tela e os mesmos pés do idle (a pose _Work_D da #71).
    for entry in manifest:
        name = entry["name"].lower()
        poses[f"civil_{name}_work"] = (f"Civilians/{entry['name']}/{name}-work-v1.png", entry["foot_px"][0], entry["foot_px"][1], entry["top_px"], 1.0)
    out = {}
    for pose_id, (path, foot_x, foot_y, top, seated) in poses.items():
        src = REPO / "SourceArt/RootStation" / path
        if not src.exists():
            print(f"  falta a pose {path}")
            continue
        dst = PROTO / "art" / "station" / "poses" / f"{pose_id}.webp"
        dst.parent.mkdir(parents=True, exist_ok=True)
        image = Image.open(src)
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            image.convert("RGBA").resize((image.width // 2, image.height // 2), Image.LANCZOS).save(dst, "WEBP", quality=90, method=4)
        out[pose_id] = {"file": f"res://art/station/poses/{pose_id}.webp", "canvas": [image.width // 2, image.height // 2],
                        "anchor": [foot_x // 2, foot_y // 2], "body_reference_pixels": round((foot_y - top) / seated / 2)}
    # Dormir (aprovadas pelo Lucas em 22/10/2026): deitados de cabeça à esquerda; a âncora é o meio do corpo no ponto em
    # que encosta no colchão, e o comprimento do corpo (o vão do alfa) vale a altura do herói.
    family = json.loads((REPO / "SourceArt/RootStation/Dormitory/Poses/sleep-family-manifest-v1.json").read_text(encoding="utf-8"))
    for entry in family["heroes"]:
        pose_id = f"{SLEEP_HEROES[entry['hero']]}_sleep"
        src = REPO / "SourceArt/RootStation/Dormitory/Poses" / entry["source"]
        dst = PROTO / "art" / "station" / "poses" / f"{pose_id}.webp"
        image = Image.open(src)
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            image.convert("RGBA").resize((image.width // 2, image.height // 2), Image.LANCZOS).save(dst, "WEBP", quality=90, method=4)
        x0, _top, x1, _bottom = entry["alpha_bounds_90"]
        out[pose_id] = {"file": f"res://art/station/poses/{pose_id}.webp", "canvas": [image.width // 2, image.height // 2],
                        "anchor": [(x0 + x1) // 4, entry["support_y_px"] // 2], "body_reference_pixels": (x1 - x0) // 2}
    target = PROTO / "data" / "presentation" / "station_poses.json"
    # A direção da pose sentada (#253): as de lado (a cantina, a fogueira) e as de frente (o banco encostado no fundo, o
    # vagão). As de frente não vêm da Unreal: foram pintadas aqui (docs/design/poses-frente.md), com o ponto hip que vai
    # no assento; ficam como estão no JSON, senão esta regravação as apagava em silêncio.
    for pose_id in out:
        if pose_id.endswith("_seat"):
            out[pose_id]["facing"] = "side"
    if target.exists():
        current = json.loads(target.read_text(encoding="utf-8"))
        for pose_id, entry in current.items():
            if entry.get("facing") == "front" and pose_id not in out:
                out[pose_id] = entry
    target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + chr(10), encoding="utf-8")
    return len(out)


SLEEP_HEROES = {"bento": "hero_cao_bento", "nick": "hero_gato_nick", "iris": "hero_sapo_iris", "vespera": "hero_coruja_vespera"}


def civilians() -> int:
    """Os civis do trem (#72): o idle na metade da resolução e as medidas do manifesto (pés, topo, retrato)."""
    import json
    from PIL import Image
    manifest = json.loads((REPO / "SourceArt/RootStation/Civilians/art-manifest.json").read_text(encoding="utf-8"))
    out = {}
    for entry in manifest:
        civilian_id = "civil_" + entry["name"].lower()
        src = REPO / entry["source"]
        dst = PROTO / "art" / "civilians" / f"{civilian_id}.webp"
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            image = Image.open(src).convert("RGBA")
            image.resize((image.width // 2, image.height // 2), Image.LANCZOS).save(dst, "WEBP", quality=90, method=4)
        width, height = entry["size"]
        out[civilian_id] = {
            "file": f"res://art/civilians/{civilian_id}.webp", "canvas": [width // 2, height // 2],
            "anchor": [entry["foot_px"][0] // 2, entry["foot_px"][1] // 2],
            "body_reference_pixels": (entry["foot_px"][1] - entry["top_px"]) // 2,
            "portrait_uv": entry["portrait_uv"],
        }
    target = PROTO / "data" / "presentation" / "civilians.json"
    target.write_text(json.dumps(out, ensure_ascii=False, indent=2) + chr(10), encoding="utf-8")
    return len(out)


# Mapa de fases (UAHExpeditionMapWidget): o bairro alagado da web, a imagem de cada fase e os ícones dos nós e da
# Mochila.
MAP_ICONS = ["node-start", "node-combat", "node-boss", "node-rest", "marker-here", "marker-visited", "marker-available",
             "ui-arrow-right",
             # Mochila (UAHInventoryWidget): suprimentos, ferramentas, recursos e relíquias.
             "lobby-food", "res-bandages", "item-ampoule", "tool-crowbar", "tool-flashlight", "tool-mask", "tool-generic",
             "lobby-seed", "lobby-scrap", "lobby-fragment", "item-generic", "relic-generic", "relic-copper-button",
             "relic-glass-feather", "relic-memory-collar",
             # HUD da exploração: os trechos da rota e a esperança.
             "node-loot", "node-event", "res-hope", "lobby-energy", "lobby-water", "lobby-settings"]


def phase_map() -> int:
    from PIL import Image
    out = PROTO / "art" / "ui"
    jobs = [(REPO / "SourceArt/Legacy/public/ui/flooded-railway-map.png", out / "map" / "flooded-railway-map.webp", 1.0)]
    for src in sorted((REPO / "SourceArt/Legacy/assets/scenarios").glob("*.png")):
        jobs.append((src, out / "scenarios" / f"{src.stem}.webp", 0.5))
    for src, dst, scale in jobs:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
            image = Image.open(src).convert("RGB")
            image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS).save(dst, "WEBP", quality=88, method=4)
    for name in MAP_ICONS:
        copy(REPO / "Content/AfterHumans/UI/Icons" / f"{name}.svg", out / "icons" / f"{name}.svg")
    return len(jobs) + len(MAP_ICONS)


# Fontes da interface (as da Unreal, OFL): Plus Jakarta Sans no texto e Cinzel nos títulos, com as licenças.
FONTS = ["plus-jakarta-sans-latin-400-normal.ttf", "plus-jakarta-sans-latin-700-normal.ttf", "cinzel-latin-600-normal.ttf",
         "cinzel-latin-700-normal.ttf", "OFL-PlusJakartaSans.txt", "OFL-Cinzel.txt"]


def fonts() -> int:
    for name in FONTS:
        copy(REPO / "SourceArt/Fonts" / name, PROTO / "art" / "ui" / "fonts" / name)
    return len(FONTS)


def copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime or dst.stat().st_size != src.stat().st_size:
        shutil.copy2(src, dst)


def main() -> None:
    for src in DATA:
        if src.name not in GODOT_OWNED_DATA:
            copy(src, PROTO / "data" / src.name)
    for src in LEGACY_KITS:
        copy(src, PROTO / "data" / "legacy_kits" / src.name)

    street = PROTO / "art" / "street"
    street.mkdir(parents=True, exist_ok=True)
    for path in WEB_STREET:
        dst = street / Path(path).name
        if not dst.exists():
            dst.write_bytes(subprocess.run(["git", "show", f"{WEB_TAG}:{path}"], cwd=REPO, check=True, capture_output=True).stdout)
    for path in SOURCE_ART:
        copy(REPO / path, street / Path(path).name)
    print(f"dados: {len(DATA) + len(LEGACY_KITS)} arquivos; arte da rua: {len(WEB_STREET) + len(SOURCE_ART)} imagens; "
          f"interiores: {rooms()} imagens; estação: {station()} superfícies; civis: {civilians()}; modelos: {station_models()}; cards: {station_cards()}; poses: {station_poses()}; mapa de fases: {phase_map()}; fontes: {fonts()}")


if __name__ == "__main__":
    main()
