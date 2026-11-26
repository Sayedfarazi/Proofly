#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_SOURCE="Designs/Proofly-AppIcon.png"
MENU_SOURCE="Designs/Proofly-MenuBarTemplate.png"
BUILD_ROOT="${PROOFLY_BUILD_DIR:-.build}"
ICONSET_DIR="$BUILD_ROOT/Proofly.iconset"
OUTPUT_DIR="$BUILD_ROOT/icon-assets"

for SOURCE in "$APP_SOURCE" "$MENU_SOURCE"; do
    if [ ! -f "$SOURCE" ]; then
        echo "error: missing approved icon source: $SOURCE" >&2
        exit 1
    fi
done

mkdir -p "$ICONSET_DIR" "$OUTPUT_DIR"

for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$APP_SOURCE" \
        --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE_SIZE=$((SIZE * 2))
    sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$APP_SOURCE" \
        --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/Proofly.icns"
sips -z 128 128 "$MENU_SOURCE" \
    --out "$OUTPUT_DIR/MenuBarIconTemplate.png" >/dev/null

echo "==> Prepared app and menu-bar icons in $OUTPUT_DIR"
