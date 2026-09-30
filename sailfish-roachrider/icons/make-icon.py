#!/usr/bin/env python3
"""Generates the Roach Rider icon: the roach on its bike facing you, in
front of a neon grid, with "RR" spray-painted in neon on the wall behind,
in a hurry: tilted, shaky, dripping.

The roach is a picture made by tools/roach-render (see tools/make-images.sh),
put into the SVG as-is.
Run: python3 icons/make-icon.py icons/roach-front.png
"""

import base64
import random
import sys

MAGENTA = "#ff2bd6"
CYAN = "#19c6ff"
S = 172
HORIZON = 104


def grid():
    """A neon floor going off to the horizon, like the game's tunnel."""
    out = []
    cx = S / 2
    # Lines towards the vanishing point.
    for k in range(-7, 8):
        out.append(f'<line x1="{cx + k * 30:.1f}" y1="{S}" x2="{cx + k * 3:.1f}" y2="{HORIZON}" '
                   f'stroke="{CYAN}" stroke-width="1.6" stroke-opacity="0.85"/>')
    # Lines across, closer together towards the horizon.
    for i in range(1, 7):
        y = HORIZON + (S - HORIZON) * (i / 6) ** 1.8
        out.append(f'<line x1="0" y1="{y:.1f}" x2="{S}" y2="{y:.1f}" stroke="{CYAN}" '
                   f'stroke-width="{1 + i * 0.25:.2f}" stroke-opacity="0.85"/>')
    # The horizon, magenta.
    out.append(f'<line x1="0" y1="{HORIZON}" x2="{S}" y2="{HORIZON}" stroke="{MAGENTA}" stroke-width="2.5"/>')
    # A faint wall grid above the horizon.
    for x in range(-2, 12):
        out.append(f'<line x1="{x * 17}" y1="0" x2="{x * 17}" y2="{HORIZON}" stroke="{MAGENTA}" '
                   f'stroke-width="1" stroke-opacity="0.22"/>')
    for y in range(1, 7):
        out.append(f'<line x1="0" y1="{y * 16}" x2="{S}" y2="{y * 16}" stroke="{MAGENTA}" '
                   f'stroke-width="1" stroke-opacity="0.22"/>')
    return "\n    ".join(out)


def letter_r(rng, x, top, bottom, w, shake):
    """An R as one stroked path: stem, bowl and leg, drawn by a shaking
    hand: every point is a little off, and the bowl overshoots."""
    def j(v):
        return v + rng.uniform(-shake, shake)
    mid = top + (bottom - top) * 0.5
    return (f"M{j(x)} {j(bottom + 3)} "
            f"L{j(x + 2)} {j(top + (bottom - top) * 0.5)} L{j(x)} {j(top)} "
            f"C{j(x + w * 0.6)} {j(top - 6)}, {j(x + w + 8)} {j(top + 4)}, {j(x + w)} {j(mid - 10)} "
            f"C{j(x + w - 4)} {j(mid + 2)}, {j(x + w * 0.4)} {j(mid + 2)}, {j(x - 2)} {j(mid)} "
            f"M{j(x + w * 0.35)} {j(mid + 1)} L{j(x + w * 0.7)} {j(mid + (bottom - mid) * 0.5)} "
            f"L{j(x + w + 6)} {j(bottom + 4)}")


def spray():
    """RR sprayed in a panic: tilted letters, a sloppy second pass, drips,
    splatter and overspray."""
    rng = random.Random(11)
    top, bottom, w = 20, 80, 42
    # Each letter: left edge, tilt in degrees.
    letters = ((24, -19), (100, 13))
    out = []
    for (x0, tilt) in letters:
        cx, cy = x0 + w / 2, (top + bottom) / 2
        first = letter_r(rng, x0, top, bottom, w, 2.5)
        second = letter_r(rng, x0 + 2, top + 1, bottom - 1, w, 4.0)
        parts = []
        # Overspray: fine dots round the letter.
        for _ in range(170):
            px = rng.uniform(x0 - 14, x0 + w + 14)
            py = rng.uniform(top - 14, bottom + 14)
            col = MAGENTA if py < cy else CYAN
            parts.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{rng.uniform(0.4, 1.3):.2f}" '
                         f'fill="{col}" fill-opacity="{rng.uniform(0.25, 0.75):.2f}"/>')
        # Splatter: a few bigger blobs flung off the can.
        for _ in range(9):
            px = rng.uniform(x0 - 10, x0 + w + 12)
            py = rng.uniform(top - 8, bottom + 10)
            parts.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{rng.uniform(1.4, 3.0):.2f}" fill="url(#paint)"/>')
        # Drips: long and uneven, from wherever the paint pooled.
        for dx in (x0 + rng.uniform(-2, 3), x0 + w * 0.45 + rng.uniform(-3, 3), x0 + w + rng.uniform(2, 6),
                   x0 + w * 0.2 + rng.uniform(-2, 2)):
            length = rng.uniform(8, 24)
            parts.append(f'<path d="M{dx:.1f} {bottom - 2} q{rng.uniform(-1.5, 1.5):.1f} {length / 2:.1f} '
                         f'{rng.uniform(-1, 1):.1f} {length:.1f}" fill="none" stroke="url(#paint)" '
                         f'stroke-width="{rng.uniform(2.2, 3.4):.1f}" stroke-linecap="round" filter="url(#rough)"/>')
            parts.append(f'<circle cx="{dx:.1f}" cy="{bottom - 2 + length:.1f}" r="{rng.uniform(1.8, 2.8):.1f}" fill="{CYAN}"/>')
        dots = "\n      ".join(parts)
        out.append(f'''<g transform="rotate({tilt} {cx} {cy})">
      <path d="{first}" fill="none" stroke="url(#paint)" stroke-width="24" stroke-opacity="0.35"
            stroke-linecap="round" stroke-linejoin="round" filter="url(#haze)"/>
      <path d="{first}" fill="none" stroke="url(#paint)" stroke-width="12"
            stroke-linecap="round" stroke-linejoin="round" filter="url(#rough)"/>
      <path d="{second}" fill="none" stroke="url(#paint)" stroke-width="6" stroke-opacity="0.75"
            stroke-linecap="round" stroke-linejoin="round" filter="url(#rough)"/>
      {dots}
    </g>''')
    return "\n    ".join(out)


def build(roach_png):
    roach = base64.b64encode(open(roach_png, "rb").read()).decode()
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#07021a"/>
      <stop offset="0.6" stop-color="#2a0850"/>
      <stop offset="1" stop-color="#0a1136"/>
    </linearGradient>
    <linearGradient id="paint" x1="0" y1="0" x2="0.3" y2="1">
      <stop offset="0" stop-color="{MAGENTA}"/>
      <stop offset="1" stop-color="{CYAN}"/>
    </linearGradient>
    <filter id="rough" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="0.35" numOctaves="2" seed="3" result="noise"/>
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="6" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="haze" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="4"/>
    </filter>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="1.6" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <clipPath id="tile"><rect x="6" y="6" width="160" height="160" rx="34"/></clipPath>
  </defs>
  <g clip-path="url(#tile)">
    <rect x="0" y="0" width="{S}" height="{S}" fill="url(#bg)"/>
    <g filter="url(#glow)">
    {grid()}
    </g>
    {spray()}
    <image x="8" y="26" width="158" height="158" xlink:href="data:image/png;base64,{roach}"/>
  </g>
  <rect x="7.5" y="7.5" width="157" height="157" rx="32.5" fill="none" stroke="{MAGENTA}" stroke-opacity="0.6" stroke-width="3"/>
</svg>
'''


open("icons/roachrider.svg", "w").write(build(sys.argv[1] if len(sys.argv) > 1 else "icons/roach-front.png"))
print("wrote icons/roachrider.svg")
