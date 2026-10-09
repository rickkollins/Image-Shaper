# Shape Resizer

A small native macOS app for resizing images to any size or aspect ratio and cutting them into shapes.

- **Drag and drop** images or whole folders onto the window, the Dock icon, or the app icon
- **Resize** to any pixel size: drag handles on the image, type exact sizes, use aspect-ratio presets (1:1, 4:3, 16:9, 9:16…), or scale by percent. Hold **Shift** while dragging to flip the aspect lock
- **Shapes:** rectangle, rounded rectangle, circle/oval, hexagon (pointy or flat), octagon, pentagon, triangle, diamond, star, heart, shield — with rotation
- **Placement:** Fill (crop), Fit, or Stretch; drag to move the photo inside the shape, pinch to zoom
- Transparent or colored background, optional border
- **Export** PNG, JPEG, or TIFF — one image or a whole batch. Saving never overwrites an existing file; a number is added instead

Requires macOS 14 or later. Universal binary (Apple silicon + Intel).

## Install

Open `ShapeResizer-1.0.dmg` and drag **Shape Resizer** onto **Applications**.

The app is not notarized by Apple. If macOS says it can't verify the app the first time you open it, go to
**System Settings → Privacy & Security** and click **Open Anyway**.

## Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh       # builds build/Shape Resizer.app
./make-dmg.sh    # builds the app and packages dist/ShapeResizer-<version>.dmg
```

| File | Purpose |
| --- | --- |
| `ShapeResizer.swift` | The whole app (SwiftUI + CoreGraphics) |
| `MakeIcon.swift` | Draws the app icon |
| `build.sh` | Compiles a universal `.app` bundle with icon and Info.plist |
| `make-dmg.sh` | Wraps the app in a drag-to-install DMG |
