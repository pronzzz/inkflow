import SwiftUI

@main
struct InkflowApp: App {
    init() {
        // Open a blank canvas at launch rather than the Open panel.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
        if let appearance = Launch.options.appearance {
            DispatchQueue.main.async {
                NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
            }
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: { InkflowDocument() }) { file in
            ContentView(document: file.document)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unifiedCompact)
        .commands { InkflowCommands() }
    }
}

struct InkflowCommands: Commands {
    @FocusedObject private var editor: Editor?

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export as PNG…") { editor?.export(.png) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(editor?.drawing.isEmpty ?? true)
            Button("Export as PDF…") { editor?.export(.pdf) }
                .keyboardShortcut("e", modifiers: [.command, .shift, .option])
                .disabled(editor?.drawing.isEmpty ?? true)
        }

        CommandGroup(after: .pasteboard) {
            Button("Duplicate") { editor?.duplicateSelection() }
                .keyboardShortcut("d")
                .disabled(editor?.selection.isEmpty ?? true)
            Button("Copy as Image") { editor?.copyAsImage() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(editor?.drawing.isEmpty ?? true)
        }

        CommandGroup(before: .toolbar) {
            Button("Zoom In") { editor?.zoomIn() }
                .keyboardShortcut("=")
            Button("Zoom Out") { editor?.zoomOut() }
                .keyboardShortcut("-")
            Button("Actual Size") { editor?.actualSize() }
                .keyboardShortcut("0")
            Button("Zoom to Fit") { editor?.zoomToFit() }
                .keyboardShortcut("9")
            Divider()
            Button(editor?.showGrid == false ? "Show Grid" : "Hide Grid") { editor?.showGrid.toggle() }
                .keyboardShortcut("'")
            Button(editor?.showLayers == true ? "Hide Layers" : "Show Layers") { editor?.showLayers.toggle() }
                .keyboardShortcut("l", modifiers: [.command, .option])
            Divider()
        }

        CommandMenu("Canvas") {
            Button("New Layer") { editor?.addLayer() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Delete Layer") { if let id = editor?.activeLayerID { editor?.deleteLayer(id) } }
                .disabled((editor?.drawing.layers.count ?? 0) < 2)
            Button("Clear Layer") { editor?.clearActiveLayer() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(editor?.activeLayer?.items.isEmpty ?? true)
            Divider()
            Menu("Background") {
                ForEach(Paper.allCases) { paper in
                    Button(paper.title) { editor?.setBackground(paper.color) }
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { editor?.showShortcuts = true }
                .keyboardShortcut("/")
            Link("Inkflow on GitHub", destination: URL(string: "https://github.com/pronzzz/inkflow")!)
        }
    }
}
