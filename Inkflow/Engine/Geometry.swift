import AppKit
import CoreGraphics

/// How a built stroke path is painted.
enum PaintMode: Equatable {
    /// Fill the path (variable-width brush outlines).
    case fill
    /// Stroke the path with a round pen of this width.
    case stroke(CGFloat)
}

struct StrokeShape {
    let path: CGPath
    let mode: PaintMode
    /// Painted area, including the pen width.
    let bounds: CGRect
}

/// Pure geometry for every item type: paths, bounds and hit testing. Everything here is
/// thread-safe, so documents can render thumbnails in the background.
enum Geometry {

    // MARK: Strokes

    static func shape(for stroke: Stroke) -> StrokeShape {
        let points = stroke.points
        guard let first = points.first else {
            return StrokeShape(path: CGMutablePath(), mode: .fill, bounds: .null)
        }
        // A tap: a single round dot.
        if points.count == 1 || points.allSatisfy({ $0.x == first.x && $0.y == first.y }) {
            let r = radius(for: stroke, pressure: first.pressure)
            let rect = CGRect(x: first.x - r, y: first.y - r, width: r * 2, height: r * 2)
            return StrokeShape(path: CGPath(ellipseIn: rect, transform: nil), mode: .fill, bounds: rect)
        }

        switch stroke.tool {
        case .brush:
            let path = outline(of: smooth(points), stroke: stroke)
            return StrokeShape(path: path, mode: .fill, bounds: path.boundingBoxOfPath)
        case .pencil, .marker, .eraser:
            let path = centerline(of: points)
            let w = stroke.width
            return StrokeShape(path: path, mode: .stroke(w),
                               bounds: path.boundingBoxOfPath.insetBy(dx: -w / 2 - 1, dy: -w / 2 - 1))
        }
    }

    /// Brush radius at a given pressure. Light pressure still leaves a visible line.
    static func radius(for stroke: Stroke, pressure: CGFloat) -> CGFloat {
        guard stroke.tool == .brush else { return stroke.width / 2 }
        return max(0.35, stroke.width / 2 * (0.25 + 0.75 * min(max(pressure, 0), 1)))
    }

    /// Catmull-Rom subdivision so the outline follows a smooth curve through the input points.
    static func smooth(_ points: [StrokePoint]) -> [StrokePoint] {
        guard points.count > 2 else { return points }
        var out: [StrokePoint] = [points[0]]
        out.reserveCapacity(points.count * 3)
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)], p1 = points[i]
            let p2 = points[i + 1], p3 = points[min(i + 2, points.count - 1)]
            let length = hypot(p2.x - p1.x, p2.y - p1.y)
            let steps = min(max(Int(length / 2.5), 1), 12)
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let t2 = t * t, t3 = t2 * t
                func cr(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
                }
                out.append(StrokePoint(x: cr(p0.x, p1.x, p2.x, p3.x),
                                       y: cr(p0.y, p1.y, p2.y, p3.y),
                                       pressure: p1.pressure + (p2.pressure - p1.pressure) * t))
            }
        }
        return out
    }

    /// The filled outline of a variable-width line: a quad between each pair of points, plus a
    /// disc wherever the line turns or ends so joints stay round. All sub-paths wind the same
    /// way, so filling with the non-zero rule paints their union in one pass (no double alpha).
    static func outline(of points: [StrokePoint], stroke: Stroke) -> CGPath {
        let path = CGMutablePath()
        let radii = points.map { radius(for: stroke, pressure: $0.pressure) }

        func disc(_ i: Int) {
            let r = radii[i]
            path.addEllipse(in: CGRect(x: points[i].x - r, y: points[i].y - r, width: r * 2, height: r * 2))
        }

        disc(0)
        var previousDirection: CGVector?
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let length = hypot(dx, dy)
            guard length > 0.0001 else { continue }
            let dir = CGVector(dx: dx / length, dy: dy / length)
            if let prev = previousDirection, prev.dx * dir.dx + prev.dy * dir.dy < 0.985 {
                disc(i) // turned more than ~10°
            }
            previousDirection = dir
            let nx = -dir.dy, ny = dir.dx
            let ra = radii[i], rb = radii[i + 1]
            // Same orientation as CGPath ellipses, so the non-zero fill unions them.
            path.move(to: CGPoint(x: a.x - nx * ra, y: a.y - ny * ra))
            path.addLine(to: CGPoint(x: b.x - nx * rb, y: b.y - ny * rb))
            path.addLine(to: CGPoint(x: b.x + nx * rb, y: b.y + ny * rb))
            path.addLine(to: CGPoint(x: a.x + nx * ra, y: a.y + ny * ra))
            path.closeSubpath()
        }
        disc(points.count - 1)
        return path
    }

    /// A smooth open path through the points (midpoint quadratic curves).
    static func centerline(of points: [StrokePoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0].point)
        if points.count == 2 {
            path.addLine(to: points[1].point)
            return path
        }
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[i].point)
        }
        path.addLine(to: points[points.count - 1].point)
        return path
    }

    // MARK: Shapes

    static func path(for shape: ShapeItem) -> CGPath {
        let path = CGMutablePath()
        switch shape.kind {
        case .line:
            path.move(to: shape.start)
            path.addLine(to: shape.end)
        case .arrow:
            path.move(to: shape.start)
            path.addLine(to: shape.end)
            let angle = atan2(shape.end.y - shape.start.y, shape.end.x - shape.start.x)
            let length = hypot(shape.end.x - shape.start.x, shape.end.y - shape.start.y)
            let head = min(max(10, shape.width * 4), length * 0.6)
            for side in [-1.0, 1.0] {
                let a = angle + .pi + side * .pi / 7
                path.move(to: CGPoint(x: shape.end.x + cos(a) * head, y: shape.end.y + sin(a) * head))
                path.addLine(to: shape.end)
            }
        case .rectangle:
            path.addRect(shape.rect)
        case .ellipse:
            path.addEllipse(in: shape.rect)
        }
        return path
    }

    /// Keeps squares square, circles round and lines at 45° steps while Shift is held.
    static func constrained(_ end: CGPoint, from start: CGPoint, kind: ShapeKind) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        switch kind {
        case .rectangle, .ellipse:
            let side = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
        case .line, .arrow:
            let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
            let length = hypot(dx, dy)
            return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        }
    }

    // MARK: Text

    static func font(size: CGFloat) -> NSFont { NSFont.systemFont(ofSize: size, weight: .regular) }

    static func attributed(_ text: TextItem) -> NSAttributedString {
        NSAttributedString(string: text.text.isEmpty ? " " : text.text, attributes: [
            .font: font(size: text.fontSize),
            .foregroundColor: NSColor(srgbRed: text.color.r, green: text.color.g, blue: text.color.b, alpha: text.color.a),
        ])
    }

    static func textBounds(_ text: TextItem) -> CGRect {
        let size = attributed(text).boundingRect(with: CGSize(width: 100_000, height: 100_000),
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading]).size
        return CGRect(origin: text.origin, size: CGSize(width: ceil(size.width), height: ceil(size.height)))
    }

    // MARK: Bounds

    /// Painted bounds of an item. Cheap for strokes and shapes (no path building).
    static func bounds(of item: CanvasItem) -> CGRect {
        switch item {
        case .stroke(let s):
            guard let first = s.points.first else { return .null }
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in s.points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            let pad = s.width / 2 + 1
            return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
        case .shape(let s):
            var rect = s.rect
            if s.kind == .arrow { rect = rect.insetBy(dx: -max(10, s.width * 4), dy: -max(10, s.width * 4)) }
            return rect.insetBy(dx: -s.width / 2 - 1, dy: -s.width / 2 - 1)
        case .text(let t):
            return textBounds(t)
        }
    }

    static func bounds(of items: [CanvasItem]) -> CGRect {
        items.reduce(CGRect.null) { $0.union(bounds(of: $1)) }
    }

    // MARK: Hit testing

    /// Whether a click at `point` (canvas coordinates) lands on the item, with `tolerance` slack.
    static func hitTest(_ item: CanvasItem, at point: CGPoint, tolerance: CGFloat) -> Bool {
        guard bounds(of: item).insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { return false }
        switch item {
        case .stroke(let s):
            guard s.tool != .eraser else { return false }
            if s.points.count == 1 {
                return hypot(point.x - s.points[0].x, point.y - s.points[0].y) <= s.width / 2 + tolerance
            }
            for i in 0..<(s.points.count - 1) {
                let a = s.points[i], b = s.points[i + 1]
                let r = max(radius(for: s, pressure: a.pressure), radius(for: s, pressure: b.pressure))
                if distance(point, toSegment: a.point, b.point) <= r + tolerance { return true }
            }
            return false
        case .shape(let s):
            let reach = s.width / 2 + tolerance
            switch s.kind {
            case .line, .arrow:
                return distance(point, toSegment: s.start, s.end) <= reach
            case .rectangle:
                let r = s.rect
                return r.insetBy(dx: -reach, dy: -reach).contains(point)
                    && !r.insetBy(dx: reach, dy: reach).contains(point)
            case .ellipse:
                let r = s.rect
                guard r.width > 0, r.height > 0 else { return distance(point, toSegment: s.start, s.end) <= reach }
                // Distance to the outline, approximated in normalised space.
                let nx = (point.x - r.midX) / (r.width / 2), ny = (point.y - r.midY) / (r.height / 2)
                let d = abs(hypot(nx, ny) - 1) * min(r.width, r.height) / 2
                return d <= reach
            }
        case .text(let t):
            return textBounds(t).insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared, 0), 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
