//
//  CockpitHeadingTapeView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Ruban de cap boussole militaire supérieur (Heading Tape).
struct CockpitHeadingTapeView: View {
    let heading: Double

    var body: some View {
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
