#!/usr/bin/env python3
"""Generates the CodeSysFish icon: a fish whose body is a PLC module, with a
small screen of Structured Text (green on black, like a terminal), status
LEDs, a DIN-rail clip for a fin and a green tail. (No CODESYS logo or
lettering: it's an independent app.)

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

S = 172
CASE = "#3a4a57"
CASE_DARK = "#232e37"
GREEN = "#2fbf71"
GREEN_DARK = "#1d8a50"
SCREEN = "#0f1a14"

# The body: a fish-shaped module, nose to the left.
BODY = ("M16 88 C 22 50, 60 38, 104 40 L 120 40 C 132 40, 138 50, 138 62 "
        "L 138 114 C 138 126, 132 136, 120 136 L 104 136 C 60 138, 22 126, 16 88 Z")


def build():
    code = []
    # Lines of "code": keyword, then the rest, like  IF x THEN / y := 1;
    rows = [(0, 14, 30), (6, 12, 22), (0, 20, 14), (6, 10, 26)]
    for i, (indent, kw, rest) in enumerate(rows):
        y = 72 + i * 11
        x = 50 + indent
        code.append(f'<rect x="{x}" y="{y}" width="{kw}" height="5" rx="2.5" fill="#ffcc66"/>')
        code.append(f'<rect x="{x + kw + 4}" y="{y}" width="{rest}" height="5" rx="2.5" fill="{GREEN}"/>')
    # The cursor.
    code.append(f'<rect x="{50 + 6 + 10 + 4 + 26 + 4}" y="{72 + 3 * 11 - 1}" width="3" height="7" fill="#ffffff"/>')
    lines = "\n    ".join(code)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <!-- Tail -->
  <path d="M134 88 L 162 56 C 167 72, 167 104, 162 120 Z" fill="{GREEN}" stroke="{GREEN_DARK}"
        stroke-width="3" stroke-linejoin="round"/>
  <!-- DIN-rail clip for a top fin, and a bottom fin -->
  <path d="M70 41 L 70 26 C 70 22, 74 20, 78 20 L 104 20 C 108 20, 110 23, 110 27 L 110 41 Z"
        fill="{CASE_DARK}" stroke="{CASE_DARK}" stroke-width="2" stroke-linejoin="round"/>
  <rect x="76" y="26" width="28" height="5" rx="2.5" fill="{CASE}"/>
  <path d="M74 135 C 80 152, 102 152, 106 134 Z" fill="{GREEN}" stroke="{GREEN_DARK}" stroke-width="3" stroke-linejoin="round"/>
  <!-- The body -->
  <path d="{BODY}" fill="{CASE}" stroke="{CASE_DARK}" stroke-width="3.5" stroke-linejoin="round"/>
  <!-- The screen with its code -->
  <rect x="44" y="62" width="82" height="54" rx="6" fill="{SCREEN}" stroke="{CASE_DARK}" stroke-width="2"/>
  {lines}
  <!-- Status LEDs: run, I/O, error -->
  <circle cx="58" cy="52" r="3.5" fill="{GREEN}"/>
  <circle cx="70" cy="52" r="3.5" fill="#ffcc33"/>
  <circle cx="82" cy="52" r="3.5" fill="#ff5a4f" fill-opacity="0.35"/>
  <!-- Terminal screws along the bottom, like gills -->
  <circle cx="60" cy="126" r="3" fill="{CASE_DARK}"/>
  <circle cx="74" cy="126" r="3" fill="{CASE_DARK}"/>
  <circle cx="88" cy="126" r="3" fill="{CASE_DARK}"/>
  <!-- The eye -->
  <circle cx="30" cy="80" r="6.5" fill="#ffffff"/>
  <circle cx="29" cy="81" r="3.8" fill="{CASE_DARK}"/>
  <circle cx="30.5" cy="79.5" r="1.4" fill="#ffffff"/>
</svg>
'''


open("icons/codesysfish.svg", "w").write(build())
print("wrote icons/codesysfish.svg")
