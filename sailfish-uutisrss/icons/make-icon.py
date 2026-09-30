#!/usr/bin/env python3
"""Generates the UutisRSS icon: a newspaper front page with the logo.

The logo is "Uutis" on the first row and "RSS" on the second, drawn as
geometric strokes (no font) so the t of "Uutis" and the R of "RSS" can
share one continuous stem: the t runs straight down into the R.
Everything is dark blue on a white page, including the column lines.
Run: python3 icons/make-icon.py  (then rsvg-convert makes the PNGs)
"""

BLUE = "#0b2e63"
W = 6.5            # letter stroke width

# Page: a portrait front page with a folded top-right corner.
PX0, PY0, PX1, PY1 = 26, 10, 146, 162
FOLD = 18

# Rows: cap height 24, x-height 17.
R1_TOP, R1_BASE = 26, 52            # "Uutis"
R1_X = R1_BASE - 17                 # x-height top of row 1
R2_TOP, R2_BASE = 62, 88            # "RSS"


def stroke(d, width=W, cap="round"):
    return (f'<path d="{d}" fill="none" stroke="{BLUE}" stroke-width="{width}" '
            f'stroke-linecap="{cap}" stroke-linejoin="round"/>')


def U(x, top, base, w=16):
    r = w / 2
    return stroke(f"M{x} {top} V{base - r} A{r} {r} 0 0 0 {x + w} {base - r} V{top}")


def u(x, top, base, w=13):
    r = w / 2
    return stroke(f"M{x} {top} V{base - r} A{r} {r} 0 0 0 {x + w} {base - r} M{x + w} {top} V{base}")


def i_(x, top, base):
    return stroke(f"M{x} {top} V{base}") + \
        f'<circle cx="{x}" cy="{top - 7}" r="{W * 0.62:.2f}" fill="{BLUE}"/>'


def s_(x, top, base, w=13):
    """A lowercase s from two half-loops."""
    h = base - top
    m = top + h / 2
    return stroke(f"M{x + w} {top + h * 0.18} "
                  f"C{x + w * 0.8} {top - h * 0.02}, {x + w * 0.05} {top}, {x + w * 0.05} {top + h * 0.26} "
                  f"C{x + w * 0.05} {m}, {x + w} {m - h * 0.04}, {x + w} {base - h * 0.26} "
                  f"C{x + w} {base}, {x + w * 0.2} {base + h * 0.02}, {x} {base - h * 0.18}")


def S(x, top, base, w=14):
    return s_(x, top, base, w)


def R_bowl_and_leg(x, top, base, w=15):
    """R without its stem (the stem is shared with the t)."""
    mid = top + (base - top) * 0.52
    r = (mid - top) / 2
    bowl = stroke(f"M{x} {top} H{x + w - r} A{r} {r} 0 0 1 {x + w - r} {mid} H{x}")
    leg = stroke(f"M{x + w * 0.45} {mid} L{x + w} {base}")
    return bowl + leg


def build():
    # Row 1 letter positions ("Uutis"), then row 2 hangs off the t's stem.
    # Widths: U 16, u 13, R 15, S 14; the whole logo (a .. end of "RSS",
    # plus stroke) is centred on the page.
    logo_w = (16 + 6 + 13 + 8) + (15 + 6 + 14 + 6 + 14) + W
    a = (PX0 + PX1) / 2 - logo_w / 2 + W / 2    # left edge of U
    ux = a + 16 + 6              # u
    tx = ux + 13 + 8             # t stem x (shared with R)
    ix = tx + 10                 # i
    sx = ix + 7                  # s
    rssx = tx                    # R stem = t stem

    parts = []
    parts.append(U(a, R1_TOP, R1_BASE))
    parts.append(u(ux, R1_X, R1_BASE))
    # The joined stem: t from its top straight down to the R's baseline.
    parts.append(stroke(f"M{tx} {R1_TOP + 2} V{R2_BASE}"))
    parts.append(stroke(f"M{tx - 6} {R1_X} H{tx + 7}"))            # t crossbar
    parts.append(i_(ix, R1_X, R1_BASE))
    parts.append(s_(sx, R1_X, R1_BASE))
    parts.append(R_bowl_and_leg(rssx, R2_TOP, R2_BASE))
    parts.append(S(rssx + 15 + 6, R2_TOP, R2_BASE))
    parts.append(S(rssx + 15 + 6 + 14 + 6, R2_TOP, R2_BASE))

    # Newspaper details, all dark blue: short text lines beside "RSS",
    # a rule under the masthead, and two columns of text lines.
    # Everything aligns to the logo's edges: same margin left and right.
    left = a - W / 2
    right = PX1 - (left - PX0)
    lines = []
    for k in range(3):
        y = R2_TOP + 4 + k * 9
        lines.append(f'<line x1="{left:.1f}" y1="{y}" x2="{tx - 10:.1f}" y2="{y}"/>')
    rule_y = R2_BASE + 11
    lines.append(f'<line x1="{left:.1f}" y1="{rule_y}" x2="{right:.1f}" y2="{rule_y}" stroke-width="3.5"/>')
    col_mid = (PX0 + PX1) / 2
    for k in range(5):
        y = rule_y + 11 + k * 9
        lines.append(f'<line x1="{left:.1f}" y1="{y}" x2="{col_mid - 5}" y2="{y}"/>')
        right_end = right if k < 4 else col_mid + 26      # last line short
        lines.append(f'<line x1="{col_mid + 5}" y1="{y}" x2="{right_end:.1f}" y2="{y}"/>')
    detail = (f'<g stroke="{BLUE}" stroke-width="3" stroke-linecap="round">\n    '
              + "\n    ".join(lines) + "\n  </g>")

    page = (f"M{PX0} {PY0} H{PX1 - FOLD} L{PX1} {PY0 + FOLD} V{PY1} H{PX0} Z")
    fold = f"M{PX1 - FOLD} {PY0} V{PY0 + FOLD} H{PX1}"

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 172 172">
  <path d="{page}" fill="#ffffff" stroke="{BLUE}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="{fold}" fill="none" stroke="{BLUE}" stroke-width="3" stroke-linejoin="round"/>
  {detail}
  {"".join(parts)}
</svg>
'''


open("icons/uutisrss.svg", "w").write(build())
print("wrote icons/uutisrss.svg")
