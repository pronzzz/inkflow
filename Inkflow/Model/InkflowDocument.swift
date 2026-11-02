import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Same identifier as Inkflow 1.x, so old files keep opening with the app.
    static let inkflow = UTType(exportedAs: "com.pranavdwivedi.inkflow.doc", conformingTo: .package)
}

/// An `.inkflow` document. Edits go through `Editor`, which registers every change with the
/// window's undo manager; that is also how SwiftUI knows the document needs saving.
final class InkflowDocument: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.inkflow] }

    @Published var drawing: Drawing

    init(drawing: Drawing = Launch.options.demoDrawing ?? Drawing()) {
        self.drawing = drawing
    }

    init(configuration: ReadConfiguration) throws {
        drawing = try DocumentCodec.read(configuration.file)
    }

    func snapshot(contentType: UTType) throws -> Drawing { drawing }

    func fileWrapper(snapshot: Drawing, configuration: WriteConfiguration) throws -> FileWrapper {
        try DocumentCodec.write(snapshot)
    }
}

/// The package layout:
///
///     Name.inkflow/
///       drawing.json             the drawing (format version 3)
///       QuickLook/Thumbnail.png  Finder icon
///       QuickLook/Preview.pdf    vector preview for Quick Look (space bar in Finder)
enum DocumentCodec {
    static func write(_ drawing: Drawing) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var children = ["drawing.json": FileWrapper(regularFileWithContents: try encoder.encode(drawing))]

        var quickLook: [String: FileWrapper] = [:]
        if let thumbnail = thumbnail(of: drawing, maxSide: 512) {
            quickLook["Thumbnail.png"] = FileWrapper(regularFileWithContents: thumbnail)
        }
        if let rect = Renderer.contentBounds(of: drawing), let pdf = Renderer.pdf(of: drawing, rect: rect) {
            quickLook["Preview.pdf"] = FileWrapper(regularFileWithContents: pdf)
        }
        if !quickLook.isEmpty {
            children["QuickLook"] = FileWrapper(directoryWithFileWrappers: quickLook)
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }

    static func read(_ file: FileWrapper) throws -> Drawing {
        let data: Data?
        if file.isDirectory {
            data = (file.fileWrappers?["drawing.json"] ?? file.fileWrappers?["data.json"])?.regularFileContents
        } else {
            data = file.regularFileContents
        }
        guard let data else { throw CocoaError(.fileReadCorruptFile) }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> Drawing {
        struct Probe: Decodable { var version: Int? }
        let version = (try? JSONDecoder().decode(Probe.self, from: data))?.version ?? 1
        if version >= 3 {
            guard version <= Drawing.formatVersion else { throw CocoaError(.fileReadUnsupportedScheme) }
            return try JSONDecoder().decode(Drawing.self, from: data)
        }
        return try LegacyFormat.decode(data)
    }

    static func thumbnail(of drawing: Drawing, maxSide: CGFloat) -> Data? {
        guard let rect = Renderer.contentBounds(of: drawing) else { return nil }
        let scale = min(maxSide / max(rect.width, rect.height), 2)
        guard let image = Renderer.image(of: drawing, rect: rect, scale: scale) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
