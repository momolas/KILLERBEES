//
//  CockpitSmartRTHBadge.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

/// Badge tactique HUD affichant les données du Smart RTH (Point de non-retour, distance Home, vent et temps de vol).
struct CockpitSmartRTHBadge: View {
    let smartRTH: SmartRTHAssessment?
    let isRthActive: Bool
    let onTriggerRth: () -> Void
    let onCancelRth: () -> Void
    let onCancelAutoTrigger: () -> Void

    var body: some View {
        if let rth = smartRTH {
            HStack(spacing: 8) {
                // 1. Indicateur Distance & Icône Home
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                        .foregroundStyle(statusColor(for: rth))

                    Text(formattedDistance(rth.distanceToHomeMeters))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.3))

                // 2. Temps de vol de retour estimé (ETA)
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    let minutes = Int(rth.estimatedTimeToHomeSeconds) / 60
                    let seconds = Int(rth.estimatedTimeToHomeSeconds) % 60
                    Text("\(minutes)m\(seconds < 10 ? "0" : "")\(seconds)s")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                // 3. Indicateur de Vent sur l'axe de retour
                if rth.windSpeedKmh > 3.0 {
                    Divider()
                        .frame(height: 12)
                        .background(Color.white.opacity(0.3))

                    HStack(spacing: 3) {
                        Image(systemName: rth.headwindKmh > 2.0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(rth.headwindKmh > 8.0 ? .orange : .cyan)

                        HStack(spacing: 2) {
                            Text(rth.windSpeedKmh, format: .number.precision(.fractionLength(0)))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("km/h")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.3))

                // 4. Statut Tactique & Actions
                if isRthActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("RTH EN COURS")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.orange)

                        Button("Annuler", action: onCancelRth)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.4))
                            .clipShape(.capsule)
                            .foregroundStyle(.white)
                    }
                } else if rth.isPointOfNoReturnPassed {
                    Button(action: onTriggerRth) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.caption2)
                                .symbolEffect(.pulse)
                            Text("NON-RETOUR DÉPASSÉ - RTH")
                                .font(.system(size: 9, weight: .black))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(.capsule)
                        .foregroundStyle(.white)
                    }
                } else if rth.homeReachability == .warning {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .symbolEffect(.pulse)
                        Text("RTH AUTO DANS \(Int(rth.autoTriggerDelaySeconds))s")
                            .font(.system(size: 9, weight: .black))

                        Button("Annuler", action: onCancelAutoTrigger)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.4))
                            .clipShape(.capsule)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.35))
                    .clipShape(.capsule)
                    .foregroundStyle(.white)
                } else {
                    HStack(spacing: 3) {
                        Text("RTH SEUIL \(rth.batteryRequiredPercent)%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.mint)

                        if rth.batteryMarginPoints > 0 {
                            Text("(+\(rth.batteryMarginPoints)%)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.green)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)
            .overlay(
                Capsule().strokeBorder(badgeBorderColor(for: rth), lineWidth: 1)
            )
        }
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            return "\(km.formatted(.number.precision(.fractionLength(1)))) km"
        } else {
            return "\(Int(meters)) m"
        }
    }

    private func statusColor(for rth: SmartRTHAssessment) -> Color {
        if isRthActive { return .orange }
        if rth.isPointOfNoReturnPassed { return .red }
        if rth.homeReachability == .warning { return .yellow }
        return .mint
    }

    private func badgeBorderColor(for rth: SmartRTHAssessment) -> Color {
        if isRthActive { return Color.orange.opacity(0.7) }
        if rth.isPointOfNoReturnPassed { return Color.red.opacity(0.8) }
        if rth.homeReachability == .warning { return Color.yellow.opacity(0.7) }
        return Color.white.opacity(0.2)
    }
}
