//
//  FocusedValues.swift
//  Inkflow
//
//  Focused value keys for menu bar command handling
//

import SwiftUI

struct CanvasViewModelKey: FocusedValueKey {
    typealias Value = CanvasViewModel
}

extension FocusedValues {
    var canvasViewModel: CanvasViewModel? {
        get { self[CanvasViewModelKey.self] }
        set { self[CanvasViewModelKey.self] = newValue }
    }
}
