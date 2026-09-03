//
//  DashboardHeaderView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct DashboardHeaderView: View {
    let isDroneConnected: Bool
    let isRcConnected: Bool
    let isFccMode: Bool
    let onToggleFcc: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            // Titre Tactique & Badge
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("KILLERBEES")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)

                    Text("TACTICAL GCS")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow.opacity(0.2))
                        .foregroundStyle(.yellow)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(.yellow.opacity(0.4), lineWidth: 1)
                        )
                }

                Text("STATION DE CONTRÔLE PARROT ANAFI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Bouton FCC Mode & Statut Système
            HStack(spacing: 12) {
                Button(isFccMode ? "FCC 1W" : "CE 100mW", systemImage: "antenna.radiowaves.left.and.right", action: onToggleFcc)
                    .font(.caption)
                    .bold()
                    .buttonStyle(.bordered)
                    .tint(isFccMode ? .green : .orange)
                    .clipShape(.capsule)

                // Indicateur de statut global
                HStack(spacing: 6) {
                    Circle()
                        .fill(systemStatusColor)
                        .frame(width: 8, height: 8)

                    Text(systemStatusText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(.capsule)
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var systemStatusColor: Color {
        if isDroneConnected && isRcConnected {
            return .green
        } else if isDroneConnected || isRcConnected {
            return .orange
        } else {
            return .red
        }
    }

    private var systemStatusText: String {
        if isDroneConnected && isRcConnected {
            return "SYSTÈME PRÊT"
        } else if isRcConnected {
            return "RC CONNECTÉE"
        } else if isDroneConnected {
            return "DRONE CONNECTÉ"
        } else {
            return "EN ATTENTE"
        }
    }
}
