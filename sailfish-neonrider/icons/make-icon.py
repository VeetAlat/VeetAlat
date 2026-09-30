#!/usr/bin/env python3
"""Generates the Neon Rider icon: looking down the neon tunnel, with the
grid floor and walls, and the bike's tail light in the middle.

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

CYAN = "#19c6ff"
MAGENTA = "#ff2bd6"
BIKE = "#2f8bff"

S = 172
C = S / 2
OUTER = 74       # half size of the tunnel's mouth
INNER = 12       # half size of the far end


def lerp(a, b, t):
    return a + (b - a) * t


def depth(t):
    """Half size of the tunnel's cross-section t of the way down (0 = mouth).
    Perspective: equal steps along the tunnel get closer together."""
    z = 1 + t * 5
    return INNER + (OUTER - INNER) * (1 / z - 1 / 6) / (1 - 1 / 6)


def build():
    lines = []
    # Rings across the tunnel at equal distances.
    for i in range(1, 6):
        h = depth(i / 6)
        lines.append(f'<rect x="{C - h:.1f}" y="{C - h:.1f}" width="{2 * h:.1f}" height="{2 * h:.1f}" '
                     f'stroke="{CYAN}" stroke-width="{1.2 + 1.6 * h / OUTER:.2f}" fill="none"/>')
    # Lanes along the tunnel: two lines on each side between the corners.
    for k in (1, 2):
        f = -1 + 2 * k / 3
        for (x0, y0) in ((f, 1), (f, -1), (1, f), (-1, f)):
            lines.append(f'<line x1="{C + x0 * OUTER:.1f}" y1="{C + y0 * OUTER:.1f}" '
                         f'x2="{C + x0 * INNER:.1f}" y2="{C + y0 * INNER:.1f}" stroke="{CYAN}" stroke-width="2"/>')
    # The corners, magenta.
    for (sx, sy) in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        lines.append(f'<line x1="{C + sx * OUTER}" y1="{C + sy * OUTER}" x2="{C + sx * INNER}" y2="{C + sy * INNER}" '
                     f'stroke="{MAGENTA}" stroke-width="3.2" stroke-linecap="round"/>')
    grid = "\n    ".join(lines)

    # The bike from behind: a small body with a bright tail light, on the floor.
    bx, by = C, C + 38
    bike = (f'<rect x="{bx - 8}" y="{by - 20}" width="16" height="22" rx="3" fill="#0b1440" stroke="{BIKE}" stroke-width="2.5"/>\n'
            f'    <line x1="{bx - 5}" y1="{by - 12}" x2="{bx + 5}" y2="{by - 12}" stroke="#ffffff" stroke-width="3.5" stroke-linecap="round"/>\n'
            f'    <line x1="{bx - 3}" y1="{by + 2}" x2="{bx - 3}" y2="{by + 9}" stroke="{BIKE}" stroke-width="3" stroke-linecap="round"/>\n'
            f'    <line x1="{bx + 3}" y1="{by + 2}" x2="{bx + 3}" y2="{by + 9}" stroke="{BIKE}" stroke-width="3" stroke-linecap="round"/>')

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="60%">
      <stop offset="0" stop-color="#3a0a6e"/>
      <stop offset="0.35" stop-color="#150533"/>
      <stop offset="1" stop-color="#07021a"/>
    </radialGradient>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="2.2" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <clipPath id="tile"><rect x="6" y="6" width="160" height="160" rx="34"/></clipPath>
  </defs>
  <rect x="6" y="6" width="160" height="160" rx="34" fill="url(#bg)"/>
  <g clip-path="url(#tile)" filter="url(#glow)">
    {grid}
    {bike}
  </g>
  <rect x="7.5" y="7.5" width="157" height="157" rx="32.5" fill="none" stroke="{MAGENTA}" stroke-opacity="0.55" stroke-width="3"/>
</svg>
'''


open("icons/neonrider.svg", "w").write(build())
print("wrote icons/neonrider.svg")
