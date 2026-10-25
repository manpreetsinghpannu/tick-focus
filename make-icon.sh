#!/bin/bash
# Regenerates Assets/AppIcon.icns from the chosen CleanIcon mark. Run after changing CleanIcon.swift.
# Usage: ./make-icon.sh [mark] [light|dark]   (marks are listed in CleanMark, e.g. pixelCheck, lanes)
set -euo pipefail
cd "$(dirname "$0")"

MARK="${1:-pixelCheck}"
TILE="${2:-dark}"

swift build
WORK="$(mktemp -d)"
.build/debug/Tick --clean-icon "$WORK/icon-1024.png" "$MARK" "$TILE"

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
