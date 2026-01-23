//
//  BrushEngine.swift
//  Inkflow
//
//  Handles stroke interpolation and rendering calculations
//

import SwiftUI

/// Engine for processing and smoothing brush strokes
struct BrushEngine {
    
    // MARK: - Stroke Smoothing
    
    /// Interpolate points using Catmull-Rom splines for smooth curves
    /// - Parameters:
    ///   - points: Original stroke points
    ///   - resolution: Number of interpolated points between each pair
    /// - Returns: Smoothed array of points
    static func smoothPoints(_ points: [StrokePoint], resolution: Int = 4) -> [StrokePoint] {
        guard points.count >= 2 else { return points }
        
        var smoothed: [StrokePoint] = []
        
        for i in 0..<points.count {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[min(points.count - 1, i + 1)]
            let p3 = points[min(points.count - 1, i + 2)]
            
            if i == 0 {
                smoothed.append(p1)
            }
            
            // Interpolate between p1 and p2
            if i < points.count - 1 {
                for j in 1...resolution {
                    let t = CGFloat(j) / CGFloat(resolution)
                    
                    let location = catmullRom(
                        p0: p0.location,
                        p1: p1.location,
                        p2: p2.location,
                        p3: p3.location,
                        t: t
                    )
                    
                    // Interpolate pressure
                    let pressure = p1.pressure + (p2.pressure - p1.pressure) * t
                    
                    // Interpolate timestamp
                    let timestamp = p1.timestamp + (p2.timestamp - p1.timestamp) * Double(t)
                    
                    smoothed.append(StrokePoint(
                        location: location,
                        pressure: pressure,
                        timestamp: timestamp
                    ))
                }
            }
        }
        
        return smoothed
    }
    
    // MARK: - Stroke Rendering
    
    /// Generate render data for a stroke (vertices, widths, etc.)
    static func generateStrokeGeometry(
        for stroke: Stroke,
        smooth: Bool = true
    ) -> StrokeGeometry {
        let points = smooth ? smoothPoints(stroke.points) : stroke.points
        
        guard points.count >= 2 else {
            return StrokeGeometry(vertices: [], widths: [], colors: [])
        }
        
        var vertices: [CGPoint] = []
        var widths: [CGFloat] = []
        var colors: [Color] = []
        
        for i in 0..<points.count {
            let point = points[i]
            
            // Calculate width based on pressure and base size
            let pressureWidth = stroke.size * point.pressure
            
            // Apply velocity-based thinning (optional)
            var width = pressureWidth
            if i > 0 {
                let velocity = point.velocity(from: points[i - 1])
                let velocityFactor = 1.0 - min(0.5, velocity / 2000.0)
                width *= velocityFactor
            }
            
            // Ensure minimum visible width
            width = max(1.0, width)
            
            vertices.append(point.location)
            widths.append(width)
            colors.append(stroke.color.opacity(stroke.opacity))
        }
        
        return StrokeGeometry(vertices: vertices, widths: widths, colors: colors)
    }
    
    // MARK: - Distance Calculation
    
    /// Calculate minimum distance from a point to a stroke
    static func distance(from point: CGPoint, to stroke: Stroke) -> CGFloat {
        guard !stroke.points.isEmpty else { return .infinity }
        
        var minDistance: CGFloat = .infinity
        
        for i in 0..<stroke.points.count - 1 {
            let p1 = stroke.points[i].location
            let p2 = stroke.points[i + 1].location
            
            let distance = distanceToLineSegment(point: point, lineStart: p1, lineEnd: p2)
            minDistance = min(minDistance, distance)
        }
        
        return minDistance
    }
    
    /// Calculate distance from a point to a line segment
    private static func distanceToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            return point.distance(to: lineStart)
        }
        
        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t))
        
        let projection = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )
        
        return point.distance(to: projection)
    }
}

/// Geometry data for rendering a stroke
struct StrokeGeometry {
    let vertices: [CGPoint]
    let widths: [CGFloat]
    let colors: [Color]
    
    var isEmpty: Bool {
        vertices.count < 2
    }
}
