//
//  CockpitLeisureBadge.swift
//  KILLERBEES
//
//  Created by Jules
//  Badge HUD Mode Loisir & Prises de Vue Cinématiques
//

import SwiftUI

struct CockpitLeisureBadge: View {
    @Binding var isGridEnabled: Bool
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isRecording ? "record.circle.fill" : "camera.macro")
                    .font(.subheadline)
                    .foregroundStyle(isRecording ? .red : .purple)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("VOL CINÉMATIQUE 4K")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.white)

                    Text("LACET DOUX 25°/S • SANS SACCADE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 18)
                .overlay {
                    Color.white.opacity(0.3)
                }

            // Bascule Grille Tiers (Cadrage Photo)
            Button(
                isGridEnabled ? "Grille Active" : "Grille 3x3",
                systemImage: isGridEnabled ? "grid.circle.fill" : "grid.circle",
                action: toggleGrid
            )
            .labelStyle(.titleAndIcon)
            .font(.caption2)
            .bold()
            .foregroundStyle(isGridEnabled ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minHeight: 44)
            .contentShape(.capsule)
            .background(isGridEnabled ? .purple.opacity(0.4) : .white.opacity(0.1))
            .clipShape(.capsule)
            .overlay {
                Capsule()
                    .strokeBorder(isGridEnabled ? .purple : .white.opacity(0.2), lineWidth: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.purple.opacity(0.4), lineWidth: 1)
        }
    }

    private func toggleGrid() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isGridEnabled.toggle()
        }
    }
}
