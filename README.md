# PiggyPet

A tiny macOS desktop pet: sleeps in the corner, turns into random pig memes or Chinese text when clicked, follows your cursor when dragged, and occasionally throws a tiny tantrum that nudges your mouse.

> **Status:** early development. Assets are sourced from the community PigHub-DB repository, which does **not** declare a license. They are included for local/personal use only — see [docs/assets-license.md](docs/assets-license.md).

## Highlights

- Native Swift / AppKit — no Electron, no Chromium, binary ~100 KB
- Borderless transparent floating panel, no Dock icon
- Pixel-accurate click-through: transparent parts of the sprite pass clicks to the app underneath
- Sleep state, tap-to-switch (image or text), drag-to-move, position memory
- Chinese speech bubbles and a right-click menu to disable the mischievous behavior
- Excitement level (低 / 中 / 高) in the menu controls how often it wanders off on its own
- Automatic activity is mostly a casual stroll; 拱鼠标频率 (从不 / 偶尔 / 经常) sets how often it becomes a cursor nudge instead (default 偶尔, ~20%). Manual 追着鼠标 always nudges.
- 走路速度 (慢悠悠 / 正常 / 利索) sets how fast it ambles. Only an angry chase uses the fast 快跑猪 running animation.

## Download (macOS 13+)

Grab `PiggyPet-<version>-universal.zip` from the [Releases page](https://github.com/Franky100-pig/PiggyPet/releases/latest). One zip works on both Apple Silicon and Intel Macs.

1. Unzip and move `PiggyPet.app` to `/Applications` (optional).
2. Remove the download quarantine flag — the app is ad-hoc signed, not notarized:

   ```bash
   xattr -dr com.apple.quarantine /Applications/PiggyPet.app
   ```

   No Terminal? Right-click the app → **Open** → **Open** instead.

3. Double-click to launch. There is no Dock icon: the pig sleeps just above the Dock on the left. Right-click it for the menu.

Check the download against the SHA-256 in `PiggyPet-<version>-checksums.txt`.

## Build & run

```bash
./scripts/build.sh     # produces build/PiggyPet.app
./scripts/run.sh       # builds and launches it
```

Requires macOS 13+ and Xcode/Swift. Python 3 + Pillow are only needed to regenerate the sprite assets.

## Project layout

- `Sources/PiggyPet/` — Swift sources
- `Resources/` — Info.plist template, manifest and processed sprites
- `scripts/` — build/run and asset preparation scripts
- `docs/assets-license.md` — asset provenance and licensing notes

## License

Source code is MIT (see [LICENSE](LICENSE)). Pig images are **not** covered by that license.
