"""Gera por síntese os sons que faltavam no jogo (#36): o sino e o freio do trem, abrir e fechar os painéis, a confirmação
da Forja, o achado raro da busca, a vitória e a derrota e a crise de instinto. Feitos aqui, do zero (osciladores e ruído),
são de domínio público (CC0) e não dependem da referência Unreal. Cada um sai em OGG Vorbis em audio/ (mono, 44,1 kHz),
com o pico em -3 dBFS; o volume de cada um no jogo fica nas chamadas e na tabela de mixagem
(tools/measure_audio.py). Precisa do numpy e do ffmpeg (com libvorbis):
  python tools/synth_sounds.py
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

PROTO = Path(__file__).resolve().parents[1]
AUDIO = PROTO / "audio"
RATE = 44100
RNG = np.random.default_rng(20261022)


def time(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(signal, cutoff):
    """Passa-baixa de um polo (o suficiente para tirar o chiado do ruído e arredondar as ondas)."""
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    level = 0.0
    for i, value in enumerate(signal):
        level += alpha * (value - level)
        out[i] = level
    return out


def bandpass(signal, low, high):
    return lowpass(signal, high) - lowpass(signal, low)


def bell(freq, seconds, decay=2.2, partials=((1.0, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12))):
    """Sino: parciais inarmônicas, cada uma caindo mais rápido que a de baixo."""
    t = time(seconds)
    out = np.zeros_like(t)
    for ratio, gain in partials:
        out += gain * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * (0.6 + ratio * 0.4))
    attack = np.minimum(1.0, t / 0.004)
    return out * attack


def tone(freq, seconds, shape=0.35, attack=0.02, release=0.4):
    """Nota com harmônicos (uma serra arredondada) e envelope de ataque e soltura."""
    t = time(seconds)
    out = np.zeros_like(t)
    for n in range(1, 8):
        out += np.sin(2 * np.pi * freq * n * t) * (shape ** (n - 1)) / n
    env = np.minimum(1.0, t / attack) * np.clip((seconds - t) / release, 0.0, 1.0)
    return out * env


def place(total, clip, at):
    start = int(at * RATE)
    end = min(total.size, start + clip.size)
    total[start:end] += clip[: end - start]


def train_bell():
    out = np.zeros(int(2.4 * RATE))
    place(out, bell(659.25, 1.6), 0.0)
    place(out, bell(523.25, 1.8), 0.55)
    return out


def train_brake():
    t = time(2.2)
    noise = bandpass(RNG.standard_normal(t.size), 1400.0, 4200.0) * 0.6
    glide = 2300.0 - 700.0 * (t / t[-1])
    squeal = np.sin(2 * np.pi * np.cumsum(glide) / RATE) * (0.55 + 0.45 * np.sin(2 * np.pi * 11.0 * t))
    env = np.minimum(1.0, t / 0.15) * np.clip((t[-1] - t) / 0.6, 0.0, 1.0)
    rumble = lowpass(RNG.standard_normal(t.size), 180.0) * 2.5
    return (noise + 0.35 * squeal + rumble) * env


def panel(opening):
    t = time(0.2)
    sweep = (900.0 + 2600.0 * (t / t[-1])) if opening else (3200.0 - 2400.0 * (t / t[-1]))
    noise = RNG.standard_normal(t.size)
    swish = np.zeros_like(t)
    level = 0.0
    for i in range(t.size):
        alpha = 1.0 - np.exp(-2.0 * np.pi * sweep[i] / RATE)
        level += alpha * (noise[i] - level)
        swish[i] = level
    env = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 2
    tick = np.zeros_like(t)
    click_at = int((0.16 if opening else 0.02) * RATE)
    tick[click_at:click_at + 220] = np.sin(2 * np.pi * 1800.0 * time(220 / RATE)) * np.exp(-time(220 / RATE) * 60)
    return swish * env * 0.8 + tick * 0.5


def forge_confirm():
    t = time(1.2)
    clang = bell(420.0, 1.2, decay=3.0, partials=((1.0, 1.0), (2.41, 0.7), (3.93, 0.5), (5.12, 0.35), (6.8, 0.2)))
    hit = lowpass(RNG.standard_normal(t.size), 3000.0) * np.exp(-t * 40.0) * 1.5
    return clang + hit


def find_rare():
    out = np.zeros(int(1.6 * RATE))
    for k, freq in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        place(out, bell(freq, 1.1, decay=3.5) * (0.9 - 0.12 * k), 0.08 * k)
    sparkle = bandpass(RNG.standard_normal(out.size), 5000.0, 9000.0) * np.exp(-time(out.size / RATE) * 4.0) * 0.25
    return out + sparkle


def victory():
    out = np.zeros(int(2.0 * RATE))
    for k, freq in enumerate((261.63, 329.63, 392.0)):
        place(out, tone(freq, 0.5, release=0.2) * 0.6, 0.11 * k)
    for freq in (261.63, 329.63, 392.0, 523.25):
        place(out, tone(freq, 1.4, release=0.9) * 0.45, 0.42)
    return lowpass(out, 5000.0)


def defeat():
    out = np.zeros(int(2.4 * RATE))
    for k, freq in enumerate((196.0, 155.56, 130.81)):
        place(out, tone(freq, 0.9 if k < 2 else 1.6, shape=0.25, release=0.5) * 0.7, 0.42 * k)
    return lowpass(out, 2200.0)


def crisis():
    t = time(1.6)
    boom = np.sin(2 * np.pi * (55.0 + 30.0 * np.exp(-t * 8.0)) * t) * np.exp(-t * 2.2)
    swell = bandpass(RNG.standard_normal(t.size), 200.0, 1800.0) * np.clip(t / 0.9, 0, 1) ** 2 * np.clip((1.6 - t) / 0.35, 0, 1)
    whine = np.sin(2 * np.pi * (440.0 - 120.0 * t) * t) * 0.15 * np.exp(-t * 1.2)
    return boom * 1.2 + swell * 0.5 + whine


SOUNDS = {
    "station/train_bell": train_bell,
    "station/train_brake": train_brake,
    "ui/panel_open": lambda: panel(True),
    "ui/panel_close": lambda: panel(False),
    "ui/forge_confirm": forge_confirm,
    "world/find_rare": find_rare,
    "ui/victory": victory,
    "ui/defeat": defeat,
    "combat/crisis": crisis,
}


def write(stem, signal):
    peak = np.max(np.abs(signal))
    signal = signal / peak * (10 ** (-3.0 / 20.0)) if peak > 0 else signal
    target = AUDIO / f"{stem}.ogg"
    with tempfile.TemporaryDirectory() as folder:
        wav = Path(folder) / "sound.wav"
        with wave.open(str(wav), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes((signal * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(target)], check=True)
    print(f"{target.relative_to(PROTO)}: {signal.size / RATE:.2f} s")


if __name__ == "__main__":
    for stem, make in SOUNDS.items():
        write(stem, make())
