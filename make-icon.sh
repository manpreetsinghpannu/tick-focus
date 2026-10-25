#!/bin/bash
# Regenerates Assets/AppIcon.icns from the AppIconView artwork. Run after changing AppIcon.swift.
set -euo pipefail
cd "$(dirname "$0")"

swift build
WORK="$(mktemp -d)"
.build/debug/Tick --icon "$WORK/icon-1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p Assets
iconutil -c icns "$ICONSET" -o Assets/AppIcon.icns
cp "$WORK/icon-1024.png" Assets/AppIcon-1024.png
rm -rf "$WORK"
echo "Wrote Assets/AppIcon.icns"
