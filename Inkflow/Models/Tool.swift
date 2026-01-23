//
//  Tool.swift
//  Inkflow
//
//  Defines drawing tool types and their properties
//

import SwiftUI

/// Available drawing tools in Inkflow
enum Tool: String, CaseIterable, Identifiable {
    case brush
    case pencil
    case eraser
    case selector
    case shapeRectangle
    case shapeCircle
    case shapeLine
    case text
    
    var id: String { rawValue }
    
    /// Display name for the tool
    var displayName: String {
        switch self {
        case .brush: return "Brush"
        case .pencil: return "Pencil"
        case .eraser: return "Eraser"
        case .selector: return "Select"
        case .shapeRectangle: return "Rectangle"
        case .shapeCircle: return "Circle"
        case .shapeLine: return "Line"
        case .text: return "Text"
        }
    }
    
    /// SF Symbol name for the tool icon
    var iconName: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .pencil: return "pencil"
        case .eraser: return "eraser.fill"
        case .selector: return "cursorarrow"
        case .shapeRectangle: return "rectangle"
        case .shapeCircle: return "circle"
        case .shapeLine: return "line.diagonal"
        case .text: return "textformat"
        }
    }
    
    /// Default size for this tool
    var defaultSize: CGFloat {
        switch self {
        case .brush: return 12.0
        case .pencil: return 4.0
        case .eraser: return 24.0
        case .shapeLine: return 4.0
        default: return 0.0
        }
    }
    
    /// Whether this tool erases content
    var isEraser: Bool {
        self == .eraser
    }
    
    /// Softness of the tool edge (0 = hard, 1 = soft)
    var softness: CGFloat {
        switch self {
        case .brush: return 0.6
        case .eraser: return 0.3
        default: return 0.0
        }
    }
}

/// Configuration for a specific tool instance
struct ToolSettings {
    var size: CGFloat
    var opacity: CGFloat
    var color: Color
    
    init(tool: Tool) {
        self.size = tool.defaultSize
        self.opacity = 1.0
        self.color = .black
    }
    
    init(size: CGFloat, opacity: CGFloat, color: Color) {
        self.size = size
        self.opacity = opacity
        self.color = color
    }
}
