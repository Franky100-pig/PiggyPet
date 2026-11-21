# PiggyPet 0.1.0

First downloadable release for macOS 13+. One Universal zip covers both Apple Silicon and Intel Macs.

## What's inside

- Sleeping pig in the bottom-left corner; left-click switches between pig meme images and Chinese text bubbles
- Drag to move, with the position remembered between launches
- Walking animation with an occasional 1–3 minute stroll, plus **到处逛逛** / **追着鼠标** in the right-click menu
- Optional mischief mode (off by default): the pig runs over and nudges your cursor using `CGWarpMouseCursorPosition` — no Accessibility permission needed
- Borderless transparent floating panel, no Dock icon, pixel-accurate click-through
- Right-click menu: switch face, stroll, chase cursor, mischief mode, bubble text, return to bottom-left, quit

## Install

1. Download `PiggyPet-0.1.0-universal.zip` and unzip it.
2. Move `PiggyPet.app` to `/Applications` (optional but recommended).
3. The app is ad-hoc signed, not notarized, so remove the download quarantine flag once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/PiggyPet.app
   ```

   Prefer no Terminal? Right-click the app → **Open** → **Open** instead.

4. Double-click to launch. There is no Dock icon — look for the sleeping pig just above the Dock on the left, and right-click it for the menu.

Verify your download with the SHA-256 in `PiggyPet-0.1.0-checksums.txt`.

## Notes

- Built with `scripts/release.sh`: separate arm64 and x86_64 slices joined by `lipo`, minimum OS macOS 13.0, ad-hoc code signature.
- Pig images come from [PigHub-DB](https://github.com/BadFish-HSrui/PigHub-DB), which declares no license. They are bundled here for personal / non-commercial use only. Replace the artwork before redistributing the app more widely.
- Source code is MIT licensed; the image assets are not covered by that license.
