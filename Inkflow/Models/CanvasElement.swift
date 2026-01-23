//
//  CanvasElement.swift
//  Inkflow
//
//  Polymorphic element types for the canvas
//

import SwiftUI

/// Type of element on the canvas
enum CanvasElementType: String, Codable {
    case stroke
    case shape
    case text
}

/// A single element on the canvas (stroke, shape, or text)
struct CanvasElement: Identifiable, Equatable {
    var id: UUID = UUID()
    var type: CanvasElementType
    var isVisible: Bool = true
    var isLocked: Bool = false
    
    // Content (mutually exclusive ideal, but optional for simplicity)
    var stroke: Stroke?
    var shape: ShapeElement?
    var text: TextElement?
    
    // MARK: - Initializers
    
    init(stroke: Stroke) {
        self.type = .stroke
        self.stroke = stroke
    }
    
    init(shape: ShapeElement) {
        self.type = .shape
        self.shape = shape
    }
    
    init(text: TextElement) {
        self.type = .text
        self.text = text
    }
    
    // MARK: - Transformation
    
    mutating func offset(by delta: CGPoint) {
        if stroke != nil {
            stroke = stroke?.offset(by: delta)
        } else if let currentShape = shape {
            var newShape = currentShape
            newShape.rect = newShape.rect.offsetBy(dx: delta.x, dy: delta.y)
            shape = newShape
        } else if let currentText = text {
            var newText = currentText
            newText.position = CGPoint(x: newText.position.x + delta.x, y: newText.position.y + delta.y)
            text = newText
        }
    }
}

// MARK: - Shape Element

enum ShapeType: String, Codable, CaseIterable {
    case rectangle
    case circle
    case line
    // Future: star, triangle, diamond
}

struct ShapeElement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: ShapeType
    var rect: CGRect // Bounding box
    var strokeColor: Color
    var fillColor: Color
    var strokeWidth: CGFloat
    var isFilled: Bool
    var rotation: Double = 0 // In degrees
    
    // Codable support for Color
    enum CodingKeys: String, CodingKey {
        case id, type, rect, strokeColorHex, fillColorHex, strokeWidth, isFilled, rotation
    }
    
    init(type: ShapeType, rect: CGRect, strokeColor: Color, fillColor: Color, strokeWidth: CGFloat, isFilled: Bool) {
        self.type = type
        self.rect = rect
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
        self.isFilled = isFilled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ShapeType.self, forKey: .type)
        rect = try container.decode(CGRect.self, forKey: .rect)
        let strokeHex = try container.decode(String.self, forKey: .strokeColorHex)
        strokeColor = Color(hex: strokeHex)
        let fillHex = try container.decode(String.self, forKey: .fillColorHex)
        fillColor = Color(hex: fillHex)
        strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        isFilled = try container.decode(Bool.self, forKey: .isFilled)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(rect, forKey: .rect)
        try container.encode(strokeColor.hexString, forKey: .strokeColorHex)
        try container.encode(fillColor.hexString, forKey: .fillColorHex)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(isFilled, forKey: .isFilled)
        try container.encode(rotation, forKey: .rotation)
    }
}

// MARK: - Text Element

struct TextElement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var content: String
    var position: CGPoint
    var fontName: String = "Helvetica"
    var fontSize: CGFloat = 24
    var color: Color
    var rotation: Double = 0
    
    enum CodingKeys: String, CodingKey {
        case id, content, position, fontName, fontSize, colorHex, rotation
    }
    
    init(content: String, position: CGPoint, color: Color) {
        self.content = content
        self.position = position
        self.color = color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        position = try container.decode(CGPoint.self, forKey: .position)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        let hex = try container.decode(String.self, forKey: .colorHex)
        color = Color(hex: hex)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(position, forKey: .position)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(color.hexString, forKey: .colorHex)
        try container.encode(rotation, forKey: .rotation)
    }
}
