//
//  CockpitSurveillanceBadge.swift
//  KILLERBEES
//
//  Created by Jules
//  Badge Tactique de Surveillance & Alerte Intrusion (Apple Vision)
//

import SwiftUI

struct CockpitSurveillanceBadge: View {
    let hasIntruderAlert: Bool
    let detectedHumansCount: Int
    let onCaptureSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Indicateur d'Alerte Visuelle
            HStack(spacing: 6) {
                Image(systemName: hasIntruderAlert ? "exclamationmark.shield.fill" : "shield.checkered")
                    .font(.subheadline)
                    .symbolEffect(.pulse, isActive: hasIntruderAlert)
                    .foregroundStyle(hasIntruderAlert ? .red : .green)

                VStack(alignment: .leading, spacing: 1) {
                    Text(hasIntruderAlert ? "⚠️ INTRUSION DÉTECTÉE" : "PÉRIMÈTRE SOUS CONTRÔLE")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(hasIntruderAlert ? .red : .white)

                    Text(hasIntruderAlert ? "\(detectedHumansCount) SILHOUETTE(S) HUMAINE(S)" : "BALAYAGE SÉCURITÉ ACTIF")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.3))

            // Bouton Capture Rapide de Preuve (Photo Horodatée & GPS)
            Button("Preuve", systemImage: "camera.badge.ellipsis", action: onCaptureSnapshot)
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(hasIntruderAlert ? Color.red.opacity(0.35) : Color.blue.opacity(0.35))
                .clipShape(.capsule)
                .overlay(
                    Capsule().strokeBorder(hasIntruderAlert ? Color.red.opacity(0.6) : Color.blue.opacity(0.6), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(hasIntruderAlert ? Color.red.opacity(0.8) : Color.blue.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: hasIntruderAlert ? Color.red.opacity(0.5) : Color.clear, radius: 8)
    }
}
