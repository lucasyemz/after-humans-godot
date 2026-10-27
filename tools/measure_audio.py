"""Mede o volume (LUFS integrado, EBU R128, pelo ffmpeg) de cada som de audio/ e grava a tabela de mixagem
data/presentation/audio_mix.json (#36). A música e os ambientes (os loops das cenas) e os sons gerados por
tools/synth_sounds.py são levados ao alvo da categoria: o ganho de cada arquivo (gain_db) é o que falta para chegar lá,
e o AHSound (Sound) aplica esse ganho por baixo do ganho de cada cena. A interface toda (audio/ui) também vai ao alvo
dela: um erro não pode soar mais alto que uma conquista. Os efeitos do mundo e da luta só são medidos (gain_db 0),
para a tabela de docs/audio.md; mexer neles muda o peso de cada golpe, que foi acertado jogando.
  python tools/measure_audio.py
"""
import json
import re
import subprocess
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
AUDIO = PROTO / "audio"
TABLE = PROTO / "data/presentation/audio_mix.json"
## Alvos em LUFS: a música e o ambiente iguais entre as cenas; os efeitos novos no nível dos que já existem.
TARGETS = {"music": -18.0, "ambience": -26.0, "sfx": -20.0, "ui": -24.0}
## Os sons de tools/synth_sounds.py (vão ao alvo da categoria deles).
SYNTH = {"station/train_bell", "station/train_brake", "ui/panel_open", "ui/panel_close", "ui/forge_confirm",
         "world/find_rare", "ui/victory", "ui/defeat", "combat/crisis", "world/security_door",
         "world/security_door_open"}
LOOPS = {"station/hum_loop", "station/bar_fan_loop", "station/depot_tube_loop"}


def category(stem):
    if stem.startswith("music/"):
        return "music"
    if stem.startswith("ambience/") or stem in LOOPS:
        return "ambience"
    if stem.startswith("ui/"):
        return "ui"
    return "sfx"


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True).stdout.strip()
    return float(out) if out else 0.0


def lufs(path):
    """O integrado do EBU R128 mede em blocos de 400 ms: um som mais curto que 0,6 s é medido tocado em sequência
    (o mesmo som repetido até passar de 3 s), que dá o volume dele e não o do silêncio em volta."""
    repeat = []
    length = duration(path)
    if 0.0 < length < 0.6:
        repeat = ["-stream_loop", str(int(3.0 / length) + 1)]
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", *repeat, "-i", str(path), "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    found = re.findall(r"I:\s+(-?[0-9.]+|-inf) LUFS", out)
    if not found or found[-1] == "-inf" or float(found[-1]) <= -69.0:
        return None
    return float(found[-1])


def main():
    files = {}
    for path in sorted(AUDIO.rglob("*")):
        if path.suffix not in (".ogg", ".mp3", ".wav"):
            continue
        stem = str(path.relative_to(AUDIO).with_suffix(""))
        kind = category(stem)
        level = lufs(path)
        normalized = level is not None and (kind in ("music", "ambience", "ui") or stem in SYNTH)
        gain = round(TARGETS[kind] - level, 1) if normalized else 0.0
        files["res://audio/" + str(path.relative_to(AUDIO))] = {"category": kind, "lufs": level, "gain_db": gain, "normalized": normalized}
        print(f"{stem:40s} {kind:9s} {level if level is not None else '-inf':>7} LUFS  {gain:+5.1f} dB")
    TABLE.write_text(json.dumps({"targets": TARGETS, "files": files}, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{TABLE.relative_to(PROTO)}: {len(files)} sons")


if __name__ == "__main__":
    main()
