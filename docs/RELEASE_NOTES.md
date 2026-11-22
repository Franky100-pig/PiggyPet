# PiggyPet 1.1.0

PiggyPet runs on Windows now.

## What's new in 1.1.0

- **A native Windows build.** Not the Mac app in a wrapper: AppKit and Win32 share no window model, so the pet was ported to C# / WinForms on .NET Framework 4.8 — the runtime that already ships with Windows 10 (1903+) and Windows 11. The exe is ~130 KB and the zip is under 2 MB, because there is no bundled runtime, no Electron and no installer. Unzip, double-click `PiggyPet.exe`.
- **The same pig, the same rules.** All 35 faces, the generated 3–5 leg strolls with filleted corners, the no-vertical-legs rule, the excitement/pace/nudge menu, the breathing Zzz, the 10–15 s return to sleep, and the one-time first-run hint. Both builds read the same `Resources/` folder, so artwork changes apply to both.
- **Windows-native plumbing.** A layered window with per-pixel alpha for the transparent background, `WM_NCHITTEST` returning `HTTRANSPARENT` so clicks pass through the pig's transparent corners, `SetCursorPos` for nudges (no permission prompt), and `HKCU\...\Run` for 开机自启 — switchable off from the menu at any time.
- **macOS 1.1.0 is behaviour-identical to 1.0.1.** It is rebuilt only so both platforms share a version number and a release page.

### About the Windows build's maturity

The Windows port is compile-verified on `windows-latest` and its platform-independent logic (manifest, sprite files, stroll geometry, arc-length walking) is covered by checks that run on the build machine — 400 random routes, no vertical legs, worst turn 5.6°, nothing off-screen.

The parts that need a real Windows desktop — layered-window rendering, click-through, DPI scaling, the context menu, SmartScreen, the registry login item — have not been run on Windows hardware yet. Treat this as the first cut: if something is off, `%TEMP%\piggy-error.log` and `%TEMP%\piggy-debug.log` (`--debug`) are what to attach to an issue.

# PiggyPet 1.0.1

First patch on top of 1.0.0. No behaviour changes to strolls, expressions or the
menu layout — only the rough edges found while re-reading the 1.0.0 sources.

## What's fixed in 1.0.1

- **The Zzz breathes again.** The sleep pulse was a one-shot timer, so the Zzz dimmed once about a second after the pig fell asleep and then stayed dim for the whole nap. It now alternates slowly while the pig sleeps and stops the moment it wakes.
- **The pig comes back when displays change.** Unplugging an external monitor (or rearranging screens) could leave it parked outside the new desktop until the next launch. It now re-clamps itself as soon as the screen layout changes, and saves the corrected spot.
- **About PiggyPet.** New entry at the bottom of the right-click menu: version, build number, a one-line reminder of the controls, and a button to open the project page. Until now there was no way to see which version was running.
- **First run says hello.** A fresh install gets one speech bubble — 「点我换表情，右键设置」 — because nothing on screen suggests the pig has a menu or can be clicked at all. It is shown once and never again; upgrading users already know and do not see it.
- **One pig only.** Launching a second copy (double-clicking another unzipped copy, `open -n`) no longer puts two pigs on screen fighting over the same saved position: the newcomer quits immediately.
- Finder's Get Info now has a category and a copyright line for the bundle.
- The install steps below were still telling people to download `0.4.2`.

## What's in 1.0.0

Universal build for macOS 13+, covering both Apple Silicon and Intel Macs.

**First stable release.** Behaviour is settled, settings are all reachable from
the right-click menu, and there is a real app icon and login item. Nothing here
is expected to change shape again; later versions will be additive.

## What's new in 1.0.0

- **A real app icon.** The sleeping pig now shows up in Finder, the Dock and the Login Items list, drawn on Apple's icon grid (824 pt of art inside a 1024 pt canvas) with every size from 16 to 1024. `scripts/make_icon.py` rebuilds it from the source artwork and crops the caption off automatically.
- **Launch at login, and a switch to turn it off.** The first launch registers PiggyPet with `SMAppService.mainApp`, so it greets you when the Mac starts. The right-click menu gained **开机自启**: toggle it off and it stays off — the app records that you made a choice and never re-enables it behind your back. If macOS parks the registration behind its approval switch, a speech bubble tells you to allow it in System Settings.
- The menu check mark is read live from the system, so turning the pig off in System Settings → General → Login Items is reflected in the menu instead of showing a stale state.

### What is in the box

- A sleeping pig above the Dock: no Dock icon, no window chrome, transparent corners that pass clicks through to whatever is underneath.
- Tap it to swap expression (35 in the pool, including five text jokes); drag it anywhere and it remembers where it fell asleep.
- Generated strolls with no two trips alike, tuned by **兴奋程度** (低 / 中 / 高) and **走路速度** (慢悠悠 / 正常 / 利索).
- **拱鼠标频率** (从不 / 偶尔 / 经常) for the occasional cursor nudge, plus a manual **追着鼠标** — the only place the fast 快跑猪 animation appears.
- Speech bubbles, **调皮模式**, **气泡文字**, **开机自启**, **回到左下角** and **退出 PiggyPet** in the right-click menu.

## Also in 0.7.0

- **Strolls are generated, not templated.** The route used to be one fixed silhouette — walk out, half-circle at the far end, walk back to exactly where it started — with only length, radius and offset randomised. Every trip therefore looked the same. Each outing is now built leg by leg: 3–5 legs, each rolling its own length (150–310 pt) and its own gentle climb or drop, so the shape, the distance and the stopping point differ every time.
- **No more coming home.** The pig stops wherever the trip ends and starts the next one from there. It drifts around the screen instead of repeatedly looping back to the same corner, and the position is remembered across relaunches.
- **Still no vertical legs, still no sharp turns.** Each leg is held within ±33° of horizontal, and every corner is filleted with a 40–85 pt arc, so the pig always reads as walking: max 16° of heading change per animation step, zero near-vertical samples across all test runs.
- **Walks away from walls.** Left/right is weighted by open space (and forced away from an edge closer than 320 pt), so it stops hugging whichever wall it happens to fall asleep next to.

## Also in 0.6.0

- **Wider wanderings.** A stroll now ranges roughly 380–620 pt from home instead of 260–400 pt, and it turns away from whichever screen edge is nearest, so the pig never walks itself half off the screen.
- **No more pivot turns.** The old route walked straight legs and changed direction on the spot at each waypoint. Each outing now walks out on one lane, swings through a half-circle (radius 55–85 pt) at the far end, and ambles home on a shallow diagonal at a different height — so it never retraces its steps and never snaps around.
- **Fixed:** the legs stopped pedalling while the pig was on a curve, and the sprite twitched as it went. The window now follows the whole route in a single pass instead of restarting a walk for each sample point, so the animation runs non-stop and the facing only flips once per turn.

## Also in 0.5.0

- **Adjustable walking pace.** New right-click submenu **走路速度** with 慢悠悠 / 正常 / 利索 (about 48 / 80 / 120 pt per second). The default is 正常, and switching takes effect on the next stroll.
- **The angry running pig is animated now.** 快跑猪 is pulled from the 276-frame GIF as a 20-frame cycle, so a chase reads as a real sprint (170 pt/s) instead of a still image. It is used only when the pig is angry and chasing your cursor — normal strolls keep the calm walking animation.
- Legs now keep pace with the body: the animation advances faster during a dash and slower during a saunter, so the pig no longer looks like it is sliding across the screen.

## Also in 0.4.2

- Stroll routes are now generated fresh every time — the number of turns, the distance and the lane heights are all randomized, so no two walks follow the same path. Two rules always hold: every leg has real horizontal travel (no vertical elevator movement), and the walk ends exactly where it started. Outbound and inbound turns are biased to different heights, so it never retraces one line or draws a circle.

## Also in 0.4.1

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
- Walking and running animations with a long automatic stroll that walks out and back on a slightly different line; frequency follows the excitement level, plus **到处逛逛** / **追着鼠标** in the right-click menu
- Right-click submenus **兴奋程度** (低 / 中 / 高), **拱鼠标频率** (从不 / 偶尔 / 经常) and **走路速度** (慢悠悠 / 正常 / 利索)
- Optional mischief mode (off by default): the pig runs over and nudges your cursor using `CGWarpMouseCursorPosition` — no Accessibility permission needed
- Borderless transparent floating panel, no Dock icon, pixel-accurate click-through
- Right-click menu: switch face, stroll, chase cursor, mischief mode, bubble text, return to bottom-left, quit

## Install

1. Download `PiggyPet-1.0.1-universal.zip` and unzip it.
2. Move `PiggyPet.app` to `/Applications` (optional but recommended).
3. The app is ad-hoc signed, not notarized, so remove the download quarantine flag once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/PiggyPet.app
   ```

   Prefer no Terminal? Right-click the app → **Open** → **Open** instead.

4. Double-click to launch. There is no Dock icon — look for the sleeping pig just above the Dock on the left, and right-click it for the menu.

Verify your download with the SHA-256 in `PiggyPet-1.0.1-checksums.txt`.

## Notes

- Built with `scripts/release.sh`: separate arm64 and x86_64 slices joined by `lipo`, minimum OS macOS 13.0, ad-hoc code signature.
- Pig images come from [PigHub-DB](https://github.com/BadFish-HSrui/PigHub-DB), which declares no license. They are bundled here for personal / non-commercial use only. Replace the artwork before redistributing the app more widely.
- Source code is MIT licensed; the image assets are not covered by that license.
