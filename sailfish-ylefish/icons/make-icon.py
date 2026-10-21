#!/usr/bin/env python3
"""Generates the YleFish icon: a fish whose body is a news page, with a
headline bar and columns of text, a teal tail and fins, and an eye.
(No Yle logo or lettering: it's an unofficial app.)

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

TEAL = "#16b3c4"
TEAL_DARK = "#0b7f8f"
INK = "#0b2e63"
S = 172

# The body: a plump fish shape, nose to the left, tail end to the right.
BODY = ("M18 88 C 30 42, 92 30, 126 58 C 134 65, 138 76, 138 88 "
        "C 138 100, 134 111, 126 118 C 92 146, 30 134, 18 88 Z")


def build():
    lines = []
    # A headline bar, then two columns of text, clipped to the body.
    lines.append(f'<rect x="44" y="56" width="74" height="9" rx="4.5" fill="{INK}"/>')
    for i in range(6):
        y = 74 + i * 9
        lines.append(f'<rect x="44" y="{y}" width="33" height="4.5" rx="2.25" fill="{INK}" fill-opacity="0.75"/>')
        if i < 5:
            lines.append(f'<rect x="83" y="{y}" width="35" height="4.5" rx="2.25" fill="{INK}" fill-opacity="0.75"/>')
    text = "\n    ".join(lines)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <clipPath id="body"><path d="{BODY}"/></clipPath>
    <linearGradient id="paper" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#e4f3f6"/>
    </linearGradient>
  </defs>
  <!-- Tail -->
  <path d="M132 88 L 160 56 C 164 70, 164 106, 160 120 Z" fill="{TEAL}" stroke="{TEAL_DARK}"
        stroke-width="3" stroke-linejoin="round"/>
  <!-- Fins, top and bottom -->
  <path d="M66 40 C 76 22, 100 20, 110 44 Z" fill="{TEAL}" stroke="{TEAL_DARK}" stroke-width="3" stroke-linejoin="round"/>
  <path d="M74 134 C 82 150, 100 150, 104 130 Z" fill="{TEAL}" stroke="{TEAL_DARK}" stroke-width="3" stroke-linejoin="round"/>
  <!-- The body: a news page -->
  <path d="{BODY}" fill="url(#paper)"/>
  <g clip-path="url(#body)">
    {text}
    <!-- A folded corner of the page, up at the gills -->
    <path d="M30 60 L 38 52 L 38 60 Z" fill="{TEAL}" fill-opacity="0.35"/>
  </g>
  <path d="{BODY}" fill="none" stroke="{TEAL_DARK}" stroke-width="4" stroke-linejoin="round"/>
  <!-- Gill and eye -->
  <path d="M38 66 C 33 78, 33 98, 38 110" fill="none" stroke="{TEAL}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="28" cy="80" r="5.5" fill="{INK}"/>
  <circle cx="29.8" cy="78.2" r="1.8" fill="#ffffff"/>
</svg>
'''


open("icons/ylefish.svg", "w").write(build())
print("wrote icons/ylefish.svg")
