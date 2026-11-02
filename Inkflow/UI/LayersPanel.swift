import SwiftUI

struct LayersPanel: View {
    @ObservedObject var editor: Editor
    @ObservedObject private var document: InkflowDocument
    @State private var renaming: UUID?
    @State private var draftName = ""

    init(editor: Editor) {
        self.editor = editor
        document = editor.document
    }

    var body: some View {
        let layers = document.drawing.layers
        VStack(spacing: 0) {
            HStack {
                Text("Layers").font(.system(size: 12, weight: .semibold))
                Spacer()
                iconButton("plus", help: "New layer (⇧⌘N)") { editor.addLayer() }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 1) {
                    // Front-most layer first, like every other app.
                    ForEach(layers.reversed()) { layer in
                        row(layer)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 260)
            .fixedSize(horizontal: false, vertical: true)

            if let active = editor.activeLayer {
                Divider().padding(.top, 6)
                VStack(spacing: 8) {
                    LabeledSlider(title: "Opacity",
                                  value: Binding(get: { active.opacity },
                                                 set: { editor.setOpacity($0, of: active.id) }),
                                  range: 0...1,
                                  format: { "\(Int(($0 * 100).rounded()))%" },
                                  onEditingChanged: { editing in if !editing { editor.endGesture("Layer Opacity") } })
                    HStack(spacing: 2) {
                        iconButton("arrow.up", help: "Bring forward") { editor.moveLayer(active.id, up: true) }
                            .disabled(layers.last?.id == active.id)
                        iconButton("arrow.down", help: "Send backward") { editor.moveLayer(active.id, up: false) }
                            .disabled(layers.first?.id == active.id)
                        Spacer()
                        iconButton("trash", help: "Delete layer") { editor.deleteLayer(active.id) }
                            .disabled(layers.count < 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 228)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }

    private func row(_ layer: DrawingLayer) -> some View {
        let isActive = layer.id == editor.activeLayerID
        return HStack(spacing: 6) {
            iconButton(layer.isVisible ? "eye" : "eye.slash", help: layer.isVisible ? "Hide" : "Show") {
                editor.toggleVisibility(layer.id)
            }
            .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)

            if renaming == layer.id {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit { finishRename(layer.id) }
                    .onExitCommand { renaming = nil }
            } else {
                Text(layer.name)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(layer.items.count)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            iconButton(layer.isLocked ? "lock.fill" : "lock.open", help: layer.isLocked ? "Unlock" : "Lock") {
                editor.toggleLock(layer.id)
            }
            .foregroundStyle(layer.isLocked ? Color.primary : Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 4)
        .frame(height: 28)
        .background(isActive ? Color.accentColor.opacity(0.14) : .clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            draftName = layer.name
            renaming = layer.id
        }
        .onTapGesture { editor.activeLayerID = layer.id }
    }

    private func finishRename(_ id: UUID) {
        editor.renameLayer(id, to: draftName)
        renaming = nil
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
