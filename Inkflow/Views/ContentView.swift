//
//  ContentView.swift
//  Inkflow
//
//  Main application layout with enhanced One UI-inspired design
//

import SwiftUI

struct ContentView: View {
    @Environment(\.undoManager) var undoManager
    @Binding var document: InkflowDocument
    @StateObject private var viewModel: CanvasViewModel
    @State private var showColorPicker = false
    @State private var showKeyboardHints = false
    @State private var toolbarPosition: ToolbarPosition = .bottom
    
    init(document: Binding<InkflowDocument>) {
        self._document = document
        self._viewModel = StateObject(wrappedValue: CanvasViewModel(document: document.wrappedValue.data))
    }
    
    enum ToolbarPosition {
        case bottom, leading, trailing
    }
    
    var body: some View {
        ZStack {
            // Canvas fills the entire window
            CanvasView()
                .background(ColorTheme.canvasBackground)
                .ignoresSafeArea()
            
            // Toolbar positioned according to preference
            toolbarContainer
            
            // Floating color picker
            if showColorPicker {
                colorPickerOverlay
            }
            
            // Layers panel
            if viewModel.showLayersPanel {
                VStack {
                    HStack {
                        Spacer()
                        LayersPanel(isPresented: $viewModel.showLayersPanel)
                            .padding(.top, 60)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            // Keyboard shortcut overlay
            KeyboardShortcutOverlay(isShowing: $showKeyboardHints)
        }
        .environmentObject(viewModel) // Inject for ALL children
        .focusedValue(\.canvasViewModel, viewModel) // Expose to Menu Bar
        .preferredColorScheme(.dark) // Dark mode as default
        .frame(minWidth: 900, minHeight: 700)
        .onAppear {
            viewModel.undoManager = undoManager
        }
        .onChange(of: viewModel.backgroundColor) { _, _ in
            document.data = viewModel.snapshot()
        }
        .touchBar {
             TouchBarView(viewModel: viewModel)
        }
    }
    
    // MARK: - Toolbar Container
    
    @ViewBuilder
    private var toolbarContainer: some View {
        switch toolbarPosition {
        case .bottom:
            VStack {
                Spacer()
                EnhancedToolbar(showColorPicker: $showColorPicker)
                    .padding(.bottom, 24)
            }
        case .leading:
            HStack {
                EnhancedToolbar(showColorPicker: $showColorPicker, isVertical: true)
                    .padding(.leading, 24)
                Spacer()
            }
        case .trailing:
            HStack {
                Spacer()
                EnhancedToolbar(showColorPicker: $showColorPicker, isVertical: true)
                    .padding(.trailing, 24)
            }
        }
    }
    
    // MARK: - Color Picker Overlay
    
    private var colorPickerOverlay: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AnimationTiming.colorPickerToggle) {
                        showColorPicker = false
                    }
                }
            
            // Picker
            VStack {
                Spacer()
                ColorPickerView(
                    selectedColor: $viewModel.color,
                    isPresented: $showColorPicker
                )
                .padding(.bottom, 120)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Enhanced Toolbar

struct EnhancedToolbar: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    @Binding var showColorPicker: Bool
    var isVertical: Bool = false
    
    @State private var hoveredTool: Tool?
    
    var body: some View {
        Group {
            if isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .padding(isVertical ? 16 : 20)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Material.toolbarMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(ColorTheme.toolbarBorder, lineWidth: 1)
                }
                .shadows(ShadowStyle.toolbar)
        }
    }
    
    // MARK: - Layouts
    
    private var horizontalLayout: some View {
        HStack(spacing: 12) {
            toolButtons
            Divider().frame(height: 40)
            colorButton
            Divider().frame(height: 40)
            brushSizeControl
            Divider().frame(height: 40)
            opacityControl
            Divider().frame(height: 40)
            zoomControls
            Divider().frame(height: 40)
            layersButton
        }
    }
    
    private var verticalLayout: some View {
        VStack(spacing: 12) {
            toolButtons
            Divider().frame(width: 40)
            colorButton
            Divider().frame(width: 40)
            brushSizeControl
            Divider().frame(width: 40)
            opacityControl
            Divider().frame(width: 40)
            zoomControls
        }
    }
    
    // MARK: - Tool Buttons
    
    private var toolButtons: some View {
        Group {
            if isVertical {
                VStack(spacing: 10) {
                    toolButtonsContent
                }
            } else {
                HStack(spacing: 10) {
                    toolButtonsContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var toolButtonsContent: some View {
        ForEach(Tool.allCases) { tool in
            EnhancedToolButton(
                tool: tool,
                isSelected: viewModel.selectedTool == tool,
                isHovered: hoveredTool == tool
            ) {
                withAnimation(AnimationTiming.toolSelection) {
                    viewModel.selectTool(tool)
                }
            }
            .onHover { isHovering in
                withAnimation(AnimationTiming.hover) {
                    hoveredTool = isHovering ? tool : nil
                }
            }
        }
    }
    
    // MARK: - Color Button
    
    private var colorButton: some View {
        Button {
            withAnimation(AnimationTiming.springStandard) {
                showColorPicker.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 14)
                .fill(viewModel.color)
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                }
                .shadow(ShadowStyle.light)
        }
        .buttonStyle(ScaleButtonStyle())
        .help("Color Picker")
    }
    
    // MARK: - Brush Size
    
    private var brushSizeControl: some View {
        Group {
            if isVertical {
                VStack(spacing: 8) {
                    brushSizeContent
                }
            } else {
                HStack(spacing: 8) {
                    brushSizeContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var brushSizeContent: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 8))
            .foregroundColor(ColorTheme.textSecondary)
        
        Slider(value: $viewModel.brushSize, in: 1...100)
            .frame(width: isVertical ? nil : 100, height: isVertical ? 100 : nil)
            .tint(ColorTheme.accentPrimary)
            .animation(AnimationTiming.sliderChange, value: viewModel.brushSize)
        
        Image(systemName: "circle.fill")
            .font(.system(size: 16))
            .foregroundColor(ColorTheme.textSecondary)
        
        Text("\(Int(viewModel.brushSize))")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(ColorTheme.textPrimary)
            .frame(width: 32)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.accentSubtle)
            }
    }
    
    // MARK: - Opacity
    
    private var opacityControl: some View {
        Group {
            if isVertical {
                VStack(spacing: 8) {
                    opacityContent
                }
            } else {
                HStack(spacing: 8) {
                    opacityContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var opacityContent: some View {
        Image(systemName: "drop.fill")
            .font(.system(size: 12))
            .foregroundColor(ColorTheme.textSecondary)
        
        Slider(value: $viewModel.opacity, in: 0.1...1.0)
            .frame(width: isVertical ? nil : 80, height: isVertical ? 80 : nil)
            .tint(ColorTheme.accentPrimary)
            .animation(AnimationTiming.sliderChange, value: viewModel.opacity)
        
        Text("\(Int(viewModel.opacity * 100))%")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(ColorTheme.textPrimary)
            .frame(width: 42)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ColorTheme.accentSubtle)
            }
    }
    
    // MARK: - Zoom Controls
    
    private var zoomControls: some View {
        Group {
            if isVertical {
                VStack(spacing: 8) {
                    zoomContent
                }
            } else {
                HStack(spacing: 8) {
                    zoomContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var zoomContent: some View {
        CompactButton(icon: "minus.magnifyingglass") {
            viewModel.zoomOut()
        }
        
        Text("\(Int(viewModel.zoom * 100))%")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(ColorTheme.textPrimary)
            .frame(width: 48)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.buttonSecondary)
            }
        
        CompactButton(icon: "plus.magnifyingglass") {
            viewModel.zoomIn()
        }
        
        CompactButton(icon: "arrow.counterclockwise", isSecondary: true) {
            viewModel.resetZoom()
        }
        .help("Reset Zoom")
    }
    
    // MARK: - Layers Button
    
    private var layersButton: some View {
        Button {
            withAnimation(AnimationTiming.springStandard) {
                viewModel.showLayersPanel.toggle()
            }
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(viewModel.showLayersPanel ? ColorTheme.accentPrimary : ColorTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.showLayersPanel ? ColorTheme.accentSubtle : ColorTheme.buttonSecondary)
                }
        }
        .buttonStyle(.plain)
        .help("Toggle Layers Panel")
    }
}

// MARK: - Enhanced Tool Button

struct EnhancedToolButton: View {
    let tool: Tool
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(ColorTheme.accentGradient) : AnyShapeStyle(ColorTheme.buttonSecondary))
                    .shadow(color: isSelected ? ColorTheme.accentPrimary.opacity(0.3) : .clear, radius: 8)
                
                // Icon
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? ColorTheme.textOnAccent : ColorTheme.textPrimary)
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isPressed ? ScaleEffect.buttonPress : (isHovered ? ScaleEffect.hover : 1.0))
            .rotationEffect(.degrees(isSelected ? 0 : 0))
        }
        .buttonStyle(.plain)
        .help("\(tool.displayName) (\(shortcutFor(tool)))")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(AnimationTiming.springQuick) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(AnimationTiming.springQuick) {
                        isPressed = false
                    }
                }
        )
    }
    
    private func shortcutFor(_ tool: Tool) -> String {
        switch tool {
        case .brush: return "⌘B"
        case .pencil: return "⌘P"
        case .eraser: return "⌘E"
        case .selector: return "S"
        case .shapeRectangle: return "R"
        case .shapeCircle: return "C"
        case .shapeLine: return "L"
        case .text: return "T"
        }
    }
}

// MARK: - Compact Button

struct CompactButton: View {
    let icon: String
    var isSecondary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(isHovered ? ColorTheme.buttonHover : ColorTheme.buttonSecondary)
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AnimationTiming.hover) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ScaleEffect.buttonPress : 1.0)
            .animation(AnimationTiming.springQuick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ContentView(document: .constant(InkflowDocument()))
}

// MARK: - Touch Bar

struct TouchBarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        HStack {
            // Tools
            Picker("Tool", selection: $viewModel.selectedTool) {
                Image(systemName: "paintbrush.fill").tag(Tool.brush)
                Image(systemName: "pencil").tag(Tool.pencil)
                Image(systemName: "eraser.fill").tag(Tool.eraser)
                Image(systemName: "lasso").tag(Tool.selector)
                Image(systemName: "textformat").tag(Tool.text)
            }
            .pickerStyle(.segmented)
            
            Spacer()
            
            // Color
            ColorPicker("Color", selection: $viewModel.color)
                .labelsHidden()
            
            Spacer()
            
            // Undo/Redo
            Button {
                viewModel.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!(viewModel.undoManager?.canUndo ?? false))
            
            Button {
                viewModel.undoManager?.redo()
            } label: {
                 Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!(viewModel.undoManager?.canRedo ?? false))
        }
    }
}
