//
//  TrackingMode.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation

/// Modes de suivi automatique de cible disponibles pour le drone.
public enum TrackingMode: String, CaseIterable, Identifiable, Sendable {
    case lookAt = "LOOK-AT"
    case followMe = "FOLLOW-ME"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lookAt: return "Cadrage Look-At"
        case .followMe: return "Poursuite Follow-Me"
        }
    }

    public var icon: String {
        switch self {
        case .lookAt: return "scope"
        case .followMe: return "figure.run"
        }
    }
}
