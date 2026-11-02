import CoreGraphics
import Foundation

/// Reads documents saved by Inkflow 1.x (format versions 1 and 2) and converts them.
///
/// 1.x stored colours as `#RRGGBB` plus a separate opacity, one JSON object per point,
/// shapes as a bounding rect, and could have a flat `strokes` array instead of layers.
enum LegacyFormat {
    static func decode(_ data: Data) throws -> Drawing {
        let doc = try JSONDecoder().decode(Document.self, from: data)
        var layers = (doc.layers ?? []).map { layer -> DrawingLayer in
            var converted = DrawingLayer(id: layer.id ?? UUID(), name: layer.name ?? "Layer",
                                         items: (layer.elements ?? []).compactMap(\.item))
            converted.isVisible = layer.isVisible ?? true
            converted.isLocked = layer.isLocked ?? false
            converted.opacity = layer.opacity ?? 1
            return converted
        }
        if layers.isEmpty, let strokes = doc.strokes {
            layers = [DrawingLayer(name: "Layer 1", items: strokes.compactMap { $0.stroke.map(CanvasItem.stroke) })]
        }
        return Drawing(background: RGBA(hex: doc.backgroundColorHex ?? "#FFFFFF"), layers: layers)
    }

    private struct Document: Decodable {
        var backgroundColorHex: String?
        var layers: [Layer]?
        var strokes: [StrokeData]?
    }

    private struct Layer: Decodable {
        var id: UUID?
        var name: String?
        var elements: [Element]?
        var isVisible: Bool?
        var isLocked: Bool?
        var opacity: Double?
    }

    private struct Element: Decodable {
        var type: String?
        var isVisible: Bool?
        var stroke: StrokeData?
        var shape: ShapeData?
        var text: TextData?

        var item: CanvasItem? {
            if isVisible == false { return nil }
            switch type {
            case "shape": return shape?.item
            case "text": return text?.item
            default: return stroke?.stroke.map(CanvasItem.stroke)
            }
        }
    }

    private struct StrokeData: Decodable {
        struct Point: Decodable { var x: CGFloat; var y: CGFloat; var pressure: CGFloat? }
        var id: UUID?
        var points: [Point]
        var tool: String?
        var colorHex: String?
        var size: CGFloat?
        var opacity: CGFloat?

        var stroke: Stroke? {
            guard points.count > 1 else { return nil }
            let tool: StrokeTool
            switch self.tool {
            case "pencil", "shapeLine": tool = .pencil
            case "eraser": tool = .eraser
            default: tool = .brush
            }
            let color = RGBA(hex: colorHex ?? "#000000").withAlpha(Double(opacity ?? 1))
            return Stroke(id: id ?? UUID(), tool: tool, color: tool == .eraser ? .ink : color,
                          width: size ?? 8,
                          points: points.map { StrokePoint(x: $0.x, y: $0.y, pressure: $0.pressure ?? 1) })
        }
    }

    private struct ShapeData: Decodable {
        var id: UUID?
        var type: String?
        var rect: CGRect
        var strokeColorHex: String?
        var strokeWidth: CGFloat?

        var item: CanvasItem {
            let kind: ShapeKind
            switch type {
            case "circle": kind = .ellipse
            case "line": kind = .line
            default: kind = .rectangle
            }
            return .shape(ShapeItem(id: id ?? UUID(), kind: kind,
                                    start: rect.origin,
                                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                                    color: RGBA(hex: strokeColorHex ?? "#000000"),
                                    width: strokeWidth ?? 2))
        }
    }

    private struct TextData: Decodable {
        var id: UUID?
        var content: String
        var position: CGPoint
        var fontSize: CGFloat?
        var colorHex: String?

        var item: CanvasItem {
            .text(TextItem(id: id ?? UUID(), text: content, origin: position,
                           fontSize: fontSize ?? 24, color: RGBA(hex: colorHex ?? "#000000")))
        }
    }
}
