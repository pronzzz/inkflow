import AppKit
import Combine

/// The drawing surface: an infinite canvas with pan and zoom.
///
/// Rendering: when idle, everything visible is drawn as vectors (stroke paths are cached).
/// While a mark is being made, the layers below, the active layer and the layers above are
/// cached as bitmaps once, and each new input point only redraws the few pixels around it.
final class CanvasView: NSView {
    let editor: Editor
    private let renderer = Renderer()
    private var subscriptions: Set<AnyCancellable> = []

    /// Screen point = canvas point × zoom + pan.
    private(set) var zoom: CGFloat = 1
    private(set) var pan: CGPoint = .zero
    private var placedInitialViewport = false

    private enum Interaction {
        case idle
        case stroke(LiveStroke)
        case shape(ShapeItem)
        case pan(last: CGPoint)
        case move(start: CGPoint)
        case marquee(start: CGPoint, current: CGPoint, base: Set<UUID>)
    }

    private struct LiveStroke {
        var stroke: Stroke
        var smoothed: CGPoint
        var lastScreen: CGPoint
        var lastTime: TimeInterval
        var pressure: CGFloat
        var tablet: Bool
    }

    private struct Snapshot {
        let key: SnapshotKey
        let below: CGImage?
        let active: CGImage?
        let above: CGImage?
        let activeOpacity: CGFloat
    }

    private struct SnapshotKey: Equatable {
        var zoom: CGFloat, pan: CGPoint, size: CGSize, scale: CGFloat, revision: Int, layer: UUID
    }

    private var interaction: Interaction = .idle
    private var snapshot: Snapshot?
    private var revision = 0
    private var spaceHeld = false
    private var pointer: CGPoint?
    private var trackingArea: NSTrackingArea?
    private var textSession: TextSession?

    init(editor: Editor) {
        self.editor = editor
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        editor.canvas = self

        editor.document.$drawing
            .sink { [weak self] _ in
                guard let self else { return }
                self.revision &+= 1
                self.needsDisplay = true
            }
            .store(in: &subscriptions)
        editor.$selection
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &subscriptions)
        editor.$tool
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.endTextEditing()
                    self?.updateCursor()
                    self?.needsDisplay = true
                }
            }
            .store(in: &subscriptions)
        editor.$sizes
            .sink { [weak self] _ in DispatchQueue.main.async { self?.needsDisplay = true } }
            .store(in: &subscriptions)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var drawing: Drawing { editor.document.drawing }

    // MARK: Coordinates

    func toCanvas(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - pan.x) / zoom, y: (p.y - pan.y) / zoom) }
    func toScreen(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * zoom + pan.x, y: p.y * zoom + pan.y) }
    func toCanvas(_ r: CGRect) -> CGRect {
        CGRect(x: (r.minX - pan.x) / zoom, y: (r.minY - pan.y) / zoom, width: r.width / zoom, height: r.height / zoom)
    }
    func toScreen(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * zoom + pan.x, y: r.minY * zoom + pan.y, width: r.width * zoom, height: r.height * zoom)
    }

    private func applyViewport(_ ctx: CGContext) {
        ctx.translateBy(x: pan.x, y: pan.y)
        ctx.scaleBy(x: zoom, y: zoom)
    }

    // MARK: Viewport

    static let zoomRange: ClosedRange<CGFloat> = 0.1...16

    func setViewport(zoom newZoom: CGFloat, pan newPan: CGPoint) {
        endTextEditing()
        zoom = min(max(newZoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        pan = newPan
        needsDisplay = true
        if editor.zoom != zoom { editor.zoom = zoom }
    }

    func zoom(by factor: CGFloat, around anchor: CGPoint? = nil) {
        let anchor = anchor ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let newZoom = min(max(zoom * factor, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        let c = toCanvas(anchor)
        setViewport(zoom: newZoom, pan: CGPoint(x: anchor.x - c.x * newZoom, y: anchor.y - c.y * newZoom))
    }

    func setZoom(_ value: CGFloat) { zoom(by: value / zoom) }

    /// Fits the drawing in the window, never enlarging past 100%. With nothing drawn, resets.
    func zoomToFit(animated: Bool = false) {
        guard bounds.width > 100, bounds.height > 100 else { return }
        guard let rect = Renderer.contentBounds(of: drawing, margin: 0) else {
            setViewport(zoom: 1, pan: .zero)
            return
        }
        // Leave room for the tool palette at the bottom.
        let available = CGRect(x: 48, y: 40, width: bounds.width - 96, height: bounds.height - 140)
        let z = min(available.width / rect.width, available.height / rect.height, 1)
        setViewport(zoom: z, pan: CGPoint(x: available.midX - rect.midX * z, y: available.midY - rect.midY * z))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Single-key tool shortcuts work as soon as the window opens.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func layout() {
        super.layout()
        guard !placedInitialViewport, bounds.width > 100, bounds.height > 100 else { return }
        placedInitialViewport = true
        if let size = Launch.options.windowSize, let window {
            window.setContentSize(size)
            window.center()
        }
        zoomToFit()
        if let z = Launch.options.zoom { setZoom(z) }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let drawing = self.drawing
        renderer.adapt(to: drawing.background)

        if isMakingMark, let snapshot = currentSnapshot() {
            if let below = snapshot.below { blit(below, in: ctx) }
            ctx.saveGState()
            ctx.setAlpha(snapshot.activeOpacity)
            ctx.beginTransparencyLayer(in: dirtyRect, auxiliaryInfo: nil)
            if let active = snapshot.active { blit(active, in: ctx) }
            applyViewport(ctx)
            drawLiveMark(in: ctx)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
            if let above = snapshot.above { blit(above, in: ctx) }
        } else {
            drawBackground(in: ctx, rect: dirtyRect, drawing: drawing)
            ctx.saveGState()
            applyViewport(ctx)
            renderer.draw(drawing, in: ctx, visible: toCanvas(dirtyRect), hiding: textSession?.existing?.id)
            ctx.restoreGState()
        }
        drawOverlays(in: ctx)
    }

    private var isMakingMark: Bool {
        switch interaction {
        case .stroke, .shape: return true
        default: return false
        }
    }

    private func drawBackground(in ctx: CGContext, rect: CGRect, drawing: Drawing) {
        ctx.setFillColor(drawing.background.cgColor)
        ctx.fill(rect)
        guard editor.showGrid else { return }
        var spacing = 24 * zoom
        while spacing < 16 { spacing *= 2 }
        while spacing > 64 { spacing /= 2 }
        let ox = pan.x.truncatingRemainder(dividingBy: spacing)
        let oy = pan.y.truncatingRemainder(dividingBy: spacing)
        let dot: CGFloat = 1.1
        var x = floor((rect.minX - ox) / spacing) * spacing + ox
        let startY = floor((rect.minY - oy) / spacing) * spacing + oy
        while x <= rect.maxX + spacing {
            var y = startY
            while y <= rect.maxY + spacing {
                ctx.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
                y += spacing
            }
            x += spacing
        }
        let tint = drawing.background.isDark ? RGBA(1, 1, 1, 0.14) : RGBA(0, 0, 0, 0.16)
        ctx.setFillColor(tint.cgColor)
        ctx.fillPath()
    }

    private func drawLiveMark(in ctx: CGContext) {
        switch interaction {
        case .stroke(let live): renderer.draw(live.stroke, in: ctx)
        case .shape(let shape): renderer.draw(shape, in: ctx)
        default: break
        }
    }

    private func drawOverlays(in ctx: CGContext) {
        let accent = NSColor.controlAccentColor.cgColor
        if !editor.selection.isEmpty, !isMakingMark {
            ctx.saveGState()
            ctx.setStrokeColor(accent)
            ctx.setLineWidth(1)
            let items = editor.selectedItems
            for item in items {
                ctx.stroke(toScreen(Geometry.bounds(of: item)).insetBy(dx: -3.5, dy: -3.5).integral.insetBy(dx: 0.5, dy: 0.5))
            }
            if items.count > 1 {
                ctx.setLineDash(phase: 0, lengths: [4, 3])
                ctx.stroke(toScreen(Geometry.bounds(of: items)).insetBy(dx: -8, dy: -8).integral.insetBy(dx: 0.5, dy: 0.5))
            }
            ctx.restoreGState()
        }
        if case .marquee(let start, let current, _) = interaction {
            let rect = toScreen(CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                                       width: abs(current.x - start.x), height: abs(current.y - start.y)))
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(accent)
            ctx.setLineWidth(1)
            ctx.stroke(rect.integral.insetBy(dx: 0.5, dy: 0.5))
        }
        if let ring = ringRect() {
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
            ctx.strokeEllipse(in: ring)
            ctx.setLineWidth(0.75)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.55))
            ctx.strokeEllipse(in: ring)
            ctx.restoreGState()
        }
    }

    /// The brush-size ring around the pointer, in view coordinates.
    private func ringRect() -> CGRect? {
        guard let pointer, !spaceHeld, editor.tool.strokeTool != nil else { return nil }
        let r = editor.size(for: editor.tool) * zoom / 2
        guard r >= 3 else { return nil }
        return CGRect(x: pointer.x - r, y: pointer.y - r, width: r * 2, height: r * 2)
    }

    private func blit(_ image: CGImage, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: bounds)
        ctx.restoreGState()
    }

    // MARK: Snapshots

    private func currentSnapshot() -> Snapshot? {
        let scale = window?.backingScaleFactor ?? 2
        let key = SnapshotKey(zoom: zoom, pan: pan, size: bounds.size, scale: scale, revision: revision,
                              layer: editor.activeLayerID)
        if let snapshot, snapshot.key == key { return snapshot }
        snapshot = makeSnapshot(key: key)
        return snapshot
    }

    private func makeSnapshot(key: SnapshotKey) -> Snapshot? {
        let drawing = self.drawing
        guard let active = drawing.layerIndex(key.layer) else { return nil }
        let visible = toCanvas(bounds)

        func render(_ body: (CGContext) -> Void) -> CGImage? {
            guard let ctx = Renderer.bitmapContext(for: bounds, scale: key.scale) else { return nil }
            body(ctx)
            return ctx.makeImage()
        }

        let below = render { ctx in
            drawBackground(in: ctx, rect: bounds, drawing: drawing)
            applyViewport(ctx)
            renderer.draw(drawing, in: ctx, visible: visible, layers: 0..<active)
        }
        var activeLayer = drawing.layers[active]
        let opacity = CGFloat(activeLayer.opacity)
        activeLayer.opacity = 1
        let activeImage = activeLayer.items.isEmpty ? nil : render { ctx in
            applyViewport(ctx)
            renderer.drawLayer(activeLayer, in: ctx, visible: visible)
        }
        let aboveRange = (active + 1)..<drawing.layers.count
        let hasAbove = drawing.layers[aboveRange].contains { $0.isVisible && !$0.items.isEmpty }
        let above = hasAbove ? render { ctx in
            applyViewport(ctx)
            renderer.draw(drawing, in: ctx, visible: visible, layers: aboveRange)
        } : nil
        return Snapshot(key: key, below: below, active: activeImage, above: above, activeOpacity: opacity)
    }

    // MARK: Mouse

    private func location(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    override func mouseDown(with event: NSEvent) {
        let hadText = textSession != nil
        endTextEditing()
        window?.makeFirstResponder(self)
        if hadText && editor.tool == .text { return }

        let screen = location(event)
        let p = toCanvas(screen)
        pointer = screen

        if spaceHeld || editor.tool == .hand {
            interaction = .pan(last: screen)
            NSCursor.closedHand.set()
            return
        }

        let tolerance = 5 / zoom
        switch editor.tool {
        case .brush, .pencil, .marker, .eraser:
            beginStroke(at: p, screen: screen, event: event)
        case .shape:
            guard editor.prepareActiveLayerForDrawing() else { return }
            interaction = .shape(ShapeItem(kind: editor.shapeKind, start: p, end: p,
                                           color: editor.inkColor, width: editor.size(for: .shape)))
        case .text:
            if case .text(let existing)? = editor.item(at: p, tolerance: tolerance) {
                beginTextEditing(existing)
            } else if editor.prepareActiveLayerForDrawing() {
                beginTextEditing(nil, at: p)
            }
        case .select:
            let hit = editor.item(at: p, tolerance: tolerance)
            if event.clickCount == 2, case .text(let text)? = hit {
                beginTextEditing(text)
                return
            }
            if let hit {
                if event.modifierFlags.contains(.shift) {
                    if editor.selection.contains(hit.id) {
                        editor.selection.remove(hit.id)
                        return
                    }
                    editor.selection.insert(hit.id)
                } else if !editor.selection.contains(hit.id) {
                    editor.selection = [hit.id]
                }
                editor.beginGesture()
                interaction = .move(start: p)
            } else {
                let base = event.modifierFlags.contains(.shift) ? editor.selection : []
                editor.selection = base
                interaction = .marquee(start: p, current: p, base: base)
            }
        case .hand:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let screen = location(event)
        let p = toCanvas(screen)
        let oldRing = ringRect()
        pointer = screen
        if let oldRing { setNeedsDisplay(oldRing.insetBy(dx: -3, dy: -3)) }
        if let ring = ringRect() { setNeedsDisplay(ring.insetBy(dx: -3, dy: -3)) }

        switch interaction {
        case .idle:
            break
        case .pan(let last):
            setViewport(zoom: zoom, pan: CGPoint(x: pan.x + screen.x - last.x, y: pan.y + screen.y - last.y))
            interaction = .pan(last: screen)
        case .stroke(var live):
            continueStroke(&live, to: p, screen: screen, event: event)
            interaction = .stroke(live)
        case .shape(var shape):
            let before = toScreen(Geometry.bounds(of: .shape(shape)))
            shape.end = event.modifierFlags.contains(.shift)
                ? Geometry.constrained(p, from: shape.start, kind: shape.kind) : p
            interaction = .shape(shape)
            setNeedsDisplay(before.union(toScreen(Geometry.bounds(of: .shape(shape)))).insetBy(dx: -4, dy: -4))
        case .move(let start):
            editor.move(editor.selection, by: CGVector(dx: p.x - start.x, dy: p.y - start.y))
        case .marquee(let start, _, let base):
            let rect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(p.x - start.x), height: abs(p.y - start.y))
            interaction = .marquee(start: start, current: p, base: base)
            editor.selection = base.union(editor.items(in: rect))
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .stroke(var live):
            finishStroke(&live, at: toCanvas(location(event)))
            editor.add(.stroke(live.stroke))
        case .shape(let shape):
            if hypot(shape.end.x - shape.start.x, shape.end.y - shape.start.y) * zoom > 3 {
                editor.add(.shape(shape))
            }
        case .move:
            editor.endGesture("Move")
        case .pan:
            updateCursor()
        case .marquee, .idle:
            break
        }
        interaction = .idle
        snapshot = nil
        needsDisplay = true
    }

    // Middle button pans with any tool.
    override func otherMouseDown(with event: NSEvent) {
        interaction = .pan(last: location(event))
        NSCursor.closedHand.set()
    }
    override func otherMouseDragged(with event: NSEvent) { mouseDragged(with: event) }
    override func otherMouseUp(with event: NSEvent) { mouseUp(with: event) }

    override func mouseMoved(with event: NSEvent) { movePointer(to: location(event)) }
    override func mouseExited(with event: NSEvent) { movePointer(to: nil) }

    private func movePointer(to point: CGPoint?) {
        if let old = ringRect() { setNeedsDisplay(old.insetBy(dx: -3, dy: -3)) }
        pointer = point
        if let new = ringRect() { setNeedsDisplay(new.insetBy(dx: -3, dy: -3)) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: Strokes

    private func beginStroke(at p: CGPoint, screen: CGPoint, event: NSEvent) {
        guard let tool = editor.tool.strokeTool, editor.prepareActiveLayerForDrawing() else { return }
        let tablet = event.subtype == .tabletPoint
        let pressure: CGFloat = tablet ? max(CGFloat(event.pressure), 0.05) : 0.5
        let stroke = Stroke(tool: tool, color: tool == .eraser ? .ink : editor.inkColor,
                            width: editor.size(for: editor.tool),
                            points: [StrokePoint(x: p.x, y: p.y, pressure: pressure)])
        interaction = .stroke(LiveStroke(stroke: stroke, smoothed: p, lastScreen: screen,
                                         lastTime: event.timestamp, pressure: pressure, tablet: tablet))
        invalidateTail(of: stroke)
    }

    private func continueStroke(_ live: inout LiveStroke, to p: CGPoint, screen: CGPoint, event: NSEvent) {
        let screenDistance = hypot(screen.x - live.lastScreen.x, screen.y - live.lastScreen.y)
        guard screenDistance >= 0.75 else { return }

        if live.tablet || event.subtype == .tabletPoint {
            live.tablet = true
            live.pressure = max(CGFloat(event.pressure), 0.05)
        } else {
            // Mouse and trackpad: faster movement draws a thinner line, like a real brush.
            let dt = max(event.timestamp - live.lastTime, 1.0 / 240)
            let speed = screenDistance / CGFloat(dt)
            let target = min(max(1.15 - speed / 2400, 0.4), 1)
            live.pressure += (target - live.pressure) * 0.22
        }
        // Light input smoothing takes the jitter out of mouse and trackpad lines.
        let follow: CGFloat = live.stroke.tool == .pencil ? 0.7 : 0.5
        live.smoothed = CGPoint(x: live.smoothed.x + (p.x - live.smoothed.x) * follow,
                                y: live.smoothed.y + (p.y - live.smoothed.y) * follow)
        live.stroke.points.append(StrokePoint(x: live.smoothed.x, y: live.smoothed.y, pressure: live.pressure))
        live.lastScreen = screen
        live.lastTime = event.timestamp
        invalidateTail(of: live.stroke)
    }

    private func finishStroke(_ live: inout LiveStroke, at p: CGPoint) {
        var points = live.stroke.points
        if let last = points.last, hypot(p.x - last.x, p.y - last.y) * zoom > 0.75 {
            points.append(StrokePoint(x: p.x, y: p.y, pressure: live.pressure))
        }
        // Without a pen, taper the end of brush strokes the way the start tapers in.
        if live.stroke.tool == .brush, !live.tablet, points.count > 4 {
            let n = min(8, points.count / 3)
            for k in 0..<n {
                let i = points.count - n + k
                points[i].pressure *= 1 - CGFloat(k + 1) / CGFloat(n + 1) * 0.8
            }
        }
        live.stroke.points = points
    }

    /// Redraws only around the newest points of a stroke being drawn.
    private func invalidateTail(of stroke: Stroke) {
        let tail = Array(stroke.points.suffix(5))
        guard let first = tail.first else { return }
        var rect = CGRect(origin: first.point, size: .zero)
        for p in tail { rect = rect.union(CGRect(origin: p.point, size: .zero)) }
        let pad = stroke.width / 2 + 2
        setNeedsDisplay(toScreen(rect.insetBy(dx: -pad, dy: -pad)).insetBy(dx: -3, dy: -3))
    }

    // MARK: Scroll and zoom

    override func scrollWheel(with event: NSEvent) {
        endTextEditing()
        let at = location(event)
        if event.modifierFlags.contains(.command) || !event.hasPreciseScrollingDeltas {
            // Mouse wheel, or ⌘-scroll on a trackpad, zooms around the pointer.
            let step = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.1
            zoom(by: exp(step), around: at)
        } else {
            setViewport(zoom: zoom, pan: CGPoint(x: pan.x + event.scrollingDeltaX, y: pan.y + event.scrollingDeltaY))
        }
    }

    override func magnify(with event: NSEvent) {
        zoom(by: 1 + event.magnification, around: location(event))
    }

    override func smartMagnify(with event: NSEvent) {
        if abs(zoom - 1) < 0.01 { zoomToFit() } else { zoom(by: 1 / zoom, around: location(event)) }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.intersection([.command, .control, .option]).isEmpty else {
            super.keyDown(with: event)
            return
        }
        let step: CGFloat = flags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 49: // space: hold to pan
            if !spaceHeld {
                spaceHeld = true
                updateCursor()
                needsDisplay = true
            }
            return
        case 51, 117: editor.deleteSelection(); return
        case 53: editor.selection = []; return
        case 123: editor.nudgeSelection(by: CGVector(dx: -step / zoom, dy: 0)); return
        case 124: editor.nudgeSelection(by: CGVector(dx: step / zoom, dy: 0)); return
        case 125: editor.nudgeSelection(by: CGVector(dx: 0, dy: step / zoom)); return
        case 126: editor.nudgeSelection(by: CGVector(dx: 0, dy: -step / zoom)); return
        default: break
        }
        if event.characters == "?" {
            editor.showShortcuts = true
            return
        }
        switch event.charactersIgnoringModifiers?.lowercased() ?? "" {
        case "v": editor.tool = .select
        case "h": editor.tool = .hand
        case "b": editor.tool = .brush
        case "p": editor.tool = .pencil
        case "m": editor.tool = .marker
        case "e": editor.tool = .eraser
        case "t": editor.tool = .text
        case "l": editor.select(shape: .line)
        case "a": editor.select(shape: .arrow)
        case "r": editor.select(shape: .rectangle)
        case "o": editor.select(shape: .ellipse)
        case "[": editor.stepSize(-1)
        case "]": editor.stepSize(1)
        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
            editor.opacity = Double(event.charactersIgnoringModifiers!)! / 10
        case "0": editor.opacity = 1
        default: super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceHeld = false
            updateCursor()
            needsDisplay = true
        } else {
            super.keyUp(with: event)
        }
    }

    override func resignFirstResponder() -> Bool {
        spaceHeld = false
        return super.resignFirstResponder()
    }

    // MARK: Cursor

    private var cursor: NSCursor {
        if spaceHeld || editor.tool == .hand { return .openHand }
        switch editor.tool {
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    private func updateCursor() {
        window?.invalidateCursorRects(for: self)
        if let window, bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)) {
            cursor.set()
        }
    }

    // MARK: Edit menu

    @objc func copy(_ sender: Any?) { editor.copySelection() }
    @objc func cut(_ sender: Any?) { editor.cutSelection() }
    @objc func paste(_ sender: Any?) { editor.paste() }
    @objc func delete(_ sender: Any?) { editor.deleteSelection() }
    override func selectAll(_ sender: Any?) { editor.selectAll() }

    // MARK: Text

    private final class TextSession {
        let view: NSTextView
        let existing: TextItem?
        let template: TextItem
        let undo = UndoManager()
        init(view: NSTextView, existing: TextItem?, template: TextItem) {
            self.view = view; self.existing = existing; self.template = template
        }
    }

    private func beginTextEditing(_ existing: TextItem?, at point: CGPoint = .zero) {
        endTextEditing()
        let item = existing ?? TextItem(text: "", origin: point, fontSize: editor.size(for: .text), color: editor.inkColor)
        let font = Geometry.font(size: item.fontSize * zoom)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let view = NSTextView(frame: CGRect(origin: toScreen(item.origin), size: CGSize(width: 8, height: lineHeight)))
        view.isRichText = false
        view.importsGraphics = false
        view.drawsBackground = false
        view.font = font
        let color = NSColor(srgbRed: item.color.r, green: item.color.g, blue: item.color.b, alpha: item.color.a)
        view.textColor = color
        view.insertionPointColor = color.withAlphaComponent(1)
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.isHorizontallyResizable = true
        view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        view.minSize = CGSize(width: 8, height: lineHeight)
        view.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.allowsUndo = true
        view.string = item.text
        view.delegate = self
        addSubview(view)
        view.sizeToFit()
        window?.makeFirstResponder(view)
        view.setSelectedRange(NSRange(location: (item.text as NSString).length, length: 0))
        textSession = TextSession(view: view, existing: existing, template: item)
        needsDisplay = true
    }

    func endTextEditing() {
        guard let session = textSession else { return }
        textSession = nil
        session.view.delegate = nil
        if window?.firstResponder === session.view { window?.makeFirstResponder(self) }
        session.view.removeFromSuperview()

        let text = session.view.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = session.existing {
            if text.isEmpty {
                editor.remove([existing.id], actionName: "Delete Text")
            } else if text != existing.text {
                var updated = existing
                updated.text = text
                editor.replace(.text(updated), actionName: "Edit Text")
            }
        } else if !text.isEmpty {
            var item = session.template
            item.text = text
            editor.add(.text(item))
        }
        needsDisplay = true
    }
}

extension CanvasView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            // Return finishes; Shift-Return or Option-Return starts a new line.
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                textView.insertNewlineIgnoringFieldEditor(nil)
            } else {
                endTextEditing()
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endTextEditing()
            return true
        default:
            return false
        }
    }

    func textDidEndEditing(_ notification: Notification) {
        endTextEditing()
    }

    func undoManager(for view: NSTextView) -> UndoManager? {
        textSession?.undo
    }
}

extension CanvasView: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)), #selector(cut(_:)), #selector(delete(_:)):
            return !editor.selection.isEmpty
        case #selector(paste(_:)):
            return editor.canPaste
        case #selector(selectAll(_:)):
            return !drawing.isEmpty
        default:
            return true
        }
    }
}
