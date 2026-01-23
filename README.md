# Inkflow

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-Stable-success?style=flat-square)

**A modern, lightweight paint application for macOS with One UI 8-inspired design philosophy.**

Inkflow combines the simplicity of Preview with the smoothness of professional tools, tailored for sketching, note-taking, and diagrams.

> **Current Version**: v1.0 (Gold)
> **Latest Update**: Text Tools, Selection, and Retina Support Added.

---

## Overview

Inkflow is a paint application that sits between **Preview** (too basic) and **GIMP/Krita** (overkill). It focuses on:

- 🎨 **Pleasant drawing experience** with smooth, natural brushes and Catmull-Rom splines.
- ⚡ **Fast performance** with 60fps+ rendering on Core Graphics.
- 🎯 **Keyboard-friendly** workflow with comprehensive shortcuts.
- 🌗 **Dark mode first** design aesthetic.
- 🖱️ **Trackpad & Apple Pencil** optimized with pressure sensitivity.

Built with **SwiftUI** and **Core Graphics** for native macOS performance.

---

## Features

### 🖌️ Drawing Tools
- **Brush**: Soft-edged brush with pressure sensitivity for natural strokes.
- **Pencil**: Hard-edged, precise tool for diagrams and writing.
- **Eraser**: Clean removal with proper transparency blending.
- **Text Tool**: Native text insertion with customizable fonts and placement.

### 🛠️ Controls & Interaction
- **Brush Size**: Adjustable 1-100px.
- **Opacity**: 10-100% transparency control.
- **Color Picker**: Full system color picker integration.
- **Selection**: Select, move, and transform objects (Text & Shapes) with visual bounding boxes.

### 🚀 Workflow
- **Infinite Canvas**: Zoom (`Cmd +/-`) and Pan (`Space+Drag`) freely.
- **Undo/Redo**: Robust command history with `Cmd+Z` support.
- **Touch Bar**: Context-aware controls for MacBook Pro users.
- **Quick Look**: Preview `.inkflow` files directly in Finder.

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Brush tool | `B` |
| Pencil tool | `P` |
| Eraser tool | `E` |
| Text tool | `T` |
| Increase brush size | `]` |
| Decrease brush size | `[` |
| Zoom in | `Cmd +` |
| Zoom out | `Cmd -` |
| Reset zoom | `Cmd 0` |
| Undo | `Cmd Z` |
| Redo | `Cmd Shift Z` |
| Clear canvas | `Cmd Delete` |

---

## Installation & Building

### Requirements
- macOS Sonoma 14.0+
- Xcode 15.0+ (for building)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/pronzzz/inkflow.git
cd inkflow

# Open in Xcode
open Inkflow.xcodeproj

# Or build via command line
xcodebuild -scheme Inkflow -configuration Debug
```

---

## Architecture

**MVVM** architecture with clear separation:

```
Inkflow/
├── Views/           # SwiftUI views
├── ViewModels/      # Business logic & state
├── Models/          # Data structures (Stroke, CanvasElement)
├── Engine/          # Brush smoothing & geometry
├── Rendering/       # Core Graphics rendering & CoreText
├── Input/           # Gesture handling
└── Utils/           # Extensions & helpers
```

### Key Technologies
- **SwiftUI**: Modern declarative UI.
- **Core Graphics**: High-performance 2D rendering.
- **Core Text**: Advanced text layout and rendering.
- **File Wrappers**: Document-based app architecture with `.inkflow` package support.

---

## Contributing

Contributions, feedback, and feature requests are welcome! Please feel free to open an issue or submit a pull request.

---

## License

[MIT License](LICENSE) - Copyright © 2026 Pranav Dwivedi

---

**Made with ❤️ for digital artists and creative professionals**
