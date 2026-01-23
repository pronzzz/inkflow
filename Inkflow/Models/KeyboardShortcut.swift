//
//  KeyboardShortcut.swift
//  Inkflow
//
//  Data model for keyboard shortcuts and hints
//

import SwiftUI

/// Represents a keyboard shortcut with metadata
struct KeyboardShortcutInfo: Identifiable {
    let id = UUID()
    let key: String
    let modifiers: EventModifiers
    let action: String
    let category: Category
    
    enum Category: String, CaseIterable {
        case tools = "Tools"
        case drawing = "Drawing"
        case view = "View"
        case edit = "Edit"
        case file = "File"
    }
    
    /// Display string for the shortcut
    var displayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        
        parts.append(key.uppercased())
        return parts.joined()
    }
}

/// Collection of all keyboard shortcuts in Inkflow
struct InkflowShortcuts {
    
    static let all: [KeyboardShortcutInfo] = [
        // Tools
        .init(key: "b", modifiers: .command, action: "Brush Tool", category: .tools),
        .init(key: "p", modifiers:.command, action: "Pencil Tool", category: .tools),
        .init(key: "e", modifiers: .command, action: "Eraser Tool", category: .tools),
        
        // Drawing
        .init(key: "]", modifiers: .command, action: "Increase Brush Size", category: .drawing),
        .init(key: "[", modifiers: .command, action: "Decrease Brush Size", category: .drawing),
        
        // View
        .init(key: "+", modifiers: .command, action: "Zoom In", category: .view),
        .init(key: "-", modifiers: .command, action: "Zoom Out", category: .view),
        .init(key: "0", modifiers: .command, action: "Reset Zoom", category: .view),
        
        // Edit
        .init(key: "z", modifiers: .command, action: "Undo", category: .edit),
        .init(key: "z", modifiers: [.command, .shift], action: "Redo", category: .edit),
        .init(key: "⌫", modifiers: .command, action: "Clear Canvas", category: .edit),
    ]
    
    /// Get shortcuts by category
    static func shortcuts(for category: KeyboardShortcutInfo.Category) -> [KeyboardShortcutInfo] {
        all.filter { $0.category == category }
    }
    
    /// Find shortcut for a specific action
    static func shortcut(for action: String) -> KeyboardShortcutInfo? {
        all.first { $0.action == action }
    }
}
