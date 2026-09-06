//
//  PitchLadderRungsView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Échelle de pas militaire dynamique (Pitch Ladder Rungs) avec échelons de tangage gradués.
struct PitchLadderRungsView: View {
    let pitchScale: CGFloat

    var body: some View {
        ZStack {
            // Ligne d'horizon principale (0°)
            HStack(spacing: 40) {
                HStack(spacing: 4) {
                    Text("0")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                    Rectangle()
                        .fill(.cyan)
                        .frame(width: 70, height: 1.5)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.cyan)
                        .frame(width: 70, height: 1.5)
                    Text("0")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }

            // Échelons positifs (Montée / Climb : +10°, +20°, +30°)
            ForEach([10, 20, 30], id: \.self) { deg in
                pitchRung(degrees: deg, isClimb: true)
                    .offset(y: -CGFloat(deg) * pitchScale)
            }

            // Ticks intermédiaires positifs (+5°, +15°, +25°)
            ForEach([5, 15, 25], id: \.self) { deg in
                intermediateTick
                    .offset(y: -CGFloat(deg) * pitchScale)
            }

            // Échelons négatifs (Descente / Dive : -10°, -20°, -30°)
            ForEach([10, 20, 30], id: \.self) { deg in
                pitchRung(degrees: deg, isClimb: false)
                    .offset(y: CGFloat(deg) * pitchScale)
            }

            // Ticks intermédiaires négatifs (-5°, -15°, -25°)
            ForEach([5, 15, 25], id: \.self) { deg in
                intermediateTick
                    .offset(y: CGFloat(deg) * pitchScale)
            }
        }
    }

    private func pitchRung(degrees: Int, isClimb: Bool) -> some View {
        HStack(spacing: 34) {
            // Côté gauche
            HStack(spacing: 4) {
                Text(degrees.formatted())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.85))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: isClimb ? 5 : -5))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 45, y: 0))
                }
                .stroke(
                    .cyan.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: isClimb ? [] : [4, 3])
                )
                .frame(width: 45, height: 6)
            }

            // Côté droit
            HStack(spacing: 4) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 45, y: 0))
                    path.addLine(to: CGPoint(x: 45, y: isClimb ? 5 : -5))
                }
                .stroke(
                    .cyan.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: isClimb ? [] : [4, 3])
                )
                .frame(width: 45, height: 6)

                Text(degrees.formatted())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.85))
            }
        }
    }

    private var intermediateTick: some View {
        HStack(spacing: 50) {
            Rectangle()
                .fill(.cyan.opacity(0.5))
                .frame(width: 20, height: 1)

            Rectangle()
                .fill(.cyan.opacity(0.5))
                .frame(width: 20, height: 1)
        }
    }
}
