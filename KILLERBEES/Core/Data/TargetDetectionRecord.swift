//
//  TargetDetectionRecord.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation
import SwiftData

/// Enregistrement persistant d'une cible ou d'une alerte d'intrusion détectée par le flux IA.
@Model
final class TargetDetectionRecord {
    var id: UUID? = UUID()
    var timestamp: Date? = Date.now
    var label: String? = ""
    var confidence: Float? = 0.0
    var latitude: Double? = 0.0
    var longitude: Double? = 0.0
    var headingDeg: Double? = nil
    var speedKmH: Double? = nil

    init(
        id: UUID? = UUID(),
        timestamp: Date? = .now,
        label: String? = "",
        confidence: Float? = 0.0,
        latitude: Double? = 0.0,
        longitude: Double? = 0.0,
        headingDeg: Double? = nil,
        speedKmH: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.confidence = confidence
        self.latitude = latitude
        self.longitude = longitude
        self.headingDeg = headingDeg
        self.speedKmH = speedKmH
    }
}
