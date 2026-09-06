//
//  DroneWatermarkSymbolView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Réticule central fixe d'axe drone (Boresight Watermark) pour le HUD militaire.
struct DroneWatermarkSymbolView: View {
    var body: some View {
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
}
