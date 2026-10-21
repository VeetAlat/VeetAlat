#!/usr/bin/env python3
"""Generates the MTVFish icon: a fish whose body is an old TV set, its
screen showing a headline bar and lines of text, with a rabbit-ear antenna
for a fin, a coral tail and an eye. (No MTV logo or lettering: it's an
unofficial app.)

Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

CORAL = "#ff6f4f"
CORAL_DARK = "#c2412a"
CASE = "#2b2b45"
SCREEN = "#bfeee8"
INK = "#1c3b5a"
S = 172

# The TV body: a plump rounded box, nose to the left, tail end to the right.
BODY = ("M22 64 C 22 50, 32 42, 46 42 L 114 42 C 128 42, 136 52, 136 66 "
        "L 136 110 C 136 124, 128 132, 114 132 L 46 132 C 32 132, 22 124, 22 110 Z")
# The screen, a slightly bulging rounded rectangle inside the case.
SCREEN_PATH = ("M42 58 C 42 54, 46 52, 52 52 L 106 52 C 112 52, 116 54, 116 58 "
               "L 116 116 C 116 120, 112 122, 106 122 L 52 122 C 46 122, 42 120, 42 116 Z")


def build():
    lines = []
    # A headline bar, then lines of text, clipped to the screen.
    lines.append(f'<rect x="50" y="62" width="58" height="9" rx="4.5" fill="{INK}"/>')
    for i, w in enumerate([58, 50, 58, 44, 54]):
        lines.append(f'<rect x="50" y="{78 + i * 8.5}" width="{w}" height="4.5" rx="2.25" '
                     f'fill="{INK}" fill-opacity="0.7"/>')
    text = "\n    ".join(lines)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}">
  <defs>
    <clipPath id="screen"><path d="{SCREEN_PATH}"/></clipPath>
    <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="{SCREEN}"/>
    </linearGradient>
  </defs>
  <g transform="translate(-6 6)">
  <!-- Tail -->
  <path d="M132 87 L 160 56 C 165 72, 165 102, 160 118 Z" fill="{CORAL}" stroke="{CORAL_DARK}"
        stroke-width="3" stroke-linejoin="round"/>
  <!-- Antenna for a top fin, and a bottom fin -->
  <path d="M74 42 L 58 14" stroke="{CASE}" stroke-width="4" stroke-linecap="round"/>
  <path d="M84 42 L 104 12" stroke="{CASE}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="58" cy="14" r="5" fill="{CORAL}" stroke="{CORAL_DARK}" stroke-width="2.5"/>
  <circle cx="104" cy="12" r="5" fill="{CORAL}" stroke="{CORAL_DARK}" stroke-width="2.5"/>
  <path d="M70 132 C 76 152, 98 152, 102 132 Z" fill="{CORAL}" stroke="{CORAL_DARK}" stroke-width="3" stroke-linejoin="round"/>
  <!-- The body: a TV set -->
  <path d="{BODY}" fill="{CASE}"/>
  <path d="{SCREEN_PATH}" fill="url(#glass)"/>
  <g clip-path="url(#screen)">
    {text}
    <!-- A glint on the glass -->
    <path d="M100 54 L 116 54 L 116 70 Z" fill="#ffffff" fill-opacity="0.55"/>
  </g>
  <path d="{SCREEN_PATH}" fill="none" stroke="{CORAL}" stroke-width="2.5"/>
  <!-- Knobs on the side, like gills -->
  <circle cx="126" cy="66" r="4.5" fill="{CORAL}"/>
  <circle cx="126" cy="82" r="4.5" fill="{CORAL}"/>
  <!-- The eye, on the case by the nose -->
  <circle cx="32" cy="70" r="6" fill="#ffffff"/>
  <circle cx="31" cy="71" r="3.6" fill="{INK}"/>
  <circle cx="32.4" cy="69.4" r="1.3" fill="#ffffff"/>
  </g>
</svg>
'''


open("icons/mtvfish.svg", "w").write(build())
print("wrote icons/mtvfish.svg")
