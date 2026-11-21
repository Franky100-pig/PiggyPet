#!/usr/bin/env python3
"""Turn the PigHub `猪溜达.gif` walk cycle into a transparent PNG frame sequence.

Key detail: every frame is cropped with the SAME bounding box (the union of all
frames' alpha bboxes), so the pig does not jitter while the legs animate.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

from process_assets import dewhite

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "assets" / ".source" / "walk_source.gif"
OUT_DIR = ROOT / "Resources" / "walk"

REPO = "BadFish-HSrui/PigHub-DB"
ASSET = "data/猪溜达.gif"
REF = "master"

CANVAS = 160
CONTENT = 144


def download_source() -> None:
    if CACHE.exists() and CACHE.stat().st_size > 10_000:
        print(f"Using cached {CACHE}")
        return
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {ASSET} from {REPO} via gh api ...")
    result = subprocess.run(
        [
            "gh", "api",
            "-H", "Accept: application/vnd.github.raw",
            f"repos/{REPO}/contents/{ASSET}?ref={REF}",
        ],
        capture_output=True,
        check=True,
    )
    CACHE.write_bytes(result.stdout)
    print(f"Saved {CACHE} ({len(result.stdout)} bytes)")


def extract_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    with Image.open(CACHE) as gif:
        count = getattr(gif, "n_frames", 1)
        for i in range(count):
            gif.seek(i)
            frames.append(dewhite(gif.convert("RGBA")))
    return frames


def union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [f.getchannel("A").getbbox() for f in frames]
    boxes = [b for b in boxes if b is not None]
    if not boxes:
        raise RuntimeError("no opaque pixels in walk frames")
    return (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def main() -> None:
    download_source()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for stale in OUT_DIR.glob("*.png"):
        stale.unlink()

    frames = extract_frames()
    box = union_bbox(frames)
    print(f"{len(frames)} frames, union bbox {box}")

    for index, frame in enumerate(frames):
        cropped = frame.crop(box)
        cropped.thumbnail((CONTENT, CONTENT), Image.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(
            cropped, ((CANVAS - cropped.width) // 2, (CANVAS - cropped.height) // 2)
        )
        canvas.save(OUT_DIR / f"{index:03d}.png", "PNG", optimize=True)

    print(f"Wrote {len(frames)} frames to {OUT_DIR}")


if __name__ == "__main__":
    main()
