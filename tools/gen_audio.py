"""Placeholder sound generator for the project.

Run:  python tools/gen_audio.py
Writes 16-bit mono WAVs into res://audio/sfx/ and res://audio/bgm/ using only
the standard library (seeded, so reruns give identical files). Every file name
matches a SoundDef id in data/sound_bank.tres; replace a file with a real
recording of the same name (or point the SoundDef at a new stream) and the
game picks it up. Music loops are written to loop seamlessly; their .import
sets edit/loop_mode=2 (forward).
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "audio", "sfx")
BGM = os.path.join(ROOT, "audio", "bgm")
RATE = 22050


def write(path, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top * 32767
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-32767, min(32767, s * scale)))) for s in samples))


def n(seconds):
    return int(seconds * RATE)


def env(i, total, attack=0.005, curve=4.0):
    """Fast attack, exponential-ish decay to 0 at `total` samples."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * (1.0 - i / total) ** curve


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(phase * math.tau)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    raise ValueError(kind)


def tone(seconds, f0, f1=None, kind="sine", attack=0.004, curve=3.0, vib=0.0):
    """Pitch glides f0 -> f1 (exponential) under a decaying envelope."""
    total = n(seconds)
    f1 = f0 if f1 is None else f1
    out, phase = [], 0.0
    for i in range(total):
        k = i / total
        f = f0 * (f1 / f0) ** k
        if vib:
            f *= 1.0 + vib * math.sin(i / RATE * math.tau * 6.0)
        phase += f / RATE
        out.append(osc(kind, phase) * env(i, total, attack, curve))
    return out


def noise(seconds, curve=3.0, lowpass=0.5, seed=1, attack=0.002):
    rnd = random.Random(seed)
    total = n(seconds)
    out, y = [], 0.0
    for i in range(total):
        y += (rnd.uniform(-1.0, 1.0) - y) * lowpass
        out.append(y * env(i, total, attack, curve))
    return out


def mix(*parts, gains=None):
    length = max(len(p) for p in parts)
    gains = gains or [1.0] * len(parts)
    out = [0.0] * length
    for p, g in zip(parts, gains):
        for i, s in enumerate(p):
            out[i] += s * g
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * n(gap)
    return out


def at(offset, part):
    return [0.0] * n(offset) + part


def note(semitones_from_a4):
    return 440.0 * 2.0 ** (semitones_from_a4 / 12.0)


def bell(seconds, f, partials=((1.0, 1.0), (2.0, 0.5), (2.76, 0.35), (5.4, 0.2), (0.5, 0.4)), curve=2.5):
    return mix(*[tone(seconds, f * r, kind="sine", attack=0.002, curve=curve * (1 + r * 0.3)) for r, _ in partials],
               gains=[g for _, g in partials])


# ---------------------------------------------------------------- effects
def sfx():
    return {
        # weapon hits a creature: a dull thud with a short scrape
        "hit": mix(tone(0.07, 180, 70, "tri", curve=4), noise(0.05, 5, 0.35, seed=2), gains=[1.0, 0.6]),
        # creature dies: downward chirp + soft burst
        "kill": mix(tone(0.12, 520, 120, "square", curve=3), noise(0.1, 4, 0.25, seed=3), gains=[0.35, 0.8]),
        # XP gem: glassy ping
        "gem": mix(tone(0.09, 1568, 2093, "sine", curve=3), tone(0.09, 3136, None, "sine", curve=5),
                   gains=[1.0, 0.25]),
        # coin: two quick bright notes
        "coin": seq(tone(0.05, 1976, None, "square", curve=2), tone(0.16, 2637, None, "square", curve=3)),
        # food / heal: soft rising triad
        "heal": seq(*[tone(0.09, note(s), None, "tri", curve=2) for s in (3, 7, 10, 15)]),
        # magnet / generic pickup: wobbling up-sweep
        "pickup": tone(0.25, 300, 1200, "tri", curve=1.5, vib=0.05),
        # level up: bright arpeggio + sparkle
        "level_up": mix(seq(*[tone(0.1, note(s), None, "square", curve=2) for s in (3, 7, 10, 15)]),
                        at(0.3, tone(0.45, note(27), None, "sine", curve=3)), gains=[0.6, 0.5]),
        # chest: wooden creak then a choir-like shimmer
        "chest_open": mix(tone(0.35, 90, 140, "saw", curve=1.5, vib=0.08),
                          at(0.25, bell(0.9, note(15))), gains=[0.35, 0.8]),
        # blessed bomb: boom
        "bomb": mix(noise(0.9, 2.5, 0.08, seed=4, attack=0.001), tone(0.7, 90, 35, "sine", curve=2.5),
                    gains=[1.0, 1.2]),
        # player hurt: harsh low down-sweep
        "player_hurt": mix(tone(0.16, 300, 110, "square", curve=2.5), noise(0.08, 4, 0.6, seed=5),
                           gains=[0.6, 0.5]),
        # boss arrives: a cracked funeral bell
        "boss_spawn": mix(bell(2.2, note(-21), curve=1.6), tone(2.0, 55, 52, "saw", curve=2.0),
                          gains=[1.0, 0.25]),
        # game over: slow falling minor line on a bell
        "game_over": seq(*[bell(0.55, note(s), curve=2.0) for s in (0, -2, -5, -9)]),
        # revival: rising shimmer
        "revive": mix(tone(0.9, 220, 880, "tri", curve=1.2, vib=0.03), at(0.4, bell(0.8, note(24))),
                      gains=[0.6, 0.7]),
        # UI
        "ui_move": tone(0.03, 1200, 1100, "square", curve=2),
        "ui_select": seq(tone(0.04, 880, None, "square", curve=2), tone(0.07, 1320, None, "square", curve=3)),
        "ui_back": tone(0.08, 700, 420, "square", curve=2),
        "buy": seq(tone(0.05, 1976, None, "square", curve=2), tone(0.05, 2637, None, "square", curve=2),
                   tone(0.18, 3136, None, "square", curve=3)),
        "deny": mix(tone(0.18, 140, 130, "square", curve=1.5), tone(0.18, 147, 137, "square", curve=1.5)),
        "unlock": mix(seq(*[tone(0.12, note(s), None, "square", curve=2) for s in (-2, 2, 5, 10)]),
                      at(0.45, bell(1.0, note(22))), gains=[0.5, 0.7]),
    }


# ---------------------------------------------------------------- music
def loop_track(bpm, bars, bass, lead, pad_chords, seed, lead_kind="tri", bell_every=0):
    """A seamless loop: every note's tail wraps around to the loop start."""
    beat = 60.0 / bpm
    length = n(beat * 4 * bars)
    out = [0.0] * length

    def add(start_s, part, gain):
        s0 = n(start_s)
        for i, v in enumerate(part):
            out[(s0 + i) % length] += v * gain

    for b, chord in enumerate(pad_chords):  # one chord per bar, soft organ pad
        for s in chord:
            add(b * 4 * beat, tone(beat * 4.2, note(s), None, "sine", attack=0.4, curve=0.8), 0.12)
            add(b * 4 * beat, tone(beat * 4.2, note(s) * 2, None, "sine", attack=0.4, curve=0.8), 0.04)
    for k, s in enumerate(bass):  # eighth notes
        if s is not None:
            add(k * beat / 2, tone(beat * 0.5, note(s), None, "tri", attack=0.005, curve=2.0), 0.35)
    for k, s in enumerate(lead):  # quarter notes
        if s is not None:
            add(k * beat, tone(beat * 0.95, note(s), None, lead_kind, attack=0.01, curve=1.8, vib=0.004), 0.16)
    if bell_every:
        for b in range(0, bars, bell_every):
            add(b * 4 * beat, bell(beat * 6, note(-9), curve=1.4), 0.25)
    rnd = random.Random(seed)
    hat = noise(0.03, 6, 0.9, seed=seed)
    for k in range(bars * 8):
        if k % 2 == 1 or rnd.random() < 0.2:
            add(k * beat / 2, hat, 0.05)
    return out


def music():
    # A minor, slow and hollow
    title = loop_track(
        bpm=72, bars=8,
        bass=[-24, None, -17, None, -24, None, -17, None] * 2 + [-28, None, -21, None, -28, None, -21, None] * 2
        + [-31, None, -24, None, -31, None, -24, None] * 2 + [-26, None, -19, None, -29, None, -22, None] * 2,
        lead=[None, 3, 7, 12, None, 10, 7, 3, None, -2, 3, 7, 8, 7, 3, -2,
              None, -5, 0, 3, None, 2, 0, -2, None, 0, -2, -5, -4, -5, None, None],
        pad_chords=[(-12, -9, -5), (-12, -9, -5), (-16, -12, -9), (-16, -12, -9),
                    (-19, -15, -12), (-19, -15, -12), (-14, -10, -7), (-17, -13, -10)],
        seed=11, bell_every=4)
    # the hunt: driving bass ostinato in D minor
    night_bass = []
    for root in (-19, -19, -23, -21):
        night_bass += [root, root + 12, root, root + 7] * 4
    night = loop_track(
        bpm=126, bars=16,
        bass=night_bass,
        lead=[5, None, 8, 7, 5, None, 0, None, 5, 7, 8, 12, 10, None, 8, None] * 2
        + [8, None, 12, 10, 8, None, 7, None, 5, 3, 5, 7, 8, None, None, None] * 2,
        pad_chords=[(-7, -4, 0)] * 4 + [(-7, -4, 0)] * 4 + [(-11, -7, -4)] * 4 + [(-9, -5, -2)] * 4,
        seed=12, lead_kind="square", bell_every=8)
    return {"title": title, "night": night}


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(BGM, exist_ok=True)
    for name, samples in sfx().items():
        write(os.path.join(SFX, name + ".wav"), samples)
    for name, samples in music().items():
        write(os.path.join(BGM, name + ".wav"), samples, peak=0.7)
    print("audio written to", os.path.join(ROOT, "audio"))


if __name__ == "__main__":
    main()
