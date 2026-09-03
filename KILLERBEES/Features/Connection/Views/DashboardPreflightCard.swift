//
//  DashboardPreflightCard.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct DashboardPreflightCard: View {
    let isFccMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)

                Text("PARAMÈTRES PRÉ-VOL")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)

                Spacer()

                Text("SÉCURITÉ OK")
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.cyan.opacity(0.2))
                    .foregroundStyle(.cyan)
                    .clipShape(.capsule)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 16) {
                // RTH
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALTITUDE RTH")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("30 MÈTRES")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                }

                Spacer()

                // Puissance
                VStack(alignment: .leading, spacing: 2) {
                    Text("PUISSANCE RF")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(isFccMode ? "FCC (1 WATT)" : "CE (100 mW)")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(isFccMode ? .green : .orange)
                }

                Spacer()

                // IA
                VStack(alignment: .leading, spacing: 2) {
                    Text("VISION IA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("NEURAL ENGINE")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
