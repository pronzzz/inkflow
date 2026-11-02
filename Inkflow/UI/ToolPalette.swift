import SwiftUI

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent))
    }

    func isClose(to other: RGBA) -> Bool {
        abs(r - other.r) + abs(g - other.g) + abs(b - other.b) < 0.02
    }
}

/// A floating bar of plain controls: tools, colour, size.
struct ToolPalette: View {
    @ObservedObject var editor: Editor

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(Tool.palette) { tool in
                    if tool == .shape {
                        ShapeButton(editor: editor)
                    } else {
                        ToolButton(symbol: tool.symbol, isOn: editor.tool == tool,
                                   help: "\(tool.title) (\(tool.key))") { editor.tool = tool }
                    }
                }
            }
            Divider().frame(height: 22)
            ColorStrip(editor: editor)
                .opacity(editor.tool.usesColor ? 1 : 0.35)
            Divider().frame(height: 22)
            StrokeControl(editor: editor)
                .opacity(editor.tool.hasSize ? 1 : 0.35)
                .disabled(!editor.tool.hasSize)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
}

private struct ToolButton: View {
    let symbol: String
    let isOn: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                .frame(width: 30, height: 30)
                .foregroundStyle(isOn ? Color.accentColor : Color.primary.opacity(0.75))
                .background(isOn ? Color.accentColor.opacity(0.14) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// One palette slot for all four shapes; the menu picks which one.
private struct ShapeButton: View {
    @ObservedObject var editor: Editor

    var body: some View {
        let isOn = editor.tool == .shape
        Menu {
            ForEach(ShapeKind.allCases) { kind in
                Button {
                    editor.select(shape: kind)
                } label: {
                    Label("\(kind.title)  \(kind.key)", systemImage: kind.symbol)
                }
            }
        } label: {
            Image(systemName: editor.shapeKind.symbol)
                .font(.system(size: 14, weight: isOn ? .semibold : .regular))
                .frame(width: 30, height: 30)
                .foregroundStyle(isOn ? Color.accentColor : Color.primary.opacity(0.75))
                .background(isOn ? Color.accentColor.opacity(0.14) : .clear, in: Circle())
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(x: -3, y: -3)
                }
                .contentShape(Circle())
        } primaryAction: {
            editor.tool = .shape
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("\(editor.shapeKind.title) (L, A, R, O) — hold for more shapes")
    }
}

private struct ColorStrip: View {
    @ObservedObject var editor: Editor

    var body: some View {
        HStack(spacing: 5) {
            ForEach(RGBA.palette, id: \.hex) { swatch in
                let isOn = editor.color.isClose(to: swatch)
                Button {
                    editor.color = swatch
                    if !editor.tool.usesColor { editor.tool = .brush }
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
                        .padding(3)
                        .overlay(Circle().strokeBorder(isOn ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            CustomColorButton(editor: editor)
        }
    }
}

/// A rainbow dot that opens the system colour panel. Shows the colour when it is not a swatch.
private struct CustomColorButton: View {
    @ObservedObject var editor: Editor

    var body: some View {
        let isCustom = !RGBA.palette.contains { $0.isClose(to: editor.color) }
        Button {
            ColorPanelBridge.shared.show(editor.color) { color in
                editor.color = color
                if !editor.tool.usesColor { editor.tool = .brush }
            }
        } label: {
            Circle()
                .strokeBorder(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                              center: .center), lineWidth: isCustom ? 3 : 8)
                .background(Circle().fill(isCustom ? editor.color.color : .clear).padding(2))
                .frame(width: 16, height: 16)
                .padding(3)
                .overlay(Circle().strokeBorder(isCustom ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("More colours")
    }
}

@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var onChange: ((RGBA) -> Void)?

    func show(_ color: RGBA, onChange: @escaping (RGBA) -> Void) {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        self.onChange = nil
        panel.color = NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: 1)
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorChanged(_ panel: NSColorPanel) {
        guard let c = panel.color.usingColorSpace(.sRGB) else { return }
        onChange?(RGBA(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)))
    }
}

/// A dot showing the current size and opacity; click for sliders.
private struct StrokeControl: View {
    @ObservedObject var editor: Editor
    @State private var showing = false

    var body: some View {
        let size = editor.size(for: editor.tool)
        Button {
            showing.toggle()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(editor.tool == .eraser ? Color.secondary : editor.color.color)
                        .opacity(editor.tool == .eraser ? 0.5 : editor.opacity)
                        .frame(width: min(max(size, 3), 22), height: min(max(size, 3), 22))
                }
                .frame(width: 24, height: 24)
                Text("\(Int(size.rounded()))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .leading)
            }
            .padding(.trailing, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Size and opacity ([ ] and 1–0)")
        .popover(isPresented: $showing, arrowEdge: .top) {
            StrokePopover(editor: editor)
        }
    }
}

private struct StrokePopover: View {
    @ObservedObject var editor: Editor

    var body: some View {
        let tool = editor.tool
        VStack(alignment: .leading, spacing: 12) {
            LabeledSlider(title: tool == .text ? "Font size" : "Size",
                          value: Binding(get: { Double(editor.size) }, set: { editor.size = CGFloat($0) }),
                          range: Double(tool.sizeRange.lowerBound)...Double(tool.sizeRange.upperBound),
                          format: { "\(Int($0.rounded())) pt" })
            if tool.usesColor {
                LabeledSlider(title: "Opacity", value: $editor.opacity, range: 0.05...1,
                              format: { "\(Int(($0 * 100).rounded()))%" })
            }
        }
        .padding(14)
        .frame(width: 230)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(format(value)).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                .controlSize(.small)
        }
    }
}

struct ZoomBadge: View {
    @ObservedObject var editor: Editor

    var body: some View {
        Menu {
            Button("Zoom In", action: editor.zoomIn)
            Button("Zoom Out", action: editor.zoomOut)
            Divider()
            Button("Actual Size", action: editor.actualSize)
            Button("Zoom to Fit", action: editor.zoomToFit)
        } label: {
            Text("\(Int((editor.zoom * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Zoom")
    }
}
