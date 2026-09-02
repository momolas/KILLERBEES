//
//  CockpitAttitudeIndicator.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitAttitudeIndicator: View {
    let pitch: Double
    let roll: Double
    let heading: Double

    var body: some View {
        VStack(spacing: 4) {
            // Indicateur de Cap Boussole (Heading)
            HStack(spacing: 4) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.cyan)
                    .rotationEffect(.degrees(-heading))
                Text("\(Int(heading))° \(compassDirection(for: heading))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(.capsule)

            // Horizon Artificiel Compact
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 54, height: 54)

                // Ligne d'horizon rotative (Roll) et translatée (Pitch)
                Rectangle()
                    .fill(Color.cyan.opacity(0.8))
                    .frame(width: 38, height: 2)
                    .offset(y: CGFloat(min(max(-pitch * 0.8, -18), 18)))
                    .rotationEffect(.degrees(-roll))

                // Réticule fixe central (Drone)
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 8, height: 8)

                Path { path in
                    path.move(to: CGPoint(x: 10, y: 27))
                    path.addLine(to: CGPoint(x: 20, y: 27))
                    path.move(to: CGPoint(x: 34, y: 27))
                    path.addLine(to: CGPoint(x: 44, y: 27))
                }
                .stroke(Color.yellow, lineWidth: 2)
            }
            .frame(width: 54, height: 54)
        }
    }

    private func compassDirection(for degrees: Double) -> String {
        let normalized = Int((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360))
        switch normalized {
        case 338...360, 0..<23: return "N"
        case 23..<68:           return "NE"
        case 68..<113:          return "E"
        case 113..<158:         return "SE"
        case 158..<203:         return "S"
        case 203..<248:         return "SO"
        case 248..<293:         return "O"
        default:                return "NO"
        }
    }
}
