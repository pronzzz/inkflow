//
//  CanvasViewModel.swift
//  Inkflow
//
//  Main view model for canvas state management supporting Layers and Elements
//

import SwiftUI
import Combine

/// Main view model managing canvas state, tools, and undo/redo
@MainActor
class CanvasViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Canvas Layers (replacing simple strokes array)
    @Published var layers: [Layer] = []
    
    /// ID of the currently active layer
    @Published var activeLayerId: UUID = UUID()
    
    /// Currently drawing stroke
    @Published var currentStroke: Stroke?
    
    /// Currently creating shape (preview)
    @Published var currentShape: ShapeElement?
    
    /// Canvas size
    @Published var size: CGSize = CGSize(width: 1920, height: 1080)
    
    /// Selected drawing tool
    @Published var selectedTool: Tool = .brush
    
    /// Current brush/tool size
    @Published var brushSize: CGFloat = 12.0
    
    /// Current opacity (0-1)
    @Published var opacity: CGFloat = 1.0
    
    /// Current drawing color
    @Published var color: Color = .black
    
    /// Canvas background color
    @Published var backgroundColor: Color = .white
    
    /// Canvas zoom level
    @Published var zoom: CGFloat = 1.0
    
    /// Canvas pan offset
    @Published var panOffset: CGPoint = .zero
    
    /// Whether canvas needs redraw
    @Published var needsRedraw: Bool = false
    
    /// Selected element IDs for Selection tool
    @Published var selectedElementIds: Set<UUID> = []
    
    /// Show layers panel
    @Published var showLayersPanel: Bool = false
    
    // MARK: - State/Interaction
    
    private var shapeStartPoint: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var isDraggingSelection: Bool = false
    
    /// Position where new text is being added
    @Published var pendingTextPosition: CGPoint?
    
    // MARK: - Undo/Redo
    
    // MARK: - Undo/Redo
    
    weak var undoManager: UndoManager?
    
    // MARK: - Constants
    
    private let minBrushSize: CGFloat = 1.0
    private let maxBrushSize: CGFloat = 100.0
    private let brushSizeStep: CGFloat = 4.0
    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 10.0
    private let zoomStep: CGFloat = 0.25
    
    // Helper
    private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        return min(max(value, minValue), maxValue)
    }
    
    // MARK: - Initialization
    
    init(document: DocumentData? = nil) {
        if let document = document {
            // Load layers
            if !document.layers.isEmpty {
                self.layers = document.layers.map { $0.toLayer() }
            } else if let strokes = document.strokes {
                // Legacy migration
                var defaultLayer = Layer(name: "Layer 1")
                defaultLayer.elements = strokes.map { CanvasElement(stroke: $0.toStroke()) }
                self.layers = [defaultLayer]
            } else {
                // Fresh default
                self.layers = [Layer(name: "Layer 1")]
            }
            
            self.activeLayerId = self.layers.first?.id ?? UUID()
            
            self.size = CGSize(width: document.width, height: document.height)
            self.backgroundColor = Color(hex: document.backgroundColorHex)
        } else {
            // Default new
            let layer = Layer(name: "Layer 1")
            self.layers = [layer]
            self.activeLayerId = layer.id
        }
        
        // Set default tool size
        brushSize = selectedTool.defaultSize
    }
    
    // MARK: - Document Sync
    
    func snapshot() -> DocumentData {
        DocumentData(layers: layers, size: size, backgroundColor: backgroundColor)
    }
    
    // MARK: - Tool Selection
    
    func selectTool(_ tool: Tool) {
        selectedTool = tool
        brushSize = tool.defaultSize
    }
    
    // MARK: - Brush Size & Zoom
    
    func increaseBrushSize() { brushSize = min(maxBrushSize, brushSize + brushSizeStep) }
    func decreaseBrushSize() { brushSize = max(minBrushSize, brushSize - brushSizeStep) }
    func zoomIn() { zoom = min(maxZoom, zoom + zoomStep) }
    func zoomOut() { zoom = max(minZoom, zoom - zoomStep) }
    func resetZoom() { zoom = 1.0; panOffset = .zero }
    
    func setZoom(_ newZoom: CGFloat, around point: CGPoint) {
        let oldZoom = zoom
        zoom = clamp(newZoom, min: minZoom, max: maxZoom)
        
        // Adjust pan to zoom around the point
        let zoomDelta = zoom / oldZoom
        panOffset.x = point.x - (point.x - panOffset.x) * zoomDelta
        panOffset.y = point.y - (point.y - panOffset.y) * zoomDelta
    }
    
    // MARK: - Input Handling
    
    func beginInteraction(at point: CGPoint, pressure: CGFloat = 1.0) {
        lastDragPoint = point
        
        switch selectedTool {
        case .brush, .pencil, .eraser:
            beginStroke(at: point, pressure: pressure)
        case .shapeRectangle, .shapeCircle, .shapeLine:
            beginShape(at: point)
        case .text:
            pendingTextPosition = point
        case .selector:
            // Check if clicking on existing selection to drag
            if isPointInSelection(point) {
                isDraggingSelection = true
            } else {
                selectElement(at: point)
                // If we selected something, enable drag immediately
                if !selectedElementIds.isEmpty {
                    isDraggingSelection = true
                }
            }
        }
    }
    
    func commitText(_ content: String) {
        guard let pos = pendingTextPosition, !content.isEmpty else {
            pendingTextPosition = nil
            return
        }
        
        let textElement = TextElement(
            content: content,
            position: pos,
            color: color
        )
        // Add font size/name from properties later
        
        let element = CanvasElement(text: textElement)
        addElement(element)
        pendingTextPosition = nil
        needsRedraw = true
    }
    
    func continueInteraction(to point: CGPoint, pressure: CGFloat = 1.0) {
        switch selectedTool {
        case .brush, .pencil, .eraser:
            continueStroke(to: point, pressure: pressure)
        case .shapeRectangle, .shapeCircle, .shapeLine:
            updateShape(to: point)
        case .selector:
            if isDraggingSelection {
                let delta = CGPoint(x: point.x - lastDragPoint.x, y: point.y - lastDragPoint.y)
                moveSelectedElements(by: delta)
                lastDragPoint = point
            }
        default:
            break
        }
    }
    
    func endInteraction() {
        switch selectedTool {
        case .brush, .pencil, .eraser:
            endStroke()
        case .shapeRectangle, .shapeCircle, .shapeLine:
            endShape()
        case .selector:
            isDraggingSelection = false
        default:
            break
        }
    }
    
    // MARK: - Drawing (Strokes)
    
    private func beginStroke(at point: CGPoint, pressure: CGFloat) {
        let strokeColor = selectedTool.isEraser ? backgroundColor : color
        var stroke = Stroke(
            tool: selectedTool,
            color: strokeColor,
            size: brushSize,
            opacity: opacity
        )
        stroke.addPoint(StrokePoint(location: point, pressure: pressure))
        currentStroke = stroke
        needsRedraw = true
    }
    
    private func continueStroke(to point: CGPoint, pressure: CGFloat) {
        guard var stroke = currentStroke else { return }
        stroke.addPoint(StrokePoint(location: point, pressure: pressure))
        currentStroke = stroke
        needsRedraw = true
    }
    
    private func endStroke() {
        guard let stroke = currentStroke, !stroke.isEmpty else {
            currentStroke = nil
            return
        }
        
        // Wrap in element and append to active layer
        let element = CanvasElement(stroke: stroke)
        addElement(element)
        
        currentStroke = nil
        needsRedraw = true
    }
    
    // MARK: - Shapes
    
    private func beginShape(at point: CGPoint) {
        shapeStartPoint = point
        let type: ShapeType
        switch selectedTool {
        case .shapeRectangle: type = .rectangle
        case .shapeCircle: type = .circle
        case .shapeLine: type = .line
        default: return
        }
        
        currentShape = ShapeElement(
            type: type,
            rect: CGRect(origin: point, size: .zero),
            strokeColor: color,
            fillColor: .clear, // Default no fill for now
            strokeWidth: brushSize,
            isFilled: false
        )
        needsRedraw = true
    }
    
    private func updateShape(to point: CGPoint) {
        guard var shape = currentShape else { return }
        
        let rect = CGRect(
            x: min(shapeStartPoint.x, point.x),
            y: min(shapeStartPoint.y, point.y),
            width: abs(point.x - shapeStartPoint.x),
            height: abs(point.y - shapeStartPoint.y)
        )
        shape.rect = rect
        currentShape = shape
        needsRedraw = true
    }
    
    private func endShape() {
        guard let shape = currentShape else { return }
        
        // Ignore tiny shapes
        if shape.rect.width > 2 || shape.rect.height > 2 || shape.type == .line {
            let element = CanvasElement(shape: shape)
            addElement(element)
        }
        
        currentShape = nil
        needsRedraw = true
    }
    
    // MARK: - Layer Operations
    
    func activeLayerIndex() -> Int? {
        layers.firstIndex(where: { $0.id == activeLayerId })
    }
    
    func addElement(_ element: CanvasElement) {
        addElement(element, to: activeLayerId)
    }
    
    func addElement(_ element: CanvasElement, to layerId: UUID) {
        if let layerIndex = layers.firstIndex(where: { $0.id == layerId }) {
            layers[layerIndex].elements.append(element)
            needsRedraw = true
            
            undoManager?.registerUndo(withTarget: self) { target in
                target.removeElement(element, from: layerId)
            }
        }
    }
    
    func removeElement(_ element: CanvasElement, from layerId: UUID) {
        if let layerIndex = layers.firstIndex(where: { $0.id == layerId }),
           let elementIndex = layers[layerIndex].elements.firstIndex(where: { $0.id == element.id }) {
            layers[layerIndex].elements.remove(at: elementIndex)
            needsRedraw = true
            
            undoManager?.registerUndo(withTarget: self) { target in
                target.addElement(element, to: layerId)
            }
        }
    }
    
    
    // MARK: - Canvas Operations
    
    func clearCanvas() {
        let oldLayers = layers
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreLayers(oldLayers)
        }
        
        for i in 0..<layers.count {
            layers[i].elements.removeAll()
        }
        needsRedraw = true
    }
    
    func restoreLayers(_ oldLayers: [Layer]) {
        let currentLayers = layers
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreLayers(currentLayers)
        }
        layers = oldLayers
        needsRedraw = true
    }
    
    // MARK: - Coordinate Transformation
    
    func canvasPoint(from screenPoint: CGPoint, in viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        return CGPoint(
            x: (screenPoint.x - centerX - panOffset.x) / zoom + centerX,
            y: (screenPoint.y - centerY - panOffset.y) / zoom + centerY
        )
    }
    
    func screenPoint(from canvasPoint: CGPoint, in viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2
        return CGPoint(
            x: (canvasPoint.x - centerX) * zoom + centerX + panOffset.x,
            y: (canvasPoint.y - centerY) * zoom + centerY + panOffset.y
        )
    }
    
    // MARK: - Layer Management
    
    func addLayer() {
        let newLayer = Layer(name: "Layer \(layers.count + 1)")
        layers.append(newLayer)
        activeLayerId = newLayer.id
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.deleteLayer(newLayer.id)
        }
    }
    
    func deleteLayer(_ layerId: UUID) {
        guard layers.count > 1 else { return } // Keep at least one layer
        
        if let layerIndex = layers.firstIndex(where: { $0.id == layerId }) {
            let layerToDelete = layers[layerIndex]
            
            layers.remove(at: layerIndex)
            if activeLayerId == layerId {
                activeLayerId = layers.first?.id ?? UUID()
            }
            needsRedraw = true
            
            undoManager?.registerUndo(withTarget: self) { target in
                target.restoreLayer(layerToDelete, at: layerIndex)
            }
        }
    }
    
    func restoreLayer(_ layer: Layer, at index: Int) {
        if index <= layers.count {
            layers.insert(layer, at: index)
            needsRedraw = true
            
            undoManager?.registerUndo(withTarget: self) { target in
                target.deleteLayer(layer.id)
            }
        }
    }
    
    func toggleLayerVisibility(_ layerId: UUID) {
        if let index = layers.firstIndex(where: { $0.id == layerId }) {
            layers[index].isVisible.toggle()
            needsRedraw = true
        }
    }
    
    func toggleLayerLock(_ layerId: UUID) {
        if let index = layers.firstIndex(where: { $0.id == layerId }) {
            layers[index].isLocked.toggle()
        }
    }
    
    // MARK: - Selection
    
    func selectElement(at point: CGPoint) {
        selectedElementIds.removeAll()
        
        // Hit test from top layer to bottom
        for layer in layers.reversed() where layer.isVisible {
            for element in layer.elements.reversed() where element.isVisible {
                if hitTest(element: element, at: point) {
                    selectedElementIds.insert(element.id)
                    needsRedraw = true
                    return
                }
            }
        }
        needsRedraw = true
    }
    
    func clearSelection() {
        selectedElementIds.removeAll()
        needsRedraw = true
    }
    
    // MARK: - Selection Helpers
    
    private func isPointInSelection(_ point: CGPoint) -> Bool {
        // Return true if point is inside ANY of the selected elements
        for layer in layers where layer.isVisible {
            for element in layer.elements where element.isVisible {
                if selectedElementIds.contains(element.id) {
                    if hitTest(element: element, at: point) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func moveSelectedElements(by delta: CGPoint) {
        // Iterate and mutate layers in place
        // Optimization: Could build a map of indices, but simple iteration is fine for N < 10000
        for i in 0..<layers.count {
            if !layers[i].isVisible || layers[i].isLocked { continue }
            
            for j in 0..<layers[i].elements.count {
                if selectedElementIds.contains(layers[i].elements[j].id) {
                    layers[i].elements[j].offset(by: delta)
                }
            }
        }
        needsRedraw = true
    }
    
    private func hitTest(element: CanvasElement, at point: CGPoint) -> Bool {
        switch element.type {
        case .shape:
            if let shape = element.shape {
                return shape.rect.contains(point)
            }
        case .stroke:
            if let stroke = element.stroke {
                // Simple bounding box test for strokes
                let bounds = stroke.boundingBox
                return bounds.contains(point)
            }
        case .text:
            if let text = element.text {
                // Simple point proximity test
                let textRect = CGRect(x: text.position.x, y: text.position.y, width: 100, height: 30)
                return textRect.contains(point)
            }
        }
        return false
    }
}

// MARK: - Canvas Commands

