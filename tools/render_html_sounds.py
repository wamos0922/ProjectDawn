"""Render the HTML demo's synth sounds (c1.js: tone(), chime(), TRACKS) to WAV files for Godot.

The HTML demo makes every sound live with WebAudio oscillators. Godot plays files, so this script
plays the same notes offline and writes them to assets/audio/html/. Same waves, same envelopes:
  gain starts at `vol`, falls exponentially to 0.0001 over `dur` seconds, oscillator stops 30 ms later.

Run:  python3 tools/render_html_sounds.py            (needs numpy)
Music files are one seamless loop (notes that ring past the end wrap round to the start).
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "html")


def osc(kind, f, n):
    t = np.arange(n) / RATE
    ph = (f * t) % 1.0
    if kind == "square":
        return np.where(ph < 0.5, 1.0, -1.0)
    if kind == "triangle":
        return 4.0 * np.abs(ph - 0.5) - 1.0
    if kind == "sawtooth":
        return 2.0 * ph - 1.0
    return np.sin(2 * np.pi * f * t)


def tone(buf, f, d, kind="square", v=0.05, t0=0.0, wrap=False):
    """Add one WebAudio-style note to buf (float array)."""
    n = int((d + 0.03) * RATE)
    k = np.arange(n) / RATE
    env = v * np.power(0.0001 / v, np.minimum(k, d) / d)
    env[k > d] = 0.0001
    note = osc(kind, f, n) * env
    i0 = int(t0 * RATE)
    if wrap:
        idx = (i0 + np.arange(n)) % len(buf)
        np.add.at(buf, idx, note)
    else:
        end = min(len(buf), i0 + n)
        buf[i0:end] += note[: end - i0]


def save(name, buf, gain=4.0):
    os.makedirs(OUT, exist_ok=True)
    pcm = np.clip(buf * gain, -1.0, 1.0)
    data = (pcm * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("wrote", name, round(len(buf) / RATE, 2), "s")


def sfx(name, notes, length):
    buf = np.zeros(int(length * RATE))
    for f, d, kind, v, when in notes:
        tone(buf, f, d, kind, v, when)
    save(name, buf)


# ---------------------------------------------------------------- one-shot sounds (c1.js)
sfx("blip", [(520, .05, "triangle", .04, 0)], .12)
sfx("chime", [(523, .14, "triangle", .07, 0), (659, .14, "triangle", .07, .12), (784, .26, "triangle", .07, .24)], .6)
sfx("bad", [(220, .18, "square", .04, 0), (165, .24, "square", .04, .16)], .45)
sfx("alarm_beep", [(880, .13, "square", .045, 0), (660, .13, "square", .045, .17)], .35)
sfx("door_hum", [(180, .5, "sawtooth", .035, 0)], .6)


# ---------------------------------------------------------------- music loops (c1.js TRACKS)
def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def arp(chords, pat):
    return [c[i] for c in chords for i in pat]


TRACKS = {
    "earth": (96, [
        ("triangle", .06, 1.8, [45, 0, 0, 0, 45, 0, 0, 0, 41, 0, 0, 0, 41, 0, 0, 0, 48, 0, 0, 0, 48, 0, 0, 0, 43, 0, 0, 0, 43, 0, 0, 0]),
        ("square", .014, .6, arp([[57, 60, 64, 69], [53, 57, 60, 65], [60, 64, 67, 72], [55, 59, 62, 67]], [0, 1, 2, 3, 2, 1, 0, 2])),
        ("square", .026, 1.6, [76, 0, 0, 74, 72, 0, 0, 0, 72, 0, 0, 74, 76, 0, 0, 0, 79, 0, 0, 76, 74, 0, 72, 0, 74, 0, 0, 0, 0, 0, 0, 0])]),
    "moon": (72, [
        ("triangle", .06, 3.5, [38, 0, 0, 0, 0, 0, 0, 0, 34, 0, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0]),
        ("triangle", .03, 1.2, arp([[62, 65, 69, 74], [58, 62, 65, 70], [60, 65, 69, 72], [60, 64, 67, 72]], [0, 2, 1, 3, 2, 1, 3, 2])),
        ("sine", .035, 3, [81, 0, 0, 0, 0, 0, 79, 0, 77, 0, 0, 0, 0, 0, 0, 0, 76, 0, 0, 0, 74, 0, 0, 0, 72, 0, 0, 0, 0, 0, 0, 0])]),
    "alarm": (140, [
        ("square", .04, .9, [81, 0, 0, 0, 76, 0, 0, 0, 81, 0, 0, 0, 76, 0, 0, 0]),
        ("sawtooth", .02, .5, [40, 0, 40, 0, 40, 0, 40, 0, 41, 0, 41, 0, 41, 0, 41, 0])]),
    "dawn": (84, [
        ("triangle", .06, 3, [48, 0, 0, 0, 0, 0, 0, 0, 43, 0, 0, 0, 0, 0, 0, 0, 45, 0, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 0]),
        ("square", .013, .7, arp([[60, 64, 67, 72], [55, 59, 62, 67], [57, 60, 64, 69], [53, 57, 60, 65]], [0, 1, 2, 3, 2, 1, 2, 3])),
        ("triangle", .04, 2, [79, 0, 0, 76, 0, 0, 79, 0, 81, 0, 0, 0, 79, 0, 0, 0, 76, 0, 0, 74, 0, 0, 72, 0, 74, 0, 0, 0, 0, 0, 0, 0])]),
}

for name, (bpm, parts) in TRACKS.items():
    step = 60 / bpm / 2
    steps = max(len(p[3]) for p in parts)
    buf = np.zeros(int(round(steps * step * RATE)))
    for kind, vol, dur, notes in parts:
        for i in range(steps):
            n = notes[i % len(notes)]
            if n:
                tone(buf, mtof(n), step * dur, kind, vol, i * step, wrap=True)
    save("music_" + name, buf, gain=3.0)
