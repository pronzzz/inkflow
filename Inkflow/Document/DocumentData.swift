//
//  DocumentData.swift
//  Inkflow
//
//  Codable data structure for Inkflow documents
//

import SwiftUI

/// Persistent data storage for an Inkflow document
struct DocumentData: Codable, Equatable {
    
    // MARK: - Metadata
    
    var version: Int = 2
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    
    // MARK: - Canvas Properties
    
    var width: CGFloat = 1920
    var height: CGFloat = 1080
    var backgroundColorHex: String = "#FFFFFF"
    
    // MARK: - Content
    
    var layers: [LayerData] = []
    
    // Legacy support
    var strokes: [StrokeData]? = nil
    
    // MARK: - Init
    
    init() {
        // Default layer
        layers = [LayerData(id: UUID(), name: "Layer 1", elements: [])]
    }
    
    init(layers: [Layer], size: CGSize, backgroundColor: Color) {
        self.layers = layers.map { LayerData($0) }
        self.width = size.width
        self.height = size.height
        self.backgroundColorHex = backgroundColor.hexString
    }
}

// MARK: - Layer Data

struct LayerData: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var elements: [ElementData]
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    
    init(id: UUID, name: String, elements: [ElementData], isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0) {
        self.id = id
        self.name = name
        self.elements = elements
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
    }
    
    init(_ layer: Layer) {
        self.id = layer.id
        self.name = layer.name
        self.elements = layer.elements.map { ElementData($0) }
        self.isVisible = layer.isVisible
        self.isLocked = layer.isLocked
        self.opacity = layer.opacity
    }
    
    func toLayer() -> Layer {
        var layer = Layer(name: name)
        layer.id = id
        layer.elements = elements.map { $0.toCanvasElement() }
        layer.isVisible = isVisible
        layer.isLocked = isLocked
        layer.opacity = opacity
        return layer
    }
}

// MARK: - Element Data

struct ElementData: Codable, Equatable, Identifiable {
    var id: UUID
    var type: String
    var isVisible: Bool
    var isLocked: Bool
    
    var stroke: StrokeData?
    var shape: ShapeElement? // ShapeElement is already Codable
    var text: TextElement?   // TextElement is already Codable
    
    init(_ element: CanvasElement) {
        self.id = element.id
        self.type = element.type.rawValue
        self.isVisible = element.isVisible
        self.isLocked = element.isLocked
        
        if let s = element.stroke {
            self.stroke = StrokeData(s)
        }
        self.shape = element.shape
        self.text = element.text
    }
    
    func toCanvasElement() -> CanvasElement {
        var typeEnum = CanvasElementType(rawValue: type) ?? .stroke
        
        var element: CanvasElement
        
        switch typeEnum {
        case .stroke:
            if let s = stroke {
                element = CanvasElement(stroke: s.toStroke())
            } else {
                element = CanvasElement(stroke: Stroke(tool: .brush, color: .black, size: 10, opacity: 1.0))
            }
        case .shape:
            if let s = shape {
                element = CanvasElement(shape: s)
            } else {
                element = CanvasElement(shape: ShapeElement(type: .rectangle, rect: .zero, strokeColor: .black, fillColor: .clear, strokeWidth: 1, isFilled: false))
            }
        case .text:
            if let t = text {
                element = CanvasElement(text: t)
            } else {
                element = CanvasElement(text: TextElement(content: "Text", position: .zero, color: .black))
            }
        }
        
        element.id = id
        element.isVisible = isVisible
        element.isLocked = isLocked
        return element
    }
}

// MARK: - Stroke Data (Existing)

/// Codable representation of a stroke
struct StrokeData: Codable, Equatable, Identifiable {
    var id: UUID
    var points: [PointData]
    var tool: String
    var colorHex: String
    var size: CGFloat
    var opacity: CGFloat
    
    init(_ stroke: Stroke) {
        self.id = stroke.id
        self.points = stroke.points.map { PointData($0) }
        self.tool = stroke.tool.rawValue
        self.colorHex = stroke.color.hexString
        self.size = stroke.size
        self.opacity = stroke.opacity
    }
    
    func toStroke() -> Stroke {
        let toolType = Tool(rawValue: tool) ?? .brush
        let color = Color(hex: colorHex)
        
        var stroke = Stroke(
            tool: toolType,
            color: color,
            size: size,
            opacity: opacity
        )
        
        for pointData in points {
            stroke.addPoint(pointData.toStrokePoint())
        }
        
        return stroke
    }
}

/// Codable representation of a stroke point
struct PointData: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var pressure: CGFloat
    var timestamp: TimeInterval
    
    init(_ point: StrokePoint) {
        self.x = point.location.x
        self.y = point.location.y
        self.pressure = point.pressure
        self.timestamp = point.timestamp
    }
    
    func toStrokePoint() -> StrokePoint {
        StrokePoint(
            location: CGPoint(x: x, y: y),
            pressure: pressure,
            timestamp: timestamp
        )
    }
}
