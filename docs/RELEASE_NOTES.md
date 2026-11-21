# PiggyPet 0.4.1

Universal build for macOS 13+, covering both Apple Silicon and Intel Macs.

## What's new in 0.4.1

- Strolls now follow a four-leg route with three turns: out along one lane, diagonally up to a **different** parallel lane, back along that lane, then diagonally home. The two lanes sit 55–85 pt apart, so the pig clearly does not retrace its steps, and every connector has real horizontal travel so it never looks like a vertical elevator ride. Still no closed loops.

## Also in 0.4.0

- Strolls are now much longer (roughly 260–420 pt out, about 8 s round trip) and come back: the pig trots out, returns along a slightly different line, and angles home. It no longer walks a short distance and instantly falls asleep. Vertical drift is kept to ~15–25 pt over the whole walk, so it reads as walking flat rather than sliding up and down. No loops or retracing the exact same line.

## Also in 0.3.0

- Automatic activity now prefers a casual stroll: only a configurable fraction of the time does it turn into a cursor nudge. New right-click submenu **拱鼠标频率** (从不 / 偶尔 / 经常) controls that fraction — default 偶尔 (~20%), so the pig wanders around far more often than it pokes your mouse. Set 从不 for strolls only; the manual **追着鼠标** action still always nudges.

## Also in 0.2.2

- After switching to a new face, the pig now goes back to sleep after 10–15 seconds of no interaction (previously 8–15 s). Any click or drag restarts the wait.

## Also in 0.2.1

- Fixed clicks going dead after switching to a meme with a transparent center (notably `pig_0002`, two pigs side by side). The torso area is now always clickable, so the right-click menu can always be opened to switch away. Corners still pass clicks through, and near-edge clicks get a small tolerance.

## Also in 0.2.0

- Excitement level (低 / 中 / 高) in the right-click menu controls how often the pig wanders off on its own: low 3–5 min, medium 45–90 s, high 12–30 s. Switching levels takes effect immediately.

## What's inside

- Sleeping pig in the bottom-left corner; left-click switches between pig meme images and Chinese text bubbles
- Drag to move, with the position remembered between launches
- Walking animation with a long automatic stroll that walks out and back on a slightly different line; frequency follows the excitement level, plus **到处逛逛** / **追着鼠标** in the right-click menu
- Right-click submenus **兴奋程度** (低 / 中 / 高) and **拱鼠标频率** (从不 / 偶尔 / 经常)
- Optional mischief mode (off by default): the pig runs over and nudges your cursor using `CGWarpMouseCursorPosition` — no Accessibility permission needed
- Borderless transparent floating panel, no Dock icon, pixel-accurate click-through
- Right-click menu: switch face, stroll, chase cursor, mischief mode, bubble text, return to bottom-left, quit

## Install

1. Download `PiggyPet-0.4.1-universal.zip` and unzip it.
2. Move `PiggyPet.app` to `/Applications` (optional but recommended).
3. The app is ad-hoc signed, not notarized, so remove the download quarantine flag once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/PiggyPet.app
   ```

   Prefer no Terminal? Right-click the app → **Open** → **Open** instead.

4. Double-click to launch. There is no Dock icon — look for the sleeping pig just above the Dock on the left, and right-click it for the menu.

Verify your download with the SHA-256 in `PiggyPet-0.4.1-checksums.txt`.

## Notes

- Built with `scripts/release.sh`: separate arm64 and x86_64 slices joined by `lipo`, minimum OS macOS 13.0, ad-hoc code signature.
- Pig images come from [PigHub-DB](https://github.com/BadFish-HSrui/PigHub-DB), which declares no license. They are bundled here for personal / non-commercial use only. Replace the artwork before redistributing the app more widely.
- Source code is MIT licensed; the image assets are not covered by that license.
