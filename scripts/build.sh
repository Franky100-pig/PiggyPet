#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PiggyPet.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

swiftc -O \
  "$ROOT"/Sources/PiggyPet/*.swift \
  -o "$CONTENTS/MacOS/PiggyPet"

cp "$ROOT/Resources/Info.plist.template" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Resources/manifest.json" ]]; then
  cp "$ROOT/Resources/manifest.json" "$CONTENTS/Resources/"
fi
if [[ -d "$ROOT/Resources/sprites" ]] && [[ -n "$(ls -A "$ROOT/Resources/sprites")" ]]; then
  cp -R "$ROOT/Resources/sprites" "$CONTENTS/Resources/"
fi

codesign --force --deep -s - "$APP" 2>/dev/null || true
touch "$APP"
echo "Built $APP"
