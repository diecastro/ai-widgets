#!/usr/bin/env bash
# Assembles AIUsage.app around the SwiftPM-built menu bar binary.
#
# This exists so the app runs before Xcode is installed: a menu bar agent needs
# a bundle with LSUIElement to stay out of the Dock, and SwiftPM does not build
# bundles. Once the Xcode project lands it produces the app directly and this
# script becomes redundant.

set -euo pipefail

CONFIG="${CONFIG:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/AIUsage.app"
BINARY="$ROOT/.build/$CONFIG/AIUsageMenuBar"

swift build -c "$CONFIG" --product AIUsageMenuBar

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/AIUsage"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>AIUsage</string>
    <key>CFBundleDisplayName</key>     <string>AI Usage</string>
    <key>CFBundleIdentifier</key>      <string>com.aiusage.menubar</string>
    <key>CFBundleExecutable</key>      <string>AIUsage</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <!-- Menu bar agent: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will launch it locally without a developer identity.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "note: ad-hoc signing skipped"

echo "built $APP"
echo "run:  open \"$APP\"    (look for it in the menu bar)"
echo "stop: click the item and choose Quit"
