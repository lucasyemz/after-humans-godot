"""Gera por síntese um som para cada habilidade de cada inimigo, ligado ao que a arte dele mostra: o servo e o soco do
Robô, os rotores e o spray do Drone de Expurgo, a catraca da Sentinela, a serra do Demolidor, a risada de fita do
Recreador, a buzina de pato do Pipoco, a madeira das raízes do Enraizado. Feitos aqui, do zero (osciladores e ruído),
são de domínio público (CC0), como os de tools/synth_sounds.py.

Cada som sai em audio/combat/enemies/<inimigo>/<ação>.wav (mono, 32 kHz, -13 LUFS, pico até -3 dBFS) e entra na
tabela de mixagem (data/presentation/audio_mix.json) com o volume medido aqui, sem precisar do ffmpeg. A Godot importa
em QOA. A luta toca o som pela ação do inimigo (combat_arena._play_enemy_cue); sem arquivo, cai no soco ou na cura de
robô de antes. Precisa só do numpy:
  python tools/synth_enemy_sounds.py
"""
import json
import wave
from pathlib import Path

import numpy as np

PROTO = Path(__file__).resolve().parents[1]
OUT = PROTO / "audio" / "combat" / "enemies"
MIX = PROTO / "data" / "presentation" / "audio_mix.json"
TARGET_LUFS = -13.0
RATE = 32000
RNG = np.random.default_rng(20261026)


# ---------------------------------------------------------------- blocos

def t_(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return RNG.uniform(-1.0, 1.0, int(seconds * RATE))


def lowpass(signal, cutoff, poles=2):
    """Passa-baixa de polos em série (dois por padrão: o ruído não fica chiado); o corte pode variar no tempo."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cut / RATE)
    out = np.asarray(signal, dtype=float)
    for _ in range(poles):
        source = out
        out = np.empty_like(source)
        level = 0.0
        for i in range(source.size):
            level += alpha[i] * (source[i] - level)
            out[i] = level
    return out


def bandpass(signal, low, high):
    return lowpass(signal, high) - lowpass(signal, low)


def env(seconds, attack=0.005, decay=6.0):
    t = t_(seconds)
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t * decay)


def sweep(f0, f1, seconds, wave_shape="sine"):
    """Oscilador que desliza de f0 a f1 (exponencial)."""
    t = t_(seconds)
    freq = f0 * (f1 / f0) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if wave_shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    if wave_shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def place(total, clip, at):
    """Soma clip em total a partir de at segundos (corta o que passar do fim)."""
    start = int(at * RATE)
    end = min(total.size, start + clip.size)
    if start < total.size:
        total[start:end] += clip[: end - start]
    return total


def silence(seconds):
    return np.zeros(int(seconds * RATE))


def clank(freq=420, seconds=0.5, decay=9.0, partials=((1.0, 1.0), (2.41, 0.6), (3.87, 0.4), (5.9, 0.25))):
    """Pancada de metal: parciais inarmônicas e um estalo de ruído no começo."""
    t = t_(seconds)
    out = np.zeros_like(t)
    for ratio, gain in partials:
        out += gain * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * (0.7 + ratio * 0.3))
    hit = bandpass(noise(seconds), 800, 6000) * env(seconds, 0.001, 60)
    return out * 0.7 + hit


def thud(freq=70, seconds=0.5, decay=8.0):
    """Baque grave: um seno que cai de tom com um sopro de ruído."""
    body = sweep(freq * 2.2, freq, seconds) * env(seconds, 0.002, decay)
    air = lowpass(noise(seconds), 400) * env(seconds, 0.001, 25)
    return body + air * 0.8


def servo(f0, f1, seconds, grit=0.25):
    """Motor elétrico: serra filtrada que sobe ou desce, com zumbido."""
    s = lowpass(sweep(f0, f1, seconds, "saw"), 2200) * 0.6
    s += np.sin(2 * np.pi * 50 * t_(seconds)) * 0.15
    s += bandpass(noise(seconds), 1500, 4000) * grit
    return s * np.minimum(1, t_(seconds) / 0.04) * np.minimum(1, (seconds - t_(seconds)) / 0.06)


def zap(seconds=0.45, density=0.5):
    """Descarga elétrica: estalos de ruído em rajadas e um zumbido de 120 Hz."""
    n = noise(seconds)
    gate = (RNG.uniform(0, 1, n.size // 64 + 1) < density).repeat(64)[: n.size]
    crackle = bandpass(n, 1200, 9000) * gate
    buzz = np.sign(np.sin(2 * np.pi * 120 * t_(seconds))) * 0.25
    return (crackle + lowpass(buzz, 1500)) * env(seconds, 0.002, 4.5)


def hiss(seconds, low=1500, high=8000, attack=0.03, decay=2.5):
    return bandpass(noise(seconds), low, high) * env(seconds, attack, decay)


def clicks(count, spacing, freq=2500, decay=180, start=0.0, total=None):
    """Catraca: estalos curtos e regulares."""
    total = silence(total if total else start + count * spacing + 0.1)
    one = bandpass(noise(0.03), freq * 0.6, freq * 1.8) * env(0.03, 0.0005, decay)
    one += np.sin(2 * np.pi * freq * 0.5 * t_(0.03)) * env(0.03, 0.0005, decay) * 0.4
    for i in range(count):
        place(total, one, start + i * spacing)
    return total


def honk(freq, seconds, nasal=0.6):
    """Buzina de brinquedo: onda quadrada com formante nasal e vibrato."""
    t = t_(seconds)
    vib = 1 + 0.03 * np.sin(2 * np.pi * 7 * t)
    phase = 2 * np.pi * np.cumsum(freq * vib) / RATE
    sq = np.sign(np.sin(phase)) * 0.5 + np.sin(phase * 2) * 0.3
    return bandpass(sq, 500, 2400 + nasal * 1000) * env(seconds, 0.01, 3.0)


def laugh_syllable(pitch, seconds=0.16):
    """Um "ha" de fita: pulso glotal filtrado nos formantes do "a"."""
    t = t_(seconds)
    pulse = sweep(pitch, pitch * 0.85, seconds, "saw")
    vowel = bandpass(pulse, 600, 1300) + bandpass(pulse, 1100, 1500) * 0.5
    breath = bandpass(noise(seconds), 900, 3000) * 0.25
    shape = np.sin(np.pi * np.minimum(1, t / seconds)) ** 0.7
    return (vowel + breath) * shape


def tape(signal, wobble=0.012, rate=3.5):
    """Fita velha: o tom oscila (wow) e as altas somem."""
    t = np.arange(signal.size) / RATE
    idx = np.arange(signal.size) + wobble * RATE * np.sin(2 * np.pi * rate * t) / (2 * np.pi * rate)
    idx = np.clip(idx, 0, signal.size - 1)
    return lowpass(np.interp(idx, np.arange(signal.size), signal), 3200)


def wet(signal, amount=0.6):
    """Fungo e umidade: abafa e junta um chiado molhado."""
    squelch = bandpass(noise(signal.size / RATE), 200, 900) * np.abs(lowpass(noise(signal.size / RATE), 12)) * 6
    return lowpass(signal, 1400) * (1 - amount * 0.3) + squelch * amount * 0.5


def echo(signal, delay=0.12, feedback=0.35, taps=4):
    out = np.concatenate([signal, silence(delay * taps + 0.05)])
    for k in range(1, taps + 1):
        place(out, signal * feedback ** k, delay * k)
    return out


def creak(seconds, f0=90, f1=140):
    """Madeira rangendo: pulsos irregulares de baixo tom."""
    t = t_(seconds)
    freq = f0 + (f1 - f0) * (t / seconds) + 15 * np.sin(2 * np.pi * 3 * t)
    phase = np.cumsum(freq) / RATE
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    grain = lowpass(pulses * RNG.uniform(0.5, 1.0, t.size), 1800)
    return bandpass(grain, 150, 2500) * 4 * np.minimum(1, t / 0.05) * np.minimum(1, (seconds - t) / 0.08)


def swoosh(seconds, low=400, high=3000):
    """Corte de ar (chicote, galho, bastão): ruído com o filtro que sobe e desce."""
    t = t_(seconds)
    cut = low + (high - low) * np.sin(np.pi * t / seconds) ** 2
    return lowpass(noise(seconds), cut) * np.sin(np.pi * t / seconds) ** 2


def rotor(seconds, f0=95, f1=95, blades=3):
    """Rotores de drone: zumbido com batida das pás."""
    t = t_(seconds)
    freq = f0 * (f1 / f0) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    buzz = lowpass(2 * ((phase * blades / (2 * np.pi)) % 1.0) - 1, 900)
    chop = 0.6 + 0.4 * np.sin(phase)
    return (buzz * chop + bandpass(noise(seconds), 2000, 6000) * 0.15) * np.minimum(1, t / 0.08)


def mix(*parts):
    size = max(p.size for p in parts)
    out = silence(size / RATE)
    for p in parts:
        out[: p.size] += p
    return out


# ---------------------------------------------------------------- os inimigos

def robot_golpe(fungal=False):
    s = silence(0.7)
    place(s, servo(180, 420, 0.22), 0.0)
    place(s, mix(clank(380, 0.45) * 0.9, thud(90, 0.4) * 0.7), 0.2)
    return wet(s) if fungal else s


def robot_descarga(fungal=False):
    s = silence(0.7)
    place(s, sweep(300, 1800, 0.18) * env(0.18, 0.01, 2) * 0.3, 0.0)
    place(s, zap(0.5), 0.15)
    return wet(s, 0.45) if fungal else s


def robot_blindagem(fungal=False):
    s = silence(0.6)
    place(s, clank(260, 0.3, 14) * 0.8, 0.0)
    place(s, clicks(4, 0.04, 1800), 0.12)
    place(s, clank(310, 0.35, 12) * 0.9, 0.3)
    return wet(s) if fungal else s


def robot_avanco(fungal=False):
    s = silence(0.9)
    place(s, clicks(6, 0.07, 2200), 0.0)
    place(s, sweep(220, 660, 0.5) * env(0.5, 0.05, 1.2) * 0.35, 0.35)
    return wet(s, 0.5) if fungal else s


def vigia_golpe():
    s = silence(0.8)
    place(s, swoosh(0.22, 300, 2400) * 0.8, 0.0)
    place(s, mix(clank(520, 0.6, 6, ((1, 1), (2.76, 0.5), (5.4, 0.3))), thud(80, 0.35) * 0.6), 0.2)
    return s


def vigia_defender():
    s = silence(0.8)
    place(s, clicks(3, 0.09, 1500, 120), 0.0)
    place(s, clank(220, 0.4, 10) * 0.9, 0.3)
    place(s, sweep(1400, 1400, 0.12) * env(0.12, 0.003, 10) * 0.25, 0.55)  # o visor confere a credencial
    return s


def vigia_avanco():
    s = silence(1.0)
    place(s, thud(55, 0.45, 7), 0.0)
    place(s, hiss(0.25, 2500, 7000, 0.005, 9) * 0.35, 0.05)
    place(s, thud(50, 0.5, 6), 0.45)
    return s


def cao_mordida():
    s = silence(0.8)
    for i in range(2):
        place(s, sweep(2400, 2400, 0.06) * env(0.06, 0.002, 30) * 0.3, i * 0.09)  # o sensor vermelho
    place(s, clank(900, 0.25, 22, ((1, 1), (1.6, 0.7), (3.1, 0.4))) * 1.1, 0.22)  # a mandíbula fecha
    place(s, bandpass(noise(0.3), 800, 3000) * env(0.3, 0.01, 8) * 0.4, 0.3)
    return s


def cao_avanco():
    s = silence(0.8)
    for i, at in enumerate([0.0, 0.08, 0.2, 0.28, 0.4, 0.48]):
        place(s, clank(1100 + 80 * (i % 2), 0.08, 50) * 0.5, at)
    place(s, servo(300, 500, 0.6, 0.1) * 0.3, 0.0)
    return s


def ninho_spray():
    s = silence(1.0)
    place(s, rotor(1.0, 110, 120) * 0.35, 0.0)
    place(s, hiss(0.7, 1200, 9000, 0.02, 2.2) * 0.9, 0.12)
    place(s, bandpass(noise(0.08), 200, 900) * env(0.08, 0.001, 40) * 0.7, 0.1)  # a válvula abre
    return s


def ninho_recuo():
    return rotor(0.9, 90, 170) * np.minimum(1, (0.9 - t_(0.9)) / 0.3) * 0.9


def sussurrador_ordem():
    s = silence(1.3)
    tone_a = honk(620, 0.32, 0.2)
    tone_b = honk(470, 0.32, 0.2)
    for i in range(2):
        place(s, tone_a, i * 0.62)
        place(s, tone_b, i * 0.62 + 0.31)
    s = bandpass(np.tanh(s * 3), 300, 3200)  # o alto-falante rasgado
    place(s, bandpass(noise(1.3), 1000, 5000) * 0.08, 0.0)  # a estática
    return echo(s, 0.16, 0.3, 3)


def sussurrador_antena():
    s = silence(0.9)
    place(s, servo(400, 250, 0.4, 0.1) * 0.5, 0.0)
    place(s, bandpass(noise(0.6), 1500, 6000) * np.abs(np.sin(2 * np.pi * 9 * t_(0.6))) * 0.4, 0.2)
    place(s, lowpass(noise(0.7), 300) * 0.5 * env(0.7, 0.05, 2.5), 0.15)  # as rodinhas
    return s


def rastejante_laco():
    s = silence(0.8)
    place(s, servo(800, 1600, 0.25, 0.05) * 0.4, 0.0)  # o carretel solta
    place(s, swoosh(0.16, 600, 5000) * 0.7, 0.18)
    crack = bandpass(noise(0.05), 2000, 9000) * env(0.05, 0.0005, 90) * 1.4
    place(s, crack, 0.33)
    place(s, clank(700, 0.25, 18) * 0.4, 0.36)
    return s


def rastejante_tracao():
    s = silence(1.0)
    place(s, clicks(10, 0.06, 1700, 160), 0.0)
    place(s, lowpass(noise(0.9), 700) * env(0.9, 0.1, 1.8) * 0.6, 0.05)  # o chassi arrastando
    return s


def carcaca_jato():
    s = silence(1.1)
    gurgle = lowpass(noise(0.4), 300) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t_(0.4))))
    place(s, gurgle * 0.8, 0.0)
    place(s, thud(60, 0.3, 10) * 0.7, 0.35)
    place(s, bandpass(noise(0.6), 300, 2500) * env(0.6, 0.01, 3.5), 0.38)  # o jato
    place(s, wet(bandpass(noise(0.4), 200, 800) * env(0.4, 0.05, 4), 1.0) * 0.6, 0.6)
    return s


def carcaca_esteira():
    s = silence(1.2)
    t = t_(1.2)
    chug = lowpass(noise(1.2), 220) * (0.4 + 0.6 * (np.sin(2 * np.pi * 7 * t) > 0.3))
    place(s, chug * 0.9, 0.0)
    place(s, clicks(12, 0.09, 900, 90) * 0.5, 0.05)  # as esteiras
    return s * np.minimum(1, (1.2 - t) / 0.2)


def condutor_arco():
    s = silence(1.0)
    place(s, sweep(200, 3200, 0.4) * env(0.4, 0.2, 0.3) * 0.25, 0.0)  # a bobina carregando
    place(s, bandpass(noise(0.06), 500, 9000) * env(0.06, 0.0005, 50) * 1.6, 0.4)  # o arco
    place(s, zap(0.5, 0.7) * 0.9, 0.42)
    return s


def porteiro_prensa():
    s = silence(1.4)
    place(s, servo(80, 160, 0.45, 0.05) * 0.4, 0.0)
    place(s, hiss(0.35, 1500, 6000, 0.1, 1) * 0.3, 0.1)
    slam = thud(45, 0.9, 4) * 1.2 + clank(160, 0.9, 4, ((1, 1), (2.1, 0.6), (3.3, 0.4))) * 0.6
    place(s, echo(slam, 0.18, 0.25, 2), 0.45)
    return s


def porteiro_sirene():
    s = silence(1.6)
    for i in range(2):
        place(s, lowpass(sweep(180, 180, 0.38, "square"), 900) * env(0.38, 0.03, 0.8) * 0.8, i * 0.6)
        place(s, lowpass(sweep(240, 240, 0.38, "square"), 900) * env(0.38, 0.03, 0.8) * 0.8, i * 0.6 + 0.3)
    return echo(s, 0.22, 0.3, 3)


def porteiro_esmagamento():
    s = silence(1.4)
    grind = bandpass(noise(0.5), 300, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t_(0.5))) * 0.6
    place(s, grind, 0.0)
    crunch = mix(thud(40, 0.9, 4) * 1.3, clank(130, 0.7, 5) * 0.7, bandpass(noise(0.3), 400, 4000) * env(0.3, 0.001, 9))
    place(s, echo(crunch, 0.2, 0.25, 2), 0.42)
    return s


def porteiro_expulsao():
    s = silence(1.2)
    place(s, hiss(0.5, 800, 7000, 0.005, 3) * 1.0, 0.1)
    place(s, thud(55, 0.7, 5) * 1.1, 0.12)
    place(s, servo(120, 60, 0.4, 0.05) * 0.3, 0.6)
    return s


def carrasco_corte():
    s = silence(1.1)
    place(s, servo(300, 1900, 0.4, 0.15) * 0.6, 0.0)  # a serra acelera
    t = t_(0.6)
    cut = lowpass(sweep(1900, 1500, 0.6, "saw"), 4000) * (0.7 + 0.3 * np.sin(2 * np.pi * 30 * t))
    cut += bandpass(noise(0.6), 2500, 9000) * 0.6  # as fagulhas
    place(s, cut * env(0.6, 0.01, 2.5), 0.4)
    return s


def faisca_serrada():
    s = silence(0.6)
    place(s, servo(900, 3200, 0.2, 0.2) * 0.5, 0.0)
    t = t_(0.3)
    place(s, (lowpass(sweep(3200, 2800, 0.3, "saw"), 6000) * 0.5 + bandpass(noise(0.3), 4000, 10000) * 0.6)
          * env(0.3, 0.01, 6), 0.18)
    return s


def recreador_pega():
    s = silence(0.7)
    place(s, honk(880, 0.12, 1.0) * 0.6, 0.0)  # o apito da festa
    place(s, sweep(300, 900, 0.18) * env(0.18, 0.005, 6) * 0.5, 0.12)  # a mola
    place(s, bandpass(noise(0.06), 600, 4000) * env(0.06, 0.0005, 70) * 1.2, 0.3)  # o tapa
    return s


def recreador_risada():
    s = silence(1.4)
    for i, pitch in enumerate([230, 215, 205, 195, 185, 170]):
        place(s, laugh_syllable(pitch), 0.05 + i * 0.19)
    return tape(s, 0.02, 2.8) + bandpass(noise(1.4), 2000, 6000) * 0.04


def pipoco_buzina():
    s = silence(1.1)
    place(s, clicks(5, 0.05, 1300, 150) * 0.6, 0.0)  # a chave de dar corda
    place(s, honk(520, 0.22), 0.3)
    place(s, honk(560, 0.28), 0.56)
    for at in RNG.uniform(0.35, 1.0, 6):  # pipoca estourando
        place(s, bandpass(noise(0.02), 1500, 6000) * env(0.02, 0.0005, 200) * 0.5, at)
    return s


def enraizado_acoite():
    s = silence(1.0)
    place(s, creak(0.35, 80, 120) * 0.7, 0.0)
    place(s, swoosh(0.22, 300, 2500) * 0.8, 0.3)
    place(s, bandpass(noise(0.08), 700, 3500) * env(0.08, 0.001, 50) * 1.0, 0.5)  # o galho estala
    place(s, bandpass(noise(0.35), 2500, 8000) * env(0.35, 0.02, 7) * 0.3, 0.52)  # as folhas
    return s


def broto_ataque():
    s = silence(0.6)
    place(s, servo(600, 900, 0.12, 0.1) * 0.25, 0.0)
    place(s, creak(0.18, 160, 220) * 0.5, 0.05)
    place(s, mix(clank(600, 0.15, 30, ((1, 1), (2.3, 0.4))) * 0.4, bandpass(noise(0.05), 800, 3000) * env(0.05, 0.0005, 80)), 0.2)
    place(s, bandpass(noise(0.25), 3000, 8000) * env(0.25, 0.02, 9) * 0.25, 0.22)
    return s


SOUNDS = {
    "robot/robot_golpe": robot_golpe,
    "robot/robot_descarga": robot_descarga,
    "robot/robot_blindagem": robot_blindagem,
    "robot/robot_avanco": robot_avanco,
    "robot_fungo/robot_golpe": lambda: robot_golpe(True),
    "robot_fungo/robot_descarga": lambda: robot_descarga(True),
    "robot_fungo/robot_blindagem": lambda: robot_blindagem(True),
    "robot_fungo/robot_avanco": lambda: robot_avanco(True),
    "vigia_enferrujado/golpe_vigia": vigia_golpe,
    "vigia_enferrujado/defender_vigia": vigia_defender,
    "vigia_enferrujado/avanco_pesado": vigia_avanco,
    "cao_eco/mordida_ferrugem": cao_mordida,
    "cao_eco/avancar_matilha": cao_avanco,
    "ninho_errante/esporo_contaminante": ninho_spray,
    "ninho_errante/recuo_fumegante": ninho_recuo,
    "sussurrador/voz_do_eco": sussurrador_ordem,
    "sussurrador/deslizar_sombra": sussurrador_antena,
    "rastejante_raiz/lufada_chicote": rastejante_laco,
    "rastejante_raiz/esgueirar_frente": rastejante_tracao,
    "carcaca_colonizada/esmagamento_fungico": carcaca_jato,
    "carcaca_colonizada/avanco_lento": carcaca_esteira,
    "condutor_raiz/descarga_raiz": condutor_arco,
    "porteiro/porteiro_golpe_escotilha": porteiro_prensa,
    "porteiro/porteiro_sirene": porteiro_sirene,
    "porteiro/porteiro_esmagamento_brutal": porteiro_esmagamento,
    "porteiro/porteiro_impacto_hidraulico": porteiro_expulsao,
    "carrasco_industrial/corte_demolicao": carrasco_corte,
    "faisca/serrada_curta": faisca_serrada,
    "recreador/pega_pega": recreador_pega,
    "recreador/risada_gravada": recreador_risada,
    "pipoco/buzina_irritante": pipoco_buzina,
    "enraizado/golpe_provisorio": enraizado_acoite,
    "broto/ataque_basico": broto_ataque,
}


def write(stem, signal):
    fade = int(0.025 * RATE)
    signal = np.nan_to_num(signal.astype(float))
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    # O mesmo volume para todos (-13 LUFS, no nível dos sons de robô de antes), sem passar do pico de -3 dBFS.
    peak = np.max(np.abs(signal))
    level = lufs(signal)
    if peak > 0 and level is not None:
        signal = signal * min((10 ** (-3.0 / 20.0)) / peak, 10 ** ((TARGET_LUFS - level) / 20.0))
    target = OUT / f"{stem}.wav"
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((signal * 32767).astype("<i2").tobytes())
    level = lufs(signal)
    print(f"{target.relative_to(PROTO)}: {signal.size / RATE:.2f} s, {level} LUFS")
    return level


def _biquad(x, b, a):
    out = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, value in enumerate(x):
        y = b[0] * value + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, value, y1, y
        out[i] = y
    return out


def lufs(signal):
    """Volume integrado (ITU-R BS.1770: o filtro K e os blocos de 400 ms com as duas portas), como o ffmpeg mede em
    tools/measure_audio.py. Som curto é repetido até 3 s, do mesmo jeito."""
    x = np.tile(signal, int(3.0 * RATE / signal.size) + 1) if signal.size < 0.6 * RATE else signal
    # O filtro K na taxa do arquivo (as fórmulas da BS.1770 para qualquer taxa).
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / RATE)
    vh, vb = 10 ** (gain / 20), 10 ** (gain / 20) ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf_b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    shelf_a = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / RATE)
    high_b = [1.0, -2.0, 1.0]
    high_a = [1.0, 2 * (k * k - 1) / (1 + k / q + k * k), (1 - k / q + k * k) / (1 + k / q + k * k)]
    y = _biquad(_biquad(x, shelf_b, shelf_a), high_b, high_a)
    block, step = int(0.4 * RATE), int(0.1 * RATE)
    powers = np.array([np.mean(y[i:i + block] ** 2) for i in range(0, y.size - block + 1, step)])
    loud = -0.691 + 10 * np.log10(np.maximum(powers, 1e-12))
    gated = powers[loud > -70]
    if gated.size == 0:
        return None
    relative = -0.691 + 10 * np.log10(np.mean(gated)) - 10
    final = gated[(-0.691 + 10 * np.log10(gated)) > relative]
    return round(float(-0.691 + 10 * np.log10(np.mean(final))), 1)


def update_mix(levels):
    """Os sons gerados entram na tabela de mixagem como os outros efeitos da luta: medidos, sem ganho extra."""
    table = json.loads(MIX.read_text(encoding="utf-8"))
    for stem, level in levels.items():
        table["files"][f"res://audio/combat/enemies/{stem}.wav"] = {"category": "sfx", "lufs": level, "gain_db": 0.0,
                                                                  "normalized": False}
    table["files"] = dict(sorted(table["files"].items()))
    MIX.write_bytes((json.dumps(table, indent="\t", ensure_ascii=False) + "\n").encode("utf-8"))
    print(f"{MIX.relative_to(PROTO)}: {len(levels)} sons dos inimigos")


if __name__ == "__main__":
    update_mix({stem: write(stem, make()) for stem, make in SOUNDS.items()})
