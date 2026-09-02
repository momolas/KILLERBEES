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
    let onTakeOff: () -> Void
    let onLand: () -> Void

    var body: some View {
        HStack(spacing: 20) {
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
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .padding(.bottom)
    }
}
