// Appended to ShapeResizer.swift (minus its App section) by tools/screenshots.sh.
// Renders README images into the folder given as the first argument.

@MainActor
enum Shots {
    static var out = ""

    static func makeSample() -> CGImage {
        let W = 1600, H = 1067
        let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
        let sky = CGGradient(colorsSpace: nil, colors: [c(0.98, 0.78, 0.45), c(0.95, 0.45, 0.40), c(0.42, 0.25, 0.55), c(0.15, 0.15, 0.35)] as CFArray,
                             locations: [0, 0.3, 0.7, 1])!
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 380), end: CGPoint(x: 0, y: CGFloat(H)), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        ctx.setFillColor(c(1, 0.93, 0.7)); ctx.fillEllipse(in: CGRect(x: 980, y: 430, width: 220, height: 220))
        ctx.setFillColor(c(1, 0.9, 0.6, 0.25)); ctx.fillEllipse(in: CGRect(x: 930, y: 380, width: 320, height: 320))
        func ridge(_ base: CGFloat, _ amp: CGFloat, _ freq: CGFloat, _ phase: CGFloat, _ col: CGColor) {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 0))
            for x in stride(from: 0, through: CGFloat(W), by: 8) {
                let y = base + amp * (sin(x / CGFloat(W) * freq + phase) * 0.6 + sin(x / CGFloat(W) * freq * 2.7 + phase * 1.3) * 0.4)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: CGFloat(W), y: 0)); p.closeSubpath()
            ctx.addPath(p); ctx.setFillColor(col); ctx.fillPath()
        }
        ridge(560, 120, 5, 1.0, c(0.55, 0.32, 0.50))
        ridge(470, 110, 7, 2.2, c(0.38, 0.22, 0.42))
        ridge(360, 90, 4, 0.3, c(0.24, 0.15, 0.30))
        let lake = CGGradient(colorsSpace: nil, colors: [c(0.30, 0.22, 0.45), c(0.85, 0.50, 0.45)] as CFArray, locations: [0, 1])!
        ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: 250))
        ctx.drawLinearGradient(lake, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 250), options: [])
        ctx.setFillColor(c(1, 0.9, 0.65, 0.5))
        for i in 0..<9 { ctx.fill(CGRect(x: 1090 - CGFloat(60 - i * 5), y: 230 - CGFloat(i * 26), width: CGFloat(120 - i * 10), height: 6)) }
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    static func save(_ img: CGImage, _ name: String) {
        try! ImageEngine.write(img, to: URL(fileURLWithPath: out + "/" + name), format: .png, quality: 1)
    }

    static func window(_ name: String, width: CGFloat = 1180, height: CGFloat = 760) {
        let host = NSHostingView(rootView: ContentView().environmentObject(AppModel.shared).frame(width: width, height: height))
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        win.title = "Shape Resizer"
        win.contentView = host
        win.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        win.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        let view = win.contentView!.superview!            // include the title bar
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + name))
        win.orderOut(nil)
    }

    /// Lays out rendered tiles in a grid with captions.
    static func sheet(_ tiles: [(CGImage, String)], columns: Int, cell: CGSize, name: String) {
        let rows = (tiles.count + columns - 1) / columns
        let pad: CGFloat = 24, caption: CGFloat = 34
        let W = Int(CGFloat(columns) * (cell.width + pad) + pad), H = Int(CGFloat(rows) * (cell.height + caption + pad) + pad)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let cg = NSGraphicsContext.current!.cgContext
        NSColor(white: 0.96, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
        for (i, t) in tiles.enumerated() {
            let col = i % columns, row = i / columns
            let x = pad + CGFloat(col) * (cell.width + pad)
            let yTop = CGFloat(H) - pad - CGFloat(row) * (cell.height + caption + pad)
            let iw = CGFloat(t.0.width), ih = CGFloat(t.0.height)
            cg.draw(t.0, in: CGRect(x: x + (cell.width - iw) / 2, y: yTop - cell.height + (cell.height - ih) / 2, width: iw, height: ih))
            let para = NSMutableParagraphStyle(); para.alignment = .center
            (t.1 as NSString).draw(in: NSRect(x: x, y: yTop - cell.height - caption + 2, width: cell.width, height: caption - 8),
                                   withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .medium),
                                                    .foregroundColor: NSColor(white: 0.25, alpha: 1), .paragraphStyle: para])
        }
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + name))
    }

    static func settings(_ w: Int, _ h: Int, _ shape: ShapeKind, fit: FitMode = .fill, border: CGFloat = 0, transparent: Bool = true) -> RenderSettings {
        RenderSettings(width: w, height: h, shape: shape, cornerFraction: 0.3, rotationDegrees: 0, fit: fit, offset: .zero, zoom: 1,
                       transparent: transparent, backgroundColor: CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1),
                       borderWidth: border, borderColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    }

    static func run() {
        out = CommandLine.arguments[1]
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .aqua)
        let sample = makeSample()

        // 1. Empty window / drop zone
        window("window-empty.png")

        // 2. Main window: hexagon with a border
        let m = AppModel.shared
        m.add(image: sample, name: "sunset")
        m.add(image: sample, name: "sunset-2")
        m.selection = m.images.first?.id
        m.lockAspect = false
        m.width = 1200; m.height = 1200
        m.lockAspect = true
        m.shape = .hexagon
        m.borderWidth = 30
        m.borderColor = .white
        window("window-main.png")

        // 3. Unlocked aspect: wide oval
        m.lockAspect = false
        m.width = 1600; m.height = 900
        m.shape = .circle
        m.borderWidth = 0
        m.transparent = false
        m.bgColor = Color(red: 0.12, green: 0.12, blue: 0.18)
        window("window-oval.png")

        // 4. Shape gallery
        let tiles = ShapeKind.allCases.map { k in
            (ImageEngine.render(sample, settings(220, 220, k, border: 8), opaque: false)!, k.rawValue)
        }
        sheet(tiles, columns: 6, cell: CGSize(width: 220, height: 220), name: "shapes.png")

        // 5. Same shape, any aspect ratio
        sheet([(ImageEngine.render(sample, settings(260, 260, .hexagon, border: 8), opaque: false)!, "1 : 1"),
               (ImageEngine.render(sample, settings(420, 236, .hexagon, border: 8), opaque: false)!, "16 : 9"),
               (ImageEngine.render(sample, settings(158, 280, .hexagon, border: 8), opaque: false)!, "9 : 16"),
               (ImageEngine.render(sample, settings(420, 210, .rounded, border: 8), opaque: false)!, "2 : 1 rounded")],
              columns: 4, cell: CGSize(width: 420, height: 280), name: "aspect.png")

        // 6. Fill / Fit / Stretch
        sheet(FitMode.allCases.map { f in
            (ImageEngine.render(sample, settings(280, 280, .circle, fit: f, border: 6, transparent: false), opaque: false)!, f.rawValue)
        }, columns: 3, cell: CGSize(width: 280, height: 280), name: "fit-modes.png")

        print("done")
    }
}

@main struct ShotsMain { @MainActor static func main() { Shots.run() } }
