import CoreGraphics
import Foundation

/// An sRGB colour with alpha. Stored in files as `#RRGGBBAA`.
struct RGBA: Hashable, Codable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Accepts `#RGB`, `#RRGGBB` or `#RRGGBBAA` (the `#` is optional). Anything else is black.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        guard Scanner(string: digits).scanHexInt64(&value) else { self.init(0, 0, 0); return }
        switch digits.count {
        case 3:
            self.init(Double((value >> 8) & 0xF) / 15, Double((value >> 4) & 0xF) / 15, Double(value & 0xF) / 15)
        case 6:
            self.init(Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        case 8:
            self.init(Double((value >> 24) & 0xFF) / 255, Double((value >> 16) & 0xFF) / 255,
                      Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        default:
            self.init(0, 0, 0)
        }
    }

    var hex: String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", byte(r), byte(g), byte(b), byte(a))
    }

    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

    func withAlpha(_ alpha: Double) -> RGBA { RGBA(r, g, b, alpha) }

    /// Relative luminance, 0 (black) to 1 (white).
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    var isDark: Bool { luminance < 0.5 }

    init(from decoder: Decoder) throws {
        self.init(hex: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

extension RGBA {
    static let ink = RGBA(hex: "#1D1D1F")
    static let white = RGBA(1, 1, 1)
    static let paper = RGBA(hex: "#FBFAF7")

    /// The swatches shown in the tool palette.
    static let palette: [RGBA] = [
        RGBA(hex: "#1D1D1F"), // ink
        RGBA(hex: "#8E8E93"), // graphite
        RGBA(hex: "#E5484D"), // red
        RGBA(hex: "#F5A623"), // amber
        RGBA(hex: "#30A46C"), // green
        RGBA(hex: "#2F6FEB"), // blue
        RGBA(hex: "#8E4EC6"), // violet
    ]
}

/// Canvas background presets.
enum Paper: String, CaseIterable, Identifiable {
    case white, paper, grey, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: return "White"
        case .paper: return "Paper"
        case .grey: return "Grey"
        case .dark: return "Dark"
        }
    }
    var color: RGBA {
        switch self {
        case .white: return .white
        case .paper: return .paper
        case .grey: return RGBA(hex: "#EDEDEF")
        case .dark: return RGBA(hex: "#1B1B1D")
        }
    }
}

// MARK: - Items

enum StrokeTool: String, Codable, Sendable {
    /// Pressure-sensitive, tapered ink.
    case brush
    /// Constant width, crisp.
    case pencil
    /// Wide, translucent, multiplies with what is underneath.
    case marker
    /// Clears pixels within its own layer.
    case eraser
}

struct StrokePoint: Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat
    /// 0…1. Real pen pressure for tablets, simulated from speed for mice and trackpads.
    var pressure: CGFloat

    init(x: CGFloat, y: CGFloat, pressure: CGFloat = 1) {
        self.x = x; self.y = y; self.pressure = pressure
    }

    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct Stroke: Hashable, Identifiable, Sendable {
    var id = UUID()
    var tool: StrokeTool
    var color: RGBA
    var width: CGFloat
    var points: [StrokePoint] = []
}

extension Stroke: Codable {
    private enum Keys: String, CodingKey { case id, tool, color, width, points }

    // Points are stored as one flat [x, y, pressure, x, y, pressure, …] array, rounded to
    // hundredths of a point: about a fifth of the size of one JSON object per point.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(UUID.self, forKey: .id)
        tool = try c.decode(StrokeTool.self, forKey: .tool)
        color = try c.decode(RGBA.self, forKey: .color)
        width = try c.decode(CGFloat.self, forKey: .width)
        let flat = try c.decode([CGFloat].self, forKey: .points)
        points = stride(from: 0, to: flat.count - 2, by: 3).map {
            StrokePoint(x: flat[$0], y: flat[$0 + 1], pressure: flat[$0 + 2])
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tool, forKey: .tool)
        try c.encode(color, forKey: .color)
        try c.encode(width, forKey: .width)
        var flat: [CGFloat] = []
        flat.reserveCapacity(points.count * 3)
        for p in points {
            flat.append((p.x * 100).rounded() / 100)
            flat.append((p.y * 100).rounded() / 100)
            flat.append((p.pressure * 1000).rounded() / 1000)
        }
        try c.encode(flat, forKey: .points)
    }
}

enum ShapeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case line, arrow, rectangle, ellipse

    var id: String { rawValue }
    var title: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        }
    }
    var symbol: String {
        switch self {
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        }
    }
    var key: String {
        switch self {
        case .line: return "L"
        case .arrow: return "A"
        case .rectangle: return "R"
        case .ellipse: return "O"
        }
    }
}

struct ShapeItem: Hashable, Identifiable, Codable, Sendable {
    var id = UUID()
    var kind: ShapeKind
    var start: CGPoint
    var end: CGPoint
    var color: RGBA
    var width: CGFloat

    var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

struct TextItem: Hashable, Identifiable, Codable, Sendable {
    var id = UUID()
    var text: String
    /// Top-left corner of the first line.
    var origin: CGPoint
    var fontSize: CGFloat
    var color: RGBA
}

enum CanvasItem: Hashable, Identifiable, Sendable {
    case stroke(Stroke)
    case shape(ShapeItem)
    case text(TextItem)

    var id: UUID {
        switch self {
        case .stroke(let s): return s.id
        case .shape(let s): return s.id
        case .text(let t): return t.id
        }
    }

    var isEraser: Bool {
        if case .stroke(let s) = self { return s.tool == .eraser }
        return false
    }

    func translated(by d: CGVector) -> CanvasItem {
        switch self {
        case .stroke(var s):
            for i in s.points.indices {
                s.points[i].x += d.dx
                s.points[i].y += d.dy
            }
            return .stroke(s)
        case .shape(var s):
            s.start = CGPoint(x: s.start.x + d.dx, y: s.start.y + d.dy)
            s.end = CGPoint(x: s.end.x + d.dx, y: s.end.y + d.dy)
            return .shape(s)
        case .text(var t):
            t.origin = CGPoint(x: t.origin.x + d.dx, y: t.origin.y + d.dy)
            return .text(t)
        }
    }

    /// The same item with a fresh identity, for paste and duplicate.
    func copyWithNewID() -> CanvasItem {
        switch self {
        case .stroke(var s): s.id = UUID(); return .stroke(s)
        case .shape(var s): s.id = UUID(); return .shape(s)
        case .text(var t): t.id = UUID(); return .text(t)
        }
    }
}

extension CanvasItem: Codable {
    private enum Keys: String, CodingKey { case type }

    // Flat encoding: {"type": "stroke", "id": …, "points": […]}
    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .type)
        switch type {
        case "stroke": self = .stroke(try Stroke(from: decoder))
        case "shape": self = .shape(try ShapeItem(from: decoder))
        case "text": self = .text(try TextItem(from: decoder))
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown item type \(type)"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .stroke(let s): try c.encode("stroke", forKey: .type); try s.encode(to: encoder)
        case .shape(let s): try c.encode("shape", forKey: .type); try s.encode(to: encoder)
        case .text(let t): try c.encode("text", forKey: .type); try t.encode(to: encoder)
        }
    }
}

// MARK: - Layers and drawing

struct DrawingLayer: Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var isVisible = true
    var isLocked = false
    var opacity: Double = 1
    var items: [CanvasItem] = []

    init(id: UUID = UUID(), name: String, items: [CanvasItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }

    /// Layers with erasers or partial opacity are composited in their own buffer.
    var needsIsolation: Bool { opacity < 1 || items.contains(where: \.isEraser) }
}

extension DrawingLayer: Codable {
    private enum Keys: String, CodingKey { case id, name, isVisible, isLocked, opacity, items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        items = try c.decodeIfPresent([CanvasItem].self, forKey: .items) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(isVisible, forKey: .isVisible)
        try c.encode(isLocked, forKey: .isLocked)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(items, forKey: .items)
    }
}

/// Everything saved in an `.inkflow` document. Coordinates are canvas points, y pointing down.
/// The canvas has no edges: items can live anywhere.
struct Drawing: Hashable, Codable, Sendable {
    static let formatVersion = 3

    var version = Drawing.formatVersion
    var background: RGBA = .white
    var layers: [DrawingLayer]

    init(background: RGBA = .white, layers: [DrawingLayer] = [DrawingLayer(name: "Layer 1")]) {
        self.background = background
        self.layers = layers.isEmpty ? [DrawingLayer(name: "Layer 1")] : layers
    }

    var isEmpty: Bool { layers.allSatisfy { $0.items.isEmpty } }
    var itemCount: Int { layers.reduce(0) { $0 + $1.items.count } }

    func layerIndex(_ id: UUID) -> Int? { layers.firstIndex { $0.id == id } }

    /// Layer and item index of every item, for batch edits.
    func index() -> [UUID: (layer: Int, item: Int)] {
        var result: [UUID: (layer: Int, item: Int)] = [:]
        for (l, layer) in layers.enumerated() {
            for (i, item) in layer.items.enumerated() { result[item.id] = (l, i) }
        }
        return result
    }

    func item(_ id: UUID) -> CanvasItem? {
        for layer in layers {
            if let item = layer.items.first(where: { $0.id == id }) { return item }
        }
        return nil
    }

    /// Items the user can currently select: on visible, unlocked layers.
    var editableItemIDs: Set<UUID> {
        Set(layers.filter { $0.isVisible && !$0.isLocked }.flatMap { $0.items.map(\.id) })
    }

    /// A name like "Layer 3" that is not taken yet.
    func nextLayerName() -> String {
        var n = layers.count + 1
        let names = Set(layers.map(\.name))
        while names.contains("Layer \(n)") { n += 1 }
        return "Layer \(n)"
    }
}
