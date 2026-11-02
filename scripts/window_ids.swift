// Prints "<windowID> <layer> <width>x<height> <x>,<y> <name>" for every on-screen window of a process.
//   swift scripts/window_ids.swift <pid>
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments[1]) ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let bounds = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let id = w[kCGWindowNumber as String] as? Int ?? 0
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    let name = w[kCGWindowName as String] as? String ?? ""
    print("\(id) \(layer) \(Int(bounds["Width"] ?? 0))x\(Int(bounds["Height"] ?? 0)) \(Int(bounds["X"] ?? 0)),\(Int(bounds["Y"] ?? 0)) \(name)")
}
