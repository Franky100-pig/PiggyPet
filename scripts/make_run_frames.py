#!/usr/bin/env python3
"""Turn PigHub's `快跑猪.gif` (276 frames) into a transparent pose sequence.

The pig's legs/body wiggle while the whole subject stays put, so every frame
is cropped with the SAME union bbox (otherwise it jitters). Frames are sampled
evenly across the GIF to keep the animation short but faithful.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

from process_assets import dewhite

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "assets" / ".source" / "custom" / "快跑猪.gif"
OUT_DIR = ROOT / "Resources" / "run"

REPO = "BadFish-HSrui/PigHub-DB"
ASSET = "data/快跑猪.gif"
REF = "master"

CANVAS = 160
CONTENT = 144
SAMPLE_FRAMES = 20


def download_source() -> None:
    if CACHE.exists() and CACHE.stat().st_size > 100_000:
        print(f"Using cached {CACHE}")
        return
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {ASSET} from {REPO} via gh api ...")
    result = subprocess.run(
        ["gh", "api", "-H", "Accept: application/vnd.github.raw",
         f"repos/{REPO}/contents/{ASSET}?ref={REF}"],
        capture_output=True, check=True,
    )
    CACHE.write_bytes(result.stdout)
    print(f"Saved {CACHE} ({len(result.stdout)} bytes)")


def union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [f.getchannel("A").getbbox() for f in frames]
    boxes = [b for b in boxes if b is not None]
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

    with Image.open(CACHE) as gif:
        total = getattr(gif, "n_frames", 1)
        picks = [round(i * (total - 1) / (SAMPLE_FRAMES - 1)) for i in range(SAMPLE_FRAMES)]
        frames: list[Image.Image] = []
        for idx in picks:
            gif.seek(idx)
            frames.append(dewhite(gif.convert("RGBA")))
        print(f"sampled {len(frames)} of {total} frames: {picks}")

    box = union_bbox(frames)
    print(f"union bbox {box}")
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
