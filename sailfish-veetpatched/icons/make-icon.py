#!/usr/bin/env python3
"""Generates the VeetPatched icon, to the shape rules of Sailfish OS's own
launcher icons (measured from Jolla's icons in the SDK theme): full bleed;
each corner fully round or nearly square (here square top-left and
bottom-right); an inset rim (13 %) with concentric corners; vertical
gradients; one bold, flat, light symbol: a sticking plaster, a patch.

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

S = 172
ROUND = S / 2
SQUARE = S * 0.04
INSET = S * 0.128
CORNERS = ("square", "round", "square", "round")  # top-left, top-right, bottom-right, bottom-left


def shape(x, y, w, h, radii):
    tl, tr, br, bl = radii
    return (f"M{x + tl:.2f} {y:.2f} H{x + w - tr:.2f} A{tr:.2f} {tr:.2f} 0 0 1 {x + w:.2f} {y + tr:.2f} "
            f"V{y + h - br:.2f} A{br:.2f} {br:.2f} 0 0 1 {x + w - br:.2f} {y + h:.2f} "
            f"H{x + bl:.2f} A{bl:.2f} {bl:.2f} 0 0 1 {x:.2f} {y + h - bl:.2f} "
            f"V{y + tl:.2f} A{tl:.2f} {tl:.2f} 0 0 1 {x + tl:.2f} {y:.2f} Z")


def radii(inset):
    return [ROUND - inset if c == "round" else max(SQUARE - inset * 0.25, SQUARE * 0.6) for c in CORNERS]


def build():
    outer = shape(0, 0, S, S, radii(0))
    inner = shape(INSET, INSET, S - 2 * INSET, S - 2 * INSET, radii(INSET))
    c = S / 2
    # The plaster: a long rounded strip, turned 45 degrees, with its pad and holes.
    holes = "\n      ".join(
        f'<circle cx="{c + dx}" cy="{c + dy}" r="2.6" fill="#8fd9b8"/>'
        for dx in (-34, -24, 24, 34) for dy in (-6, 6))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#2fc48a"/>
      <stop offset="1" stop-color="#0d7a63"/>
    </linearGradient>
    <linearGradient id="inside" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#5fe0ae"/>
      <stop offset="1" stop-color="#1fa883"/>
    </linearGradient>
  </defs>
  <path d="{outer}" fill="url(#rim)"/>
  <path d="{inner}" fill="url(#inside)"/>
  <g transform="rotate(-45 {c} {c})">
    <rect x="{c - 58}" y="{c - 19}" width="116" height="38" rx="19" fill="#ffffff"/>
    <rect x="{c - 16}" y="{c - 15}" width="32" height="30" rx="5" fill="#ffe9c7"/>
    <g>
      {holes}
    </g>
  </g>
</svg>
'''


open("icons/veetpatched.svg", "w").write(build())
print("wrote icons/veetpatched.svg")
