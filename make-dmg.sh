#!/bin/zsh
# Builds the app and packages it as a drag-to-install DMG in dist/.
set -e
cd "$(dirname "$0")"
./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "build/Shape Resizer.app/Contents/Info.plist")
STAGE=build/dmg
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "build/Shape Resizer.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/ShapeResizer-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Shape Resizer" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
# Give the DMG file itself the app icon
swift - "$DMG" build/icon1024.png <<'SWIFT'
import AppKit
NSWorkspace.shared.setIcon(NSImage(contentsOfFile: CommandLine.arguments[2]), forFile: CommandLine.arguments[1])
SWIFT
echo "Created $DMG ($(du -h "$DMG" | cut -f1))"
