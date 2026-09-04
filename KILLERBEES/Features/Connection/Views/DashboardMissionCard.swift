//
//  DashboardMissionCard.swift
//  KILLERBEES
//
//  Created by Jules
//  Tuile Bento Sélecteur de Mission Tactique : Surveillance, Loisir, Chasse
//

import SwiftUI

struct DashboardMissionCard: View {
    let selectedMode: MissionMode
    let onSelectMode: (MissionMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Titre de la Tuile
            HStack {
                Image(systemName: "slider.horizontal.2.square")
                    .foregroundStyle(.white)
                    .font(.subheadline)

                Text("PROFIL DE MISSION")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)

                Spacer()

                Text(selectedMode.rawValue.uppercased())
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(selectedMode.accentColor.opacity(0.3))
                    .foregroundStyle(selectedMode.accentColor)
                    .clipShape(.capsule)
                    .overlay(
                        Capsule().strokeBorder(selectedMode.accentColor.opacity(0.6), lineWidth: 1)
                    )
            }

            // Sélecteur des 3 Modes Côte à Côte
            HStack(spacing: 8) {
                ForEach(MissionMode.allCases) { mode in
                    Button {
                        HapticFeedback.tap()
                        onSelectMode(mode)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.title3)
                                .foregroundStyle(selectedMode == mode ? mode.accentColor : .secondary)

                            Text(mode.rawValue)
                                .font(.caption)
                                .bold()
                                .foregroundStyle(selectedMode == mode ? .white : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedMode == mode ? mode.accentColor.opacity(0.22) : Color.white.opacity(0.04))
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedMode == mode ? mode.accentColor : Color.white.opacity(0.08), lineWidth: selectedMode == mode ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Détails & Paramètres de Vol du Mode Choisi
            HStack(spacing: 12) {
                // Vitesse de Lacet
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROTATION LACET")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(Int(selectedMode.maxYawSpeed))°/s")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                }

                Divider()
                    .frame(height: 22)
                    .overlay(Color.white.opacity(0.15))

                // Vitesse Max / Inclinaison
                VStack(alignment: .leading, spacing: 2) {
                    Text("INCLINAISON")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(Int(selectedMode.maxPitchRoll))° max")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                }

                Divider()
                    .frame(height: 22)
                    .overlay(Color.white.opacity(0.15))

                // IA & Traitement
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBJECTIF IA")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(aiDescription(for: selectedMode))
                        .font(.caption)
                        .bold()
                        .foregroundStyle(selectedMode.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(.rect(cornerRadius: 8))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func aiDescription(for mode: MissionMode) -> String {
        switch mode {
        case .surveillance: return "Silhouettes & Intrus"
        case .loisir: return "Cinématique & Tiers"
        case .chasse: return "Gibier & Cap Fuite"
        }
    }
}
