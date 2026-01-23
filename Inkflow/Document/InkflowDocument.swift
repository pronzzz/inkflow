//
//  InkflowDocument.swift
//  Inkflow
//
//  Document wrapper for file operations
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

extension UTType {
    static var inkflowDocument: UTType {
        UTType(exportedAs: "com.pranavdwivedi.inkflow.doc")
    }
}

struct InkflowDocument: FileDocument {
    var data: DocumentData
    
    init() {
        self.data = DocumentData()
    }
    
    init(configuration: ReadConfiguration) throws {
        if let wrapper = configuration.file.fileWrappers?["data.json"],
           let data = wrapper.regularFileContents {
            self.data = try JSONDecoder().decode(DocumentData.self, from: data)
        } else if let data = configuration.file.regularFileContents {
            // Legacy flat file support
            self.data = try JSONDecoder().decode(DocumentData.self, from: data)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted // Easier debugging
        let data = try jsonEncoder.encode(self.data)
        
        let dataWrapper = FileWrapper(regularFileWithContents: data)
        dataWrapper.preferredFilename = "data.json"
        
        var children: [String: FileWrapper] = ["data.json": dataWrapper]
        
        // Generate Thumbnail for Quick Look
        if let thumbData = generateThumbnail() {
            let thumbWrapper = FileWrapper(regularFileWithContents: thumbData)
            thumbWrapper.preferredFilename = "Thumbnail.png"
            children["Thumbnail.png"] = thumbWrapper
        }
        
        return FileWrapper(directoryWithFileWrappers: children)
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail() -> Data? {
        let renderer = CanvasRenderer()
        let layers = self.data.layers.map { $0.toLayer() }
        let size = CGSize(width: self.data.width, height: self.data.height)
        let color = Color(hex: self.data.backgroundColorHex)
        
        // Fit within 512x512
        let maxDim: CGFloat = 512
        let scale = min(maxDim / size.width, maxDim / size.height)
        
        guard let cgImage = renderer.render(
            layers: layers,
            currentStroke: nil,
            currentShape: nil,
            selectedElementIds: [],
            size: size,
            backgroundColor: color,
            zoom: scale,
            panOffset: .zero
        ) else { return nil }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    static var readableContentTypes: [UTType] { [.inkflowDocument] }
}
