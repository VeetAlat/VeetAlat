#!/usr/bin/env python3
"""Generates the AmbienceCrop icon, following the shape rules of Sailfish
OS's own launcher icons (measured from Jolla's icons in the SDK theme):

- The shape fills the whole canvas, edge to edge.
- It's the circle-and-square system: each corner is either fully round
  (radius = half the icon) or nearly square (radius about 4 %). This one
  is square at the top left, round elsewhere.
- An inset rim: the same shape again, inset by 13 % of the icon, with
  concentric corners.
- Vertical gradients, brighter at the top; no shadow outside the shape.
- One bold, flat, light symbol in the middle: here a tall phone screen
  showing a sun over the sea, between two crop brackets.

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

S = 172
ROUND = S / 2           # a round corner: a quarter circle
SQUARE = S * 0.04       # a "square" corner, as Sailfish rounds it slightly
INSET = S * 0.128       # the rim's width
CORNERS = ("square", "round", "round", "round")  # top-left, top-right, bottom-right, bottom-left


def shape(x, y, w, h, radii):
    """A path for a rectangle with its own radius at each corner (tl, tr, br, bl)."""
    tl, tr, br, bl = radii
    return (f"M{x + tl:.2f} {y:.2f} H{x + w - tr:.2f} A{tr:.2f} {tr:.2f} 0 0 1 {x + w:.2f} {y + tr:.2f} "
            f"V{y + h - br:.2f} A{br:.2f} {br:.2f} 0 0 1 {x + w - br:.2f} {y + h:.2f} "
            f"H{x + bl:.2f} A{bl:.2f} {bl:.2f} 0 0 1 {x:.2f} {y + h - bl:.2f} "
            f"V{y + tl:.2f} A{tl:.2f} {tl:.2f} 0 0 1 {x + tl:.2f} {y:.2f} Z")


def radii(inset):
    out = []
    for c in CORNERS:
        if c == "round":
            out.append(ROUND - inset)               # concentric with the outer circle
        else:
            out.append(max(SQUARE - inset * 0.25, SQUARE * 0.6))
    return out


def build():
    outer = shape(0, 0, S, S, radii(0))
    inner = shape(INSET, INSET, S - 2 * INSET, S - 2 * INSET, radii(INSET))
    # The symbol: a tall screen, centred.
    sw, sh = 52, 94
    sx, sy = (S - sw) / 2, (S - sh) / 2
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#9a6cf5"/>
      <stop offset="1" stop-color="#d9478e"/>
    </linearGradient>
    <linearGradient id="glow" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffb37a"/>
      <stop offset="1" stop-color="#f2667e"/>
    </linearGradient>
    <clipPath id="screen"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="7"/></clipPath>
  </defs>
  <path d="{outer}" fill="url(#rim)"/>
  <path d="{inner}" fill="url(#glow)"/>
  <!-- The screen: a sun over the sea, flat -->
  <g clip-path="url(#screen)">
    <rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" fill="#fff4e0"/>
    <circle cx="{S / 2}" cy="{sy + sh * 0.56}" r="15" fill="#ffc54d"/>
    <rect x="{sx}" y="{sy + sh * 0.62}" width="{sw}" height="{sh * 0.38}" fill="#5b4bc4"/>
    <path d="M{sx} {sy + sh * 0.75} q {sw / 4} -6 {sw / 2} 0 t {sw / 2} 0" fill="none" stroke="#fff4e0" stroke-width="3" stroke-linecap="round"/>
  </g>
  <rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="7" fill="none" stroke="#ffffff" stroke-width="6"/>
  <!-- Crop brackets around it -->
  <g fill="none" stroke="#ffffff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M{sx - 16} {sy + 22} V{sy - 10} H{sx + 14}"/>
    <path d="M{sx + sw + 16} {sy + sh - 22} V{sy + sh + 10} H{sx + sw - 14}"/>
  </g>
</svg>
'''


open("icons/ambiencecrop.svg", "w").write(build())
print("wrote icons/ambiencecrop.svg")
