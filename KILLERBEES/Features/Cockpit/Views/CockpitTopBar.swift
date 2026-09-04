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
    let isFccMode: Bool
    let activeMissionMode: MissionMode
    let droneConnectionState: DeviceState.ConnectionState
    let smartRTH: SmartRTHAssessment?
    let onToggleFcc: () -> Void
    let onSelectMissionMode: (MissionMode) -> Void
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
                    .fill(connectionStatusColor)
                    .frame(width: 8, height: 8)

                Text(droneName.isEmpty ? "Drone" : droneName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)

                switch droneConnectionState {
                case .connecting:
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("CONNEXION...")
                            .font(.caption2)
                            .bold()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.3))
                    .clipShape(.capsule)
                    .foregroundStyle(.orange)

                case .disconnected, .disconnecting:
                    Text("DÉCONNECTÉ")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.4))
                        .clipShape(.capsule)
                        .foregroundStyle(.white)

                case .connected:
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)

            Spacer()

            // Sélecteur Tactique de Mode de Mission (Surveillance, Loisir, Chasse)
            Menu {
                ForEach(MissionMode.allCases) { mode in
                    Button {
                        HapticFeedback.tap()
                        onSelectMissionMode(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: activeMissionMode.icon)
                        .font(.caption2)
                    Text(activeMissionMode.rawValue.uppercased())
                        .font(.caption2)
                        .bold()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(activeMissionMode.accentColor.opacity(0.35))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .overlay(
                    Capsule().strokeBorder(activeMissionMode.accentColor.opacity(0.8), lineWidth: 1)
                )
            }
            .accessibilityLabel("Mode de mission \(activeMissionMode.title)")

            Spacer()

            // Badge & Sélecteur Réglementaire RF (Mod FCC)
            Button {
                onToggleFcc()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isFccMode ? "bolt.fill" : "globe.europe.africa.fill")
                        .font(.caption2)
                    Text(isFccMode ? "FCC 1W" : "CE 100mW")
                        .font(.caption2)
                        .bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isFccMode ? Color.purple.opacity(0.4) : Color.blue.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .overlay(
                    Capsule().strokeBorder(isFccMode ? Color.purple : Color.blue.opacity(0.6), lineWidth: 1)
                )
            }
            .accessibilityLabel(isFccMode ? "Mode FCC activé à un watt" : "Mode CE standard à cent milliwatts")

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
                    CockpitSmartBatteryBar(
                        batteryLevel: droneBattery,
                        smartRTH: smartRTH
                    )
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

    private var connectionStatusColor: Color {
        switch droneConnectionState {
        case .connected:
            return isRthActive ? .orange : (flyingState == .flying ? .green : .blue)
        case .connecting:
            return .orange
        case .disconnected, .disconnecting:
            return .red
        }
    }
}
