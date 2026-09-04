//
//  DetectedObject.swift
//  KILLERBEES
//
//  Created by Jules
//

import CoreGraphics
import Foundation

/// Objet détecté dans le flux vidéo par le moteur de vision par ordinateur Core AI.
public struct DetectedObject: Identifiable, Sendable {
    public let id = UUID()
    public let box: CGRect // Coordonnées normalisées SwiftUI [0, 1] (origine haut-gauche)
    public let label: String
    public let confidence: Float
    public var orientedAngleRad: Float? = nil // Angle d'orientation OBB en radians
    public var orientedCorners: [CGPoint]? = nil // 4 sommets OBB normalisés [0, 1]
    public var hasSilhouetteMask: Bool = false // Silhouette détourée au pixel près

    public init(
        box: CGRect,
        label: String,
        confidence: Float,
        orientedAngleRad: Float? = nil,
        orientedCorners: [CGPoint]? = nil,
        hasSilhouetteMask: Bool = false
    ) {
        self.box = box
        self.label = label
        self.confidence = confidence
        self.orientedAngleRad = orientedAngleRad
        self.orientedCorners = orientedCorners
        self.hasSilhouetteMask = hasSilhouetteMask
    }
}
