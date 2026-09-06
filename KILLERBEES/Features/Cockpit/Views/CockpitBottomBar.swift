//
//  CockpitBottomBar.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

struct CockpitBottomBar: View {
    let flyingState: FlyingIndicatorsState
    let isRthActive: Bool
    let onTakeOff: () -> Void
    let onLand: () -> Void
    let onToggleRth: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Bouton RTH (Return-To-Home) disponible en vol
            if flyingState == .flying {
                Button(isRthActive ? "Annuler RTH" : "RTH", systemImage: isRthActive ? "xmark.circle.fill" : "house.fill", action: onToggleRth)
                    .buttonStyle(.borderedProminent)
                    .tint(isRthActive ? .red : .blue)
                    .controlSize(.large)
                    .bold()
            }

            // Bouton Principal Décoller / Atterrir
            if flyingState == .flying {
                Button("Atterrir", systemImage: "arrow.down.circle.fill", action: onLand)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .bold()
            } else {
                Button("Décoller", systemImage: "arrow.up.circle.fill", action: onTakeOff)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                    .bold()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}
