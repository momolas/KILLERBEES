//
//  ControlButtonsSection.swift
//  KILLERBEES
//

import SwiftUI

struct ControlButtonsSection: View {
    let onTakeOff: () -> Void
    let onLand: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button("Décoller", systemImage: "arrow.up.circle.fill", action: onTakeOff)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)

            Button("Atterrir", systemImage: "arrow.down.circle.fill", action: onLand)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
        }
        .padding(.bottom)
    }
}
