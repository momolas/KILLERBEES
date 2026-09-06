//
//  CockpitCompositionGridView.swift
//  KILLERBEES
//
//  Created by Jules
//  Grille de Composition Tiers pour Cadrage Cinématique & Paysage
//

import SwiftUI

/// Vue de superposition affichant la grille des tiers sans GeometryReader.
struct CockpitCompositionGridView: View {
    var body: some View {
        CompositionGridShape()
            .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .allowsHitTesting(false)
    }
}
