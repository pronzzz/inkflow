//
//  CanvasRenderer.swift
//  Inkflow
//
//  Core Graphics-based canvas rendering supporting Layers and Elements
//

import SwiftUI

import AppKit
import CoreText

/// Renders strokes, shapes, and text to a bitmap context
class CanvasRenderer {
    
    // MARK: - Properties
    
    private var cachedImage: CGImage?
    private var dirtyRect: CGRect?
    private var lastStrokeCount: Int = 0
    
    // MARK: - Rendering
    
    /// Render all active layers to an image
    func render(
        layers: [Layer],
        currentStroke: Stroke?,
        currentShape: ShapeElement?, // Preview for shape creation
        selectedElementIds: Set<UUID> = [],
        size: CGSize,
        backgroundColor: Color,
        zoom: CGFloat,
        panOffset: CGPoint,
        scale: CGFloat = 1.0
    ) -> CGImage? {
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        
        guard width > 0, height > 0 else { return nil }
        
        // ... (Context setup)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Apply Retina scale
        context.scaleBy(x: scale, y: scale)
        
        // Flip coordinate system (using logical size)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        
        // Fill background
        let bgComponents = backgroundColor.components
        context.setFillColor(red: bgComponents.red, green: bgComponents.green, blue: bgComponents.blue, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Apply transform
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        context.translateBy(x: centerX + panOffset.x, y: centerY + panOffset.y)
        context.scaleBy(x: zoom, y: zoom)
        context.translateBy(x: -centerX, y: -centerY)
        
        // Enable anti-aliasing
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        
        // Render all layers
        for layer in layers where layer.isVisible {
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            
            for element in layer.elements where element.isVisible {
                renderElement(element, in: context)
                
                // Render selection highlight if selected
                if selectedElementIds.contains(element.id) {
                    renderSelectionHighlight(for: element, in: context)
                }
            }
            
            context.restoreGState()
        }
        
        // Render ephemeral content
        if let current = currentStroke {
            renderStroke(current, in: context)
        }
        
        if let currentShape = currentShape {
            renderShape(currentShape, in: context)
        }
        
        return context.makeImage()
    }
    
    // ... (renderElement implementation unchanged)
    private func renderElement(_ element: CanvasElement, in context: CGContext) {
        switch element.type {
        case .stroke:
            if let stroke = element.stroke {
                renderStroke(stroke, in: context)
            }
        case .shape:
            if let shape = element.shape {
                renderShape(shape, in: context)
            }
        case .text:
            if let text = element.text {
                renderText(text, in: context)
            }
        }
    }
    
    // MARK: - Specialized Renderers
    
    /// Render a single stroke
    private func renderStroke(_ stroke: Stroke, in context: CGContext) {
        guard !stroke.isEmpty else { return }
        
        let geometry = BrushEngine.generateStrokeGeometry(for: stroke)
        guard !geometry.isEmpty else { return }
        
        // Set up stroke appearance
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let colorComponents = stroke.color.components
        context.setStrokeColor(
            red: colorComponents.red,
            green: colorComponents.green,
            blue: colorComponents.blue,
            alpha: colorComponents.alpha * stroke.opacity
        )
        
        // Handle eraser
        if stroke.tool.isEraser {
            context.setBlendMode(.clear)
        } else {
            context.setBlendMode(.normal)
        }
        
        // Draw stroke segments
        context.setLineWidth(1.0) // Geometry handles width
        
        for i in 0..<geometry.vertices.count - 1 {
            let start = geometry.vertices[i]
            let end = geometry.vertices[i + 1]
            let width = (geometry.widths[i] + geometry.widths[i + 1]) / 2
            
            context.setLineWidth(width)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
        
        // Smoothing caps
        context.setBlendMode(stroke.tool.isEraser ? .clear : .normal)
        context.setFillColor(
            red: colorComponents.red,
            green: colorComponents.green,
            blue: colorComponents.blue,
            alpha: colorComponents.alpha * stroke.opacity
        )
        
        for i in 0..<geometry.vertices.count {
            let point = geometry.vertices[i]
            let radius = geometry.widths[i] / 2
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fillEllipse(in: rect)
        }
    }
    
    /// Render a vector shape
    private func renderShape(_ shape: ShapeElement, in context: CGContext) {
        context.saveGState()
        
        // Setup colors
        let strokeC = shape.strokeColor.components
        context.setStrokeColor(red: strokeC.red, green: strokeC.green, blue: strokeC.blue, alpha: strokeC.alpha)
        
        let fillC = shape.fillColor.components
        context.setFillColor(red: fillC.red, green: fillC.green, blue: fillC.blue, alpha: fillC.alpha)
        
        context.setLineWidth(shape.strokeWidth)
        context.translateBy(x: shape.rect.midX, y: shape.rect.midY)
        context.rotate(by: CGFloat(shape.rotation * .pi / 180))
        context.translateBy(x: -shape.rect.midX, y: -shape.rect.midY)
        
        let rect = shape.rect
        
        switch shape.type {
        case .rectangle:
            if shape.isFilled { context.fill(rect) }
            context.stroke(rect)
            
        case .circle:
            if shape.isFilled { context.fillEllipse(in: rect) }
            context.strokeEllipse(in: rect)
            
        case .line:
            context.beginPath()
            context.move(to: CGPoint(x: rect.minX, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    private func renderSelectionHighlight(for element: CanvasElement, in context: CGContext) {
        var bounds: CGRect = .zero
        
        switch element.type {
        case .stroke:
            bounds = element.stroke?.boundingBox ?? .zero
        case .shape:
            bounds = element.shape?.rect ?? .zero
        case .text:
            if let text = element.text {
                bounds = CGRect(x: text.position.x, y: text.position.y, width: 100, height: 30) // Fallback
            }
        }
        
        guard bounds != .zero else { return }
        
        context.saveGState()
        context.setStrokeColor(red: 0, green: 0.5, blue: 1.0, alpha: 1.0) // System Blue
        context.setLineWidth(1.5 / 1.0) // constant width regardless of zoom? No, scalable.
        // Actually, to make line width constant 1px on screen, we need to divide by zoom. 
        // But zoom isn't passed here easily unless I capture it or pass it. 
        // For now, let it scale with zoom.
        
        context.setLineDash(phase: 0, lengths: [4, 4])
        
        // Expand bounds slightly
        let padding: CGFloat = 4
        let selectionRect = bounds.insetBy(dx: -padding, dy: -padding)
        
        context.stroke(selectionRect)
        
        // Draw corner handles
        let handleSize: CGFloat = 6
        let corners = [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY)
        ]
        
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.setLineDash(phase: 0, lengths: [])
        
        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize/2,
                y: corner.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            context.fill(handleRect)
            context.stroke(handleRect)
        }
        
        context.restoreGState()
    }

    /// Render test
    private func renderText(_ text: TextElement, in context: CGContext) {
        let string = text.content
        let fontSize = text.fontSize
        // Use a safe font fallback
        let font = NSFont(name: text.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let color = NSColor(text.color)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attrString = NSAttributedString(string: string, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        
        // Calculate dimensions to adjust baseline
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        
        context.saveGState()
        
        // Transform to text position
        // Current CTM is Y-down (flipped). Text expects Y-up.
        // We want text top-left to be at text.position.
        // So baseline should be at text.position.y + ascent.
        
        context.translateBy(x: text.position.x, y: text.position.y + ascent)
        context.scaleBy(x: 1.0, y: -1.0) // Flip Y-axis to point UP for CoreText
        
        context.textPosition = .zero
        CTLineDraw(line, context)
        
        context.restoreGState()
    }
    
    /// Clear cached rendering
    func invalidateCache() {
        cachedImage = nil
        dirtyRect = nil
        lastStrokeCount = 0
    }
}

// MARK: - Export Helper (Legacy shim)
extension CanvasRenderer {
    static func renderStrokesLegacy(strokes: [Stroke], size: CGSize, backgroundColor: Color) -> CGImage? {
        let renderer = CanvasRenderer()
        // Wrap strokes in a temporary layer
        var layer = Layer(name: "Export")
        layer.elements = strokes.map { CanvasElement(stroke: $0) }
        
        return renderer.render(
            layers: [layer],
            currentStroke: nil,
            currentShape: nil,
            selectedElementIds: [],
            size: size,
            backgroundColor: backgroundColor,
            zoom: 1.0,
            panOffset: .zero
        )
    }
}
