//
//  FlightLog.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation
import SwiftData

/// Enregistrement d'un vol avec statistiques de mission et de télémétrie.
@Model
final class FlightLog {
    var id: UUID? = UUID()
    var date: Date? = Date.now
    var droneUid: String? = ""
    var droneName: String? = ""
    var durationSeconds: TimeInterval? = 0
    var maxAltitudeMeters: Double? = 0
    var maxSpeedKmh: Double? = 0
    var missionMode: String? = "Loisir"
    var isFccEnabled: Bool? = false

    init(
        id: UUID? = UUID(),
        date: Date? = .now,
        droneUid: String? = "",
        droneName: String? = "",
        durationSeconds: TimeInterval? = 0,
        maxAltitudeMeters: Double? = 0,
        maxSpeedKmh: Double? = 0,
        missionMode: String? = "Loisir",
        isFccEnabled: Bool? = false
    ) {
        self.id = id
        self.date = date
        self.droneUid = droneUid
        self.droneName = droneName
        self.durationSeconds = durationSeconds
        self.maxAltitudeMeters = maxAltitudeMeters
        self.maxSpeedKmh = maxSpeedKmh
        self.missionMode = missionMode
        self.isFccEnabled = isFccEnabled
    }
}
