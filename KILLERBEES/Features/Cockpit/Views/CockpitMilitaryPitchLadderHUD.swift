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
                    CockpitHeadingTapeView(heading: heading)
                        .padding(.top, 72)
                    Spacer()
                }

                // 2. Échelle de Pas Militaire Dynamique (Pitch Ladder)
                ZStack {
                    // Échelle de tangage (bouge avec pitch et roll)
                    PitchLadderRungsView(pitchScale: pitchScale)
                        .offset(y: CGFloat(pitch) * pitchScale)
                        .rotationEffect(.degrees(-roll))
                        .frame(width: 260, height: 200)
                        .clipped()

                    // Réticule central fixe d'axe drone (Boresight Watermark)
                    DroneWatermarkSymbolView()
                }

                // 3. Indicateur d'arc de roulis supérieur (Roll Sky Pointer)
                VStack {
                    RollPointerView(roll: roll)
                        .padding(.top, 116)
                    Spacer()
                }
            }
            .opacity(0.5)
            .allowsHitTesting(false)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
    }
}
