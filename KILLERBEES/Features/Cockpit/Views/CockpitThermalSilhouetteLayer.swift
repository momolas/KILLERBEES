//
//  CockpitThermalSilhouetteLayer.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Calque d'affichage de la silhouette thermique issue de la segmentation YOLO.
struct CockpitThermalSilhouetteLayer: View {
    let cgImage: CGImage
    let color: Color

    var body: some View {
        Image(decorative: cgImage, scale: 1.0, orientation: .up)
            .resizable()
            .scaledToFill()
            .colorMultiply(color)
            .opacity(0.40)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}
