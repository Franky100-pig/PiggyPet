#!/usr/bin/env python3
"""Build the app icon (.icns) from the source artwork.

The source is a 1080×1080 sleeping-pig illustration with a caption underneath.
Only the pig is wanted, so the caption is cropped off, the artwork is placed on
a white rounded square (Apple's icon grid: 824 pt of content inside a 1024 pt
canvas) and every size macOS asks for is written into an .iconset, then compiled
with `iconutil`.

Usage: python3 scripts/make_icon.py [source.png]
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/.source/custom/pig-icon.png"
OUT_ICNS = ROOT / "Resources/PiggyPet.icns"

CANVAS = 1024
MARGIN = 100          # transparent border around the rounded square
RADIUS = 186          # matches Apple's squircle closely enough at icon sizes
ART_INSET = 78        # padding between the artwork and the square edge
WHITE_FLOOR = 246     # pixels at least this bright become transparent


def artwork_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of the pig, ignoring any caption below the largest gap.

    Content is measured against the white backdrop, not against luminance: the
    pig's body is pale peach and would slip under a darkness threshold, leaving
    only the eyes and snout in the crop.
    """
    flat = Image.new("RGB", image.size, (255, 255, 255))
    diff = ImageChops.difference(image.convert("RGB"), flat).convert("L")
    width, height = diff.size
    pixels = diff.load()

    rows = [
        y for y in range(height)
        if sum(1 for x in range(0, width, 2) if pixels[x, y] > 12) > 2
    ]
    if not rows:
        raise SystemExit("no artwork found in the source image")

    # Split the drawing from the caption: a wide empty band separates them, and
    # the pig is the taller of the resulting groups.
    groups: list[list[int]] = [[rows[0]]]
    for y in rows[1:]:
        if y - groups[-1][-1] > 30:
            groups.append([y])
        else:
            groups[-1].append(y)
    pig = max(groups, key=lambda group: group[-1] - group[0])
    top, bottom = pig[0], pig[-1]

    columns = [
        x for x in range(width)
        if any(pixels[x, y] > 12 for y in range(top, bottom + 1, 2))
    ]
    return (columns[0], top, columns[-1] + 1, bottom + 1)


def transparent_white(image: Image.Image) -> Image.Image:
    """Turn the flat white backdrop into transparency so edges blend cleanly."""
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b, a = pixels[x, y]
            if r >= WHITE_FLOOR and g >= WHITE_FLOOR and b >= WHITE_FLOOR:
                pixels[x, y] = (r, g, b, 0)
    return image


def build_master() -> Image.Image:
    source = Image.open(SOURCE).convert("RGB")
    art = source.crop(artwork_bounds(source))
    art = transparent_white(art)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    # Soft rounded square, very slightly warm so it does not read as a hole in
    # light docks while still letting the illustration sit on white.
    plate = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(plate)
    draw.rounded_rectangle(
        (MARGIN, MARGIN, CANVAS - MARGIN - 1, CANVAS - MARGIN - 1),
        radius=RADIUS,
        fill=(255, 255, 255, 255),
    )
    canvas.alpha_composite(plate)

    # Fit the artwork inside the plate, centred.
    box = CANVAS - 2 * (MARGIN + ART_INSET)
    scale = min(box / art.width, box / art.height)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(
        art, ((CANVAS - art.width) // 2, (CANVAS - art.height) // 2)
    )
    return canvas


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing source artwork: {SOURCE}")

    master = build_master()
    master.save(ROOT / "Resources/icon-1024.png")

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "PiggyPet.iconset"
        iconset.mkdir()
        for size in sizes:
            icon = master.resize((size, size), Image.LANCZOS)
            if size <= 512:
                icon.save(iconset / f"icon_{size}x{size}.png")
            # 1024 doubles as the @2x variant of 512.
            if size in (32, 64, 256, 512, 1024):
                base = size // 2
                icon.save(iconset / f"icon_{base}x{base}@2x.png")
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(OUT_ICNS)],
            check=True,
        )

    print(f"wrote {OUT_ICNS.relative_to(ROOT)} "
          f"({OUT_ICNS.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
