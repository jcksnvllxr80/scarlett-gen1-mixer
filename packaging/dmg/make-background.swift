import AppKit
// Draws the disk-image window background (640×400 points) at the given scale.
// Usage: make-background <scale 1|2> <out.png>
let scale = CGFloat(Double(CommandLine.arguments[1])!)
let w = 640 * scale, h = 400 * scale
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: scale, y: scale)
let teal = NSColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1)
let amber = NSColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)
let blue = NSColor(red: 0.55, green: 0.65, blue: 1.0, alpha: 1)

// Background and faint patch-bay grid (teal / amber / blue bands)
NSGradient(colors: [NSColor(red: 0.071, green: 0.082, blue: 0.090, alpha: 1), NSColor(red: 0.030, green: 0.036, blue: 0.040, alpha: 1)])!
    .draw(in: CGRect(x: 0, y: 0, width: 640, height: 400), angle: -90)
let cell: CGFloat = 28, gap: CGFloat = 4
for c in 0..<21 { for r in 0..<13 {
    let tint = c < 7 ? teal : (c < 14 ? amber : blue)
    ctx.setFillColor(tint.withAlphaComponent(0.05).cgColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: CGFloat(c) * (cell + gap) + 2, y: CGFloat(r) * (cell + gap) + 2, width: cell, height: cell),
                       cornerWidth: 4, cornerHeight: 4, transform: nil)); ctx.fillPath()
}}

// Arrow from the app (x≈170) to Applications (x≈470), at icon height (y = 400 − 200)
let y: CGFloat = 200
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 14, color: teal.cgColor)
ctx.setStrokeColor(teal.cgColor); ctx.setLineWidth(7); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 258, y: y)); ctx.addLine(to: CGPoint(x: 380, y: y)); ctx.strokePath()
ctx.move(to: CGPoint(x: 358, y: y + 22)); ctx.addLine(to: CGPoint(x: 384, y: y)); ctx.addLine(to: CGPoint(x: 358, y: y - 22)); ctx.strokePath()
ctx.restoreGState()

// Light strips behind the icon names (Finder always draws them in dark text)
for cx in [CGFloat(170), 470] {
    ctx.setFillColor(NSColor(white: 0.82, alpha: 0.9).cgColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx - 78, y: 123, width: 156, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.fillPath()
}

// Text
func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: mono ? 2 : 0])
    attr.draw(at: CGPoint(x: (640 - attr.size().width) / 2, y: y))
}
draw("SCARLETT GEN 1 MIXER", size: 13, weight: .bold, color: teal, y: 340, mono: true)
draw("Drag the app to Applications to install", size: 15, weight: .semibold, color: NSColor(white: 0.88, alpha: 1), y: 80)
draw("First launch: if macOS can't verify the developer, open System Settings ▸ Privacy & Security ▸ Open Anyway",
     size: 10, weight: .regular, color: NSColor(white: 0.55, alpha: 1), y: 40)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
