import XCTest
@testable import Inkflow

final class FormatTests: XCTestCase {
    private func sampleDrawing() -> Drawing {
        var layer = DrawingLayer(name: "Ink")
        layer.items = [
            .stroke(Stroke(tool: .brush, color: RGBA(hex: "#2F6FEB"), width: 6, points: [
                StrokePoint(x: 10, y: 10, pressure: 0.5), StrokePoint(x: 40.25, y: 12.5, pressure: 0.9),
                StrokePoint(x: 80, y: 30, pressure: 0.7),
            ])),
            .shape(ShapeItem(kind: .arrow, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 50), color: .ink, width: 2)),
            .text(TextItem(text: "Hello\nworld", origin: CGPoint(x: 5, y: 60), fontSize: 24, color: RGBA(hex: "#FF000080"))),
        ]
        layer.opacity = 0.8
        var hidden = DrawingLayer(name: "Hidden")
        hidden.isVisible = false
        hidden.isLocked = true
        return Drawing(background: .paper, layers: [layer, hidden])
    }

    func testRoundTrip() throws {
        let drawing = sampleDrawing()
        let data = try JSONEncoder().encode(drawing)
        XCTAssertEqual(try DocumentCodec.decode(data), drawing)
    }

    func testPackageRoundTrip() throws {
        let drawing = sampleDrawing()
        let wrapper = try DocumentCodec.write(drawing)
        XCTAssertNotNil(wrapper.fileWrappers?["drawing.json"])
        XCTAssertNotNil(wrapper.fileWrappers?["QuickLook"]?.fileWrappers?["Thumbnail.png"])
        XCTAssertNotNil(wrapper.fileWrappers?["QuickLook"]?.fileWrappers?["Preview.pdf"])
        XCTAssertEqual(try DocumentCodec.read(wrapper), drawing)
    }

    func testPointsAreCompact() throws {
        let stroke = Stroke(tool: .pencil, color: .ink, width: 2,
                            points: [StrokePoint(x: 1.23456, y: 2.34567, pressure: 0.123456)])
        let json = String(data: try JSONEncoder().encode(stroke), encoding: .utf8)!
        XCTAssertTrue(json.contains("[1.23,2.35,0.123]"), json)
    }

    func testColorHex() {
        XCTAssertEqual(RGBA(hex: "#FF8000").hex, "#FF8000FF")
        XCTAssertEqual(RGBA(hex: "#FF800080").a, 128.0 / 255, accuracy: 0.001)
        XCTAssertEqual(RGBA(hex: "F00").r, 1)
        XCTAssertEqual(RGBA(hex: "nonsense").hex, "#000000FF")
    }

    func testNewerFormatIsRejected() {
        let data = Data(#"{"version": 99, "layers": []}"#.utf8)
        XCTAssertThrowsError(try DocumentCodec.decode(data))
    }

    /// A document as saved by Inkflow 1.0.
    func testReadsVersionOneDocuments() throws {
        let json = """
        {"version":2,"id":"0A6A4E6A-29C4-4D49-9C57-6A9B1E2C5F10","createdAt":780000000,"modifiedAt":780000000,
         "width":1920,"height":1080,"backgroundColorHex":"#F0F0F0",
         "layers":[{"id":"8B1D2D0E-1B5C-4F32-9F6F-1C2D3E4F5A6B","name":"Layer 1","isVisible":true,"isLocked":false,"opacity":1,
           "elements":[
             {"id":"11111111-1111-1111-1111-111111111111","type":"stroke","isVisible":true,"isLocked":false,
              "stroke":{"id":"11111111-1111-1111-1111-111111111111","tool":"brush","colorHex":"#FF0000","size":12,"opacity":0.5,
                "points":[{"x":1,"y":2,"pressure":1,"timestamp":1},{"x":3,"y":4,"pressure":0.5,"timestamp":2}]}},
             {"id":"22222222-2222-2222-2222-222222222222","type":"shape","isVisible":true,"isLocked":false,
              "shape":{"id":"22222222-2222-2222-2222-222222222222","type":"circle","rect":[[10,20],[30,40]],
                "strokeColorHex":"#0000FF","fillColorHex":"#000000","strokeWidth":3,"isFilled":false,"rotation":0}},
             {"id":"33333333-3333-3333-3333-333333333333","type":"text","isVisible":true,"isLocked":false,
              "text":{"id":"33333333-3333-3333-3333-333333333333","content":"Hi","position":[5,6],"fontName":"Helvetica",
                "fontSize":18,"colorHex":"#000000","rotation":0}}
           ]}]}
        """
        let drawing = try DocumentCodec.decode(Data(json.utf8))
        XCTAssertEqual(drawing.background.hex, "#F0F0F0FF")
        XCTAssertEqual(drawing.layers.count, 1)
        let items = drawing.layers[0].items
        XCTAssertEqual(items.count, 3)
        guard case .stroke(let stroke) = items[0], case .shape(let shape) = items[1], case .text(let text) = items[2] else {
            return XCTFail("wrong item types")
        }
        XCTAssertEqual(stroke.tool, .brush)
        XCTAssertEqual(stroke.color.a, 0.5, accuracy: 0.001)
        XCTAssertEqual(stroke.points.count, 2)
        XCTAssertEqual(shape.kind, .ellipse)
        XCTAssertEqual(shape.rect, CGRect(x: 10, y: 20, width: 30, height: 40))
        XCTAssertEqual(text.text, "Hi")
        XCTAssertEqual(text.origin, CGPoint(x: 5, y: 6))
    }

    func testReadsFlatLegacyStrokes() throws {
        let json = ##"{"version":1,"backgroundColorHex":"#FFFFFF","layers":[],"strokes":[{"tool":"pencil","colorHex":"#000000","size":2,"opacity":1,"points":[{"x":0,"y":0,"pressure":1},{"x":5,"y":5,"pressure":1}]}]}"##
        let drawing = try DocumentCodec.decode(Data(json.utf8))
        XCTAssertEqual(drawing.itemCount, 1)
    }
}

final class GeometryTests: XCTestCase {
    func testBrushOutlineCoversItsPoints() {
        let points = (0...40).map { i -> StrokePoint in
            let t = CGFloat(i) / 40
            return StrokePoint(x: t * 200, y: sin(t * 6) * 40, pressure: 0.8)
        }
        let stroke = Stroke(tool: .brush, color: .ink, width: 10, points: points)
        let shape = Geometry.shape(for: stroke)
        XCTAssertEqual(shape.mode, .fill)
        for p in points {
            XCTAssertTrue(shape.path.contains(p.point, using: .winding), "\(p)")
        }
        XCTAssertFalse(shape.path.contains(CGPoint(x: 100, y: 200), using: .winding))
    }

    func testSharpCornerHasNoHoles() {
        // A hairpin: the joint is covered by both a disc and two quads.
        let stroke = Stroke(tool: .brush, color: .ink, width: 20, points: [
            StrokePoint(x: 0, y: 0), StrokePoint(x: 100, y: 0), StrokePoint(x: 0, y: 4),
        ])
        let shape = Geometry.shape(for: stroke)
        for x in stride(from: 0.0, through: 100.0, by: 5) {
            XCTAssertTrue(shape.path.contains(CGPoint(x: x, y: 1), using: .winding), "hole at \(x)")
        }
    }

    func testTapMakesADot() {
        let stroke = Stroke(tool: .pencil, color: .ink, width: 8, points: [StrokePoint(x: 5, y: 5)])
        XCTAssertTrue(Geometry.shape(for: stroke).path.contains(CGPoint(x: 7, y: 5)))
    }

    func testHitTesting() {
        let line = CanvasItem.stroke(Stroke(tool: .pencil, color: .ink, width: 4,
                                            points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 100, y: 0)]))
        XCTAssertTrue(Geometry.hitTest(line, at: CGPoint(x: 50, y: 3), tolerance: 2))
        XCTAssertFalse(Geometry.hitTest(line, at: CGPoint(x: 50, y: 10), tolerance: 2))

        let rect = CanvasItem.shape(ShapeItem(kind: .rectangle, start: .zero, end: CGPoint(x: 100, y: 100), color: .ink, width: 2))
        XCTAssertTrue(Geometry.hitTest(rect, at: CGPoint(x: 0, y: 50), tolerance: 3))
        XCTAssertFalse(Geometry.hitTest(rect, at: CGPoint(x: 50, y: 50), tolerance: 3), "unfilled shapes are hit on the outline")

        let eraser = CanvasItem.stroke(Stroke(tool: .eraser, color: .ink, width: 20,
                                              points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 100, y: 0)]))
        XCTAssertFalse(Geometry.hitTest(eraser, at: CGPoint(x: 50, y: 0), tolerance: 2), "eraser marks are not selectable")
    }

    func testConstrainedShapes() {
        let square = Geometry.constrained(CGPoint(x: 30, y: -10), from: .zero, kind: .rectangle)
        XCTAssertEqual(square, CGPoint(x: 30, y: -30))
        let line = Geometry.constrained(CGPoint(x: 100, y: 8), from: .zero, kind: .line)
        XCTAssertEqual(line.y, 0, accuracy: 0.001)
    }

    func testPathCacheFollowsMoves() {
        let cache = PathCache()
        let stroke = Stroke(tool: .brush, color: .ink, width: 6,
                            points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 50, y: 20), StrokePoint(x: 90, y: 0)])
        let first = cache.shape(for: stroke)
        XCTAssertEqual(first.offset, .zero)
        guard case .stroke(let moved) = CanvasItem.stroke(stroke).translated(by: CGVector(dx: 10, dy: 5)) else { return XCTFail() }
        let second = cache.shape(for: moved)
        XCTAssertTrue(second.shape.path === first.shape.path, "moving reuses the cached path")
        XCTAssertEqual(second.offset, CGVector(dx: 10, dy: 5))
    }

    func testContentBoundsAndExport() throws {
        var drawing = Drawing()
        XCTAssertNil(Renderer.contentBounds(of: drawing))
        drawing.layers[0].items = [.shape(ShapeItem(kind: .rectangle, start: CGPoint(x: 100, y: 100),
                                                     end: CGPoint(x: 200, y: 150), color: .ink, width: 2))]
        let rect = try XCTUnwrap(Renderer.contentBounds(of: drawing, margin: 10))
        XCTAssertTrue(rect.contains(CGRect(x: 100, y: 100, width: 100, height: 50)))
        let image = try XCTUnwrap(Renderer.image(of: drawing, rect: rect, scale: 2))
        XCTAssertEqual(image.width, Int(rect.width * 2))
        XCTAssertNotNil(Renderer.pdf(of: drawing, rect: rect))
    }
}

@MainActor
final class EditorTests: XCTestCase {
    private func makeEditor() -> (Editor, UndoManager) {
        let editor = Editor(document: InkflowDocument(drawing: Drawing()))
        let undo = UndoManager()
        undo.groupsByEvent = false
        editor.undoManager = undo
        return (editor, undo)
    }

    private func dot(_ x: CGFloat) -> CanvasItem {
        .stroke(Stroke(tool: .pencil, color: .ink, width: 4, points: [StrokePoint(x: x, y: 0), StrokePoint(x: x + 10, y: 0)]))
    }

    private func step(_ undo: UndoManager, _ body: () -> Void) {
        undo.beginUndoGrouping()
        body()
        undo.endUndoGrouping()
    }

    func testAddUndoRedo() {
        let (editor, undo) = makeEditor()
        step(undo) { editor.add(dot(0)) }
        step(undo) { editor.add(dot(20)) }
        XCTAssertEqual(editor.drawing.itemCount, 2)
        undo.undo()
        XCTAssertEqual(editor.drawing.itemCount, 1)
        undo.redo()
        XCTAssertEqual(editor.drawing.itemCount, 2)
    }

    func testMoveIsOneUndoStep() {
        let (editor, undo) = makeEditor()
        let item = dot(0)
        step(undo) { editor.add(item) }
        editor.selection = [item.id]
        step(undo) {
            editor.beginGesture()
            for i in 1...10 { editor.move(editor.selection, by: CGVector(dx: CGFloat(i), dy: 0)) }
            editor.endGesture("Move")
        }
        guard case .stroke(let moved)? = editor.drawing.item(item.id) else { return XCTFail() }
        XCTAssertEqual(moved.points[0].x, 10)
        undo.undo()
        guard case .stroke(let back)? = editor.drawing.item(item.id) else { return XCTFail() }
        XCTAssertEqual(back.points[0].x, 0)
    }

    func testLockedLayersRefuseNewMarks() {
        let (editor, undo) = makeEditor()
        step(undo) { editor.toggleLock(editor.activeLayerID) }
        XCTAssertFalse(editor.prepareActiveLayerForDrawing())
    }

    func testDeleteLayerKeepsOne() {
        let (editor, undo) = makeEditor()
        step(undo) { editor.addLayer() }
        XCTAssertEqual(editor.drawing.layers.count, 2)
        let second = editor.activeLayerID
        step(undo) { editor.deleteLayer(second) }
        XCTAssertEqual(editor.drawing.layers.count, 1)
        XCTAssertNotEqual(editor.activeLayerID, second)
        editor.deleteLayer(editor.activeLayerID)
        XCTAssertEqual(editor.drawing.layers.count, 1)
    }

    func testDuplicateAndDelete() {
        let (editor, undo) = makeEditor()
        let item = dot(0)
        step(undo) { editor.add(item) }
        editor.selection = [item.id]
        step(undo) { editor.duplicateSelection() }
        XCTAssertEqual(editor.drawing.itemCount, 2)
        XCTAssertFalse(editor.selection.contains(item.id))
        step(undo) { editor.deleteSelection() }
        XCTAssertEqual(editor.drawing.itemCount, 1)
        XCTAssertTrue(editor.selection.isEmpty)
    }

    func testUndoClearsStaleSelection() {
        let (editor, undo) = makeEditor()
        let item = dot(0)
        step(undo) { editor.add(item) }
        editor.selection = [item.id]
        undo.undo()
        XCTAssertTrue(editor.selection.isEmpty)
    }
}
