#!/bin/zsh
# Regenerates the README images in docs/ by rendering the real app UI offscreen.
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
python3 - "$TMP/shots.swift" <<'PY'
import sys
s = open('ShapeResizer.swift').read()
s = s[:s.index('// MARK: - App')] + open('tools/Screenshots.swift').read()
open(sys.argv[1], 'w').write(s)
PY
swiftc -swift-version 5 -parse-as-library "$TMP/shots.swift" -o "$TMP/shots"
"$TMP/shots" docs
[ -f build/icon1024.png ] && sips -z 256 256 build/icon1024.png --out docs/icon.png >/dev/null
rm -rf "$TMP"
