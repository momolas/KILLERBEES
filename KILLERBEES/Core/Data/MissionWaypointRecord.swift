//
//  MissionWaypointRecord.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation
import SwiftData

/// Enregistrement persistant d'un waypoint de plan de vol MAVLink.
@Model
final class MissionWaypointRecord {
    var id: UUID? = UUID()
    var latitude: Double? = 0.0
    var longitude: Double? = 0.0
    var altitudeMeters: Double? = 15.0
    var sequenceOrder: Int? = 0
    var createdAt: Date? = Date.now

    init(
        id: UUID? = UUID(),
        latitude: Double? = 0.0,
        longitude: Double? = 0.0,
        altitudeMeters: Double? = 15.0,
        sequenceOrder: Int? = 0,
        createdAt: Date? = .now
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.sequenceOrder = sequenceOrder
        self.createdAt = createdAt
    }
}
