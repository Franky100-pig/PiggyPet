#!/usr/bin/env bash
set -euo pipefail

# Build a Universal (Apple Silicon + Intel) release bundle and a distributable zip.
# Usage: ./scripts/release.sh [version]   (default: CFBundleShortVersionString from Info.plist)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist.template"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")}"

OUT="$ROOT/build/release"
WORK="$OUT/.work"
APP="$OUT/PiggyPet.app"
CONTENTS="$APP/Contents"
ZIP_NAME="PiggyPet-${VERSION}-universal.zip"
SUMS_NAME="PiggyPet-${VERSION}-checksums.txt"
MINOS="13.0"
SOURCES=("$ROOT"/Sources/PiggyPet/*.swift)

echo "==> Building PiggyPet $VERSION (universal, macOS $MINOS+)"
rm -rf "$OUT"
mkdir -p "$WORK/arm64" "$WORK/x86_64" "$CONTENTS/MacOS" "$CONTENTS/Resources"

for ARCH in arm64 x86_64; do
  echo "    compiling $ARCH"
  swiftc -O -target "${ARCH}-apple-macosx${MINOS}" "${SOURCES[@]}" -o "$WORK/$ARCH/PiggyPet"
done

echo "==> Merging architectures"
lipo -create "$WORK/arm64/PiggyPet" "$WORK/x86_64/PiggyPet" \
  -output "$CONTENTS/MacOS/PiggyPet"
chmod 755 "$CONTENTS/MacOS/PiggyPet"

echo "==> Assembling bundle"
cp "$PLIST" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/manifest.json" "$CONTENTS/Resources/"
for DIR in sprites walk run custom; do
  if [[ -d "$ROOT/Resources/$DIR" ]]; then
    cp -R "$ROOT/Resources/$DIR" "$CONTENTS/Resources/"
  fi
done

echo "==> Ad-hoc signing"
codesign --force --deep --strict -s - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Packaging"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$ZIP_NAME"
(cd "$OUT" && shasum -a 256 "$ZIP_NAME" > "$SUMS_NAME")

echo
echo "==> Verification"
lipo -info "$CONTENTS/MacOS/PiggyPet"
vtool -show-build "$CONTENTS/MacOS/PiggyPet" 2>/dev/null | grep -E 'minos|sdk' || true
unzip -l "$OUT/$ZIP_NAME" | tail -3
echo
cat "$OUT/$SUMS_NAME"
ls -lh "$OUT/$ZIP_NAME"
echo "Release assets are in $OUT"
