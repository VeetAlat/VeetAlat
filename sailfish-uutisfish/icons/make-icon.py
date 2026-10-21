#!/usr/bin/env python3
"""Generates the UutisFish icon: a little school of three newspaper fish,
one for each news source, in the colours the home page gives them (teal
for Yle, coral for MTV Uutiset, blue for AP News). Each fish's body is a
news page with a headline bar and lines of text. (No logos or lettering:
it's an unofficial app.)

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

S = 172
INK = "#0b2e63"
FISH = [  # colour, darker edge, x, y, scale
    ("#16b3c4", "#0b7f8f", 4, -4, 0.52),    # Yle, top left
    ("#ff6f4f", "#c2412a", 76, 44, 0.52),   # MTV Uutiset, middle right
    ("#3f6fd8", "#2849a0", 12, 90, 0.52),   # AP News, bottom left
]

# One fish in a 172 x 172 box: nose to the left, tail to the right.
BODY = ("M18 88 C 30 42, 92 30, 126 58 C 134 65, 138 76, 138 88 "
        "C 138 100, 134 111, 126 118 C 92 146, 30 134, 18 88 Z")


def fish(i, color, dark, x, y, scale):
    lines = [f'<rect x="44" y="58" width="74" height="11" rx="5.5" fill="{INK}"/>']
    for r in range(4):
        yy = 78 + r * 12
        lines.append(f'<rect x="44" y="{yy}" width="33" height="6" rx="3" fill="{INK}" fill-opacity="0.7"/>')
        lines.append(f'<rect x="84" y="{yy}" width="34" height="6" rx="3" fill="{INK}" fill-opacity="0.7"/>')
    text = "\n      ".join(lines)
    return f'''  <g transform="translate({x} {y}) scale({scale})">
    <path d="M132 88 L 162 54 C 167 70, 167 106, 162 122 Z" fill="{color}" stroke="{dark}"
          stroke-width="5" stroke-linejoin="round"/>
    <path d="M64 42 C 76 20, 102 18, 112 46 Z" fill="{color}" stroke="{dark}" stroke-width="5" stroke-linejoin="round"/>
    <path d="M74 134 C 82 152, 102 152, 106 130 Z" fill="{color}" stroke="{dark}" stroke-width="5" stroke-linejoin="round"/>
    <path d="{BODY}" fill="#ffffff"/>
    <g clip-path="url(#body)">
      {text}
    </g>
    <path d="{BODY}" fill="none" stroke="{dark}" stroke-width="6" stroke-linejoin="round"/>
    <path d="M38 66 C 33 78, 33 98, 38 110" fill="none" stroke="{color}" stroke-width="6" stroke-linecap="round"/>
    <circle cx="27" cy="80" r="7" fill="{INK}"/>
    <circle cx="29.5" cy="77.5" r="2.4" fill="#ffffff"/>
  </g>'''


def build():
    body = "\n".join(fish(i, *f) for i, f in enumerate(FISH))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <clipPath id="body"><path d="{BODY}"/></clipPath>
  </defs>
{body}
</svg>
'''


open("icons/uutisfish.svg", "w").write(build())
print("wrote icons/uutisfish.svg")
