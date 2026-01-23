//
//  InkflowApp.swift
//  Inkflow
//
//  Application entry point with document-based architecture
//

import SwiftUI

@main
struct InkflowApp: App {
    
    // MARK: - Scene
    
    var body: some Scene {
        DocumentGroup(newDocument: InkflowDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            InkflowCommands()
        }
    }
}

// MARK: - Commands

struct InkflowCommands: Commands {
    @FocusedValue(\.canvasViewModel) var canvasViewModel
    
    var body: some Commands {
        // Standard commands
        SidebarCommands()
        ToolbarCommands()
        
        // Custom drawing commands
        CommandMenu("Tools") {
            Button("Brush") {
                canvasViewModel?.selectTool(.brush)
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(canvasViewModel == nil)
            
            Button("Pencil") {
                canvasViewModel?.selectTool(.pencil)
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(canvasViewModel == nil)
            
            Button("Eraser") {
                canvasViewModel?.selectTool(.eraser)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(canvasViewModel == nil)
            
            Divider()
            
            Button("Increase Size") {
                canvasViewModel?.increaseBrushSize()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(canvasViewModel == nil)
            
            Button("Decrease Size") {
                canvasViewModel?.decreaseBrushSize()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(canvasViewModel == nil)
        }
        
        CommandMenu("Canvas") {
            Button("Clear Canvas") {
                canvasViewModel?.clearCanvas()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(canvasViewModel == nil)
            
            Divider()
            
            Button("Reset Zoom") {
                canvasViewModel?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(canvasViewModel == nil)
        }
        
        CommandMenu("Export") {
            Button("Export to PNG...") {
                // Trigger export
            }
            .disabled(true) // Not implemented yet
            
            Button("Export to JPEG...") {
                
            }
            .disabled(true) // Not implemented yet
        }
    }
}
