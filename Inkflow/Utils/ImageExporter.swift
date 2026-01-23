//
//  ImageExporter.swift
//  Inkflow
//
//  Handles exporting canvas to various image formats
//

import SwiftUI
import UniformTypeIdentifiers

struct ImageExporter {
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case png
        case jpeg
        case tiff
        
        var id: String { rawValue }
        
        var contentType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            }
        }
        
        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            }
        }
    }
    
    /// Export canvas data to a file URL
    @MainActor
    static func export(
        layers: [Layer],
        size: CGSize,
        backgroundColor: Color,
        format: ExportFormat,
        to url: URL
    ) throws {
        // Render image
        let renderer = CanvasRenderer()
        guard let cgImage = renderer.render(
            layers: layers,
            currentStroke: nil,
            currentShape: nil,
            size: size,
            backgroundColor: backgroundColor,
            zoom: 1.0,
            panOffset: .zero
        ) else {
            throw ImageExportError.renderingFailed
        }
        
        // Convert to data
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let storageType: NSBitmapImageRep.FileType
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        
        switch format {
        case .png:
            storageType = .png
        case .jpeg:
            storageType = .jpeg
            properties[.compressionFactor] = 0.9
        case .tiff:
            storageType = .tiff
            properties[.compressionMethod] = NSBitmapImageRep.TIFFCompression.lzw.rawValue
        }
        
        guard let data = bitmapRep.representation(using: storageType, properties: properties) else {
            throw ImageExportError.encodingFailed
        }
        
        // Write to file
        try data.write(to: url)
    }
}

enum ImageExportError: Error {
    case renderingFailed
    case encodingFailed
}
