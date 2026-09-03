//
//  CockpitMissionStatusBar.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI
import GroundSdk

struct CockpitMissionStatusBar: View {
    let isConnected: Bool
    let isTargetLocked: Bool
    let isTrackingActive: Bool
    let trackingMode: TrackingMode
    let flyingState: FlyingIndicatorsState
    let altitude: Double?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        if !isConnected {
            return .red
        } else if isTargetLocked {
            return trackingMode == .followMe ? .orange : .cyan
        } else if isTrackingActive {
            return .green
        } else if flyingState == .flying {
            return .blue
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if !isConnected {
            return "DRONE DÉCONNECTÉ"
        } else if isTargetLocked {
            return trackingMode == .followMe ? "MISSION : POURSUITE PHYSIQUE" : "MISSION : CADRAGE CAMÉRA"
        } else if isTrackingActive {
            return "SCANNER IA ACTIF — CIBLAGE PRÊT"
        } else if flyingState == .flying {
            let alt = altitude.map { "\(Int($0))M" } ?? "--"
            return "VOL EN COURS — ALT: \(alt)"
        } else {
            return "DRONE AU SOL — PRÊT AU DÉCOLLAGE"
        }
    }
}
