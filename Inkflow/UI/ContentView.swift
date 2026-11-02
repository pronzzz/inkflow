import SwiftUI

struct ContentView: View {
    @ObservedObject var document: InkflowDocument
    @StateObject private var editor: Editor
    @Environment(\.undoManager) private var undoManager

    init(document: InkflowDocument) {
        self.document = document
        _editor = StateObject(wrappedValue: Editor(document: document))
    }

    var body: some View {
        ZStack {
            CanvasRepresentable(editor: editor)
                .ignoresSafeArea()

            if document.drawing.isEmpty {
                EmptyHint(dark: document.drawing.background.isDark)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            ToolPalette(editor: editor)
                .padding(.bottom, 14)
        }
        .overlay(alignment: .bottomLeading) {
            ZoomBadge(editor: editor)
                .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            if editor.showLayers {
                LayersPanel(editor: editor)
                    .padding(12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: editor.showLayers)
        .animation(.easeOut(duration: 0.3), value: document.drawing.isEmpty)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor.showLayers.toggle()
                } label: {
                    Label("Layers", systemImage: "square.3.layers.3d")
                }
                .help("Show or hide layers (⌥⌘L)")
            }
        }
        .sheet(isPresented: $editor.showShortcuts) {
            ShortcutsView()
        }
        .focusedSceneObject(editor)
        .frame(minWidth: 680, minHeight: 460)
        .onAppear { editor.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in editor.undoManager = manager }
    }
}

private struct EmptyHint: View {
    let dark: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("Draw anywhere")
                .font(.system(size: 15, weight: .medium))
            Text("Scroll to pan · Pinch to zoom · Press ? for shortcuts")
                .font(.system(size: 12))
        }
        .foregroundStyle(dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3))
        .offset(y: -30)
    }
}

/// Bridges the AppKit canvas into SwiftUI.
struct CanvasRepresentable: NSViewRepresentable {
    let editor: Editor

    func makeNSView(context: Context) -> CanvasView {
        CanvasView(editor: editor)
    }

    func updateNSView(_ view: CanvasView, context: Context) {}
}
