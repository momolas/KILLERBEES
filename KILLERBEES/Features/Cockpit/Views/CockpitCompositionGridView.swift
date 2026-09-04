//
//  CockpitCompositionGridView.swift
//  KILLERBEES
//
//  Created by Jules
//  Grille de Composition Tiers pour Cadrage Cinématique & Paysage
//

import SwiftUI

/// Forme géométrique de la règle des tiers pour le cadrage photo/cinématographique.
struct CompositionGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

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

        return path
    }
}

/// Vue de superposition affichant la grille des tiers sans GeometryReader.
struct CockpitCompositionGridView: View {
    var body: some View {
        CompositionGridShape()
            .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .allowsHitTesting(false)
    }
}
