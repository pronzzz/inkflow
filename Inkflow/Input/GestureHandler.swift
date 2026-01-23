//
//  GestureHandler.swift
//  Inkflow
//
//  Handles advanced input gestures including trackpad and stylus
//

import SwiftUI
import AppKit

/// Handles advanced gesture recognition and input processing
@MainActor
class GestureHandler: ObservableObject {
    
    // MARK: - Properties
    
    weak var viewModel: CanvasViewModel?
    
    /// Current gesture state
    @Published var gestureState: GestureState = .idle
    
    /// Whether a modifier key is pressed
    @Published var isModifierPressed = false
    
    // MARK: - State Machine
    
    enum GestureState {
        case idle
        case drawing
        case panning
        case zooming
    }
    
    // MARK: - Initialization
    
    init(viewModel: CanvasViewModel? = nil) {
        self.viewModel = viewModel
    }
    
    // MARK: - Touch Handling
    
    /// Process scroll wheel event for zooming
    func handleScrollWheel(_ event: NSEvent, in viewSize: CGSize) {
        guard let viewModel = viewModel else { return }
        
        // Pinch gesture (magnification)
        if event.phase == .changed && event.momentumPhase == .none {
            if event.modifierFlags.contains(.command) {
                // Cmd + scroll for precise zoom
                let zoomDelta = 1.0 + event.scrollingDeltaY * 0.01
                let mouseLocation = CGPoint(x: event.locationInWindow.x, y: event.locationInWindow.y)
                viewModel.setZoom(viewModel.zoom * zoomDelta, around: mouseLocation)
            }
        }
    }
    
    /// Calculate pressure from tablet event
    func pressure(from event: NSEvent) -> CGFloat {
        if event.type == .tabletPoint || event.subtype == .tabletPoint {
            return CGFloat(event.pressure)
        }
        return 1.0
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert window coordinates to canvas coordinates
    func canvasCoordinate(from windowPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        guard let viewModel = viewModel else { return windowPoint }
        return viewModel.canvasPoint(from: windowPoint, in: viewSize)
    }
}

// MARK: - Trackpad Gesture Recognizer

/// A custom NSView that handles advanced trackpad gestures
class TrackpadGestureView: NSView {
    
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    var onRotate: ((CGFloat) -> Void)?
    var onScroll: ((CGPoint) -> Void)?
    
    override func magnify(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onMagnify?(event.magnification, location)
    }
    
    override func rotate(with event: NSEvent) {
        onRotate?(CGFloat(event.rotation))
    }
    
    override func scrollWheel(with event: NSEvent) {
        let delta = CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY)
        onScroll?(delta)
    }
    
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - SwiftUI Wrapper

struct TrackpadGestureViewRepresentable: NSViewRepresentable {
    let onMagnify: (CGFloat, CGPoint) -> Void
    let onScroll: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> TrackpadGestureView {
        let view = TrackpadGestureView()
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: TrackpadGestureView, context: Context) {
        nsView.onMagnify = onMagnify
        nsView.onScroll = onScroll
    }
}
