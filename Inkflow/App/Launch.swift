import Foundation

/// Command-line options, used to render the README screenshots:
///
///     Inkflow --demo [light|dark] --appearance light --size 1280x800 --tool brush --zoom 1 --layers
///
/// `--demo` opens new documents with a sample drawing instead of a blank canvas.
struct LaunchOptions {
    var demoDrawing: Drawing?
    var windowSize: CGSize?
    var tool: Tool?
    var showLayers = false
    var zoom: CGFloat?
    /// "light" or "dark" forces the app's appearance.
    var appearance: String?

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count,
                  !arguments[i + 1].hasPrefix("--") else { return nil }
            return arguments[i + 1]
        }
        if arguments.contains("--demo") {
            demoDrawing = Demo.drawing(dark: value(after: "--demo") == "dark")
        }
        if let size = value(after: "--size")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
            windowSize = CGSize(width: size[0], height: size[1])
        }
        tool = value(after: "--tool").flatMap(Tool.init(rawValue:))
        showLayers = arguments.contains("--layers")
        appearance = value(after: "--appearance")
        zoom = value(after: "--zoom").flatMap(Double.init).map { CGFloat($0) }
    }
}

enum Launch {
    static let options = LaunchOptions(arguments: CommandLine.arguments)
}
