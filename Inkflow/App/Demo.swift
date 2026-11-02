import CoreGraphics
import Foundation

/// A sample drawing for screenshots, built from code so it is the same every time.
enum Demo {
    static func drawing(dark: Bool) -> Drawing {
        let ink = dark ? RGBA(hex: "#F2F1EE") : RGBA.ink
        let graphite = dark ? RGBA(hex: "#A1A1A6") : RGBA(hex: "#6E6E73")
        let amber = RGBA(hex: "#F5A623"), green = RGBA(hex: "#30A46C"), blue = RGBA(hex: "#2F6FEB")
        let red = RGBA(hex: "#E5484D"), violet = RGBA(hex: "#8E4EC6")
        var rand = Rand(seed: 7)

        // MARK: Sketch layer: a small landscape in brush ink
        var sketch: [CanvasItem] = []
        let sun = CGPoint(x: 400, y: 230)
        sketch.append(brush(width: 7, color: amber, rand: &rand, steps: 90) { t in
            let a = -0.4 + t * (.pi * 2 + 0.55)
            let r = 44 + 2 * sin(t * 9)
            return CGPoint(x: sun.x + cos(a) * r, y: sun.y + sin(a) * r)
        })
        for i in 0..<9 {
            let a = CGFloat(i) / 9 * .pi * 2 + 0.2
            sketch.append(brush(width: 5, color: amber, rand: &rand, steps: 8) { t in
                let r = 62 + t * 20
                return CGPoint(x: sun.x + cos(a) * r, y: sun.y + sin(a) * r)
            })
        }
        let ridge: [CGPoint] = [
            CGPoint(x: 50, y: 470), CGPoint(x: 130, y: 380), CGPoint(x: 175, y: 330), CGPoint(x: 215, y: 375),
            CGPoint(x: 250, y: 345), CGPoint(x: 300, y: 290), CGPoint(x: 360, y: 370), CGPoint(x: 430, y: 420),
            CGPoint(x: 520, y: 470),
        ]
        sketch.append(brush(width: 6, color: ink, rand: &rand, steps: 120) { along(ridge, $0) })
        sketch.append(brush(width: 3.5, color: ink, rand: &rand, steps: 30) { t in
            CGPoint(x: 300 - t * 46, y: 290 + t * 52 + sin(t * 6) * 3)
        })
        sketch.append(brush(width: 9, color: green, rand: &rand, steps: 140) { t in
            let x = 30 + t * 520
            return CGPoint(x: x, y: 492 + 16 * sin(x / 58))
        })
        sketch.append(brush(width: 8, color: blue, rand: &rand, steps: 140) { t in
            let x = 40 + t * 500
            return CGPoint(x: x, y: 536 + 10 * sin(x / 40 + 1.4))
        })
        sketch.append(brush(width: 5, color: blue, rand: &rand, steps: 100) { t in
            let x = 90 + t * 400
            return CGPoint(x: x, y: 566 + 7 * sin(x / 30 + 0.4))
        })
        for (bx, by, s) in [(150.0, 200.0, 1.0), (205.0, 176.0, 0.8), (240.0, 214.0, 0.65)] {
            for side in [-1.0, 1.0] {
                sketch.append(pencil(width: 2, color: ink, rand: &rand, steps: 10) { t in
                    let x = bx + side * t * 16 * s
                    return CGPoint(x: x, y: by - sin(t * .pi * 0.9) * 7 * s + t * 3 * s)
                })
            }
        }

        // MARK: Notes layer: a small plan with shapes and text
        var notes: [CanvasItem] = []
        notes.append(.text(TextItem(text: "Weekend sketchbook", origin: CGPoint(x: 40, y: 40), fontSize: 36, color: ink)))
        notes.append(.text(TextItem(text: "a landscape, a plan, a palette", origin: CGPoint(x: 42, y: 92), fontSize: 17, color: graphite)))

        let boxes = ["Sketch", "Refine", "Share"]
        for (i, label) in boxes.enumerated() {
            let rect = CGRect(x: 640 + CGFloat(i) * 190, y: 190, width: 140, height: 76)
            notes.append(.shape(ShapeItem(kind: .rectangle, start: rect.origin, end: CGPoint(x: rect.maxX, y: rect.maxY),
                                          color: ink, width: 2.5)))
            var text = TextItem(text: label, origin: .zero, fontSize: 21, color: ink)
            let size = Geometry.textBounds(text).size
            text.origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
            notes.append(.text(text))
            if i < boxes.count - 1 {
                notes.append(.shape(ShapeItem(kind: .arrow, start: CGPoint(x: rect.maxX + 10, y: rect.midY),
                                              end: CGPoint(x: rect.maxX + 42, y: rect.midY), color: graphite, width: 2.5)))
            }
        }

        let list = ["– ink the hills", "– pick a palette", "– share on Sunday"]
        for (i, line) in list.enumerated() {
            notes.append(.text(TextItem(text: line, origin: CGPoint(x: 660, y: 330 + CGFloat(i) * 38), fontSize: 20, color: ink)))
        }
        // A check mark next to the second item, and Sunday circled.
        notes.append(pencil(width: 3, color: green, rand: &rand, steps: 12) { t in
            t < 0.35 ? CGPoint(x: 625 + t / 0.35 * 9, y: 383 + t / 0.35 * 9)
                     : CGPoint(x: 634 + (t - 0.35) / 0.65 * 18, y: 392 - (t - 0.35) / 0.65 * 24)
        })
        notes.append(brush(width: 3.5, color: red, rand: &rand, steps: 80) { t in
            let a = -2.6 + t * (.pi * 2 + 0.4)
            return CGPoint(x: 824 + cos(a) * 48, y: 419 + sin(a) * 20)
        })
        notes.append(.shape(ShapeItem(kind: .arrow, start: CGPoint(x: 1010, y: 468), end: CGPoint(x: 882, y: 430),
                                      color: red, width: 2.5)))
        notes.append(.text(TextItem(text: "deadline!", origin: CGPoint(x: 1016, y: 458), fontSize: 18, color: red)))

        // Paint dabs.
        for (i, color) in [ink, graphite, red, amber, green, blue, violet].enumerated() {
            let c = CGPoint(x: 668 + CGFloat(i) * 46, y: 540 + sin(CGFloat(i) * 1.7) * 4)
            notes.append(brush(width: 30, color: color, rand: &rand, steps: 6) { t in
                CGPoint(x: c.x - 6 + t * 12, y: c.y + sin(t * .pi) * 3)
            })
        }

        // MARK: Highlights layer
        var highlights: [CanvasItem] = []
        highlights.append(marker(width: 24, color: amber.withAlpha(0.45), from: CGPoint(x: 36, y: 72), to: CGPoint(x: 372, y: 70)))
        highlights.append(marker(width: 30, color: RGBA(hex: "#F5D90A").withAlpha(0.5),
                                 from: CGPoint(x: 852, y: 228), to: CGPoint(x: 948, y: 229)))

        var layers = [
            DrawingLayer(name: "Sketch", items: sketch),
            DrawingLayer(name: "Notes", items: notes),
            DrawingLayer(name: "Highlights", items: highlights),
        ]
        layers[0].opacity = 1
        return Drawing(background: dark ? Paper.dark.color : Paper.paper.color, layers: layers)
    }

    // MARK: Helpers

    private struct Rand {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 10_000) / 10_000 - 0.5
        }
    }

    /// A point `t` (0…1) of the way along a polyline.
    private static func along(_ points: [CGPoint], _ t: CGFloat) -> CGPoint {
        let scaled = t * CGFloat(points.count - 1)
        let i = min(Int(scaled), points.count - 2)
        let f = scaled - CGFloat(i)
        return CGPoint(x: points[i].x + (points[i + 1].x - points[i].x) * f,
                       y: points[i].y + (points[i + 1].y - points[i].y) * f)
    }

    private static func brush(width: CGFloat, color: RGBA, rand: inout Rand, steps: Int,
                              _ f: (CGFloat) -> CGPoint) -> CanvasItem {
        var points: [StrokePoint] = []
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let p = f(t)
            let pressure = pow(sin(.pi * min(max(t, 0.02), 0.98)), 0.45) * (0.85 + 0.15 * sin(t * 11))
            points.append(StrokePoint(x: p.x + rand.next() * 0.8, y: p.y + rand.next() * 0.8, pressure: pressure))
        }
        return .stroke(Stroke(tool: .brush, color: color, width: width, points: points))
    }

    private static func pencil(width: CGFloat, color: RGBA, rand: inout Rand, steps: Int,
                               _ f: (CGFloat) -> CGPoint) -> CanvasItem {
        let points = (0...steps).map { s -> StrokePoint in
            let p = f(CGFloat(s) / CGFloat(steps))
            return StrokePoint(x: p.x + rand.next() * 0.4, y: p.y + rand.next() * 0.4)
        }
        return .stroke(Stroke(tool: .pencil, color: color, width: width, points: points))
    }

    private static func marker(width: CGFloat, color: RGBA, from a: CGPoint, to b: CGPoint) -> CanvasItem {
        let points = (0...12).map { s -> StrokePoint in
            let t = CGFloat(s) / 12
            return StrokePoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t + sin(t * 3) * 1.5)
        }
        return .stroke(Stroke(tool: .marker, color: color, width: width, points: points))
    }
}
