//
//  CockpitGameVectorBadge.swift
//  KILLERBEES
//
//  Created by Jules
//  Badge HUD de Traque Cynégétique : Cap & Vitesse du Gibier en Temps Réel
//

import SwiftUI

struct CockpitGameVectorBadge: View {
    let headingDeg: Double?
    let speedKmH: Double?
    let cardinal: String?
    let isProfileActive: Bool
    let onToggleProfile: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icône Gibier & Statut
            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.yellow)

                Text("GIBIER TRAQUÉ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.yellow)
            }

            Divider()
                .frame(height: 14)
                .background(Color.white.opacity(0.2))

            // Cap de fuite
            HStack(spacing: 4) {
                Text("CAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                if let heading = headingDeg, let card = cardinal {
                    Text("\(Int(heading))° \(card)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("--")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider()
                .frame(height: 14)
                .background(Color.white.opacity(0.2))

            // Vitesse estimée
            HStack(spacing: 4) {
                Text("VITESSE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                if let speed = speedKmH, speed > 0.5 {
                    Text("\(Int(speed)) KM/H")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(speed > 25.0 ? .red : .green)
                } else {
                    Text("À L'ARRÊT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Divider()
                .frame(height: 14)
                .background(Color.white.opacity(0.2))

            // Bouton Toggle Profil 120°/s
            Button {
                HapticFeedback.tap()
                onToggleProfile()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text(isProfileActive ? "LACET 120°/S" : "LACET 60°/S")
                        .font(.system(size: 8, weight: .black))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isProfileActive ? Color.yellow.opacity(0.25) : Color.white.opacity(0.1))
                .foregroundStyle(isProfileActive ? Color.yellow : Color.white.opacity(0.7))
                .clipShape(.capsule)
            }
            .accessibilityLabel(isProfileActive ? "Désactiver mode lacet 120 degrés par seconde" : "Activer mode lacet 120 degrés par seconde")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4)
    }
}
