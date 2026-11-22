import AppKit
// The app's "Cool S" mark, drawn as glowing neon lines in the app's teal.
// Usage:
//   make-icon icon <out.png>   → 1024×1024 app icon: the S almost filling a solid dark rounded tile
//   make-icon mark <out.png>   → 1024×1024 transparent image of just the S (splash screen)
let mode = CommandLine.arguments[1]
let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let size = CGFloat(px)
let teal = NSColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1)
let tealBright = NSColor(red: 0.62, green: 1.0, blue: 0.94, alpha: 1)

// Solid dark rounded tile (macOS icon grid: 824×824 centred, radius ~185)
if mode == "icon" {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.setFillColor(NSColor(red: 0.043, green: 0.051, blue: 0.055, alpha: 1).cgColor)
    ctx.fillPath()
}

// Cool S geometry on a 2 × 7.5 grid, sized to almost fill the tile
let unitY: CGFloat = mode == "icon" ? 88 : 108, unitX: CGFloat = unitY * 2.25
let ox = size / 2 - unitX, oy = size / 2 - 3.75 * unitY
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * unitX, y: oy + y * unitY) }
let segs: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [
    ((0, 6), (1, 7.5)), ((1, 7.5), (2, 6)),
    ((0, 6), (0, 4.5)), ((1, 6), (1, 4.5)), ((2, 6), (2, 4.5)),
    ((0, 4.5), (1, 3)), ((1, 4.5), (2, 3)),
    ((2, 4.5), (1.5, 3.75)), ((0, 3), (0.5, 3.75)),
    ((0, 3), (0, 1.5)), ((1, 3), (1, 1.5)), ((2, 3), (2, 1.5)),
    ((0, 1.5), (1, 0)), ((1, 0), (2, 1.5)),
]
// Glowing neon lines: wide soft halo, teal tube, bright core
func strokeS(width: CGFloat, color: NSColor, blur: CGFloat) {
    ctx.saveGState()
    if blur > 0 { ctx.setShadow(offset: .zero, blur: blur, color: teal.cgColor) }
    for (a, b) in segs { ctx.move(to: p(a.0, a.1)); ctx.addLine(to: p(b.0, b.1)) }
    ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(width); ctx.strokePath()
    ctx.restoreGState()
}
ctx.setLineCap(.round); ctx.setLineJoin(.round)
strokeS(width: unitY * 0.55, color: teal.withAlphaComponent(0.18), blur: unitY * 0.9)
strokeS(width: unitY * 0.30, color: teal, blur: unitY * 0.45)
strokeS(width: unitY * 0.11, color: tealBright, blur: 0)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
