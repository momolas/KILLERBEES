//
//  CockpitTelemetryHUD.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitTelemetryHUD: View {
    let altitude: Double?
    let verticalSpeed: Double?
    let groundSpeed: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Altitude & Vitesse Verticale
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "arrow.up.and.down.and.sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.cyan)
                    .frame(width: 12)

                Text(max(altitude ?? 0.0, 0.0), format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("m")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let vSpeed = verticalSpeed, abs(vSpeed) > 0.2 {
                    HStack(spacing: 1) {
                        Image(systemName: vSpeed > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9))
                        Text(abs(vSpeed), format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(vSpeed > 0 ? .green : .orange)
                }
            }

            // Vitesse Sol
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .frame(width: 12)

                let speedKmh = (groundSpeed ?? 0.0) * 3.6
                Text(max(speedKmh, 0.0), format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("km/h")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
