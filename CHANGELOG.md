# Changelog

All notable changes to Inkflow are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-11-03

Inkflow 2 is a ground-up rewrite. The canvas is now a native AppKit view with a much faster renderer, the interface is a single quiet tool bar, and the features 1.0 advertised but did not have (saving, export, Quick Look, an infinite canvas, single-key shortcuts) now work.

### Highlights

- **Your work is saved.** 1.0 only marked a document as changed when you changed the background colour, so drawings were often never saved. Every change now goes through undo, so the title bar shows *Edited*, autosave works, and closing an unsaved drawing asks before discarding it.
- **Infinite canvas.** Scroll with two fingers to pan, pinch or ⌘-scroll to zoom (10%–1600%) around the pointer, hold Space or use the middle mouse button to drag. Double-tap with two fingers toggles between fit and 100%.
- **Real pressure.** Pen tablets (Wacom, Sidecar with Apple Pencil, and others) now drive the brush width. With a mouse or trackpad, stroke speed thins the line and both ends taper, so it still looks like ink.
- **Export.** PNG (2×) and vector PDF of the whole drawing (⇧⌘E, ⌥⇧⌘E), and Copy as Image (⇧⌘C) for pasting into other apps.
- **Quick Look and Finder thumbnails.** Every `.inkflow` file carries a PDF preview and a thumbnail.
- **Single-key tools.** V select, B brush, P pencil, M highlighter, E eraser, L line, A arrow, R rectangle, O ellipse, T text, H or Space for the hand. `[` and `]` change size, 1–0 set opacity, ? shows every shortcut.

### Drawing

- New **Highlighter**: wide, translucent ink that tints what is underneath without hiding it (it multiplies on light paper and screens on dark paper).
- **Brush** strokes are smoothed with Catmull-Rom curves and filled as one outline, so translucent strokes no longer show darker beads where segments overlap.
- **Pencil** is a crisp, constant-width line.
- **Eraser** erases only the layer it is used on, and each layer can be erased independently.
- **Shapes**: line, arrow, rectangle and ellipse. Hold Shift for 45° lines, squares and circles.
- **Text**: click to type, Return to finish, Shift-Return for a new line. Double-click text with the select tool, or click it with the text tool, to edit it.
- A brush-size ring follows the pointer.

### Editing

- Select by clicking or dragging a marquee; Shift adds to the selection. Drag to move, arrow keys nudge (Shift for 10 points), Delete removes.
- Cut, copy, paste and duplicate (⌘D) items, within a drawing or between drawings.
- Undo and redo for everything, including moves, layer changes and background changes. A whole drag is one undo step.

### Layers

- Add, delete, rename (double-click), reorder, hide, lock and set opacity per layer, from a small floating panel (⌥⌘L).
- Drawing on a hidden layer shows it again; drawing on a locked layer is refused with a beep instead of silently failing.

### Interface

- One floating tool bar: tools, seven colours plus the system colour panel, and a size and opacity popover.
- Follows the system light or dark appearance (1.0 was always dark). The canvas itself can be White, Paper, Grey or Dark from **Canvas → Background**.
- Optional dot grid (⌘'), zoom indicator, and a blank canvas at launch instead of the Open panel.
- New app icon.

### Performance

- The canvas is an AppKit view. While you draw, the layers below and above are cached as bitmaps once and only the few pixels around the newest point are redrawn. 1.0 re-rendered the entire canvas into a new bitmap on every mouse movement, on a background thread.
- Stroke outlines are built once and reused, including while items are being moved.
- Files are about a fifth of the size: points are stored as one flat number array instead of one JSON object per point with a timestamp.
- The code is smaller (about 3,200 lines of Swift, down from about 4,000) and has 20 unit tests covering the file format, 1.0 file import, geometry, hit testing and undo.

### Compatibility

- Documents from Inkflow 1.0 open in 2.0 and are converted when saved. Inkflow 1.0 cannot open documents saved by 2.0.
- Universal app for Apple silicon and Intel Macs. macOS 14 Sonoma or later.

### Removed

- Touch Bar controls.
- The 1.0 custom colour picker (replaced by swatches and the system colour panel).
- Movable tool bar positions.

### Install

Download **Inkflow-2.0.0.dmg** below, open it and drag Inkflow into Applications.

Inkflow is ad-hoc signed and not notarized, so the first time you open it macOS asks you to confirm: open **System Settings → Privacy & Security** and click **Open Anyway**.

## [1.0.0] - 2026-01-24

First release: brush, pencil, eraser and text tools, layers, undo, and the `.inkflow` document format.
