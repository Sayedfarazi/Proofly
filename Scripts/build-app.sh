#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="release"
APP_NAME="Proofly"
SIGN_IDENTITY="${1:--}"
BUILD_ROOT="${PROOFLY_BUILD_DIR:-.build}"
SWIFT_ARGS=(--scratch-path "$BUILD_ROOT")

bash Scripts/build-icons.sh

echo "==> Building $APP_NAME ($CONFIG)"
swift build "${SWIFT_ARGS[@]}" -c "$CONFIG" --product "$APP_NAME"
BUILD_DIR="$(swift build "${SWIFT_ARGS[@]}" -c "$CONFIG" --show-bin-path)"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Sources/$APP_NAME/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_ROOT/icon-assets/Proofly.icns" "$APP_BUNDLE/Contents/Resources/Proofly.icns"
cp "$BUILD_ROOT/icon-assets/MenuBarIconTemplate.png" "$APP_BUNDLE/Contents/Resources/MenuBarIconTemplate.png"

cp LICENSE "$APP_BUNDLE/Contents/Resources/LICENSE"

echo "==> Code signing with identity: $SIGN_IDENTITY"
codesign --force --deep --sign "$SIGN_IDENTITY" \
    --entitlements "Sources/$APP_NAME/$APP_NAME.entitlements" \
    "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "    Run:  open \"$APP_BUNDLE\""
