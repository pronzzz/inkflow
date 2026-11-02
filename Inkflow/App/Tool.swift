import Foundation

enum Tool: String, CaseIterable, Identifiable {
    case select, hand, brush, pencil, marker, eraser, shape, text

    var id: String { rawValue }

    /// Tools shown in the palette, in order. The hand tool is reached with Space or H.
    static let palette: [Tool] = [.select, .brush, .pencil, .marker, .eraser, .shape, .text]

    var title: String {
        switch self {
        case .select: return "Select"
        case .hand: return "Hand"
        case .brush: return "Brush"
        case .pencil: return "Pencil"
        case .marker: return "Highlighter"
        case .eraser: return "Eraser"
        case .shape: return "Shapes"
        case .text: return "Text"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .hand: return "hand.raised"
        case .brush: return "paintbrush.pointed"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .eraser: return "eraser"
        case .shape: return "square.on.circle"
        case .text: return "textformat"
        }
    }

    var key: String {
        switch self {
        case .select: return "V"
        case .hand: return "H"
        case .brush: return "B"
        case .pencil: return "P"
        case .marker: return "M"
        case .eraser: return "E"
        case .shape: return "R"
        case .text: return "T"
        }
    }

    var strokeTool: StrokeTool? {
        switch self {
        case .brush: return .brush
        case .pencil: return .pencil
        case .marker: return .marker
        case .eraser: return .eraser
        default: return nil
        }
    }

    /// Whether the size control applies (and what it means).
    var hasSize: Bool { strokeTool != nil || self == .shape || self == .text }
    var usesColor: Bool { self != .eraser && self != .select && self != .hand }

    var defaultSize: CGFloat {
        switch self {
        case .brush: return 6
        case .pencil: return 2
        case .marker: return 18
        case .eraser: return 24
        case .shape: return 3
        case .text: return 24
        default: return 4
        }
    }

    var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .text: return 8...144
        case .eraser, .marker: return 2...160
        default: return 1...80
        }
    }
}
