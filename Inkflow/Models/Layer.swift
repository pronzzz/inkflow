//
//  Layer.swift
//  Inkflow
//
//  Layer model for organizing canvas elements
//

import SwiftUI

struct Layer: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var elements: [CanvasElement] = []
    
    var isVisible: Bool = true
    var isLocked: Bool = false
    var opacity: Double = 1.0
    
    init(name: String) {
        self.name = name
    }
}
