#!/usr/bin/env python3
"""Synthesises the game's sounds into qml/sounds/, from nothing but maths:

- hum-low.wav, hum-high.wav: the bike's techie electric hum, like an
  electric car backing up: a synth tone with a whine on top, pulsing twice
  a second. Two seamless 2 second loops; the game blends from the low one
  to the high one as the roach speeds up.
- swoosh.wav: changing lanes. jump.wav: a longer, rising swoosh.
- crash.wav: hitting a block. fall.wav: dropping into the void.

Plain Python, no extra modules. Run: python3 tools/make-sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "qml", "sounds")
TAU = 2 * math.pi


def save(name, samples, peak=0.85, loop=False):
    if not loop:
        # Fade out the last 20 ms, so a sound never ends with a click.
        fade = int(0.02 * RATE)
        samples = samples[:-fade] + [v * (1 - k / fade) for k, v in enumerate(samples[-fade:])]
    top = max(1e-9, max(abs(s) for s in samples))
    k = peak / top
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def hum(f0, whine):
    """A 2 s loop. Every frequency is a multiple of 0.5 Hz, so the end
    meets the start exactly and the loop never clicks."""
    n = 2 * RATE
    out = []
    for i in range(n):
        t = i / RATE
        # The body: a warm tone and a copy 1 Hz off, which beat slowly.
        body = (math.sin(TAU * f0 * t) + 0.5 * math.sin(TAU * 2 * f0 * t)
                + 0.25 * math.sin(TAU * 3 * f0 * t) + 0.6 * math.sin(TAU * (f0 + 1) * t))
        # The electric whine, wavering a little.
        w = 0.35 * math.sin(TAU * whine * t + 2.5 * math.sin(TAU * 1 * t))
        w += 0.12 * math.sin(TAU * whine * 1.5 * t)
        # Pulsing twice a second, like a car's reversing warning.
        pulse = 0.72 + 0.28 * math.sin(TAU * 2 * t) ** 2
        out.append((0.55 * body + w) * pulse)
    return out


class Bandpass:
    """A resonant band-pass filter whose centre can move every sample."""

    def __init__(self):
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x, freq, q):
        w = TAU * freq / RATE
        alpha = math.sin(w) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
        y = (b0 * x + b2 * self.x2 - a1 * self.y1 - a2 * self.y2) / a0
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


def swoosh(seconds, f_from, f_to, seed, tone=0.0):
    """Air rushing past: noise through a filter sweeping f_from to f_to."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    bp = Bandpass()
    out = []
    phase = 0.0
    for i in range(n):
        p = i / n
        f = f_from * (f_to / f_from) ** p
        env = math.sin(math.pi * p) ** 1.5              # swells and fades
        s = bp(rng.uniform(-1, 1), f, 1.6) * env
        if tone:
            phase += TAU * f * 0.35 / RATE
            s += tone * math.sin(phase) * env ** 2
        out.append(s)
    return out


def crash():
    """A digital crunch, a low thud and a metallic clang."""
    rng = random.Random(3)
    n = int(0.9 * RATE)
    out = []
    lp = 0.0
    phase = 0.0
    for i in range(n):
        t = i / RATE
        # Crunch: noise, dulled a little, crushed to a few levels for a
        # glitchy, digital edge.
        lp += 0.45 * (rng.uniform(-1, 1) - lp)
        crunch = round(lp * 6) / 6 * math.exp(-t / 0.09)
        # Thud: a sine falling from 130 Hz to 40 Hz.
        f = 40 + 90 * math.exp(-t / 0.08)
        phase += TAU * f / RATE
        thud = 1.3 * math.sin(phase) * math.exp(-t / 0.22)
        # Clang: out-of-tune partials, like struck metal.
        clang = sum(a * math.sin(TAU * pf * t) for pf, a in ((523, 0.5), (1187, 0.35), (1853, 0.25), (2631, 0.18)))
        clang *= math.exp(-t / 0.28)
        attack = min(1.0, t / 0.002)
        out.append(attack * (crunch + thud + 0.6 * clang))
    return out


def fall():
    """Dropping into the void: a falling whistle and a dark swoosh."""
    n = int(0.8 * RATE)
    base = swoosh(0.8, 2200, 250, 9)
    out = []
    phase = 0.0
    for i in range(n):
        p = i / n
        f = 900 * (0.18 ** p)
        phase += TAU * f / RATE
        out.append(base[i] + 0.35 * math.sin(phase) * (1 - p) ** 1.2)
    return out


os.makedirs(OUT, exist_ok=True)
save("hum-low.wav", hum(110, 880), 0.8, loop=True)
save("hum-high.wav", hum(147, 1323), 0.8, loop=True)
save("swoosh.wav", swoosh(0.22, 700, 2600, 1))
save("jump.wav", swoosh(0.38, 350, 3800, 2, tone=0.25))
save("crash.wav", crash())
save("fall.wav", fall())
print("sounds written to", os.path.normpath(OUT))
