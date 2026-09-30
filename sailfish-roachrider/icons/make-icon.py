#!/usr/bin/env python3
"""Generates the Roach Rider icon: the roach on its bike facing you, in
front of a neon grid, with "RR" spray-painted in neon on the wall behind.

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


def letter_r(x, top, bottom, w):
    """An R as one stroked path: stem, bowl and leg."""
    mid = top + (bottom - top) * 0.52
    r = (mid - top) / 2
    return (f"M{x} {bottom} V{top} H{x + w - r} A{r} {r} 0 0 1 {x + w - r} {mid} H{x} "
            f"M{x + w * 0.42} {mid} L{x + w} {bottom}")


def spray():
    """RR in spray paint: rough edged strokes, drips and overspray."""
    rng = random.Random(7)
    top, bottom, w = 16, 84, 44
    xs = (27, 97)
    paths = " ".join(letter_r(x, top, bottom, w) for x in xs)
    parts = []
    # Overspray: fine dots round the letters.
    for x0 in xs:
        for _ in range(140):
            px = rng.uniform(x0 - 10, x0 + w + 10)
            py = rng.uniform(top - 10, bottom + 10)
            col = MAGENTA if py < (top + bottom) / 2 else CYAN
            parts.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{rng.uniform(0.4, 1.2):.2f}" '
                         f'fill="{col}" fill-opacity="{rng.uniform(0.25, 0.7):.2f}"/>')
    # Drips running down from the letters.
    for (dx, length) in ((27, 12), (27 + 44, 7), (97, 16), (97 + 18, 9), (97 + 44, 11), (27 + 18, 5)):
        parts.append(f'<path d="M{dx} {bottom} v{length}" stroke="url(#paint)" stroke-width="3.2" '
                     f'stroke-linecap="round" filter="url(#rough)"/>')
        parts.append(f'<circle cx="{dx}" cy="{bottom + length + 1}" r="2.4" fill="{CYAN}"/>')
    speckles = "\n    ".join(parts)
    return f'''<g>
    <path d="{paths}" fill="none" stroke="url(#paint)" stroke-width="22" stroke-opacity="0.35"
          stroke-linecap="round" stroke-linejoin="round" filter="url(#haze)"/>
    <path d="{paths}" fill="none" stroke="url(#paint)" stroke-width="13"
          stroke-linecap="round" stroke-linejoin="round" filter="url(#rough)"/>
    {speckles}
  </g>'''


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
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="4" xChannelSelector="R" yChannelSelector="G"/>
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
    <image x="16" y="36" width="140" height="140" xlink:href="data:image/png;base64,{roach}"/>
  </g>
  <rect x="7.5" y="7.5" width="157" height="157" rx="32.5" fill="none" stroke="{MAGENTA}" stroke-opacity="0.6" stroke-width="3"/>
</svg>
'''


open("icons/roachrider.svg", "w").write(build(sys.argv[1] if len(sys.argv) > 1 else "icons/roach-front.png"))
print("wrote icons/roachrider.svg")
