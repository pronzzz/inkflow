//
//  Extensions.swift
//  Inkflow
//
//  Utility extensions for common types
//

import SwiftUI

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Linear interpolation to another point
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t
        )
    }
    
    /// Add two points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    /// Subtract two points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    /// Multiply point by scalar
    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    
    /// Divide point by scalar
    static func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x / scalar, y: point.y / scalar)
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Center point of the size
    var center: CGPoint {
        CGPoint(x: width / 2, y: height / 2)
    }
    
    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1 }
        return width / height
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Center point of the rectangle
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    /// Expand rect by a uniform amount
    func expanded(by amount: CGFloat) -> CGRect {
        CGRect(
            x: origin.x - amount,
            y: origin.y - amount,
            width: width + amount * 2,
            height: height + amount * 2
        )
    }
}

// MARK: - Color Extensions

extension Color {
    /// Convert Color to NSColor for rendering
    var nsColor: NSColor {
        NSColor(self)
    }
    
    /// Get RGBA components
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let nsColor = self.nsColor.usingColorSpace(.deviceRGB) ?? .black
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    
    /// Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Math Helpers

/// Clamp value between min and max
func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
    max(minValue, min(maxValue, value))
}

/// Catmull-Rom spline interpolation for smooth curves
func catmullRom(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
    let t2 = t * t
    let t3 = t2 * t
    
    let x = 0.5 * ((2 * p1.x) +
                   (-p0.x + p2.x) * t +
                   (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                   (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
    
    let y = 0.5 * ((2 * p1.y) +
                   (-p0.y + p2.y) * t +
                   (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                   (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
    
    return CGPoint(x: x, y: y)
}
