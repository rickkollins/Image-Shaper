#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP="Shape Resizer.app"
rm -rf build && mkdir -p build/icon.iconset "build/$APP/Contents/MacOS" "build/$APP/Contents/Resources"
# Universal binary: runs natively on Apple silicon and Intel Macs
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target $arch-apple-macos14.0 ShapeResizer.swift -o build/ShapeResizer-$arch
done
lipo -create build/ShapeResizer-arm64 build/ShapeResizer-x86_64 -output "build/$APP/Contents/MacOS/ShapeResizer"
swift MakeIcon.swift build/icon1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon1024.png --out build/icon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon1024.png --out build/icon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/icon.iconset -o "build/$APP/Contents/Resources/AppIcon.icns"
cat > "build/$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Shape Resizer</string>
  <key>CFBundleDisplayName</key><string>Shape Resizer</string>
  <key>CFBundleIdentifier</key><string>com.rickkollins.shaperesizer</string>
  <key>CFBundleExecutable</key><string>ShapeResizer</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
  <key>CFBundleDocumentTypes</key><array><dict>
    <key>CFBundleTypeName</key><string>Image</string>
    <key>CFBundleTypeRole</key><string>Viewer</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key><array><string>public.image</string><string>public.folder</string></array>
  </dict></array>
</dict></plist>
PLIST
codesign --force --deep -s - "build/$APP"
echo "Built build/$APP"
