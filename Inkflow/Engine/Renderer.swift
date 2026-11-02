import AppKit
import CoreGraphics

/// Builds each stroke's path once and reuses it while the stroke is only moved.
///
/// Moving a stroke shifts all of its points by the same amount, so a cached path stays valid
/// if it is translated by the difference between the stroke's first point now and when cached.
/// Not thread-safe: give each thread its own cache.
final class PathCache {
    private struct Entry {
        let count: Int
        let anchor: CGPoint
        let last: CGPoint
        let width: CGFloat
        let shape: StrokeShape
    }

    private var entries: [UUID: Entry] = [:]

    func shape(for stroke: Stroke) -> (shape: StrokeShape, offset: CGVector) {
        let anchor = stroke.points.first?.point ?? .zero
        let last = stroke.points.last?.point ?? .zero
        if let entry = entries[stroke.id], entry.count == stroke.points.count, entry.width == stroke.width {
            let offset = CGVector(dx: anchor.x - entry.anchor.x, dy: anchor.y - entry.anchor.y)
            // Same shape if the last point moved by the same amount as the first.
            if abs(last.x - entry.last.x - offset.dx) < 0.001, abs(last.y - entry.last.y - offset.dy) < 0.001 {
                return (entry.shape, offset)
            }
        }
        let shape = Geometry.shape(for: stroke)
        entries[stroke.id] = Entry(count: stroke.points.count, anchor: anchor, last: last, width: stroke.width, shape: shape)
        return (shape, .zero)
    }

    /// Drops entries for strokes that no longer exist.
    func prune(keeping ids: Set<UUID>) {
        guard entries.count > ids.count + 64 else { return }
        entries = entries.filter { ids.contains($0.key) }
    }
}

/// Draws items into a Core Graphics context whose coordinates are canvas points, y down.
final class Renderer {
    let cache: PathCache
    /// Highlighter ink multiplies on light paper and screens on dark paper, so it tints
    /// what is underneath without hiding it.
    var markerBlend: CGBlendMode = .multiply

    init(cache: PathCache = PathCache()) {
        self.cache = cache
    }

    func adapt(to background: RGBA) {
        markerBlend = background.isDark ? .screen : .multiply
    }

    /// Draws every visible layer. `visible` (canvas coordinates) culls items outside it.
    func draw(_ drawing: Drawing, in ctx: CGContext, visible: CGRect? = nil,
              layers range: Range<Int>? = nil, hiding hidden: UUID? = nil, only: Set<UUID>? = nil) {
        adapt(to: drawing.background)
        let indices = range ?? drawing.layers.indices
        for i in indices where drawing.layers[i].isVisible {
            drawLayer(drawing.layers[i], in: ctx, visible: visible, hiding: hidden, only: only)
        }
    }

    func drawLayer(_ layer: DrawingLayer, in ctx: CGContext, visible: CGRect? = nil,
                   hiding hidden: UUID? = nil, only: Set<UUID>? = nil, isolate: Bool? = nil) {
        let isolated = isolate ?? layer.needsIsolation
        ctx.saveGState()
        if isolated {
            ctx.setAlpha(CGFloat(layer.opacity))
            if let visible {
                ctx.beginTransparencyLayer(in: visible, auxiliaryInfo: nil)
            } else {
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            }
        }
        for item in layer.items where item.id != hidden {
            if let only, !only.contains(item.id), !item.isEraser { continue }
            if let visible, !Geometry.bounds(of: item).intersects(visible) { continue }
            draw(item, in: ctx)
        }
        if isolated { ctx.endTransparencyLayer() }
        ctx.restoreGState()
    }

    func draw(_ item: CanvasItem, in ctx: CGContext) {
        switch item {
        case .stroke(let stroke): draw(stroke, in: ctx)
        case .shape(let shape): draw(shape, in: ctx)
        case .text(let text): draw(text, in: ctx)
        }
    }

    func draw(_ stroke: Stroke, in ctx: CGContext) {
        guard !stroke.points.isEmpty else { return }
        let (shape, offset) = cache.shape(for: stroke)
        ctx.saveGState()
        if offset != .zero { ctx.translateBy(x: offset.dx, y: offset.dy) }
        switch stroke.tool {
        case .eraser:
            ctx.setBlendMode(.clear)
        case .marker:
            ctx.setBlendMode(markerBlend)
        default:
            ctx.setBlendMode(.normal)
        }
        let color = stroke.tool == .marker ? stroke.color.withAlpha(min(stroke.color.a, 0.4)) : stroke.color
        ctx.addPath(shape.path)
        switch shape.mode {
        case .fill:
            ctx.setFillColor(color.cgColor)
            ctx.fillPath(using: .winding)
        case .stroke(let width):
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    func draw(_ shape: ShapeItem, in ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(Geometry.path(for: shape))
        ctx.setStrokeColor(shape.color.cgColor)
        ctx.setLineWidth(shape.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    func draw(_ text: TextItem, in ctx: CGContext) {
        guard !text.text.isEmpty else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        Geometry.attributed(text).draw(
            with: CGRect(origin: text.origin, size: CGSize(width: 100_000, height: 100_000)),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Offscreen rendering

extension Renderer {
    /// A y-down bitmap context covering `rect` (canvas points) at `scale` pixels per point.
    static func bitmapContext(for rect: CGRect, scale: CGFloat) -> CGContext? {
        let width = Int((rect.width * scale).rounded(.up)), height = Int((rect.height * scale).rounded(.up))
        guard width > 0, height > 0, width * height < 400_000_000,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        ctx.interpolationQuality = .high
        return ctx
    }

    /// Renders the drawing's `rect` to an image. With `only`, just those items are drawn.
    static func image(of drawing: Drawing, rect: CGRect, scale: CGFloat,
                      background: Bool = true, only: Set<UUID>? = nil) -> CGImage? {
        guard let ctx = bitmapContext(for: rect, scale: scale) else { return nil }
        if background {
            ctx.setFillColor(drawing.background.cgColor)
            ctx.fill(rect)
        }
        Renderer().draw(drawing, in: ctx, visible: rect, only: only)
        return ctx.makeImage()
    }

    /// A one-page vector PDF of `rect`. Layers that use the eraser are embedded as images,
    /// because PDF has no "clear" blend mode.
    static func pdf(of drawing: Drawing, rect: CGRect, background: Bool = true, only: Set<UUID>? = nil) -> Data? {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: rect.size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        ctx.beginPDFPage(nil)
        ctx.translateBy(x: 0, y: rect.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        if background {
            ctx.setFillColor(drawing.background.cgColor)
            ctx.fill(rect)
        }
        let renderer = Renderer()
        renderer.adapt(to: drawing.background)
        for layer in drawing.layers where layer.isVisible {
            if layer.items.contains(where: \.isEraser) {
                var single = drawing
                single.layers = [layer]
                if let image = image(of: single, rect: rect, scale: 3, background: false, only: only) {
                    ctx.saveGState()
                    ctx.translateBy(x: rect.minX, y: rect.maxY)
                    ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
                    ctx.restoreGState()
                }
            } else {
                renderer.drawLayer(layer, in: ctx, visible: rect, only: only)
            }
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    /// Bounds of what would be exported, with a margin. Nil when there is nothing to export.
    static func contentBounds(of drawing: Drawing, only: Set<UUID>? = nil, margin: CGFloat = 24) -> CGRect? {
        var rect = CGRect.null
        for layer in drawing.layers where layer.isVisible {
            for item in layer.items where !item.isEraser && (only?.contains(item.id) ?? true) {
                rect = rect.union(Geometry.bounds(of: item))
            }
        }
        guard !rect.isNull, !rect.isEmpty else { return nil }
        return rect.insetBy(dx: -margin, dy: -margin).integral
    }
}
