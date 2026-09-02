//
//  CockpitTopBar.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

struct CockpitTopBar: View {
    let droneName: String
    let droneBattery: Int?
    let rcBattery: Int?
    let flyingState: FlyingIndicatorsState
    let satelliteCount: Int?
    let isGpsFixed: Bool
    let radioSignalQuality: Int?
    let isRthActive: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Retour", systemImage: "chevron.left", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(.circle)

            Spacer()

            // Statut Central Drone & Vol
            HStack(spacing: 8) {
                Circle()
                    .fill(isRthActive ? .orange : (flyingState == .flying ? .green : .blue))
                    .frame(width: 8, height: 8)

                Text(droneName.isEmpty ? "Drone" : droneName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)

                if isRthActive {
                    Text("RTH ACTIF")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.4))
                        .clipShape(.capsule)
                        .foregroundStyle(.white)
                } else {
                    Text(flyingState == .flying ? "EN VOL" : "AU SOL")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(flyingState == .flying ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
                        .clipShape(.capsule)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)

            Spacer()

            // Télémétrie GPS, Radio & Batteries
            HStack(spacing: 10) {
                // GPS
                HStack(spacing: 4) {
                    Image(systemName: isGpsFixed ? "location.fill" : "location.slash")
                        .font(.caption2)
                        .foregroundStyle(isGpsFixed ? .green : .secondary)
                    if let satellites = satelliteCount {
                        Text("\(satellites)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                    }
                }

                // Radio Link
                if let quality = radioSignalQuality {
                    HStack(spacing: 3) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(quality >= 3 ? .green : (quality == 2 ? .orange : .red))
                    }
                }

                // Batteries
                if let rcBattery {
                    HStack(spacing: 3) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.caption2)
                        Text("\(rcBattery)%")
                            .font(.caption)
                            .bold()
                    }
                    .foregroundStyle(.white)
                }

                if let droneBattery {
                    HStack(spacing: 4) {
                        Image(systemName: batterySystemImage(for: droneBattery))
                            .font(.caption)
                            .foregroundStyle(batteryColor(for: droneBattery))
                        Text("\(droneBattery)%")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)
        }
        .padding(.horizontal)
    }

    private func batterySystemImage(for level: Int) -> String {
        switch level {
        case 75...100: return "battery.100percent"
        case 50..<75:  return "battery.75percent"
        case 25..<50:  return "battery.50percent"
        default:       return "battery.25percent"
        }
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 50...100: return .green
        case 20..<50:  return .orange
        default:       return .red
        }
    }
}
