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
        HStack(spacing: 16) {
            // Altitude & Vitesse Verticale
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.and.down.and.sparkles")
                    .font(.caption)
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(altitude != nil ? (altitude! >= 0 ? altitude! : 0.0) : 0.0, format: .number.precision(.fractionLength(1)))
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.white)
                        Text("m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let vSpeed = verticalSpeed, abs(vSpeed) > 0.2 {
                        HStack(spacing: 2) {
                            Image(systemName: vSpeed > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8))
                            Text(abs(vSpeed), format: .number.precision(.fractionLength(1)))
                                .font(.system(size: 9))
                            Text("m/s")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(vSpeed > 0 ? .green : .orange)
                    } else {
                        Text("ALTITUDE")
                            .font(.system(size: 9))
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)

            // Vitesse Sol (km/h)
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        let speedKmh = (groundSpeed ?? 0.0) * 3.6
                        Text(speedKmh >= 0 ? speedKmh : 0.0, format: .number.precision(.fractionLength(1)))
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.white)
                        Text("km/h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("VITESSE")
                        .font(.system(size: 9))
                        .bold()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)

            Spacer()
        }
        .padding(.horizontal)
    }
}
