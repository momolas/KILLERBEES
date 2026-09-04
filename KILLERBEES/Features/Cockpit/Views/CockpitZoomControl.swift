//
//  CockpitZoomControl.swift
//  KILLERBEES
//
//  Created by Jules
//  Contrôle Tactile Rapide du Zoom Caméra (1x, 1.5x, 2x, 3x)
//

import SwiftUI

struct CockpitZoomControl: View {
    let currentZoom: Double
    let onSelectZoom: (Double) -> Void

    private let zoomPresets: [Double] = [1.0, 1.5, 2.0, 3.0]

    var body: some View {
        VStack(spacing: 4) {
            Text("ZOOM")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 2)

            ForEach(zoomPresets.reversed(), id: \.self) { preset in
                let isSelected = abs(currentZoom - preset) < 0.25

                Button {
                    HapticFeedback.tap()
                    onSelectZoom(preset)
                } label: {
                    Text(formatZoomText(preset))
                        .font(.system(size: 11, weight: isSelected ? .black : .semibold))
                        .foregroundStyle(isSelected ? .black : .white)
                        .frame(width: 38, height: 26)
                        .background(
                            isSelected ? Color.yellow : Color.white.opacity(0.12)
                        )
                        .clipShape(.rect(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Zoom \(formatZoomText(preset))")
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func formatZoomText(_ value: Double) -> String {
        if value == 1.0 {
            return "1x"
        } else if value == 1.5 {
            return "1.5x"
        } else if value == 2.0 {
            return "2x"
        } else {
            return "3x"
        }
    }
}
