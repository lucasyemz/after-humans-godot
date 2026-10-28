"""Gera por síntese os sons que faltavam no jogo (#36): o sino e o freio do trem, abrir e fechar os painéis, a confirmação
da Forja, o achado raro da busca, a vitória e a derrota e a crise de instinto; e o trem andando na passagem do vagão
(#133), um laço sem emenda. Feitos aqui, do zero (osciladores e ruído),
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


def security_door():
    """A porta de segurança do Corredor de Contenção (#147) baixando: o chiado hidráulico e a batida de aço no chão."""
    rng = np.random.default_rng(147)
    t = time(1.5)
    hiss = bandpass(rng.standard_normal(t.size), 1500.0, 6000.0) * np.clip(t / 0.08, 0, 1) * np.clip((0.75 - t) / 0.2, 0, 1) * 0.35
    slide = np.sin(2 * np.pi * (90.0 + 25.0 * t) * t) * np.clip(t / 0.1, 0, 1) * np.clip((0.78 - t) / 0.1, 0, 1) * 0.25
    hit_t = np.clip(t - 0.78, 0, None)
    hit = (t >= 0.78) * (np.sin(2 * np.pi * 48.0 * hit_t) * 1.0 + np.sin(2 * np.pi * 131.0 * hit_t) * 0.5
                         + np.sin(2 * np.pi * 347.0 * hit_t) * 0.25) * np.exp(-hit_t * 5.5)
    clank = (t >= 0.78) * bandpass(rng.standard_normal(t.size), 400.0, 3000.0) * np.exp(-hit_t * 22.0) * 0.8
    return hiss + slide + hit + clank


def security_door_open():
    """A porta de segurança subindo (a zona vencida, #147): o chiado hidráulico e o motor que sobe, sem a batida."""
    rng = np.random.default_rng(1470)
    t = time(1.3)
    hiss = bandpass(rng.standard_normal(t.size), 1500.0, 6000.0) * np.clip(t / 0.05, 0, 1) * np.clip((0.4 - t) / 0.2, 0, 1) * 0.3
    motor = np.sin(2 * np.pi * (70.0 + 60.0 * t) * t) * np.clip(t / 0.15, 0, 1) * np.clip((1.3 - t) / 0.35, 0, 1) * 0.45
    whine = np.sin(2 * np.pi * (300.0 + 180.0 * t) * t) * np.clip(t / 0.3, 0, 1) * np.clip((1.3 - t) / 0.4, 0, 1) * 0.12
    stop_t = np.clip(t - 1.05, 0, None)
    stop = (t >= 1.05) * bandpass(rng.standard_normal(t.size), 300.0, 2500.0) * np.exp(-stop_t * 30.0) * 0.5
    return hiss + motor + whine + stop


def containment_loop():
    """O ambiente do Corredor de Contenção (#147): o zumbido da casa de máquinas e, ao fundo, o alarme da contenção
    (dois tons que sobem e descem a cada 4 s). 16 s que emendam: tudo tem período que divide a duração."""
    rng = np.random.default_rng(1147)
    seconds = 16.0
    t = time(seconds)
    hum = (np.sin(2 * np.pi * 50.0 * t) + 0.45 * np.sin(2 * np.pi * 100.0 * t) + 0.2 * np.sin(2 * np.pi * 150.0 * t)) * 0.35
    air = lowpass(rng.standard_normal(t.size), 400.0) * 0.6
    # O ruído emenda: o fim se funde ao começo em 0,5 s.
    fade = int(0.5 * RATE)
    air[:fade] = air[:fade] * np.linspace(0, 1, fade) + air[-fade:] * np.linspace(1, 0, fade)
    cycle = np.mod(t, 4.0)
    pitch = 620.0 + 180.0 * np.sin(np.pi * np.clip(cycle / 1.6, 0, 1))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    gate = np.clip(cycle / 0.05, 0, 1) * np.clip((1.6 - cycle) / 0.2, 0, 1)
    alarm = lowpass(np.sign(np.sin(phase)) * 0.5 + np.sin(phase) * 0.5, 2500.0) * gate * 0.22
    return hum + air + alarm


## O trem andando (#133): o "ta-dum" das rodas nas emendas dos trilhos (dois truques por vagão, a cada 1,25 s), o ronco
## grave do motor, que sobe e desce devagar, e o chiado das rodas. RIDE_SECONDS fecha um número inteiro de batidas e de
## ondas do ronco; o rabo do ruído entra misturado no começo, então o laço emenda sem estalo.
RIDE_SECONDS = 5.0
RIDE_BEAT = 1.25


def rail_click(seconds=0.18):
    t = time(seconds)
    knock = bandpass(RNG.standard_normal(t.size), 500.0, 2800.0) * np.exp(-t * 38.0)
    thump = np.sin(2 * np.pi * 72.0 * t) * np.exp(-t * 22.0)
    return knock * 0.9 + thump * 0.8


def train_ride():
    size = int(RIDE_SECONDS * RATE)
    tail = int(0.6 * RATE)
    total = (size + tail) / RATE
    t = np.arange(size + tail) / RATE
    out = np.zeros_like(t)
    beat = 0.0
    while beat < total:
        for offset, gain in ((0.0, 1.0), (0.11, 0.8), (0.46, 0.85), (0.57, 0.7)):
            place(out, rail_click() * gain, beat + offset)
        beat += RIDE_BEAT
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t / RIDE_SECONDS)
    motor = (np.sin(2 * np.pi * 46.0 * t) + 0.45 * np.sin(2 * np.pi * 92.0 * t) + 0.2 * np.sin(2 * np.pi * 138.0 * t)) * 0.35
    rumble = lowpass(RNG.standard_normal(t.size), 160.0) * 3.0
    hiss = bandpass(RNG.standard_normal(t.size), 400.0, 1800.0) * 0.25
    out += (motor + rumble) * swell + hiss
    loop = out[:size].copy()
    ramp = np.linspace(0.0, 1.0, tail)
    loop[:tail] = loop[:tail] * ramp + out[size:size + tail] * (1.0 - ramp)
    return loop


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
    "world/security_door": security_door,
    "world/security_door_open": security_door_open,
    "ambience/ContainmentCorridor": containment_loop,
    "station/train_ride": train_ride,
}
## Os laços: sem a saída suave do fim (o fim emenda com o começo).
LOOPED = {"station/train_ride"}


def write(stem, signal):
    signal = signal.copy()
    # 25 ms de saída suave: nenhum som termina com sinal ainda tocando (o "tum" no fim da crise). O laço não: o fim
    # emenda com o começo.
    if stem not in LOOPED:
        fade = int(0.025 * RATE)
        signal[-fade:] *= np.linspace(1.0, 0.0, fade)
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
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "1", str(target)], check=True)
    print(f"{target.relative_to(PROTO)}: {signal.size / RATE:.2f} s")


if __name__ == "__main__":
    import sys
    # Com nomes (python tools/synth_sounds.py world/security_door), só esses.
    wanted = sys.argv[1:]
    for stem, make in SOUNDS.items():
        if not wanted or stem in wanted:
            write(stem, make())
