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


def copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime or dst.stat().st_size != src.stat().st_size:
        shutil.copy2(src, dst)


def main() -> None:
    for src in DATA:
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
          f"interiores: {rooms()} imagens")


if __name__ == "__main__":
    main()
