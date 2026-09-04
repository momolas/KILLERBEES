//
//  CockpitMilitaryPitchLadderHUD.swift
//  KILLERBEES
//
//  Created by Jules
//  Horizon Artificiel Militaire Central (Pitch Ladder & Heading Tape HUD)
//

import SwiftUI

/// Horizon artificiel militaire central projeté sur le flux vidéo (Pitch Ladder & Heading Tape).
struct CockpitMilitaryPitchLadderHUD: View {
    let pitch: Double       // Tangage en degrés (-90° à +90°)
    let roll: Double        // Roulis en degrés (-180° à +180°)
    let heading: Double     // Cap boussole en degrés (0° à 360°)
    var isEnabled: Bool = true

    // Échelle de translation du tangage : 3,5 points d'écran par degré
    private let pitchScale: CGFloat = 3.5

    var body: some View {
        if isEnabled {
            ZStack {
                // 1. Ruban de Cap Boussole Supérieur (Military Heading Tape)
                VStack {
                    headingTapeView
                        .padding(.top, 64)
                    Spacer()
                }

                // 2. Échelle de Pas Militaire Dynamique (Pitch Ladder)
                ZStack {
                    // Échelle de tangage (bouge avec pitch et roll)
                    pitchLadderRungs
                        .offset(y: CGFloat(pitch) * pitchScale)
                        .rotationEffect(.degrees(-roll))
                        .frame(width: 280, height: 220)
                        .clipped()

                    // Réticule central fixe d'axe drone (Boresight Watermark)
                    droneWatermarkSymbol
                }

                // 3. Indicateur d'arc de roulis supérieur (Roll Sky Pointer)
                VStack {
                    rollPointerView
                        .padding(.top, 110)
                    Spacer()
                }
            }
            .allowsHitTesting(false)
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Réticule Central d'Axe Drone (Boresight)

    private var droneWatermarkSymbol: some View {
        ZStack {
            // Point central
            Circle()
                .fill(.cyan)
                .frame(width: 4, height: 4)

            // Ailettes horizontales avec retour vertical vers le bas
            Path { path in
                // Ailette gauche
                path.move(to: CGPoint(x: -24, y: 0))
                path.addLine(to: CGPoint(x: -8, y: 0))
                path.addLine(to: CGPoint(x: -8, y: 4))

                // Ailette droite
                path.move(to: CGPoint(x: 8, y: 4))
                path.addLine(to: CGPoint(x: 8, y: 0))
                path.addLine(to: CGPoint(x: 24, y: 0))
            }
            .stroke(.cyan, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    // MARK: - Échelons de Tangage (Pitch Ladder Rungs)

    private var pitchLadderRungs: some View {
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

    // Échelon individuel de l'échelle militaire
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

    // Tiret intermédiaire (5°)
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

    // MARK: - Ruban de Cap Supérieur (Heading Tape)

    private var headingTapeView: some View {
        VStack(spacing: 2) {
            // Boîte numérique centrale affichant le cap exact
            HStack(spacing: 3) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 6))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(.cyan)

                Text("\(normalizedHeading.formatted())°")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text(cardinalString(for: normalizedHeading))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.black.opacity(0.45))
            .clipShape(.capsule)
            .overlay(
                Capsule().strokeBorder(.cyan.opacity(0.4), lineWidth: 1)
            )

            // Fenêtre de défilement du ruban de cap (-30° à +30°)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.black.opacity(0.2))
                    .frame(width: 220, height: 16)
                    .clipShape(.rect(cornerRadius: 3))

                // Graduations de cap
                HStack(spacing: 0) {
                    ForEach(-3...3, id: \.self) { offset in
                        let tickDegree = (normalizedHeading + (offset * 10) + 360) % 360
                        VStack(spacing: 1) {
                            Rectangle()
                                .fill(offset == 0 ? .cyan : .white.opacity(0.6))
                                .frame(width: 1, height: offset == 0 ? 8 : 5)

                            if offset % 2 == 0 {
                                Text(headingLabel(for: tickDegree))
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(offset == 0 ? .cyan : .white.opacity(0.8))
                            }
                        }
                        .frame(width: 32)
                    }
                }
                .frame(width: 220)
            }
        }
    }

    // MARK: - Arc de Roulis Supérieur (Roll Pointer)

    private var rollPointerView: some View {
        ZStack {
            // Graduations fixes de roulis (-30°, -20°, -10°, 0°, 10°, 20°, 30°)
            ForEach([-30, -20, -10, 0, 10, 20, 30], id: \.self) { angle in
                Rectangle()
                    .fill(angle == 0 ? .cyan : .white.opacity(0.4))
                    .frame(width: angle == 0 ? 2 : 1, height: angle == 0 ? 6 : 4)
                    .offset(y: -95)
                    .rotationEffect(.degrees(Double(angle)))
            }

            // Flèche mobile de roulis indiquant l'angle actuel
            Image(systemName: "triangle.fill")
                .font(.system(size: 7))
                .foregroundStyle(.cyan)
                .offset(y: -88)
                .rotationEffect(.degrees(-roll))
        }
        .frame(width: 200, height: 20)
    }

    // MARK: - Helpers

    private var normalizedHeading: Int {
        Int((heading.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360))
    }

    private func cardinalString(for deg: Int) -> String {
        switch deg {
        case 338...360, 0..<23: return "N"
        case 23..<68:           return "NE"
        case 68..<113:          return "E"
        case 113..<158:         return "SE"
        case 158..<203:         return "S"
        case 203..<248:         return "SO"
        case 248..<293:         return "O"
        case 293..<338:         return "NO"
        default:                return ""
        }
    }

    private func headingLabel(for deg: Int) -> String {
        switch deg {
        case 0:   return "N"
        case 90:  return "E"
        case 180: return "S"
        case 270: return "O"
        default:  return "\(deg / 10)"
        }
    }
}
