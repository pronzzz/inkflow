// Generates Inkflow's app icon and DMG background.
//   swift scripts/make_art.swift icon <out.png>            1024×1024 app icon
//   swift scripts/make_art.swift appiconset <dir>          every AppIcon size into an .appiconset folder
//   swift scripts/make_art.swift dmg <out.png> <scale>     660×400 pt DMG window background
import AppKit

let ink = NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
let blue = NSColor(srgbRed: 0.184, green: 0.435, blue: 0.922, alpha: 1)

func render(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .high
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// A variable-width brush line through `points` (y up), using the same quad-and-disc outline as the app.
func brush(_ ctx: CGContext, _ points: [CGPoint], width: (CGFloat) -> CGFloat, color: NSColor) {
    let path = CGMutablePath()
    let n = points.count
    func r(_ i: Int) -> CGFloat { width(CGFloat(i) / CGFloat(n - 1)) / 2 }
    for i in 0..<n {
        let p = points[i], ri = r(i)
        path.addEllipse(in: CGRect(x: p.x - ri, y: p.y - ri, width: ri * 2, height: ri * 2))
        guard i < n - 1 else { break }
        let q = points[i + 1], rq = r(i + 1)
        let len = hypot(q.x - p.x, q.y - p.y)
        guard len > 0 else { continue }
        let nx = -(q.y - p.y) / len, ny = (q.x - p.x) / len
        path.move(to: CGPoint(x: p.x - nx * ri, y: p.y - ny * ri))
        path.addLine(to: CGPoint(x: q.x - nx * rq, y: q.y - ny * rq))
        path.addLine(to: CGPoint(x: q.x + nx * rq, y: q.y + ny * rq))
        path.addLine(to: CGPoint(x: p.x + nx * ri, y: p.y + ny * ri))
        path.closeSubpath()
    }
    ctx.addPath(path)
    ctx.setFillColor(color.cgColor)
    ctx.fillPath(using: .winding)
}

/// One confident S-shaped ink stroke, thick in the middle and tapered at both ends.
func swoosh(center c: CGPoint, size s: CGFloat) -> [CGPoint] {
    (0...400).map { i in
        let t = CGFloat(i) / 400
        let x = c.x + (t - 0.5) * s * 0.92
        let y = c.y + sin((t - 0.5) * .pi * 1.9) * s * 0.20 - (t - 0.5) * s * 0.10
        return CGPoint(x: x, y: y)
    }
}

func drawIcon(_ ctx: CGContext) {
    // macOS icon grid: an 824 pt rounded square centred in 1024, with a soft shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.addPath(shape)
    ctx.setFillColor(NSColor(srgbRed: 0.984, green: 0.980, blue: 0.969, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
        NSColor(srgbRed: 1, green: 1, blue: 0.995, alpha: 1).cgColor,
        NSColor(srgbRed: 0.945, green: 0.937, blue: 0.918, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Faint dot grid, like the canvas.
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.07).cgColor)
    for gx in stride(from: 152.0, through: 872, by: 72) {
        for gy in stride(from: 152.0, through: 872, by: 72) {
            ctx.fillEllipse(in: CGRect(x: gx - 4, y: gy - 4, width: 8, height: 8))
        }
    }

    let points = swoosh(center: CGPoint(x: 500, y: 520), size: 600)
    brush(ctx, points, width: { t in 22 + 96 * pow(sin(.pi * t), 1.25) }, color: ink)
    // The ink drop the stroke is heading for.
    ctx.setFillColor(blue.cgColor)
    ctx.fillEllipse(in: CGRect(x: 760, y: 676, width: 88, height: 88))
    ctx.restoreGState()

    ctx.addPath(shape)
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func drawDMG(_ ctx: CGContext, size: CGSize) {
    ctx.setFillColor(NSColor(srgbRed: 0.984, green: 0.980, blue: 0.969, alpha: 1).cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.09).cgColor)
    for gx in stride(from: 12.0, through: size.width, by: 24) {
        for gy in stride(from: 12.0, through: size.height, by: 24) {
            ctx.fillEllipse(in: CGRect(x: gx - 1, y: gy - 1, width: 2, height: 2))
        }
    }
    // A hand-drawn arrow from the app to Applications (icons sit at 170 and 490, y 170 from the top).
    let y = size.height - 175
    let points = (0...200).map { i -> CGPoint in
        let t = CGFloat(i) / 200
        return CGPoint(x: 258 + t * 144, y: y + sin(t * .pi) * 14)
    }
    brush(ctx, points, width: { t in 2 + 4 * pow(sin(.pi * min(t * 1.1, 1)), 0.8) }, color: ink.withAlphaComponent(0.55))
    let tip = points.last!
    for a in [CGFloat.pi * 0.80, CGFloat.pi * 1.22] {
        let end = CGPoint(x: tip.x + cos(a) * 16, y: tip.y + sin(a) * 16)
        brush(ctx, [end, tip], width: { _ in 4.5 }, color: ink.withAlphaComponent(0.55))
    }
    let text = NSAttributedString(string: "Drag Inkflow into Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.black.withAlphaComponent(0.45),
    ])
    let w = text.size().width
    text.draw(at: CGPoint(x: (size.width - w) / 2, y: 70))
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "icon":
    try! render(size: CGSize(width: 1024, height: 1024), scale: 1, draw: drawIcon).write(to: URL(fileURLWithPath: args[2]))
case "appiconset":
    let dir = URL(fileURLWithPath: args[2])
    for base in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
            let px = CGFloat(base * scale)
            let data = render(size: CGSize(width: px, height: px), scale: 1) { ctx in
                ctx.scaleBy(x: px / 1024, y: px / 1024)
                drawIcon(ctx)
            }
            try! data.write(to: dir.appendingPathComponent(name))
        }
    }
case "dmg":
    let scale = CGFloat(Double(args[3]) ?? 1)
    try! render(size: CGSize(width: 660, height: 400), scale: scale) { drawDMG($0, size: CGSize(width: 660, height: 400)) }
        .write(to: URL(fileURLWithPath: args[2]))
default:
    print("usage: make_art.swift icon <out.png> | appiconset <dir> | dmg <out.png> <scale>")
}
