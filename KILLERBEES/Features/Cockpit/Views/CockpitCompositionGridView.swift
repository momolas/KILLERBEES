//
//  CockpitCompositionGridView.swift
//  KILLERBEES
//
//  Created by Jules
//  Grille de Composition Tiers pour Cadrage Cinématique & Paysage
//

import SwiftUI

struct CockpitCompositionGridView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            Path { path in
                // Lignes verticales (1/3 et 2/3)
                path.move(to: CGPoint(x: width / 3.0, y: 0))
                path.addLine(to: CGPoint(x: width / 3.0, y: height))

                path.move(to: CGPoint(x: 2.0 * width / 3.0, y: 0))
                path.addLine(to: CGPoint(x: 2.0 * width / 3.0, y: height))

                // Lignes horizontales (1/3 et 2/3)
                path.move(to: CGPoint(x: 0, y: height / 3.0))
                path.addLine(to: CGPoint(x: width, y: height / 3.0))

                path.move(to: CGPoint(x: 0, y: 2.0 * height / 3.0))
                path.addLine(to: CGPoint(x: width, y: 2.0 * height / 3.0))
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .allowsHitTesting(false)
    }
}
