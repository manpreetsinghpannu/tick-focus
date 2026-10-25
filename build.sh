#!/bin/bash
# Builds "On Track.app" into ./build. Usage: ./build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/On Track.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tick "$APP/Contents/MacOS/Tick"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Tick</string>
    <key>CFBundleIdentifier</key><string>com.manpreet.tick</string>
    <key>CFBundleName</key><string>On Track</string>
    <key>CFBundleDisplayName</key><string>On Track</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Tick 2>/dev/null || true
    rm -rf /Applications/Tick.app "/Applications/Tick Focus.app" "/Applications/On Track.app"
    cp -R "$APP" "/Applications/On Track.app"
    echo "Installed to /Applications/On Track.app"
fi
