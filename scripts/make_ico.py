#!/usr/bin/env python3
"""Build Resources/PiggyPet.ico (Windows app icon) from the sleeping-pig art.

The macOS build uses PiggyPet.icns; Windows needs a multi-size .ico with the
same artwork. Run this whenever the source sprite changes.
"""

import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Resources", "sprites", "sleep.png")
TARGET = os.path.join(ROOT, "Resources", "PiggyPet.ico")
SIZES = [16, 24, 32, 48, 64, 128, 256]


def main() -> None:
    art = Image.open(SOURCE).convert("RGBA")

    # Crop to the visible pixels so the pig fills the tile instead of sitting
    # in the transparent margins of the 160x160 sprite.
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)

    side = max(art.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(art, ((side - art.width) // 2, (side - art.height) // 2))

    frames = []
    for size in SIZES:
        frames.append(canvas.resize((size, size), Image.LANCZOS))

    frames[-1].save(TARGET, format="ICO", sizes=[(s, s) for s in SIZES])
    print(f"wrote {TARGET} ({os.path.getsize(TARGET)} bytes, {len(SIZES)} sizes)")


if __name__ == "__main__":
    main()
