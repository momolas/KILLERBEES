//
//  CockpitSmartBatteryBar.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Jauge de batterie intelligente avec visualisation dynamique du Point de Non-Retour (Smart RTH).
struct CockpitSmartBatteryBar: View {
    let batteryLevel: Int?
    let smartRTH: SmartRTHAssessment?

    var body: some View {
        if let level = batteryLevel {
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    // Icône d'alerte si sous le seuil de non-retour
                    if let rth = smartRTH, rth.isPointOfNoReturnPassed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse)
                    }

                    // Pourcentage de batterie
                    HStack(spacing: 1) {
                        Text(level, format: .number)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(statusColor)
                        Text("%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(statusColor.opacity(0.8))
                    }

                    // Temps de vol restant estimé avant point de non-retour
                    if let rth = smartRTH, let safeTime = rth.safeTimeMarginSeconds {
                        let minutes = Int(safeTime) / 60
                        Text("(\(minutes)m)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Barre de jauge avec marqueur Home (Point de non-retour)
                ZStack(alignment: .leading) {
                    // Fond de la barre
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 80, height: 6)

                    // Barre de progression actuelle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeGradient)
                        .frame(width: max(2, 80 * CGFloat(min(100, max(0, level))) / 100.0), height: 6)

                    // Marqueur vertical du Point de Non-Retour (RTH seuil)
                    if let rth = smartRTH, rth.batteryRequiredPercent > 0 {
                        let thresholdRatio = CGFloat(min(100, max(0, rth.batteryRequiredPercent))) / 100.0
                        let markerX = 80 * thresholdRatio

                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 1.5, height: 8)
                            .offset(x: markerX - 0.75)
                            .overlay(alignment: .top) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Color.yellow)
                                    .offset(y: -7)
                            }
                    }
                }
                .frame(width: 80, height: 10, alignment: .bottom)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Batterie \(level) pourcent\(smartRTH?.isPointOfNoReturnPassed == true ? ", alerte point de non retour" : "")")
        }
    }

    private var statusColor: Color {
        if let rth = smartRTH, rth.isPointOfNoReturnPassed {
            return .red
        }
        guard let level = batteryLevel else { return .white }
        switch level {
        case 50...100: return .green
        case 25..<50:  return .yellow
        default:       return .red
        }
    }

    private var gaugeGradient: LinearGradient {
        if let rth = smartRTH, rth.isPointOfNoReturnPassed {
            return LinearGradient(
                colors: [.red, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        guard let level = batteryLevel else {
            return LinearGradient(colors: [.green], startPoint: .leading, endPoint: .trailing)
        }

        if level >= 50 {
            return LinearGradient(
                colors: [.green, .mint],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if level >= 25 {
            return LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [.red, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
