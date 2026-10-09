import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

// MARK: - Options

enum ShapeKind: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case rounded = "Rounded"
    case circle = "Circle"
    case hexagon = "Hexagon"
    case hexagonFlat = "Hex (flat)"
    case octagon = "Octagon"
    case pentagon = "Pentagon"
    case triangle = "Triangle"
    case diamond = "Diamond"
    case star = "Star"
    case heart = "Heart"
    case shield = "Shield"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .rounded: return "app"
        case .circle: return "circle"
        case .hexagon: return "hexagon"
        case .hexagonFlat: return "hexagon"
        case .octagon: return "octagon"
        case .pentagon: return "pentagon"
        case .triangle: return "triangle"
        case .diamond: return "diamond"
        case .star: return "star"
        case .heart: return "heart"
        case .shield: return "shield"
        }
    }

    var fileTag: String { String(describing: self) }
}

enum FitMode: String, CaseIterable, Identifiable {
    case fill = "Fill (crop)"
    case fit = "Fit (whole)"
    case stretch = "Stretch"
    var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    var id: String { rawValue }

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }

    var ext: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        }
    }

    var supportsAlpha: Bool { self != .jpeg }
}

struct RenderSettings {
    var width: Int
    var height: Int
    var shape: ShapeKind
    var cornerFraction: CGFloat
    var rotationDegrees: CGFloat
    var fit: FitMode
    var offset: CGPoint          // -1...1 pan for crop position
    var zoom: CGFloat            // 1 = normal
    var transparent: Bool
    var backgroundColor: CGColor
    var borderWidth: CGFloat
    var borderColor: CGColor
}

struct SimpleError: LocalizedError {
    var errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

// MARK: - Shapes

enum ShapeGeometry {
    static func path(_ kind: ShapeKind, in r: CGRect, cornerFraction: CGFloat, rotation: CGFloat) -> CGPath {
        let base: CGPath
        switch kind {
        case .rectangle:
            base = CGPath(rect: r, transform: nil)
        case .rounded:
            let c = min(r.width, r.height) * 0.5 * max(0, min(1, cornerFraction))
            base = CGPath(roundedRect: r, cornerWidth: c, cornerHeight: c, transform: nil)
        case .circle:
            base = CGPath(ellipseIn: r, transform: nil)
        case .hexagon:
            base = fit(polygon(sides: 6, startDegrees: -90), in: r)
        case .hexagonFlat:
            base = fit(polygon(sides: 6, startDegrees: 0), in: r)
        case .octagon:
            base = fit(polygon(sides: 8, startDegrees: -90 + 22.5), in: r)
        case .pentagon:
            base = fit(polygon(sides: 5, startDegrees: -90), in: r)
        case .triangle:
            base = fit(polygon(sides: 3, startDegrees: -90), in: r)
        case .diamond:
            base = fit(polygon(sides: 4, startDegrees: -90), in: r)
        case .star:
            base = fit(star(points: 5, inner: 0.45), in: r)
        case .heart:
            base = fit(heart(), in: r)
        case .shield:
            base = fit(shield(), in: r)
        }
        guard rotation != 0 else { return base }
        // Rotate about the center, then re-fit so the shape still fills the canvas.
        var t = CGAffineTransform(translationX: r.midX, y: r.midY)
            .rotated(by: -rotation * .pi / 180)
            .translatedBy(x: -r.midX, y: -r.midY)
        guard let rotated = base.copy(using: &t) else { return base }
        return fitKeepingOrientation(rotated, in: r)
    }

    /// Unit-space points use y-down coordinates; `fit` flips into CoreGraphics' y-up space.
    private static func polygon(sides: Int, startDegrees: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<sides {
            let a = (startDegrees + CGFloat(i) * 360 / CGFloat(sides)) * .pi / 180
            let pt = CGPoint(x: cos(a), y: sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func star(points: Int, inner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<(points * 2) {
            let a = (-90 + CGFloat(i) * 180 / CGFloat(points)) * .pi / 180
            let rad: CGFloat = i.isMultiple(of: 2) ? 1 : inner
            let pt = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func heart() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.5, y: 1.0))
        p.addCurve(to: CGPoint(x: 0.0, y: 0.32), control1: CGPoint(x: 0.38, y: 0.86), control2: CGPoint(x: 0.0, y: 0.6))
        p.addCurve(to: CGPoint(x: 0.25, y: 0.02), control1: CGPoint(x: 0.0, y: 0.14), control2: CGPoint(x: 0.11, y: 0.02))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.2), control1: CGPoint(x: 0.38, y: 0.02), control2: CGPoint(x: 0.47, y: 0.1))
        p.addCurve(to: CGPoint(x: 0.75, y: 0.02), control1: CGPoint(x: 0.53, y: 0.1), control2: CGPoint(x: 0.62, y: 0.02))
        p.addCurve(to: CGPoint(x: 1.0, y: 0.32), control1: CGPoint(x: 0.89, y: 0.02), control2: CGPoint(x: 1.0, y: 0.14))
        p.addCurve(to: CGPoint(x: 0.5, y: 1.0), control1: CGPoint(x: 1.0, y: 0.6), control2: CGPoint(x: 0.62, y: 0.86))
        p.closeSubpath()
        return p
    }

    private static func shield() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.5, y: 0.0))
        p.addCurve(to: CGPoint(x: 1.0, y: 0.12), control1: CGPoint(x: 0.68, y: 0.1), control2: CGPoint(x: 0.85, y: 0.12))
        p.addLine(to: CGPoint(x: 1.0, y: 0.45))
        p.addCurve(to: CGPoint(x: 0.5, y: 1.0), control1: CGPoint(x: 1.0, y: 0.75), control2: CGPoint(x: 0.75, y: 0.9))
        p.addCurve(to: CGPoint(x: 0.0, y: 0.45), control1: CGPoint(x: 0.25, y: 0.9), control2: CGPoint(x: 0.0, y: 0.75))
        p.addLine(to: CGPoint(x: 0.0, y: 0.12))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.0), control1: CGPoint(x: 0.15, y: 0.12), control2: CGPoint(x: 0.32, y: 0.1))
        p.closeSubpath()
        return p
    }

    /// Scale a y-down unit path so its bounding box exactly fills `r` (in y-up space).
    private static func fit(_ unit: CGPath, in r: CGRect) -> CGPath {
        let bb = unit.boundingBoxOfPath
        guard bb.width > 0, bb.height > 0 else { return unit }
        let sx = r.width / bb.width, sy = r.height / bb.height
        var t = CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: r.minX - bb.minX * sx, ty: r.maxY + bb.minY * sy)
        return unit.copy(using: &t) ?? unit
    }

    /// Scale a y-up path so its bounding box fills `r` without flipping.
    private static func fitKeepingOrientation(_ path: CGPath, in r: CGRect) -> CGPath {
        let bb = path.boundingBoxOfPath
        guard bb.width > 0, bb.height > 0 else { return path }
        let sx = r.width / bb.width, sy = r.height / bb.height
        var t = CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: r.minX - bb.minX * sx, ty: r.minY - bb.minY * sy)
        return path.copy(using: &t) ?? path
    }
}

// MARK: - Image engine

enum ImageEngine {
    static func load(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return load(source: src)
    }

    static func load(source src: CGImageSource) -> CGImage? {
        guard CGImageSourceGetCount(src) > 0 else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let w = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        var opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honor camera rotation
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if max(w, h) > 0 { opts[kCGImageSourceThumbnailMaxPixelSize] = max(w, h) }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func thumbnail(_ img: CGImage, maxSide: Int = 160) -> CGImage {
        let k = min(1, CGFloat(maxSide) / CGFloat(max(img.width, img.height)))
        let w = max(1, Int(CGFloat(img.width) * k)), h = max(1, Int(CGFloat(img.height) * k))
        guard let ctx = makeContext(w, h) else { return img }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? img
    }

    private static func makeContext(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    static func render(_ img: CGImage, _ s: RenderSettings, scale: CGFloat = 1, opaque: Bool) -> CGImage? {
        let W = max(1, Int((CGFloat(s.width) * scale).rounded()))
        let H = max(1, Int((CGFloat(s.height) * scale).rounded()))
        guard let ctx = makeContext(W, H) else { return nil }
        ctx.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: W, height: H)

        if opaque {
            ctx.setFillColor(s.transparent ? CGColor(red: 1, green: 1, blue: 1, alpha: 1) : s.backgroundColor)
            ctx.fill(canvas)
        } else if !s.transparent {
            ctx.setFillColor(s.backgroundColor)
            ctx.fill(canvas)
        }

        let bw = max(0, s.borderWidth * scale)
        let shapeRect = canvas.insetBy(dx: bw / 2, dy: bw / 2)
        let path = ShapeGeometry.path(s.shape, in: shapeRect, cornerFraction: s.cornerFraction, rotation: s.rotationDegrees)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        // Background color also shows behind letterboxed images inside the shape.
        let sw = CGFloat(img.width), sh = CGFloat(img.height)
        var dr: CGRect
        switch s.fit {
        case .stretch:
            dr = shapeRect
        case .fill, .fit:
            let k = (s.fit == .fill ? max(shapeRect.width / sw, shapeRect.height / sh)
                                    : min(shapeRect.width / sw, shapeRect.height / sh)) * max(0.05, s.zoom)
            dr = CGRect(x: shapeRect.midX - sw * k / 2, y: shapeRect.midY - sh * k / 2, width: sw * k, height: sh * k)
        }
        if s.fit != .stretch || s.zoom != 1 {
            if s.fit == .stretch {
                dr = dr.insetBy(dx: -dr.width * (s.zoom - 1) / 2, dy: -dr.height * (s.zoom - 1) / 2)
            }
            // Pan: offset ranges -1...1 across the overflow (or free movement when there's no overflow).
            let slackX = max(abs(dr.width - shapeRect.width) / 2, shapeRect.width * 0.25)
            let slackY = max(abs(dr.height - shapeRect.height) / 2, shapeRect.height * 0.25)
            dr.origin.x += s.offset.x * slackX
            dr.origin.y -= s.offset.y * slackY
        }
        ctx.draw(img, in: dr)
        ctx.restoreGState()

        if bw > 0 {
            ctx.addPath(path)
            ctx.setStrokeColor(s.borderColor)
            ctx.setLineWidth(bw)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }
        return ctx.makeImage()
    }

    static func write(_ img: CGImage, to url: URL, format: OutputFormat, quality: Double) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw SimpleError("Couldn't create \(url.lastPathComponent)")
        }
        var props: [CFString: Any] = [:]
        if format == .jpeg { props[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(dest, img, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw SimpleError("Couldn't write \(url.lastPathComponent)") }
    }
}

// MARK: - Model

struct LoadedImage: Identifiable {
    let id = UUID()
    let name: String
    let image: CGImage
    let thumb: CGImage
}

final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let maxSide = 16000

    @Published var images: [LoadedImage] = []
    @Published var selection: UUID?
    @Published var width = 1000
    @Published var height = 1000
    @Published var lockAspect = true { didSet { if lockAspect { ratio = Double(width) / Double(max(height, 1)) } } }
    @Published var shape = ShapeKind.rectangle
    @Published var corner = 0.3
    @Published var rotation = 0.0
    @Published var fit = FitMode.fill
    @Published var zoom = 1.0
    @Published var offsetX = 0.0
    @Published var offsetY = 0.0
    @Published var transparent = true
    @Published var bgColor = Color.white
    @Published var borderWidth = 0.0
    @Published var borderColor = Color.white
    @Published var format = OutputFormat.png
    @Published var quality = 0.9
    @Published var status = ""
    @Published var dropTargeted = false
    /// Display scale frozen while a resize handle is dragged, so the canvas doesn't rescale under the cursor.
    @Published var frozenScale: CGFloat?
    var resizeStart: (w: Int, h: Int)?
    var panStart: (x: Double, y: Double)?
    var zoomStart: Double?

    private var ratio = 1.0
    private var lastSaveDirectory: URL?

    var selected: LoadedImage? { images.first { $0.id == selection } ?? images.first }

    // MARK: Loading

    func add(urls: [URL]) {
        var files: [URL] = []
        for u in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue {
                let e = FileManager.default.enumerator(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                while let f = e?.nextObject() as? URL {
                    if let t = UTType(filenameExtension: f.pathExtension), t.conforms(to: .image) { files.append(f) }
                }
            } else {
                files.append(u)
            }
        }
        var skipped = 0
        for f in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            if let img = ImageEngine.load(url: f) {
                append(LoadedImage(name: f.deletingPathExtension().lastPathComponent, image: img, thumb: ImageEngine.thumbnail(img)))
            } else {
                skipped += 1
            }
        }
        status = skipped > 0 ? "\(skipped) file(s) weren't images and were skipped" : "\(images.count) image(s) loaded"
    }

    func add(image: CGImage, name: String) {
        append(LoadedImage(name: name, image: image, thumb: ImageEngine.thumbnail(image)))
        status = "\(images.count) image(s) loaded"
    }

    private func append(_ item: LoadedImage) {
        let first = images.isEmpty
        images.append(item)
        if first {
            selection = item.id
            useOriginalSize()
        }
    }

    func remove(_ id: UUID) {
        images.removeAll { $0.id == id }
        if selection == id { selection = images.first?.id }
    }

    func clear() {
        images = []
        selection = nil
        status = ""
    }

    func openPanel() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image, .folder]
        p.allowsMultipleSelection = true
        p.canChooseDirectories = true
        p.message = "Choose images (or folders of images)"
        if p.runModal() == .OK { add(urls: p.urls) }
    }

    // MARK: Size

    func setWidth(_ w: Int) {
        let w = min(max(w, 1), Self.maxSide)
        width = w
        if lockAspect { height = min(max(1, Int((Double(w) / ratio).rounded())), Self.maxSide) }
    }

    func setHeight(_ h: Int) {
        let h = min(max(h, 1), Self.maxSide)
        height = h
        if lockAspect { width = min(max(1, Int((Double(h) * ratio).rounded())), Self.maxSide) }
    }

    func applyRatio(_ r: Double) {
        ratio = r
        height = min(max(1, Int((Double(width) / r).rounded())), Self.maxSide)
        lockAspect = true
        ratio = r
    }

    func useOriginalSize() {
        scale(1)
    }

    func scale(_ pct: Double) {
        guard let s = selected else { return }
        width = min(max(1, Int((Double(s.image.width) * pct).rounded())), Self.maxSide)
        height = min(max(1, Int((Double(s.image.height) * pct).rounded())), Self.maxSide)
        ratio = Double(s.image.width) / Double(s.image.height)
    }

    func resetPosition() {
        zoom = 1; offsetX = 0; offsetY = 0
    }

    // MARK: Rendering

    var settings: RenderSettings {
        RenderSettings(width: width, height: height, shape: shape, cornerFraction: corner, rotationDegrees: rotation,
                       fit: fit, offset: CGPoint(x: offsetX, y: offsetY), zoom: zoom,
                       transparent: transparent, backgroundColor: NSColor(bgColor).cgColor,
                       borderWidth: borderWidth, borderColor: NSColor(borderColor).cgColor)
    }

    func preview(for item: LoadedImage) -> CGImage? {
        let k = min(1, 900 / CGFloat(max(width, height)))
        return ImageEngine.render(item.image, settings, scale: k, opaque: !format.supportsAlpha)
    }

    private func renderFull(_ item: LoadedImage) -> CGImage? {
        ImageEngine.render(item.image, settings, scale: 1, opaque: !format.supportsAlpha)
    }

    func outputName(for item: LoadedImage) -> String {
        "\(item.name)-\(width)x\(height)-\(shape.fileTag).\(format.ext)"
    }

    private func save(_ item: LoadedImage, to url: URL) throws {
        guard let img = renderFull(item) else { throw SimpleError("Image too large to render") }
        try ImageEngine.write(img, to: url, format: format, quality: quality)
    }

    func exportSelected() {
        guard let item = selected else { return }
        let p = NSSavePanel()
        p.allowedContentTypes = [format.utType]
        p.canCreateDirectories = true
        if let dir = lastSaveDirectory { p.directoryURL = dir }
        // Suggest a name that doesn't already exist in the folder the panel opens to.
        let startDir = p.directoryURL ?? FileManager.default.homeDirectoryForCurrentUser
        p.nameFieldStringValue = uniqueURL(startDir.appendingPathComponent(outputName(for: item))).lastPathComponent
        guard p.runModal() == .OK, let chosen = p.url else { return }
        lastSaveDirectory = chosen.deletingLastPathComponent()
        // Never overwrite: if the name is taken (even if "Replace" was clicked), add a number.
        let url = uniqueURL(chosen)
        do {
            try save(item, to: url)
            status = url == chosen ? "Saved \(url.lastPathComponent)"
                                   : "Name was taken — saved as \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showError(error)
        }
    }

    func exportAll() {
        guard !images.isEmpty else { return }
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.prompt = "Save Here"
        p.message = "Choose a folder for \(images.count) resized image(s)"
        if let dir = lastSaveDirectory { p.directoryURL = dir }
        guard p.runModal() == .OK, let dir = p.url else { return }
        lastSaveDirectory = dir
        var saved: [URL] = []
        do {
            for item in images {
                let url = uniqueURL(dir.appendingPathComponent(outputName(for: item)))
                try save(item, to: url)
                saved.append(url)
            }
            status = "Saved \(saved.count) image(s)"
            NSWorkspace.shared.activateFileViewerSelecting(saved)
        } catch {
            showError(error)
        }
    }

    /// Writes the rendered image to a temp file so it can be dragged out to Finder or other apps.
    func dragFile(for item: LoadedImage) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShapeResizer-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(outputName(for: item))
        do { try save(item, to: url); return url } catch { return nil }
    }

    private func uniqueURL(_ url: URL) -> URL {
        var candidate = url
        var n = 2
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent().appendingPathComponent("\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }

    private func showError(_ error: Error) {
        let a = NSAlert(error: error)
        a.runModal()
    }
}

// MARK: - Views

struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 10
            for row in 0..<Int(ceil(size.height / s)) {
                for col in 0..<Int(ceil(size.width / s)) where (row + col).isMultiple(of: 2) {
                    ctx.fill(Path(CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)),
                             with: .color(.gray.opacity(0.22)))
                }
            }
        }
        .background(Color.white)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                previewArea
                if !model.images.isEmpty { thumbnailStrip }
            }
            Divider()
            controls.frame(width: 320)
        }
    }

    // MARK: Preview

    private var previewArea: some View {
        VStack(spacing: 0) {
            if model.selected != nil {
                canvasToolbar
                Divider()
            }
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                if let item = model.selected, let cg = model.preview(for: item) {
                    GeometryReader { geo in
                        let fitScale = min(1, (geo.size.width - 90) / CGFloat(model.width),
                                              (geo.size.height - 90) / CGFloat(model.height))
                        let scale = max(0.01, model.frozenScale ?? fitScale)
                        let w = CGFloat(model.width) * scale, h = CGFloat(model.height) * scale
                        editableImage(cg, width: w, height: h, scale: scale)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .clipped()
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("Drop images here").font(.title2.weight(.semibold))
                        Text("JPEG, PNG, HEIC, TIFF, GIF, WebP… or whole folders")
                            .foregroundStyle(.secondary)
                        Button("Choose Images…") { model.openPanel() }
                            .controlSize(.large)
                    }
                }
                if model.dropTargeted {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 4, dash: [12, 8]))
                        .background(Color.accentColor.opacity(0.08))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL, .image], isTargeted: $model.dropTargeted, perform: handleDrop)
        }
    }

    /// The preview with resize handles, drag-to-move and pinch/scroll-to-zoom.
    private func editableImage(_ cg: CGImage, width w: CGFloat, height h: CGFloat, scale: CGFloat) -> some View {
        Image(decorative: cg, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: w, height: h)
            .background(model.format.supportsAlpha ? AnyView(Checkerboard()) : AnyView(Color.white))
            .background(Rectangle().fill(Color.white).shadow(color: .black.opacity(0.25), radius: 8, y: 3))
            .overlay(Rectangle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1))
            .gesture(panGesture(w: w, h: h))
            .simultaneousGesture(zoomGesture)
            .onHover { inside in
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .overlay {
                ZStack {
                    ForEach(0..<9) { i in
                        let fx = CGFloat(i % 3) / 2, fy = CGFloat(i / 3) / 2
                        if !(fx == 0.5 && fy == 0.5) {
                            resizeHandle(fx: fx, fy: fy, scale: scale)
                                .position(x: fx * w, y: fy * h)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                Text("\(model.width) × \(model.height) px")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: 26)
                    .allowsHitTesting(false)
            }
    }

    private func resizeHandle(fx: CGFloat, fy: CGFloat, scale: CGFloat) -> some View {
        let isCorner = fx != 0.5 && fy != 0.5
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: isCorner ? 11 : (fx == 0.5 ? 22 : 8), height: isCorner ? 11 : (fy == 0.5 ? 22 : 8))
            .padding(6)                       // larger hit area
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    (fx == 0.5 ? NSCursor.resizeUpDown : fy == 0.5 ? NSCursor.resizeLeftRight : NSCursor.crosshair).push()
                } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { v in
                        if model.resizeStart == nil {
                            model.resizeStart = (model.width, model.height)
                            model.frozenScale = scale
                        }
                        guard let start = model.resizeStart, let k = model.frozenScale else { return }
                        // Image is centered, so an edge moves by half the size change.
                        let sx: CGFloat = fx == 0 ? -1 : (fx == 1 ? 1 : 0)
                        let sy: CGFloat = fy == 0 ? -1 : (fy == 1 ? 1 : 0)
                        let dw = sx * v.translation.width * 2 / k
                        let dh = sy * v.translation.height * 2 / k
                        let newW = Int((CGFloat(start.w) + dw).rounded())
                        let newH = Int((CGFloat(start.h) + dh).rounded())
                        // Holding Shift temporarily flips the aspect lock.
                        let lock = model.lockAspect != NSEvent.modifierFlags.contains(.shift)
                        if lock {
                            let ratio = Double(start.w) / Double(start.h)
                            let useWidth = sx != 0 && (sy == 0 || abs(dw) >= abs(dh) * CGFloat(ratio))
                            if useWidth {
                                model.width = min(max(1, newW), AppModel.maxSide)
                                model.height = min(max(1, Int((Double(model.width) / ratio).rounded())), AppModel.maxSide)
                            } else {
                                model.height = min(max(1, newH), AppModel.maxSide)
                                model.width = min(max(1, Int((Double(model.height) * ratio).rounded())), AppModel.maxSide)
                            }
                        } else {
                            if sx != 0 { model.width = min(max(1, newW), AppModel.maxSide) }
                            if sy != 0 { model.height = min(max(1, newH), AppModel.maxSide) }
                        }
                    }
                    .onEnded { _ in
                        model.resizeStart = nil
                        model.frozenScale = nil
                        if model.lockAspect { model.lockAspect = true }   // re-capture ratio
                    }
            )
            .help("Drag to resize · hold Shift to \(model.lockAspect ? "ignore" : "keep") the aspect ratio")
    }

    private func panGesture(w: CGFloat, h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if model.panStart == nil { model.panStart = (model.offsetX, model.offsetY) }
                guard let st = model.panStart else { return }
                model.offsetX = min(1, max(-1, st.x + Double(v.translation.width / (w / 2))))
                model.offsetY = min(1, max(-1, st.y + Double(v.translation.height / (h / 2))))
            }
            .onEnded { _ in model.panStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                if model.zoomStart == nil { model.zoomStart = model.zoom }
                model.zoom = min(4, max(0.25, (model.zoomStart ?? 1) * Double(v.magnification)))
            }
            .onEnded { _ in model.zoomStart = nil }
    }

    // MARK: Canvas toolbar

    private var canvasToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(.secondary)
                TextField("W", value: widthBinding, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
                Button {
                    model.lockAspect.toggle()
                } label: {
                    Image(systemName: model.lockAspect ? "lock.fill" : "lock.open").frame(width: 16)
                }
                .buttonStyle(.borderless)
                .help(model.lockAspect ? "Aspect ratio locked" : "Aspect ratio unlocked — any size")
                TextField("H", value: heightBinding, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
                Text("px").foregroundStyle(.secondary)
                Divider().frame(height: 18)
                Menu("Aspect") {
                    ForEach(ratios, id: \.0) { r in Button(r.0) { model.applyRatio(r.1) } }
                    Divider()
                    Button("Original") { model.useOriginalSize() }
                }
                .fixedSize()
                Menu("Scale") {
                    ForEach([0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0], id: \.self) { p in
                        Button("\(Int(p * 100))% of original") { model.scale(p) }
                    }
                }
                .fixedSize()
                Menu("Square") {
                    ForEach([128, 256, 512, 1024, 2048, 4096], id: \.self) { sz in
                        Button("\(sz) × \(sz)") {
                            model.width = sz; model.height = sz; model.lockAspect = true
                        }
                    }
                }
                .fixedSize()
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Picker("", selection: $model.fit) {
                    ForEach(FitMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Divider().frame(height: 18)
                Button { model.zoom = max(0.25, model.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    .buttonStyle(.borderless)
                Slider(value: $model.zoom, in: 0.25...4).frame(minWidth: 60, maxWidth: 120)
                Button { model.zoom = min(4, model.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                    .buttonStyle(.borderless)
                Text("\(Int(model.zoom * 100))%").font(.caption.monospacedDigit()).frame(width: 38, alignment: .leading)
                Button("Reset") { model.resetPosition() }.controlSize(.small)
                Spacer(minLength: 0)
                if let item = model.selected {
                    Label("Drag out", systemImage: "hand.draw")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .onDrag {
                            if let url = model.dragFile(for: item) { return NSItemProvider(object: url as NSURL) }
                            return NSItemProvider()
                        }
                        .help("Drag this to Finder or another app to save the result")
                }
            }
            Text("Drag the white handles to resize · drag the picture to move it · pinch to zoom · Shift-drag flips the aspect lock")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    private var thumbnailStrip: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.images) { item in
                        Image(decorative: item.thumb, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(item.id == model.selected?.id ? Color.accentColor : Color.clear, lineWidth: 3))
                            .onTapGesture { model.selection = item.id }
                            .contextMenu { Button("Remove") { model.remove(item.id) } }
                            .help(item.name)
                    }
                }
                .padding(10)
            }
            Divider()
            VStack(spacing: 4) {
                Button { model.openPanel() } label: { Label("Add", systemImage: "plus") }
                Button(role: .destructive) { model.clear() } label: { Label("Clear", systemImage: "trash") }
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
        }
        .frame(height: 76)
        .background(.bar)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { AppModel.shared.add(urls: [url]) }
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                let name = p.suggestedName ?? "image"
                p.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let src = CGImageSourceCreateWithData(data as CFData, nil),
                          let img = ImageEngine.load(source: src) else { return }
                    DispatchQueue.main.async { AppModel.shared.add(image: img, name: name) }
                }
            }
        }
        return handled
    }

    // MARK: Controls

    private var widthBinding: Binding<Int> { Binding(get: { model.width }, set: { model.setWidth($0) }) }
    private var heightBinding: Binding<Int> { Binding(get: { model.height }, set: { model.setHeight($0) }) }

    private let ratios: [(String, Double)] = [
        ("1:1 Square", 1), ("4:3", 4.0 / 3), ("3:2", 1.5), ("16:9 Wide", 16.0 / 9), ("21:9 Ultrawide", 21.0 / 9),
        ("3:4", 3.0 / 4), ("2:3", 2.0 / 3), ("9:16 Story", 9.0 / 16), ("4:5 Portrait", 0.8),
    ]

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Shape") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(ShapeKind.allCases) { s in
                            Button { model.shape = s } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: s.symbol)
                                        .font(.system(size: 20))
                                        .rotationEffect(.degrees(s == .hexagonFlat ? 90 : 0))
                                        .frame(height: 24)
                                    Text(s.rawValue).font(.caption2).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(model.shape == s ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(model.shape == s ? Color.accentColor : .clear, lineWidth: 1.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if model.shape == .rounded {
                        labeledSlider("Corner radius", value: $model.corner, in: 0...1, display: "\(Int(model.corner * 100))%")
                    }
                    if model.shape != .rectangle && model.shape != .rounded {
                        labeledSlider("Rotate shape", value: $model.rotation, in: -180...180, display: "\(Int(model.rotation))°")
                    }
                    Text("Tip: unlock the aspect ratio to stretch a shape — e.g. a wide hexagon or an oval.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                section("Background & Border") {
                    Toggle("Transparent background", isOn: $model.transparent)
                    if !model.transparent { ColorPicker("Background color", selection: $model.bgColor) }
                    if model.transparent && !model.format.supportsAlpha {
                        Text("JPEG can't be transparent — white will be used. Choose PNG for transparency.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    labeledSlider("Border width", value: $model.borderWidth, in: 0...100, display: "\(Int(model.borderWidth)) px")
                    if model.borderWidth > 0 { ColorPicker("Border color", selection: $model.borderColor) }
                }

                section("Export") {
                    Picker("Format", selection: $model.format) {
                        ForEach(OutputFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if model.format == .jpeg {
                        labeledSlider("Quality", value: $model.quality, in: 0.1...1, display: "\(Int(model.quality * 100))%")
                    }
                    Button {
                        model.exportSelected()
                    } label: {
                        Label("Save Image…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s")
                    .disabled(model.selected == nil)
                    if model.images.count > 1 {
                        Button {
                            model.exportAll()
                        } label: {
                            Label("Save All \(model.images.count) Images…", systemImage: "square.stack.3d.down.right")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                    }
                    if !model.status.isEmpty {
                        Text(model.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func numberField(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, display: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(display).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.add(urls: urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ShapeResizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("Shape Resizer", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Images…") { model.openPanel() }.keyboardShortcut("o")
            }
        }
    }
}
