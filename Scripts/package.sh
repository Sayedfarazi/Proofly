#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Proofly"
BUILD_DIR="$(swift build --scratch-path "${PROOFLY_BUILD_DIR:-.build}" -c release --show-bin-path)"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run Scripts/build-app.sh first" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
OUT_DIR="${PROOFLY_DIST_DIR:-dist}"
mkdir -p "$OUT_DIR"
OUT_ZIP="$OUT_DIR/$APP_NAME-$VERSION-build$BUILD.zip"
if [ -e "$OUT_ZIP" ]; then
    echo "error: $OUT_ZIP already exists; increment the version/build or choose another output directory" >&2
    exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$OUT_ZIP"

echo "==> Wrote $OUT_ZIP"
echo "    Transfer this file to the other Mac (AirDrop, USB, cloud drive, etc.),"
echo "    unzip it, then follow the installation notes in the project documentation."
