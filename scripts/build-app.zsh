#!/bin/zsh
set -euo pipefail

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP_DIR=".build/Emacx.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_DIR/Emacx" "$MACOS/Emacx"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

cat > "$RESOURCES/README.txt" <<'TEXT'
Emacx requires Accessibility permission in System Settings > Privacy & Security > Accessibility.
TEXT

codesign --force --sign - "$APP_DIR"

printf 'Built %s\n' "$APP_DIR"
