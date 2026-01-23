# Inkflow User Guide

Welcome to **Inkflow**, a modern, lightweight paint application for macOS designed for smooth drawing, quick sketching, and efficient workflows.

## Table of Contents
1. [Getting Started](#getting-started)
2. [Tools & Toolbar](#tools--toolbar)
3. [Canvas Navigation](#canvas-navigation)
4. [Working with Objects](#working-with-objects)
5. [Keyboard Shortcuts](#keyboard-shortcuts)
6. [Advanced Features](#advanced-features)

---

## Getting Started

### Launching the App
Open `Inkflow.app` from your Applications folder (or build folder). The app launches instantly with a blank infinite canvas ready for drawing.

### The Interface
Inkflow follows a "One UI" inspired design usage:
- **Main Canvas**: The infinite space where you draw.
- **Floating Toolbar**: Located at the bottom center for easy access to tools.
- **Top Menu Bar**: Standard macOS menu integration for file operations and view controls.

---

## Tools & Toolbar

The toolbar provides quick access to essential creative tools. You can also use keyboard keys (see Shortcuts).

### 🖊️ Brush Tool (B)
A pressure-sensitive tool designed for sketching and painting.
- **Best for**: Artistic work, shading, and variable-width strokes.
- **Settings**: Adjust size (1-100px) and opacity using the sliders.

### ✏️ Pencil Tool (P)
A precise, non-anti-aliased tool (pixel-perfect appearance).
- **Best for**: Diagrams, writing notes, and line art.
- **Behavior**: Constant width regardless of pressure.

### 📄 Text Tool (T)
Add text annotations directly to your canvas.
1. Select the Text tool (or press `T`).
2. Click anywhere on the canvas to place a cursor.
3. Type your text and press **Enter** to finalize.

### 🧹 Eraser Tool (E)
Removes content from the canvas.
- **Behavior**: Works as a true eraser, making pixels transparent again.

### 🎨 Color Picker
Click the colored circle in the toolbar to open the system Color Picker.
- Choose from wheel, sliders, or standard palettes.
- Supports opacity (alpha) control.

---

## Canvas Navigation

Inkflow supports standard macOS multi-touch gestures and shortcuts.

- **Zoom**: Pinch on trackpad or use `Cmd +` / `Cmd -`.
- **Pan**: Hold `Space` or `Option` and drag with the mouse/trackpad.
- **Reset View**: Press `Cmd + 0` to fit content or reset zoom to 100%.

---

## Working with Objects

Inkflow treats strokes and text as objects (vectors) in its internal engine, allowing for powerful manipulation.

### Selection & Move
1. **Select**: Currently, previous strokes are part of the bitmap layer, but Text objects can be selected.
   - *Note: In the latest update, click on a text element or shape to select it.*
2. **Move**: When an object is selected (blue dashed box appears), drag it to move it around the canvas.
3. **Delete**: Select an object and press `Delete` or `Backspace` to remove it.

---

## Keyboard Shortcuts

Maximize your productivity with these dedicated hotkeys:

| Category | Action | Shortcut |
|----------|--------|----------|
| **Tools** | Brush | `B` |
| | Pencil | `P` |
| | Eraser | `E` |
| | Text | `T` |
| **Properties** | Increase Size | `]` |
| | Decrease Size | `[` |
| **View** | Zoom In | `Cmd +` |
| | Zoom Out | `Cmd -` |
| | Reset Zoom | `Cmd 0` |
| **Edit** | Undo | `Cmd Z` |
| | Redo | `Cmd Shift Z` |
| | Clear Canvas | `Cmd Delete` |

---

## Advanced Features

### Touch Bar Support
If you have a MacBook with a Touch Bar, Inkflow provides context-aware controls right at your fingertips:
- Switch tools instantly.
- Adjust colors.
- Undo/Redo operations.

### Quick Look
Inkflow saves files in a custom `.inkflow` package format.
- Select a file in Finder and press `Space` to see a high-resolution preview of your artwork without opening the app.

---

**Happy Creating!**
For support, please visit the [GitHub Repository](https://github.com/pronzzz/inkflow).
