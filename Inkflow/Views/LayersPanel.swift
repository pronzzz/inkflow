//
//  LayersPanel.swift
//  Inkflow
//
//  Floating panel for layer management
//

import SwiftUI

struct LayersPanel: View {
    @EnvironmentObject var viewModel: CanvasViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Button {
                    viewModel.addLayer()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(ColorTheme.buttonSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add Layer")
                
                Button {
                    withAnimation(AnimationTiming.springQuick) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(ColorTheme.buttonSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ColorTheme.panelBackground.opacity(0.8))
            
            Divider()
                .background(ColorTheme.toolbarBorder)
            
            // Layer List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.layers.reversed()) { layer in
                        LayerRow(
                            layer: layer,
                            isActive: layer.id == viewModel.activeLayerId,
                            onSelect: {
                                viewModel.activeLayerId = layer.id
                            },
                            onToggleVisibility: {
                                viewModel.toggleLayerVisibility(layer.id)
                            },
                            onToggleLock: {
                                viewModel.toggleLayerLock(layer.id)
                            },
                            onDelete: {
                                viewModel.deleteLayer(layer.id)
                            }
                        )
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 220)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.toolbarMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(ColorTheme.toolbarBorder, lineWidth: 1)
                }
        }
        .shadows(ShadowStyle.toolbar)
    }
}

// MARK: - Layer Row

struct LayerRow: View {
    let layer: Layer
    let isActive: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Visibility toggle
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(layer.isVisible ? ColorTheme.textPrimary : ColorTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
            
            // Lock toggle
            Button(action: onToggleLock) {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 10))
                    .foregroundColor(layer.isLocked ? ColorTheme.accentPrimary : ColorTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
            
            // Layer name
            Text(layer.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                .lineLimit(1)
            
            Spacer()
            
            // Element count
            Text("\(layer.elements.count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(ColorTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ColorTheme.accentSubtle)
                .clipShape(Capsule())
            
            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? ColorTheme.accentSubtle : (isHovered ? ColorTheme.buttonHover : Color.clear))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(AnimationTiming.hover) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LayersPanel(isPresented: .constant(true))
        .environmentObject(CanvasViewModel())
        .padding()
        .background(Color.black)
}
