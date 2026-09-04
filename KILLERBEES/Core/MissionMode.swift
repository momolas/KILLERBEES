//
//  MissionMode.swift
//  KILLERBEES
//
//  Created by Jules
//  Modèle d'Architecture Multi-Missions : Surveillance, Loisir et Chasse
//

import SwiftUI

public enum MissionMode: String, CaseIterable, Identifiable, Sendable {
    case surveillance = "Surveillance"
    case loisir = "Loisir"
    case chasse = "Chasse"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .surveillance: return "Surveillance"
        case .loisir: return "Loisir & Vidéo"
        case .chasse: return "Chasse & Traque"
        }
    }

    public var subtitle: String {
        switch self {
        case .surveillance: return "Périmètre, Détection Intrus, Gardiennage"
        case .loisir: return "Cinématique Douce, 4K HDR, Vue Aérienne"
        case .chasse: return "Poursuite Réactive, Vecteur Fuite, Zoom Rapide"
        }
    }

    public var icon: String {
        switch self {
        case .surveillance: return "shield.checkered"
        case .loisir: return "camera.macro"
        case .chasse: return "scope"
        }
    }

    public var accentColor: Color {
        switch self {
        case .surveillance: return .blue
        case .loisir: return .purple
        case .chasse: return .orange
        }
    }

    // Paramètres Dynamiques de Vol Anafi (GroundSdk)
    public var maxYawSpeed: Double {
        switch self {
        case .surveillance: return 50.0  // Balayage régulier et maintien stationnaire
        case .loisir: return 25.0        // Lacet très doux et cinématique sans saccades
        case .chasse: return 120.0       // Lacet réactif pour ne jamais perdre le gibier
        }
    }

    public var maxPitchRoll: Double {
        switch self {
        case .surveillance: return 20.0  // Stabilité maximale de la caméra
        case .loisir: return 15.0        // Mouvements souples et progressifs
        case .chasse: return 30.0        // Vitesse d'accélération jusqu'à 50 km/h
        }
    }

    public var maxVerticalSpeed: Double {
        switch self {
        case .surveillance: return 2.0
        case .loisir: return 1.5
        case .chasse: return 3.0
        }
    }

    public var hudBadgeTitle: String {
        switch self {
        case .surveillance: return "SURVEILLANCE PÉRIMÈTRE"
        case .loisir: return "VOL CINÉMATIQUE"
        case .chasse: return "TRAQUE GIBIER ACTIF"
        }
    }
}
