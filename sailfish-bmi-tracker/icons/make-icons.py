#!/usr/bin/env python3
"""Generates the app icon and the cover's background gauge.

Geometry is computed, not hand-drawn, so it stays exactly symmetrical:
a half-circle gauge centred on the icon, split into four equal 45° segments
(blue, green, yellow, red) with identical gaps, and a needle pointing at the
middle of the green "normal" segment.
Run: python3 icons/make-icons.py  (then rsvg-convert makes the PNGs)
"""
import math

COLORS = ["#3987e5", "#0ca30c", "#fab219", "#d03b3b"]  # under, normal, over, obese


def point(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy - r * math.sin(a)


def gauge(cx, cy, r, width, gap_deg, needle_len, needle_color, hub_r, opacity=1.0):
    parts = []
    for i, color in enumerate(COLORS):
        start = 180 - i * 45 - gap_deg / 2 * (i > 0)
        end = 180 - (i + 1) * 45 + gap_deg / 2 * (i < 3)
        x1, y1 = point(cx, cy, r, start)
        x2, y2 = point(cx, cy, r, end)
        parts.append(f'<path d="M{x1:.2f} {y1:.2f} A{r} {r} 0 0 1 {x2:.2f} {y2:.2f}" '
                     f'stroke="{color}" stroke-width="{width}" fill="none" '
                     f'stroke-linecap="butt" opacity="{opacity}"/>')
    nx, ny = point(cx, cy, needle_len, 180 - 45 - 22.5)  # middle of green
    parts.append(f'<line x1="{cx}" y1="{cy}" x2="{nx:.2f}" y2="{ny:.2f}" stroke="{needle_color}" '
                 f'stroke-width="{width * 0.4:.1f}" stroke-linecap="round" opacity="{opacity}"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{hub_r}" fill="{needle_color}" opacity="{opacity}"/>')
    return "\n  ".join(parts)


# App icon: white disc with a soft grey rim, gauge and "BMI" centred.
icon = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 172 172">
  <circle cx="86" cy="86" r="84" fill="#ffffff"/>
  <circle cx="86" cy="86" r="83" fill="none" stroke="#d5d9df" stroke-width="2"/>
  {gauge(86, 96, 54, 17, 5, 44, "#2d3440", 9)}
  <text x="86" y="138" text-anchor="middle" font-family="sans-serif" font-weight="700"
        font-size="28" fill="#2d3440" letter-spacing="3">BMI</text>
</svg>
'''
open("icons/harbour-bmitracker.svg", "w").write(icon)

# Cover background: the same gauge alone, drawn faintly by the cover.
cover = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 120">
  {gauge(100, 104, 84, 22, 5, 70, "#8a93a0", 11)}
</svg>
'''
open("qml/images/cover-gauge.svg", "w").write(cover)
print("wrote icons/harbour-bmitracker.svg and qml/images/cover-gauge.svg")
