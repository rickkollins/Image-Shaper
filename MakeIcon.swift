import AppKit
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(red: 0.98, green: 0.45, blue: 0.35, alpha: 1), NSColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 1)])!.draw(in: squircle, angle: -60)
// back: hexagon
func poly(_ n: Int, _ c: NSPoint, _ r: CGFloat, _ start: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0..<n { let a = (start + CGFloat(i) * 360 / CGFloat(n)) * .pi / 180
        let pt = NSPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        i == 0 ? p.move(to: pt) : p.line(to: pt) }
    p.close(); return p
}
NSColor.white.withAlphaComponent(0.35).setFill()
poly(6, NSPoint(x: 600, y: 600), 230, 90).fill()
NSColor.white.withAlphaComponent(0.6).setFill()
NSBezierPath(ovalIn: NSRect(x: 230, y: 230, width: 340, height: 340)).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 380, y: 380, width: 270, height: 270), xRadius: 40, yRadius: 40).fill()
// resize arrow
let arrow = NSBezierPath()
arrow.lineWidth = 34; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 440, y: 440)); arrow.line(to: NSPoint(x: 590, y: 590))
arrow.move(to: NSPoint(x: 590, y: 500)); arrow.line(to: NSPoint(x: 590, y: 590)); arrow.line(to: NSPoint(x: 500, y: 590))
arrow.move(to: NSPoint(x: 440, y: 530)); arrow.line(to: NSPoint(x: 440, y: 440)); arrow.line(to: NSPoint(x: 530, y: 440))
NSColor(red: 0.6, green: 0.3, blue: 0.85, alpha: 1).setStroke(); arrow.stroke()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
