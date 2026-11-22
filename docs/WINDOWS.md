# The Windows build

PiggyPet 1.1.0 is the first Windows release. It is a **separate native
implementation**, not the macOS binary wrapped in something: AppKit and Win32
share no window model, so the pet's behaviour was ported to C# / WinForms on
.NET Framework 4.8, which ships with Windows 10 (1903+) and Windows 11.

The two builds share exactly one thing, deliberately: `Resources/` — the
manifest, the 30 sprite PNGs, the 19 walk frames and the 20 run frames. Artwork
changes apply to both platforms at once.

## Why .NET Framework 4.8

- Preinstalled on every Windows 10 1903+ and Windows 11 machine, so the download
  is a ~200 KB zip instead of a 60 MB self-contained .NET 8 bundle.
- No installer, no runtime prompt: unzip, double-click.
- Cost: the source is `net48`, so it uses the older BCL (no `System.Text.Json`,
  no `Span<T>` niceties). The manifest parser and settings writer are therefore
  hand-rolled in `Core/Json.cs` — about 150 lines, no NuGet dependency, and the
  exe stays a single file.

## How the macOS pieces map to Win32

| macOS (Swift) | Windows (C#) |
| --- | --- |
| `NSPanel` borderless, `.floating`, `LSUIElement` | `Form` + `WS_EX_LAYERED \| WS_EX_TOOLWINDOW \| WS_EX_NOACTIVATE`, `TopMost`, no taskbar button |
| `PetView.hitTest` sampling the sprite's alpha | `WM_NCHITTEST` returns `HTTRANSPARENT` when the composed canvas is transparent at the cursor |
| `NSImage.draw` in `draw(_:)` | GDI+ composition into a 32bpp ARGB bitmap, pushed with `UpdateLayeredWindow` |
| `Timer` on the main run loop | `System.Windows.Forms.Timer` (16 ms walk tick, one-shot timers for schedules) |
| `SMAppService.mainApp` login item | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value `PiggyPet` |
| `UserDefaults` | `%APPDATA%\PiggyPet\settings.json` |
| `NSScreen.visibleFrame` (bottom-left origin) | `Screen.WorkingArea` (top-left origin — Y is flipped throughout) |
| `CGWarpMouseCursorPosition` nudge | `SetCursorPos` (no Accessibility-style permission on Windows) |

Window positioning is stored as the window's top-left corner on Windows, whereas
the Mac build stores its bottom-left origin. Everything else — the 200×240
window, the 160×160 sprite at (20, 64), the 172×44 bubble, the 48/80/120 pt/s
paces, the 170 pt/s dash — is identical.

## Stroll generation

`Core/StrollPlanner.cs` is a line-for-line port of the Swift generator:

- 3–5 legs, each 150–310 pt long, heading held within ±33° of horizontal.
- Legs turn away from whichever screen edge is closer than 80 pt, and the
  up/down sign flips most legs so the wave has an irregular profile.
- The whole trip travels one way (left or right), weighted by open space, so it
  never hairpins back over itself or draws a loop.
- Corners are quadratic Bézier fillets (radius 40–85 pt, never eating more than
  45% of a leg), and the sprite-safe insets keep the pig — not the window — on
  screen: x −20…−180, y −64…−224.

## What is verified, and what is not

Verified on the build machine (macOS, via `windows/tests/PiggyPet.LogicTests`,
which compiles the platform-independent `Core/` files):

- Manifest: 35 sprites (30 images + 5 text), every referenced PNG exists, 19 walk
  frames, 20 run frames.
- 400 randomly planned strolls on a 1440×860 work area: 0 vertical legs, worst
  slope 0.66, worst per-sample turn 5.6°, every point inside the sprite-safe
  band, every trip ≥ 237 pt of sideways travel and ending ≥ 255 pt from home.
- Starting near the right wall always walks left; a 420×320 screen still gets a
  valid (short) route.
- `WalkPath` arc-length sampling, and the fillet's endpoints/NaN behaviour.

Verified by CI: the project compiles on `windows-latest` and the package is built
there, not on a Mac.

**Not verified: anything that needs a real Windows desktop.** The layered-window
rendering, per-pixel click-through, DPI scaling, the context menu, SmartScreen
behaviour and the registry login item were all written against the documented
Win32 behaviour but have not been run on Windows hardware yet. If something is
off, `%TEMP%\piggy-error.log` gets crash reports and `--debug` writes
`%TEMP%\piggy-debug.log`; please attach those to an issue.

## Building

```bash
cd windows/PiggyPet.Windows
dotnet build -c Release          # bin/Release/net48/PiggyPet.exe + assets
dotnet run --project ../tests/PiggyPet.LogicTests -c Release
```

Cross-building from macOS or Linux works because the project targets `net48`
with the reference-assembly package; only *running* it needs Windows. GitHub
Actions does the real packaging on `windows-latest`
(`.github/workflows/windows.yml`) and attaches the zip to a release when a `v*`
tag is pushed.

## Icon

`scripts/make_ico.py` turns `Resources/sprites/sleep.png` into
`Resources/PiggyPet.ico` (7 sizes, 16–256) for the exe; the macOS build keeps
using `Resources/PiggyPet.icns`.
