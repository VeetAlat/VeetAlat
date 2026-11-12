#!/usr/bin/env python3
"""Makes the test photos in tests/fixtures (run from the project folder).

landscape.png: 1200 x 800, the left half red, the right half blue.
rotated.jpg:   stored 800 x 600, top half yellow, bottom half purple, with
               EXIF orientation 6 ("turn 90 degrees clockwise"), as phone
               cameras save upright photos: shown 600 x 800, purple on
               the left, yellow on the right.
"""
from PIL import Image

RED, BLUE, YELLOW, PURPLE = (220, 40, 40), (40, 60, 220), (230, 200, 40), (120, 40, 160)

img = Image.new("RGB", (1200, 800), RED)
img.paste(Image.new("RGB", (600, 800), BLUE), (600, 0))
img.save("tests/fixtures/landscape.png")

img = Image.new("RGB", (800, 600), YELLOW)
img.paste(Image.new("RGB", (800, 300), PURPLE), (0, 300))
exif = Image.Exif()
exif[0x0112] = 6
img.save("tests/fixtures/rotated.jpg", quality=95, exif=exif.tobytes())
print("made tests/fixtures/landscape.png and rotated.jpg")
