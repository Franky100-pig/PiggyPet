#!/usr/bin/env python3
"""Turn curated raw pig memes into transparent 160x160 sprites + manifest.

Pipeline: border flood-fill dewhiting -> keep the largest connected subject
(drops meme captions and decorative corners) -> tight crop -> resize -> PNG.
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / ".source" / "raw"
SELECTED = ROOT / "assets" / ".source" / "selected.json"
OUT_DIR = ROOT / "Resources" / "sprites"
CUSTOM_SLEEP = ROOT / "Resources" / "custom" / "sleep.png"
CUSTOM_CHASE = ROOT / "assets" / ".source" / "custom" / "chase_run.jpg"
MANIFEST = ROOT / "Resources" / "manifest.json"

CANVAS = 160
CONTENT = 144
WORK_MAX = 600

BUBBLES = {
    "sleep": ["呼…呼…", "Zzz…", "别吵，在睡觉"],
    "angry": ["哼！", "再碰我试试", "猪猪生气了"],
    "happy": ["嘿嘿", "猪咪开心", "好耶！"],
    "neutral": ["嗯？", "摸鱼中…", "你叫我？"],
}

# Memes whose composition (screenshots, people, large caption panels, isolated
# fragments) does not survive cropping to a single clean pig sprite.
EXCLUDE = {
    "pigsleep.png",  # replaced by the custom ticket-free sleeping sprite
    "你是只邪恶小猪.jpeg",
    "吃了就睡睡了就吃.png",
    "我再也不会笑了(搜索版).jpg",
    "愤怒猪.jpg",
    "挡路猪.jpg",
    "洗衣机猪（舞萌猪）.jpg",
    "猪做图.jpg",
    "猪借口.jpg",
    "猪名言(哼唧！).png",
    "猪坐牢（影之诗）.jpg",
    "猪射箭.jpg",
    "猪生气.jpg",
    "猪打乌蒙(猪打舞萌).jpg",
    "猪打牌（FGO）.jpg",
    "猪搓搓背.jpg",
    "猪歪倒(睡觉).jpg",
    "猪钓鱼(星露谷).jpg",
    "猪错觉.png",
    "织猪.jpg",
}

TEXT_SPRITES = [
    ("text_01", "猪猪不开心", "angry"),
    ("text_02", "摸鱼中…", "neutral"),
    ("text_03", "哼哼哼", "angry"),
    ("text_04", "Zzz…", "sleep"),
    ("text_05", "别管我", "neutral"),
]


def near_white(p: tuple[int, int, int, int]) -> bool:
    r, g, b, a = p
    return a < 16 or (min(r, g, b) > 225 and max(r, g, b) - min(r, g, b) < 28)


def remove_purple(img: Image.Image) -> Image.Image:
    """Drop the purple corner decorations used by the PigHub sticker template."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and b > 55 and b > r * 1.15 and b > g * 1.15 and r < 170 and g < 130:
                px[x, y] = (r, g, b, 0)
    return img


def dewhite(img: Image.Image) -> Image.Image:
    """Remove background white connected to the image border only."""
    w, h = img.size
    px = img.load()
    visited = bytearray(w * h)
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
        if visited[idx]:
            continue
        visited[idx] = 1
        if not near_white(px[x, y]):
            continue
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < w:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < h:
            queue.append((x, y + 1))
    return img


def keep_largest_subject(img: Image.Image) -> Image.Image:
    """Keep the pig component; drop captions, badges and decorative corners."""
    w, h = img.size
    px = img.load()
    mask = bytearray(a > 20 for *_, a in (px[x, y] for y in range(h) for x in range(w)))
    seen = bytearray(w * h)
    components: list[dict] = []

    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        pixels: list[int] = []
        while stack:
            idx = stack.pop()
            pixels.append(idx)
            x, y = idx % w, idx // w
            for nx in (x - 1, x, x + 1):
                for ny in (y - 1, y, y + 1):
                    if nx == x and ny == y:
                        continue
                    if 0 <= nx < w and 0 <= ny < h:
                        nidx = ny * w + nx
                        if mask[nidx] and not seen[nidx]:
                            seen[nidx] = 1
                            stack.append(nidx)

        pink = 0
        cx = cy = 0
        touches_border = False
        for idx in pixels:
            x, y = idx % w, idx // w
            r, g, b, _ = px[x, y]
            if r > 140 and r > g + 18 and r > b + 10:
                pink += 1
            cx += x
            cy += y
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                touches_border = True
        n = len(pixels)
        cx /= n
        cy /= n
        center_dist = ((cx - w / 2) ** 2 + (cy - h / 2) ** 2) ** 0.5 / max(w, h)
        components.append(
            {
                "pixels": pixels,
                "area": n,
                "pink": pink / n,
                "score": n * (1 + 2.5 * pink / n) * max(0.35, 1 - center_dist),
                "border": touches_border,
            }
        )

    if not components:
        return img
    components.sort(key=lambda item: item["score"], reverse=True)
    main = components[0]
    threshold = max(80, main["area"] * 0.35)
    keep = bytearray(w * h)
    for item in components:
        if item is main:
            selected = True
        else:
            selected = not item["border"] and item["area"] >= threshold and item["pink"] > 0.12
        if not selected:
            continue
        for idx in item["pixels"]:
            keep[idx] = 1

    for idx in range(w * h):
        if not keep[idx]:
            x, y = idx % w, idx // w
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
    return img


def process_one(source: Path, destination: Path) -> None:
    with Image.open(source) as opened:
        if getattr(opened, "is_animated", False):
            opened.seek(0)
        img = opened.convert("RGBA")
    img.thumbnail((WORK_MAX, WORK_MAX), Image.LANCZOS)
    img = remove_purple(img)
    img = dewhite(img)
    img = keep_largest_subject(img)

    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"no opaque pixels left after processing {source}")
    img = img.crop(bbox)
    img.thumbnail((CONTENT, CONTENT), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((CANVAS - img.width) // 2, (CANVAS - img.height) // 2))
    canvas.save(destination, "PNG", optimize=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for stale in OUT_DIR.glob("*.png"):
        stale.unlink()
    entries = json.loads(SELECTED.read_text(encoding="utf-8"))
    sprites = []
    for index, entry in enumerate(entries):
        if entry["original"] in EXCLUDE:
            continue
        source = RAW / entry["file"]
        filename = f"{index:04d}.png"
        process_one(source, OUT_DIR / filename)
        mood = entry["mood"]
        sprites.append(
            {
                "id": entry["id"],
                "kind": "image",
                "file": f"sprites/{filename}",
                "original": entry["original"],
                "mood": mood,
                "bubble": BUBBLES[mood][index % len(BUBBLES[mood])],
            }
        )
        print(f"[{index + 1}/{len(entries)}] {entry['original']} -> {filename}")

    if CUSTOM_SLEEP.exists():
        import shutil

        shutil.copy2(CUSTOM_SLEEP, OUT_DIR / "sleep.png")
        sprites.append(
            {
                "id": "sleep",
                "kind": "image",
                "file": "sprites/sleep.png",
                "original": "user-provided 猪睡觉 meme (caption and template corners removed)",
                "mood": "sleep",
                "bubble": "呼…呼…",
            }
        )

    if CUSTOM_CHASE.exists():
        process_one(CUSTOM_CHASE, OUT_DIR / "chase.png")
        sprites.append(
            {
                "id": "chase",
                "kind": "image",
                "file": "sprites/chase.png",
                "original": "user-provided 快跑猪 (angry running pig, background removed)",
                "mood": "angry",
                "bubble": "别跑！",
            }
        )

    for sprite_id, text, mood in TEXT_SPRITES:
        sprites.append(
            {
                "id": sprite_id,
                "kind": "text",
                "text": text,
                "mood": mood,
                "bubble": BUBBLES[mood][1],
            }
        )

    manifest = {
        "version": 1,
        "spriteSize": CANVAS,
        "sleepId": "sleep" if any(s["id"] == "sleep" for s in sprites) else sprites[0]["id"],
        "sprites": sprites,
    }
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {MANIFEST} with {len(sprites)} sprites")


if __name__ == "__main__":
    main()
