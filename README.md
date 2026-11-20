# PiggyPet

A tiny macOS desktop pet: sleeps in the corner, turns into random pig memes or Chinese text when clicked, follows your cursor when dragged, and occasionally throws a tiny tantrum that nudges your mouse.

> **Status:** early development. Assets are sourced from the community PigHub-DB repository, which does **not** declare a license. They are included for local/personal use only — see [docs/assets-license.md](docs/assets-license.md).

## Highlights

- Native Swift / AppKit — no Electron, no Chromium, binary ~100 KB
- Borderless transparent floating panel, no Dock icon
- Pixel-accurate click-through: transparent parts of the sprite pass clicks to the app underneath
- Sleep state, tap-to-switch (image or text), drag-to-move, position memory
- Chinese speech bubbles and a right-click menu to disable the mischievous behavior

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
