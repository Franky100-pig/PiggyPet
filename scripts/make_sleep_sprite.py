#!/usr/bin/env python3
"""Build the custom sleeping pig sprite from the user-provided meme screenshot.

Removes the paper ticket on the pig's back, keeps the pink pig only, writes a
transparent 160x160 sprite to Resources/custom/sleep.png.
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from process_assets import dewhite, keep_largest_subject, remove_purple

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = Path(
    "/Users/franky100/.workbuddy/clipboard-images/"
    "clipboard-2026-11-20T14-49-58-417Z-639d937f.png"
)
OUT = ROOT / "Resources" / "custom" / "sleep.png"

# Ticket area in the 640x573 source image (with a small margin for its shadow).
TICKET = (370, 96, 566, 372)


def is_pink(p: tuple[int, ...]) -> bool:
    r, g, b = p[:3]
    return r > 170 and r > g + 30 and r > b + 30


def remove_ticket(img: Image.Image) -> Image.Image:
    """Diffuse surrounding pink pigment into the ticket area (Laplace fill)."""
    arr = np.asarray(img.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    x0, y0, x1, y1 = TICKET
    mask = np.zeros((h, w), dtype=bool)
    mask[y0:y1, x0:x1] = True

    pink_all = (
        (arr[..., 0] > 170)
        & (arr[..., 0] > arr[..., 1] + 30)
        & (arr[..., 0] > arr[..., 2] + 30)
    )
    pink = np.mean(arr[pink_all], axis=0) if pink_all.any() else np.mean(arr[y0:y1, x0:x1], axis=(0, 1))
    source = arr.copy()
    source[~pink_all] = pink
    filled = source.copy()

    for _ in range(400):
        total = np.zeros_like(filled)
        count = np.zeros((h, w), dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ty0, ty1 = max(0, dy), min(h, h + dy)
            tx0, tx1 = max(0, dx), min(w, w + dx)
            sy0, sy1 = max(0, -dy), min(h, h - dy)
            sx0, sx1 = max(0, -dx), min(w, w - dx)
            total[ty0:ty1, tx0:tx1] += filled[sy0:sy1, sx0:sx1]
            count[ty0:ty1, tx0:tx1] += 1
        filled[mask] = (total / np.maximum(count, 1)[..., None])[mask]

    arr[mask] = filled[mask]
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def pink_subject(img: Image.Image) -> Image.Image:
    w, h = img.size
    px = img.load()
    mask = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if r > 170 and r > g + 30 and r > b + 30:
                mask[y * w + x] = 1

    # Mark pixels connected to the border as outside; everything else enclosed
    # by pink (eyes, folds) becomes part of the pig.
    outside = bytearray(w * h)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))
    while queue:
        x, y = queue.popleft()
        idx = y * w + x
        if outside[idx]:
            continue
        if mask[idx]:
            continue
        outside[idx] = 1
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                queue.append((nx, ny))

    for idx in range(w * h):
        if not outside[idx]:
            x, y = idx % w, idx // w
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 255)
        else:
            x, y = idx % w, idx // w
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
    return img


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    with Image.open(source) as opened:
        img = opened.convert("RGBA")

    if source == DEFAULT_SOURCE:
        img = remove_ticket(img)
        img = img.crop((60, 70, 600, 465))
        img = pink_subject(img)
    else:
        # Sticker-style source: strip purple template corners/caption and white
        # background, then keep the pig (and its pillow) as one subject.
        img.thumbnail((600, 600), Image.LANCZOS)
        img = remove_purple(img)
        img = dewhite(img)
        img = keep_largest_subject(img)

    # Feather only the alpha channel.
    alpha = img.getchannel("A").filter(ImageFilter.GaussianBlur(1.2))
    img.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("no pig pixels found")
    img = img.crop(bbox)
    img.thumbnail((144, 144), Image.LANCZOS)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((160 - img.width) // 2, (160 - img.height) // 2))
    canvas.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
