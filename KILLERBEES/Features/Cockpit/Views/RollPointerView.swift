//
//  RollPointerView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Indicateur d'arc de roulis supérieur (Roll Pointer) pour le HUD militaire.
struct RollPointerView: View {
    let roll: Double

    var body: some View {
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
}
