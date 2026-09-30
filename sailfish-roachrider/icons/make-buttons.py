#!/usr/bin/env python3
"""Generates the three game buttons as SVGs, each normal and held down:
neon arrows to the left and right, and the round jump button.

They're pictures rather than drawn by the app, because drawing a glow
with QML's Canvas takes seconds on a phone.
Run: python3 icons/make-buttons.py <out-dir>  (writes btn-*.svg)
"""

import os
import sys

CYAN = "#19c6ff"
MAGENTA = "#ff2bd6"
S = 300


def button(kind, down):
    color = MAGENTA if kind == "jump" else CYAN
    fill_opacity = 0.45 if down else 0.1
    glow = 14 if down else 8
    symbol = "#ffffff" if down else color
    pad = 34
    if kind == "jump":
        frame = f'<circle cx="{S / 2}" cy="{S / 2}" r="{S / 2 - pad}"/>'
        mark = (f'<circle cx="{S / 2}" cy="{S / 2}" r="{S * 0.17}" fill="none" '
                f'stroke="{symbol}" stroke-width="{S * 0.06}"/>')
    else:
        frame = f'<rect x="{pad}" y="{pad}" width="{S - 2 * pad}" height="{S - 2 * pad}" rx="{S * 0.16}"/>'
        d = -1 if kind == "left" else 1
        s = S * 0.2
        c = S / 2
        mark = (f'<path d="M{c + d * s} {c} L{c - d * s * 0.7} {c - s} L{c - d * s * 0.7} {c + s} Z" '
                f'fill="{symbol}"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="{glow}" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <g filter="url(#glow)">
    <g fill="{color}" fill-opacity="{fill_opacity}" stroke="{color}" stroke-width="{S * 0.035}">{frame}</g>
    {mark}
  </g>
</svg>
'''


out = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(out, exist_ok=True)
for kind in ("left", "right", "jump"):
    for down in (False, True):
        name = f"btn-{kind}{'-down' if down else ''}.svg"
        open(os.path.join(out, name), "w").write(button(kind, down))
print("wrote the buttons to", out)
