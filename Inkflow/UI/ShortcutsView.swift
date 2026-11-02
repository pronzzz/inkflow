import SwiftUI

struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    static let sections: [(title: String, rows: [(String, String)])] = [
        ("Tools", [
            ("Select", "V"), ("Brush", "B"), ("Pencil", "P"), ("Highlighter", "M"), ("Eraser", "E"),
            ("Line · Arrow", "L · A"), ("Rectangle · Ellipse", "R · O"), ("Text", "T"), ("Hand", "H or hold Space"),
        ]),
        ("Style", [
            ("Smaller · larger", "[ · ]"), ("Opacity 10–90%", "1 – 9"), ("Opacity 100%", "0"),
            ("Straight lines, squares", "Hold ⇧"),
        ]),
        ("Canvas", [
            ("Pan", "Scroll · Space-drag"), ("Zoom", "Pinch · ⌘-scroll"), ("Zoom in · out", "⌘= · ⌘−"),
            ("Actual size", "⌘0"), ("Zoom to fit", "⌘9"), ("Grid", "⌘'"), ("Layers", "⌥⌘L"),
        ]),
        ("Edit", [
            ("Undo · Redo", "⌘Z · ⇧⌘Z"), ("Copy · Cut · Paste", "⌘C · ⌘X · ⌘V"), ("Duplicate", "⌘D"),
            ("Delete", "⌫"), ("Nudge", "Arrows (⇧ ×10)"), ("Select all", "⌘A"), ("Copy as image", "⇧⌘C"),
            ("Export PNG · PDF", "⇧⌘E · ⌥⇧⌘E"), ("New line in text", "⇧↩"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Keyboard Shortcuts").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    section(Self.sections[0])
                    section(Self.sections[1])
                }
                VStack(alignment: .leading, spacing: 18) {
                    section(Self.sections[2])
                    section(Self.sections[3])
                }
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    private func section(_ section: (title: String, rows: [(String, String)])) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            ForEach(section.rows, id: \.0) { row in
                HStack {
                    Text(row.0).font(.system(size: 12))
                    Spacer(minLength: 12)
                    Text(row.1).font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 252)
    }
}
