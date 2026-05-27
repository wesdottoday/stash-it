#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"
APP="stash-it.app"
BIN_NAME="stash-it"

cd "$(dirname "$0")/.."

echo "Building stash-it ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH=".build/$CONFIG/$BIN_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    # Architecture-specific path on Apple Silicon
    BIN_PATH=$(find .build -type f -name "$BIN_NAME" -perm -u+x | head -n1)
fi

if [[ -z "${BIN_PATH:-}" || ! -f "$BIN_PATH" ]]; then
    echo "Error: built binary not found" >&2
    exit 1
fi

echo "Bundling into ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Ad-hoc sign so the app runs without Gatekeeper complaints on the build machine.
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built $(pwd)/$APP"
