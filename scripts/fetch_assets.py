#!/usr/bin/env python3
"""Fetch a small, curated subset of pig memes from PigHub-DB via the GitHub API.

The upstream repo does not declare a license; files stay in assets/.source/ and
are never committed. Only processed sprites under Resources/ are checked in.
"""

from __future__ import annotations

import base64
import json
import random
import subprocess
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / ".source" / "raw"
REPO = "BadFish-HSrui/PigHub-DB"
MAX_BYTES = 700_000
TOTAL = 48

KEYWORDS = {
    "sleep": ["睡", "sleep", "zzz"],
    "angry": ["怒", "生气", "气猪", "哼", "邪恶", "恶魔", "暴躁", "发火"],
    "happy": ["笑", "开心", "快乐", "可爱", "萌"],
}


def gh_api(*args: str) -> str:
    result = subprocess.run(
        ["gh", "api", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def mood_for(name: str) -> str:
    lowered = name.lower()
    for mood, words in KEYWORDS.items():
        if any(word in lowered for word in words):
            return mood
    return "neutral"


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    tree = json.loads(gh_api(f"repos/{REPO}/git/trees/HEAD?recursive=1"))
    candidates = [
        item
        for item in tree["tree"]
        if item.get("path", "").startswith("data/")
        and Path(item["path"]).suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".gif"}
        and item.get("size", 0) < MAX_BYTES
    ]

    chosen: dict[str, dict] = {}
    for mood, limit in (("sleep", 8), ("angry", 9), ("happy", 10)):
        hits = [c for c in candidates if mood_for(c["path"]) == mood]
        random.Random(100 + len(chosen)).shuffle(hits)
        for item in hits[:limit]:
            chosen[item["path"]] = item

    rng = random.Random(2026)
    rest = [c for c in candidates if c["path"] not in chosen and "猪" in c["path"]]
    rng.shuffle(rest)
    for item in rest:
        if len(chosen) >= TOTAL:
            break
        chosen[item["path"]] = item

    selected = []
    for index, (path, item) in enumerate(sorted(chosen.items())):
        encoded = urllib.parse.quote(path, safe="/")
        content = gh_api(f"repos/{REPO}/contents/{encoded}?ref=HEAD", "--jq", ".content")
        ext = Path(path).suffix.lower()
        filename = f"{index:04d}{ext}"
        (SOURCE / filename).write_bytes(base64.b64decode(content))
        selected.append(
            {
                "id": "pigsleep" if path == "data/pigsleep.png" else f"pig_{index:04d}",
                "file": filename,
                "original": Path(path).name,
                "mood": mood_for(path),
            }
        )
        print(f"[{index + 1}/{len(chosen)}] {path}")

    out = ROOT / "assets" / ".source" / "selected.json"
    out.write_text(json.dumps(selected, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved {len(selected)} entries to {out}")


if __name__ == "__main__":
    main()
