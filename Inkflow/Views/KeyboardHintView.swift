//
//  KeyboardHintView.swift
//  Inkflow
//
//  Floating keyboard shortcut hints
//

import SwiftUI

struct KeyboardHintView: View {
    let shortcut: String
    let description: String
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Shortcut key
            Text(shortcut)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(ColorTheme.textOnAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorTheme.accentGradient)
                        .shadow(ShadowStyle.light)
                }
            
            // Description
            Text(description)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .onAppear {
            withAnimation(AnimationTiming.tooltip.delay(0.1)) {
                isVisible = true
            }
        }
    }
}

/// Overlay showing keyboard shortcuts when Command key is held
struct KeyboardShortcutOverlay: View {
    @Binding var isShowing: Bool
    @State private var commandKeyPressed = false
    
    var body: some View {
        ZStack {
            if commandKeyPressed && isShowing {
                VStack(spacing: 16) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    ForEach(KeyboardShortcutInfo.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                            
                            ForEach(InkflowShortcuts.shortcuts(for: category)) { shortcut in
                                HStack {
                                    Text(shortcut.displayString)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(ColorTheme.accentPrimary)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text(shortcut.action)
                                        .font(.system(size: 11))
                                        .foregroundColor(ColorTheme.textPrimary)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Material.panelMaterial)
                        .shadows(ShadowStyle.panel)
                }
                .frame(width: 300)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CommandKeyPressed"))) { _ in
            withAnimation(AnimationTiming.tooltip) {
                commandKeyPressed = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CommandKeyReleased"))) { _ in
            withAnimation(AnimationTiming.tooltip) {
                commandKeyPressed = false
            }
        }
    }
}

#Preview {
    KeyboardHintView(shortcut: "⌘B", description: "Brush")
        .padding()
        .background(Color.gray.opacity(0.2))
}
