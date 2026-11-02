import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Per-window editing state: the current tool and style, the selection, the active layer,
/// and every change to the document (each one undoable).
@MainActor
final class Editor: ObservableObject {
    let document: InkflowDocument
    weak var undoManager: UndoManager?
    weak var canvas: CanvasView?

    @Published var tool: Tool = .brush {
        didSet { if tool != oldValue { previousTool = oldValue; Defaults.tool = tool } }
    }
    @Published var shapeKind: ShapeKind = Defaults.shapeKind {
        didSet { Defaults.shapeKind = shapeKind }
    }
    @Published var color: RGBA = Defaults.color {
        didSet { Defaults.color = color }
    }
    @Published var opacity: Double = Defaults.opacity {
        didSet { Defaults.opacity = opacity }
    }
    @Published private(set) var sizes: [Tool: CGFloat] = Defaults.sizes
    @Published var selection: Set<UUID> = []
    @Published var activeLayerID: UUID
    @Published var showLayers = false
    @Published var showShortcuts = false
    @Published var showGrid = Defaults.showGrid {
        didSet { Defaults.showGrid = showGrid; canvas?.needsDisplay = true }
    }
    /// Mirrors the canvas zoom for the zoom badge.
    @Published var zoom: CGFloat = 1

    private var previousTool: Tool = .brush
    private var gestureBaseline: Drawing?
    private var pasteCount = 0

    init(document: InkflowDocument) {
        self.document = document
        activeLayerID = document.drawing.layers.last!.id
        tool = Launch.options.tool ?? Defaults.tool
        if Launch.options.showLayers { showLayers = true }
    }

    var drawing: Drawing { document.drawing }

    // MARK: Tool and style

    var size: CGFloat {
        get { sizes[tool] ?? tool.defaultSize }
        set {
            sizes[tool] = min(max(newValue, tool.sizeRange.lowerBound), tool.sizeRange.upperBound)
            Defaults.sizes = sizes
        }
    }

    func size(for tool: Tool) -> CGFloat { sizes[tool] ?? tool.defaultSize }

    /// The colour new marks are made with, opacity included.
    var inkColor: RGBA { color.withAlpha(opacity) }

    func select(shape kind: ShapeKind) {
        shapeKind = kind
        tool = .shape
    }

    /// Temporarily switches tools (Space for the hand) and back.
    func toggleBack() { tool = previousTool }

    func stepSize(_ direction: CGFloat) {
        let current = size
        let step: CGFloat = current < 10 ? 1 : current < 40 ? 2 : 6
        size = current + direction * step
    }

    // MARK: Changes and undo

    /// Applies one undoable change to the drawing.
    func perform(_ actionName: String, _ change: (inout Drawing) -> Void) {
        let before = document.drawing
        var after = before
        change(&after)
        guard after != before else { return }
        commit(after, replacing: before, actionName: actionName)
    }

    private func commit(_ new: Drawing, replacing old: Drawing, actionName: String) {
        document.drawing = new
        undoManager?.registerUndo(withTarget: self) { editor in
            editor.commit(old, replacing: new, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
        reconcile()
    }

    /// Continuous changes (dragging items, an opacity slider) become one undo step:
    /// `beginGesture`, any number of `updateGesture`, then `endGesture`.
    func beginGesture() {
        if gestureBaseline == nil { gestureBaseline = document.drawing }
    }

    func updateGesture(_ change: (inout Drawing) -> Void) {
        guard let base = gestureBaseline else { return }
        var next = base
        change(&next)
        document.drawing = next
    }

    func endGesture(_ actionName: String) {
        guard let base = gestureBaseline else { return }
        gestureBaseline = nil
        let current = document.drawing
        guard current != base else { return }
        undoManager?.registerUndo(withTarget: self) { editor in
            editor.commit(base, replacing: current, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }

    /// Keeps the active layer and selection valid after any change (including undo).
    private func reconcile() {
        let drawing = document.drawing
        if drawing.layerIndex(activeLayerID) == nil, let last = drawing.layers.last {
            activeLayerID = last.id
        }
        if !selection.isEmpty {
            let valid = selection.intersection(drawing.editableItemIDs)
            if valid != selection { selection = valid }
        }
    }

    // MARK: Items

    var activeLayer: DrawingLayer? { drawing.layers.first { $0.id == activeLayerID } }

    /// Whether new marks can go on the active layer. Hidden layers are shown again; locked
    /// layers refuse with a beep.
    func prepareActiveLayerForDrawing() -> Bool {
        guard let index = drawing.layerIndex(activeLayerID) else { return false }
        if drawing.layers[index].isLocked {
            NSSound.beep()
            return false
        }
        if !drawing.layers[index].isVisible {
            perform("Show Layer") { $0.layers[index].isVisible = true }
        }
        return true
    }

    func add(_ item: CanvasItem) {
        guard let index = drawing.layerIndex(activeLayerID) else { return }
        let name: String
        switch item {
        case .stroke(let s): name = s.tool == .eraser ? "Erase" : "Draw"
        case .shape(let s): name = s.kind.title
        case .text: name = "Add Text"
        }
        perform(name) { $0.layers[index].items.append(item) }
    }

    func replace(_ item: CanvasItem, actionName: String) {
        perform(actionName) { drawing in
            if let at = drawing.index()[item.id] { drawing.layers[at.layer].items[at.item] = item }
        }
    }

    func remove(_ ids: Set<UUID>, actionName: String = "Delete") {
        guard !ids.isEmpty else { return }
        perform(actionName) { drawing in
            for l in drawing.layers.indices { drawing.layers[l].items.removeAll { ids.contains($0.id) } }
        }
        selection.subtract(ids)
    }

    /// The topmost editable item under a canvas point.
    func item(at point: CGPoint, tolerance: CGFloat) -> CanvasItem? {
        for layer in drawing.layers.reversed() where layer.isVisible && !layer.isLocked {
            if let item = layer.items.last(where: { Geometry.hitTest($0, at: point, tolerance: tolerance) }) {
                return item
            }
        }
        return nil
    }

    func items(in rect: CGRect) -> Set<UUID> {
        var ids = Set<UUID>()
        for layer in drawing.layers where layer.isVisible && !layer.isLocked {
            for item in layer.items where !item.isEraser && Geometry.bounds(of: item).intersects(rect) {
                ids.insert(item.id)
            }
        }
        return ids
    }

    var selectedItems: [CanvasItem] {
        drawing.layers.flatMap { $0.items.filter { selection.contains($0.id) } }
    }

    // MARK: Selection commands

    func selectAll() {
        tool = .select
        selection = Set(drawing.layers.filter { $0.isVisible && !$0.isLocked }
            .flatMap { $0.items.filter { !$0.isEraser }.map(\.id) })
    }

    func deleteSelection() { remove(selection) }

    func move(_ ids: Set<UUID>, by delta: CGVector) {
        updateGesture { drawing in
            for l in drawing.layers.indices where !drawing.layers[l].isLocked {
                for i in drawing.layers[l].items.indices where ids.contains(drawing.layers[l].items[i].id) {
                    drawing.layers[l].items[i] = drawing.layers[l].items[i].translated(by: delta)
                }
            }
        }
    }

    func nudgeSelection(by delta: CGVector) {
        guard !selection.isEmpty else { return }
        beginGesture()
        move(selection, by: delta)
        endGesture("Move")
    }

    func duplicateSelection() {
        guard !selection.isEmpty else { return }
        insertCopies(of: selectedItems, offset: CGVector(dx: 16, dy: 16), actionName: "Duplicate")
    }

    private func insertCopies(of items: [CanvasItem], offset: CGVector, actionName: String) {
        guard let index = drawing.layerIndex(activeLayerID), prepareActiveLayerForDrawing() else { return }
        let copies = items.map { $0.copyWithNewID().translated(by: offset) }
        perform(actionName) { $0.layers[index].items.append(contentsOf: copies) }
        selection = Set(copies.map(\.id))
        tool = .select
    }

    // MARK: Clipboard

    static let itemsPasteboardType = NSPasteboard.PasteboardType("com.pranavdwivedi.inkflow.items")

    var canPaste: Bool {
        NSPasteboard.general.availableType(from: [Self.itemsPasteboardType]) != nil
    }

    func copySelection() {
        let items = selectedItems
        guard !items.isEmpty, let data = try? JSONEncoder().encode(items) else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setData(data, forType: Self.itemsPasteboardType)
        if let png = pngData(only: selection) { board.setData(png, forType: .png) }
        pasteCount = 0
    }

    func cutSelection() {
        copySelection()
        remove(selection, actionName: "Cut")
    }

    func paste() {
        guard let data = NSPasteboard.general.data(forType: Self.itemsPasteboardType),
              let items = try? JSONDecoder().decode([CanvasItem].self, from: data), !items.isEmpty else { return }
        pasteCount += 1
        let step = CGFloat(16 * pasteCount)
        insertCopies(of: items, offset: CGVector(dx: step, dy: step), actionName: "Paste")
    }

    /// Copies the selection (or the whole drawing) to the clipboard as a PNG.
    func copyAsImage() {
        guard let png = pngData(only: selection.isEmpty ? nil : selection) else { NSSound.beep(); return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setData(png, forType: .png)
    }

    // MARK: Layers

    func addLayer() {
        let layer = DrawingLayer(name: drawing.nextLayerName())
        let insertAt = (drawing.layerIndex(activeLayerID) ?? drawing.layers.count - 1) + 1
        perform("New Layer") { $0.layers.insert(layer, at: insertAt) }
        activeLayerID = layer.id
    }

    func deleteLayer(_ id: UUID) {
        guard drawing.layers.count > 1, let index = drawing.layerIndex(id) else { NSSound.beep(); return }
        perform("Delete Layer") { $0.layers.remove(at: index) }
        if activeLayerID == id { activeLayerID = drawing.layers[max(index - 1, 0)].id }
    }

    /// Moves a layer up (towards the front) or down.
    func moveLayer(_ id: UUID, up: Bool) {
        guard let index = drawing.layerIndex(id) else { return }
        let target = up ? index + 1 : index - 1
        guard drawing.layers.indices.contains(target) else { return }
        perform(up ? "Bring Layer Forward" : "Send Layer Backward") { $0.layers.swapAt(index, target) }
    }

    func renameLayer(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = drawing.layerIndex(id) else { return }
        perform("Rename Layer") { $0.layers[index].name = trimmed }
    }

    func toggleVisibility(_ id: UUID) {
        guard let index = drawing.layerIndex(id) else { return }
        perform(drawing.layers[index].isVisible ? "Hide Layer" : "Show Layer") { $0.layers[index].isVisible.toggle() }
    }

    func toggleLock(_ id: UUID) {
        guard let index = drawing.layerIndex(id) else { return }
        perform(drawing.layers[index].isLocked ? "Unlock Layer" : "Lock Layer") { $0.layers[index].isLocked.toggle() }
    }

    func setOpacity(_ opacity: Double, of id: UUID) {
        guard let index = drawing.layerIndex(id) else { return }
        beginGesture()
        updateGesture { $0.layers[index].opacity = opacity }
    }

    func clearActiveLayer() {
        guard let index = drawing.layerIndex(activeLayerID), !drawing.layers[index].items.isEmpty else { return }
        perform("Clear Layer") { $0.layers[index].items.removeAll() }
    }

    func setBackground(_ color: RGBA) {
        perform("Change Background") { $0.background = color }
    }

    // MARK: View

    func zoomIn() { canvas?.zoom(by: 1.25) }
    func zoomOut() { canvas?.zoom(by: 0.8) }
    func actualSize() { canvas?.setZoom(1) }
    func zoomToFit() { canvas?.zoomToFit(animated: true) }

    // MARK: Export

    private func pngData(only: Set<UUID>? = nil) -> Data? {
        let drawing = document.drawing
        guard let rect = Renderer.contentBounds(of: drawing, only: only),
              let image = Renderer.image(of: drawing, rect: rect, scale: 2, only: only) else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = rect.size // 144 dpi, so it pastes at its real size
        return rep.representation(using: .png, properties: [:])
    }

    enum ExportFormat { case png, pdf }

    func export(_ format: ExportFormat) {
        let drawing = document.drawing
        guard Renderer.contentBounds(of: drawing) != nil else { NSSound.beep(); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .pdf]
        panel.canCreateDirectories = true
        let title = canvas?.window?.title ?? "Drawing"
        panel.nameFieldStringValue = (title as NSString).deletingPathExtension
        let write: (URL) -> Void = { [weak self] url in
            guard let self else { return }
            let data: Data?
            switch format {
            case .png: data = self.pngData()
            case .pdf: data = Renderer.contentBounds(of: drawing).flatMap { Renderer.pdf(of: drawing, rect: $0) }
            }
            do {
                guard let data else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        if let window = canvas?.window {
            panel.beginSheetModal(for: window) { if $0 == .OK, let url = panel.url { write(url) } }
        } else if panel.runModal() == .OK, let url = panel.url {
            write(url)
        }
    }
}

// MARK: - Preferences

/// Tool preferences shared by all windows.
enum Defaults {
    private static let store = UserDefaults.standard

    static var tool: Tool {
        get { store.string(forKey: "tool").flatMap(Tool.init(rawValue:)) ?? .brush }
        set { store.set(newValue.rawValue, forKey: "tool") }
    }
    static var shapeKind: ShapeKind {
        get { store.string(forKey: "shapeKind").flatMap(ShapeKind.init(rawValue:)) ?? .rectangle }
        set { store.set(newValue.rawValue, forKey: "shapeKind") }
    }
    static var color: RGBA {
        get { store.string(forKey: "color").map(RGBA.init(hex:)) ?? .ink }
        set { store.set(newValue.hex, forKey: "color") }
    }
    static var opacity: Double {
        get { store.object(forKey: "opacity") as? Double ?? 1 }
        set { store.set(newValue, forKey: "opacity") }
    }
    static var showGrid: Bool {
        get { store.object(forKey: "showGrid") as? Bool ?? true }
        set { store.set(newValue, forKey: "showGrid") }
    }
    static var sizes: [Tool: CGFloat] {
        get {
            let raw = store.dictionary(forKey: "sizes") as? [String: Double] ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                Tool(rawValue: key).map { ($0, CGFloat(value)) }
            })
        }
        set {
            store.set(Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, Double($0.value)) }),
                      forKey: "sizes")
        }
    }
}
