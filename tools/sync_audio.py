"""Traz da referência Unreal a trilha, os ambientes, a chuva, os passos e os sons da exploração, da Estação e da
interface (a mesma tabela do Tools/Unreal/import-sounds.py da #62), para audio/.

Os WAV viram OGG Vorbis (qualidade 0,45: a trilha e os loops cabem no pacote da web); MP3 e OGG são copiados como
vieram. Os sons do combate continuam no tools/sync_combat_art.py. Precisa do soundfile:  python -m pip install soundfile
  python tools/sync_audio.py
"""
import shutil
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
REPO = PROTO.parent
AUDIO = PROTO / "audio"
SYNTH = REPO / "SourceArt/Audio/Synth"
WORLD = SYNTH / "World"
KENNEY = REPO / "SourceArt/Audio/ThirdParty/Kenney"
OGA = REPO / "SourceArt/Audio/ThirdParty/OpenGameArt"
QUALITY = 0.45

# (fonte, destino em audio/ sem extensão)
SOUNDS = [
    (SYNTH / "SFX_UI_Click.wav", "ui/click"),
    (SYNTH / "SFX_UI_Confirm.wav", "ui/confirm"),
    (SYNTH / "SFX_UI_Deny.wav", "ui/deny"),
    (SYNTH / "SFX_UI_BagOpen.wav", "ui/bag_open"),
    (SYNTH / "AMB_Station_Hum_Loop.wav", "station/hum_loop"),
    (SYNTH / "AMB_Bar_Fan_Loop.wav", "station/bar_fan_loop"),
    (SYNTH / "AMB_Depot_Tube_Loop.wav", "station/depot_tube_loop"),
    (SYNTH / "SFX_Depot_Tube_Flicker.wav", "station/depot_tube_flicker"),
    (SYNTH / "SFX_Research_Monitor_Beep.wav", "station/research_beep"),
    (SYNTH / "SFX_Train_Arrival.wav", "station/train_arrival"),
    (SYNTH / "SFX_Train_Departure.wav", "station/train_departure"),
    (KENNEY / "rpg-audio/doorOpen_1.ogg", "world/door_open"),
    (KENNEY / "rpg-audio/doorClose_1.ogg", "world/door_close"),
    (KENNEY / "rpg-audio/cloth1.ogg", "world/search_cloth_1"),
    (KENNEY / "rpg-audio/cloth3.ogg", "world/search_cloth_2"),
    (KENNEY / "rpg-audio/metalClick.ogg", "world/prop_open"),
    (KENNEY / "rpg-audio/handleCoins.ogg", "world/find_coins"),
    (WORLD / "AMB_Rain_Outdoor_Loop.wav", "ambience/rain_outdoor"),
    (WORLD / "AMB_Rain_Indoor_Loop.wav", "ambience/rain_indoor"),
    # Exploração e refúgio: as faixas da OpenGameArt escolhidas pelo Lucas (20/10/2026); a Ponte tem a sua.
    (OGA / "tragic-ambient-main-menu/ambientmain_0.ogg", "music/explore_1"),
    (OGA / "soundscape-dust/Dust.mp3", "music/explore_2"),
    (OGA / "contemplation/Contemplation.mp3", "music/explore_3"),
    (OGA / "soundscape-find-nothing/Find Nothing.mp3", "music/explore_root_bridge"),
    (OGA / "determined-pursuit/determined_pursuit_loop.wav", "music/battle"),
    (OGA / "boss-battle/epic_boss_battle_loop.wav", "music/boss"),
]
for _scenario in ("ShopfrontStreet", "FloodedDepot", "SewerDucts", "RiverDock", "RootBridge", "TriageGate", "SealedShelter"):
    SOUNDS.append((WORLD / f"AMB_{_scenario}_Loop.wav", f"ambience/{_scenario}"))
for _k in range(5):
    SOUNDS.append((KENNEY / f"impact-sounds/footstep_concrete_{_k:03d}.ogg", f"world/footstep_concrete_{_k + 1}"))
    SOUNDS.append((KENNEY / f"impact-sounds/footstep_wood_{_k:03d}.ogg", f"world/footstep_wood_{_k + 1}"))
for _k in range(4):
    SOUNDS.append((WORLD / f"SFX_Footstep_Water_{_k + 1}.wav", f"world/footstep_water_{_k + 1}"))


def convert(src: Path, stem: str) -> Path:
    if src.suffix.lower() != ".wav":
        dst = AUDIO / f"{stem}{src.suffix.lower()}"
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dst)
        return dst
    import soundfile
    dst = AUDIO / f"{stem}.ogg"
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        # Em blocos: o libsndfile cai ao gravar Vorbis longo de uma vez.
        with soundfile.SoundFile(src) as reader, soundfile.SoundFile(dst, "w", reader.samplerate, reader.channels,
                                                                     format="OGG", subtype="VORBIS",
                                                                     compression_level=1.0 - QUALITY) as writer:
            for block in reader.blocks(blocksize=8192, dtype="float32", always_2d=True):
                writer.write(block)
    return dst


def main() -> None:
    total = 0
    for src, stem in SOUNDS:
        assert src.is_file(), src
        total += convert(src, stem).stat().st_size
    # A música de refúgio é a Contemplation, a mesma da exploração (Lucas, 20/10/2026): o jogo reusa explore_3.
    print(f"sons: {len(SOUNDS)}; {total / 1e6:.1f} MB em audio/ (fora o combate)")


if __name__ == "__main__":
    main()
