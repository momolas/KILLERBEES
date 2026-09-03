//
//  DroneRow.swift
//  KILLERBEES
//

import SwiftUI
import GroundSdk

struct DroneRow: View {
    let drone: Drone
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(drone.name.isEmpty ? "Drone Inconnu" : drone.name)
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Text("UID: \(drone.uid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    switch drone.state.connectionState {
                    case .connected:
                        Text("Connecté")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.green)
                    case .connecting:
                        Text("Connexion en cours...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    case .disconnecting:
                        Text("Déconnexion...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .disconnected:
                        Text("Déconnecté")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else if drone.state.connectionState == .connecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(drone.state.connectionState.description)
    }
}
