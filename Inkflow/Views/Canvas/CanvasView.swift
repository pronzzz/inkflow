//
//  CanvasView.swift
//  Inkflow
//
//  Main canvas view with gesture handling
//

import SwiftUI

/// The main drawing canvas
struct CanvasView: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    @Environment(\.displayScale) var displayScale
    
    @State private var renderer = CanvasRenderer()
    @State private var canvasImage: CGImage?
    @State private var imageScale: CGFloat = 1.0
    @State private var viewSize: CGSize = .zero
    @State private var isDrawing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(viewModel.backgroundColor)
                
                // Rendered canvas
                if let image = canvasImage {
                    Image(decorative: image, scale: imageScale)
                        .interpolation(.high)
                }
                
                // Text Input Overlay
                if let pendingPos = viewModel.pendingTextPosition {
                    TextInputView(
                        position: viewModel.screenPoint(from: pendingPos, in: viewSize),
                        onSubmit: { text in
                            viewModel.commitText(text)
                        },
                        onCancel: {
                            viewModel.pendingTextPosition = nil
                        }
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(drawingGesture)
            .gesture(magnificationGesture)
            .simultaneousGesture(panGesture)
            .onAppear {
                viewSize = geometry.size
                updateCanvas()
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                updateCanvas()
            }
            .onChange(of: viewModel.needsRedraw) { _, needsRedraw in
                if needsRedraw {
                    updateCanvas()
                    viewModel.needsRedraw = false
                }
            }
            .onChange(of: viewModel.layers) { _, _ in
                updateCanvas()
            }
            .onChange(of: viewModel.currentStroke) { _, _ in
                updateCanvas()
            }
            .onChange(of: viewModel.currentShape) { _, _ in
                updateCanvas()
            }
            .onChange(of: viewModel.zoom) { _, _ in
                updateCanvas()
            }
            .onChange(of: viewModel.panOffset) { _, _ in
                updateCanvas()
            }
        }
    }
    
    // MARK: - Gestures
    
    /// Drawing/Interaction gesture (drag)
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let canvasPoint = viewModel.canvasPoint(from: value.location, in: viewSize)
                
                if !isDrawing {
                    isDrawing = true
                    viewModel.beginInteraction(at: canvasPoint)
                } else {
                    viewModel.continueInteraction(to: canvasPoint)
                }
            }
            .onEnded { _ in
                isDrawing = false
                viewModel.endInteraction()
            }
    }
    
    /// Pinch to zoom gesture
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let newZoom = viewModel.zoom * scale
                viewModel.zoom = clamp(newZoom, min: 0.1, max: 10.0)
            }
    }
    
    /// Two-finger pan gesture
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .modifiers(.option) // Option + drag to pan
            .onChanged { value in
                viewModel.panOffset = CGPoint(
                    x: viewModel.panOffset.x + value.translation.width,
                    y: viewModel.panOffset.y + value.translation.height
                )
            }
    }
    
    // MARK: - Rendering
    
    private func updateCanvas() {
        // Capture MainActor properties
        let layers = viewModel.layers
        let currentStroke = viewModel.currentStroke
        let currentShape = viewModel.currentShape
        let selectedElementIds = viewModel.selectedElementIds
        let backgroundColor = viewModel.backgroundColor
        let zoom = viewModel.zoom
        let panOffset = viewModel.panOffset
        let size = viewSize
        let scale = displayScale
        
        DispatchQueue.global(qos: .userInteractive).async {
            let image = renderer.render(
                layers: layers,
                currentStroke: currentStroke,
                currentShape: currentShape,
                selectedElementIds: selectedElementIds,
                size: size,
                backgroundColor: backgroundColor,
                zoom: zoom,
                panOffset: panOffset,
                scale: scale
            )
            
            DispatchQueue.main.async {
                self.canvasImage = image
                self.imageScale = scale
            }
        }
    }
}

// MARK: - Text Input View

struct TextInputView: View {
    let position: CGPoint
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("Enter text", text: $text)
            .textFieldStyle(.plain)
            .padding(8)
            .background(ColorTheme.panelBackground.opacity(0.9))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTheme.accentPrimary, lineWidth: 2)
            )
            .frame(width: 200)
            .position(position)
            .focused($isFocused)
            .onSubmit {
                onSubmit(text)
                text = ""
            }
            .onAppear {
                isFocused = true
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                     // If lost focus (clicked away), commit or cancel?
                     // Usually cancelling if empty is safely handled by submit logic
                     if text.isEmpty { onCancel() }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    CanvasView()
        .environmentObject(CanvasViewModel())
        .frame(width: 800, height: 600)
}
