//
//  DashboardRemoteCard.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

struct DashboardRemoteCard: View {
    let remoteControl: RemoteControl?
    let isConnected: Bool
    let batteryLevel: Int?
    let isScanning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // En-tête de la tuile
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(isConnected ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(remoteControl?.name ?? "SKYCONTROLLER 3")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)

                    Text(isConnected ? "Liaison Filaire USB OK" : "Non branché")
                        .font(.caption2)
                        .foregroundStyle(isConnected ? .green : .white.opacity(0.5))
                }

                Spacer()

                if isConnected {
                    Text("CONNECTÉ")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(.green.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            if isConnected {
                HStack(spacing: 20) {
                    // Batterie Radiocommande
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BATTERIE RC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 6) {
                            Image(systemName: "battery.100")
                                .foregroundStyle(batteryLevel != nil && batteryLevel! > 20 ? .green : .orange)
                            Text(batteryLevel.map { "\($0)%" } ?? "--")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // Portée Radio
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIAISON RF")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.green)
                            Text("5 GHz MIMO")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cable.connector.slash")
                        .font(.title3)
                        .foregroundStyle(.orange.opacity(0.8))
                    Text("Reliez le SkyController 3 à l'iPhone à l'aide d'un câble USB pour une portée maximale.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isConnected ? Color.green.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
