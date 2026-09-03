//
//  DashboardDroneCard.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

struct DashboardDroneCard: View {
    let connectedDrone: Drone?
    let isConnected: Bool
    let batteryLevel: Int?
    let satelliteCount: Int?
    let isGpsFixed: Bool
    let availableDrones: [Drone]
    let onSelectDrone: (Drone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // En-tête de la tuile
            HStack {
                Image(systemName: "airplane")
                    .font(.title2)
                    .foregroundStyle(isConnected ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectedDrone?.name ?? "DRONE ANAFI")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)

                    Text(isConnected ? "Liaison Wi-Fi active" : "Recherche en cours...")
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
                // Télémétrie vitale pré-vol
                HStack(spacing: 20) {
                    // Jauge de Batterie
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BATTERIE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 6) {
                            Image(systemName: batteryIcon(for: batteryLevel))
                                .foregroundStyle(batteryColor(for: batteryLevel))
                            Text(batteryLevel.map { "\($0)%" } ?? "--")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // Fix GPS
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GPS SATELLITES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 6) {
                            Image(systemName: isGpsFixed ? "location.fill" : "location.slash")
                                .foregroundStyle(isGpsFixed ? .green : .orange)
                            Text(satelliteCount.map { "\($0)" } ?? "0")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // État Moteurs
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STATUT VOL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("PRÊT")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.green)
                    }
                }
            } else {
                // Drones disponibles à proximité
                if availableDrones.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                        Text("Allumez votre drone Anafi ou connectez la radiocommande...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drones détectés :")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        ForEach(availableDrones) { drone in
                            Button {
                                onSelectDrone(drone)
                            } label: {
                                HStack {
                                    Image(systemName: "airplane.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.cyan)
                                    Text(drone.name)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("CONNECTER")
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.cyan.opacity(0.2))
                                        .foregroundStyle(.cyan)
                                        .clipShape(.capsule)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 8))
                            }
                        }
                    }
                }
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

    private func batteryIcon(for level: Int?) -> String {
        guard let level else { return "battery.0" }
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(for level: Int?) -> Color {
        guard let level else { return .secondary }
        if level > 40 { return .green }
        if level > 20 { return .orange }
        return .red
    }
}
