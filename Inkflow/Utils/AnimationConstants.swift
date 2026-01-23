//
//  AnimationConstants.swift
//  Inkflow
//
//  Centralized animation timing and easing curves
//

import SwiftUI

/// Animation constants for consistent motion design
enum AnimationTiming {
    
    // MARK: - Duration Constants
    
    /// Quick interactions (100-150ms) - Button press, toggle
    static let quick: TimeInterval = 0.15
    
    /// Standard transitions (200-250ms) - Panel expand, tool switch
    static let standard: TimeInterval = 0.25
    
    /// Smooth animations (300-350ms) - Page transitions, large movements
    static let smooth: TimeInterval = 0.35
    
    /// Slow animations (400-500ms) - Modal presentations, complex transitions
    static let slow: TimeInterval = 0.45
    
    // MARK: - Spring Physics
    
    /// Quick spring - Button feedback
    static let springQuick = Animation.spring(response: 0.25, dampingFraction: 0.7)
    
    /// Standard spring - Most UI animations
    static let springStandard = Animation.spring(response: 0.35, dampingFraction: 0.75)
    
    /// Smooth spring - Large movements
    static let springSmooth = Animation.spring(response: 0.45, dampingFraction: 0.8)
    
    /// Bouncy spring - Playful interactions
    static let springBouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
    
    // MARK: - Easing Curves
    
    /// Ease out - Start fast, end slow (most common)
    static let easeOut = Animation.easeOut(duration: standard)
    
    /// Ease in - Start slow, end fast
    static let easeIn = Animation.easeIn(duration: standard)
    
    /// Ease in-out - Smooth acceleration and deceleration
    static let easeInOut = Animation.easeInOut(duration: standard)
    
    // MARK: - Specific Use Cases
    
    /// Tool selection animation
    static let toolSelection = springQuick
    
    /// Panel expand/collapse
    static let panelToggle = springStandard
    
    /// Color picker show/hide
    static let colorPickerToggle = springSmooth
    
    /// Slider value change
    static let sliderChange = Animation.spring(response: 0.2, dampingFraction: 0.85)
    
    /// Toolbar position change
    static let toolbarMove = springSmooth
    
    /// Hover effect
    static let hover = Animation.easeOut(duration: quick)
    
    /// Tooltip fade
    static let tooltip = Animation.easeInOut(duration: quick)
    
    // MARK: - Delay Constants
    
    /// Short delay before action
    static let delayShort: TimeInterval = 0.1
    
    /// Medium delay for sequenced animations
    static let delayMedium: TimeInterval = 0.2
    
    /// Long delay for staggered effects
    static let delayLong: TimeInterval = 0.3
}

// MARK: - Scale Constants

enum ScaleEffect {
    /// Subtle scale for button press
    static let buttonPress: CGFloat = 0.95
    
    /// Hover scale for interactive elements
    static let hover: CGFloat = 1.05
    
    /// Active/selected scale
    static let active: CGFloat = 1.08
    
    /// Emphasis scale for important elements
    static let emphasis: CGFloat = 1.12
}

// MARK: - Shadow Constants

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    // MARK: - Preset Shadows
    
    /// Light shadow for subtle elevation
    static let light = ShadowStyle(
        color: ColorTheme.shadowLight,
        radius: 8,
        x: 0,
        y: 2
    )
    
    /// Medium shadow for floating elements
    static let medium = ShadowStyle(
        color: ColorTheme.shadowMedium,
        radius: 16,
        x: 0,
        y: 4
    )
    
    /// Heavy shadow for modals and overlays
    static let heavy = ShadowStyle(
        color: ColorTheme.shadowDark,
        radius: 24,
        x: 0,
        y: 8
    )
    
    /// Toolbar shadow (layered)
    static var toolbar: [ShadowStyle] {
        [
            ShadowStyle(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2),
            ShadowStyle(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
        ]
    }
    
    /// Floating panel shadow (layered)
    static var panel: [ShadowStyle] {
        [
            ShadowStyle(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8),
            ShadowStyle(color: Color.black.opacity(0.1), radius: 40, x: 0, y: 16)
        ]
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a shadow style to a view
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    /// Apply layered shadows to a view
    func shadows(_ styles: [ShadowStyle]) -> some View {
        var view: AnyView = AnyView(self)
        for style in styles {
            view = AnyView(view.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y))
        }
        return view
    }
    
    /// Animate with standard spring
    func animateWithSpring(_ value: some Equatable) -> some View {
        self.animation(AnimationTiming.springStandard, value: value)
    }
}
