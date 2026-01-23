//
//  ColorTheme.swift
//  Inkflow
//
//  Centralized color theme system with dark mode optimization
//

import SwiftUI

/// Color theme for Inkflow with One UI 8 inspired palette
struct ColorTheme {
    
    // MARK: - Current Theme
    
    @AppStorage("appearanceMode") private static var appearanceMode: AppearanceMode = .dark
    
    enum AppearanceMode: String {
        case light
        case dark
        case auto
    }
    
    // MARK: - Canvas Colors
    
    static var canvasBackground: Color {
        isDarkMode ? Color(hex: "1C1C1E") : .white
    }
    
    static var panelBackground: Color {
        isDarkMode ? Color(hex: "252525") : Color(hex: "F2F2F7")
    }
    
    static var canvasBorder: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    // MARK: - Toolbar Colors
    
    static var toolbarTint: Color {
        isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
    }
    
    static var toolbarBorder: Color {
        isDarkMode ? accentPrimary.opacity(0.2) : accentPrimary.opacity(0.15)
    }
    
    // MARK: - Accent Colors
    
    static var accentPrimary: Color {
        isDarkMode ? Color(hex: "8B7FFC") : Color(hex: "7060E8")
    }
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ? [
                Color(hex: "8B7FFC"),
                Color(hex: "A89FFF")
            ] : [
                Color(hex: "7060E8"),
                Color(hex: "8B7FFC")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var accentSubtle: Color {
        accentPrimary.opacity(0.15)
    }
    
    // MARK: - Button Colors
    
    static var buttonPrimary: Color {
        accentPrimary
    }
    
    static var buttonSecondary: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }
    
    static var buttonHover: Color {
        isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    static var buttonActive: Color {
        accentPrimary
    }
    
    // MARK: - Text Colors
    
    static var textPrimary: Color {
        isDarkMode ? .white : .black
    }
    
    static var textSecondary: Color {
        isDarkMode ? Color(hex: "8E8E93") : Color(hex: "6C6C70")
    }
    
    static var textTertiary: Color {
        isDarkMode ? Color(hex: "636366") : Color(hex: "A8A8AD")
    }
    
    static var textOnAccent: Color {
        .white
    }
    
    // MARK: - Shadow Colors
    
    static var shadowLight: Color {
        Color.black.opacity(isDarkMode ? 0.3 : 0.12)
    }
    
    static var shadowMedium: Color {
        Color.black.opacity(isDarkMode ? 0.4 : 0.08)
    }
    
    static var shadowDark: Color {
        Color.black.opacity(isDarkMode ? 0.5 : 0.2)
    }
    
    // MARK: - Slider Colors
    
    static var sliderTrack: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    static var sliderThumb: LinearGradient {
        accentGradient
    }
    
    // MARK: - Helpers
    
    private static var isDarkMode: Bool {
        switch appearanceMode {
        case .dark:
            return true
        case .light:
            return false
        case .auto:
            return NSApp.effectiveAppearance.name == .darkAqua
        }
    }
    
    // MARK: - Preset Color Palettes
    
    static let presetColors: [[Color]] = [
        // Row 1: Grayscale
        [
            Color(hex: "000000"), // Black
            Color(hex: "3C3C3C"), // Dark Gray
            Color(hex: "787878"), // Gray
            Color(hex: "B4B4B4"), // Light Gray
            Color(hex: "E0E0E0"), // Very Light Gray
            Color(hex: "FFFFFF"), // White
        ],
        // Row 2: Warm
        [
            Color(hex: "FF3B30"), // Red
            Color(hex: "FF9500"), // Orange
            Color(hex: "FFCC00"), // Yellow
            Color(hex: "FF6B6B"), // Light Red
            Color(hex: "FFB347"), // Peach
            Color(hex: "FFE066"), // Light Yellow
        ],
        // Row 3: Cool
        [
            Color(hex: "34C759"), // Green
            Color(hex: "00C7BE"), // Teal
            Color(hex: "32ADE6"), // Blue
            Color(hex: "5AC8FA"), // Light Blue
            Color(hex: "64D2FF"), // Sky
            Color(hex: "7AE7C7"), // Mint
        ],
        // Row 4: Purple & Pink
        [
            Color(hex: "5856D6"), // Purple
            Color(hex: "AF52DE"), // Violet
            Color(hex: "FF2D55"), // Pink
            Color(hex: "8B7FFC"), // Light Purple
            Color(hex: "C77DFF"), // Lavender
            Color(hex: "FF85B3"), // Light Pink
        ],
    ]
}

// MARK: - Material Styles

extension Material {
    static var toolbarMaterial: Material {
        .ultraThinMaterial
    }
    
    static var panelMaterial: Material {
        .regularMaterial
    }
}
