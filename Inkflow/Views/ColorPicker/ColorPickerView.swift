//
//  ColorPickerView.swift
//  Inkflow
//
//  Advanced color picker with presets, recent colors, and HSB sliders
//

import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var isPresented: Bool
    @StateObject private var viewModel = ColorPickerViewModel()
    
    @State private var isExpanded = false
    @State private var hue: Double = 0.5
    @State private var saturation: Double = 0.8
    @State private var brightness: Double = 0.9
    @State private var hexInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact view - always visible
            compactView
            
            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Material.toolbarMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(ColorTheme.toolbarBorder, lineWidth: 1)
                }
                .shadows(ShadowStyle.panel)
        }
        .frame(width: 280)
        .onAppear {
            updateFromColor(selectedColor)
            viewModel.addRecentColor(selectedColor)
        }
        .onChange(of: selectedColor) { _, newColor in
            updateFromColor(newColor)
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: 12) {
            // Current color preview
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedColor)
                .frame(width: 44, height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                }
                .shadow(ShadowStyle.light)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Color")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
                
                Text(selectedColor.hexString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(ColorTheme.textPrimary)
            }
            
            Spacer()
            
            // Expand/collapse button
            Button {
                withAnimation(AnimationTiming.colorPickerToggle) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(ColorTheme.buttonSecondary)
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 4)
            
            // Preset colors
            presetColorsGrid
            
            // Recent colors
            if !viewModel.recentColors.isEmpty {
                recentColorsRow
            }
            
            // HSB sliders
            hsbSliders
            
            // Hex input
            hexInputField
            
            // Native picker button
            Button {
                // Show native color picker
            } label: {
                HStack {
                    Image(systemName: "eyedropper")
                    Text("Advanced Picker")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.buttonSecondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Preset Colors Grid
    
    private var presetColorsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
            
            VStack(spacing: 8) {
                ForEach(0..<ColorTheme.presetColors.count, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(ColorTheme.presetColors[row], id: \.self) { color in
                            colorSwatch(color)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Colors
    
    private var recentColorsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recentColors, id: \.self) { color in
                        colorSwatch(color, size: 32)
                    }
                }
            }
        }
    }
    
    // MARK: - HSB Sliders
    
    private var hsbSliders: some View {
        VStack(spacing: 12) {
            Text("Adjust")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Hue
            customSlider(
                value: $hue,
                label: "H",
                range: 0...1,
                displayValue: "\(Int(hue * 360))°",
                gradient: LinearGradient(
                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Saturation
            customSlider(
                value: $saturation,
                label: "S",
                range: 0...1,
                displayValue: "\(Int(saturation * 100))%",
                gradient: LinearGradient(
                    colors: [.white, Color(hue: hue, saturation: 1, brightness: brightness)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Brightness
            customSlider(
                value: $brightness,
                label: "B",
                range: 0...1,
                displayValue: "\(Int(brightness * 100))%",
                gradient: LinearGradient(
                    colors: [.black, Color(hue: hue, saturation: saturation, brightness: 1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .onChange(of: hue) { _, _ in updateColorFromHSB() }
        .onChange(of: saturation) { _, _ in updateColorFromHSB() }
        .onChange(of: brightness) { _, _ in updateColorFromHSB() }
    }
    
    // MARK: - Hex Input
    
    private var hexInputField: some View {
        HStack(spacing: 8) {
            Text("#")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(ColorTheme.textSecondary)
            
            TextField("Hex Code", text: $hexInput)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .onSubmit {
                    let color = Color(hex: hexInput)
                    if hexInput.count >= 6 { // Basic validation
                        selectedColor = color
                        viewModel.addRecentColor(color)
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.buttonSecondary)
        }
    }
    
    // MARK: - Helper Views
    
    private func colorSwatch(_ color: Color, size: CGFloat = 32) -> some View {
        Button {
            withAnimation(AnimationTiming.springQuick) {
                selectedColor = color
                viewModel.addRecentColor(color)
            }
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            color.isSimilar(to: selectedColor) ? ColorTheme.accentPrimary : Color.clear,
                            lineWidth: 2
                        )
                }
                .shadow(color: Color.black.opacity(0.1), radius: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func customSlider(
        value: Binding<Double>,
        label: String,
        range: ClosedRange<Double>,
        displayValue: String,
        gradient: LinearGradient
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(ColorTheme.textSecondary)
                .frame(width: 12)
            
            Slider(value: value, in: range)
                .tint(ColorTheme.accentPrimary)
            
            Text(displayValue)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(ColorTheme.textSecondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
    
    // MARK: - Helpers
    
    private func updateFromColor(_ color: Color) {
        let components = color.hsbComponents
        hue = components.hue
        saturation = components.saturation
        brightness = components.brightness
        hexInput = color.hexString.replacingOccurrences(of: "#", with: "")
    }
    
    private func updateColorFromHSB() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        viewModel.addRecentColor(selectedColor)
        hexInput = selectedColor.hexString.replacingOccurrences(of: "#", with: "")
    }
}

// MARK: - View Model

@MainActor
class ColorPickerViewModel: ObservableObject {
    @Published var recentColors: [Color] = []
    private let maxRecentColors = 10
    
    func addRecentColor(_ color: Color) {
        // Remove if already exists
        recentColors.removeAll { $0.isSimilar(to: color) }
        
        // Add to beginning
        recentColors.insert(color, at: 0)
        
        // Limit to max
        if recentColors.count > maxRecentColors {
            recentColors = Array(recentColors.prefix(maxRecentColors))
        }
    }
}

// MARK: - Color Extensions

extension Color {
    var hexString: String {
        let components = self.components
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    var hsbComponents: (hue: Double, saturation: Double, brightness: Double) {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }
    
    func isSimilar(to other: Color, tolerance: CGFloat = 0.01) -> Bool {
        let c1 = self.components
        let c2 = other.components
        return abs(c1.red - c2.red) < tolerance &&
               abs(c1.green - c2.green) < tolerance &&
               abs(c1.blue - c2.blue) < tolerance
    }
}

#Preview {
    ColorPickerView(
        selectedColor: .constant(.blue),
        isPresented: .constant(true)
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
