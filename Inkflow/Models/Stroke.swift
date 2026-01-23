//
//  Stroke.swift
//  Inkflow
//
//  Data model for drawing strokes
//

import SwiftUI

/// A single point in a stroke with associated metadata
struct StrokePoint: Equatable {
    let location: CGPoint
    let pressure: CGFloat
    let timestamp: TimeInterval
    
    init(location: CGPoint, pressure: CGFloat = 1.0, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.location = location
        self.pressure = pressure
        self.timestamp = timestamp
    }
    
    /// Calculate velocity to previous point
    func velocity(from previous: StrokePoint) -> CGFloat {
        let dx = location.x - previous.location.x
        let dy = location.y - previous.location.y
        let distance = sqrt(dx * dx + dy * dy)
        let dt = timestamp - previous.timestamp
        return dt > 0 ? distance / CGFloat(dt) : 0
    }
}

/// A complete stroke drawn by the user
struct Stroke: Identifiable, Equatable {
    let id: UUID
    var points: [StrokePoint]
    let tool: Tool
    let color: Color
    let size: CGFloat
    let opacity: CGFloat
    
    /// Bounding box of the stroke for optimization
    var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for point in points {
            minX = min(minX, point.location.x)
            minY = min(minY, point.location.y)
            maxX = max(maxX, point.location.x)
            maxY = max(maxY, point.location.y)
        }
        
        // Expand by stroke size
        let padding = size / 2 + 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }
    
    init(tool: Tool, color: Color, size: CGFloat, opacity: CGFloat) {
        self.id = UUID()
        self.points = []
        self.tool = tool
        self.color = color
        self.size = size
        self.opacity = opacity
    }
    
    mutating func addPoint(_ point: StrokePoint) {
        points.append(point)
    }
    
    /// Create a new stroke offset by a certain amount
    func offset(by delta: CGPoint) -> Stroke {
        var newStroke = self
        for i in 0..<newStroke.points.count {
            let p = newStroke.points[i]
            newStroke.points[i] = StrokePoint(
                location: CGPoint(x: p.location.x + delta.x, y: p.location.y + delta.y),
                pressure: p.pressure,
                timestamp: p.timestamp
            )
        }
        return newStroke
    }
    
    /// Check if stroke is empty or too small to render
    var isEmpty: Bool {
        points.count < 2
    }
}

/// Represents the entire canvas state
struct CanvasState: Equatable {
    var strokes: [Stroke] = []
    var backgroundColor: Color = .white
    var size: CGSize = CGSize(width: 1920, height: 1080)
    
    mutating func addStroke(_ stroke: Stroke) {
        if !stroke.isEmpty {
            strokes.append(stroke)
        }
    }
    
    mutating func removeLastStroke() -> Stroke? {
        strokes.popLast()
    }
    
    mutating func clear() {
        strokes.removeAll()
    }
}
