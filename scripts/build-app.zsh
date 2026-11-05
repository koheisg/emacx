#!/bin/zsh
set -euo pipefail

swift build -c release

APP_DIR=".build/Emacx.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/Emacx" "$MACOS/Emacx"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

cat > "$RESOURCES/README.txt" <<'TEXT'
Emacx requires Accessibility permission in System Settings > Privacy & Security > Accessibility.
TEXT

printf 'Built %s\n' "$APP_DIR"
