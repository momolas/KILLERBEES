//
//  SmartRTHAssessment.swift
//  KILLERBEES
//
//  Created by Jules
//

import Foundation
import CoreLocation
@preconcurrency import GroundSdk

/// Évaluation dynamique du retour au point de départ (Smart RTH) et calcul du Point de Non-Retour.
public struct SmartRTHAssessment: Sendable, Equatable {
    /// Distance horizontale directe vers le point Home (en mètres).
    public let distanceToHomeMeters: Double

    /// Altitude relative actuelle par rapport au décollage (en mètres).
    public let currentAltitudeMeters: Double

    /// Altitude minimale de sécurité RTH (en mètres).
    public let rthAltitudeMeters: Double

    /// Vitesse du vent horizontal estimée (en km/h).
    public let windSpeedKmh: Double

    /// Composante de vent le long de l'axe de retour (en km/h, positif = vent de face résistant, négatif = vent arrière favorable).
    public let headwindKmh: Double

    /// Temps de vol estimé pour regagner le point Home et atterrir en toute sécurité (en secondes).
    public let estimatedTimeToHomeSeconds: TimeInterval

    /// Seuil de batterie minimum requis pour exécuter le RTH et atterrir avec réserve de sécurité (0...100%).
    public let batteryRequiredPercent: Int

    /// Niveau de batterie actuel du drone (0...100%).
    public let currentBatteryPercent: Int

    /// Marge de temps de vol sécurisé restante avant d'atteindre le point de non-retour (en secondes, nil si déjà dépassé).
    public let safeTimeMarginSeconds: TimeInterval?

    /// Statut d'accessibilité du point Home fourni par le pilote automatique Parrot.
    public let homeReachability: HomeReachability

    /// Délai avant déclenchement automatique de sécurité du RTH par le drone (en secondes).
    public let autoTriggerDelaySeconds: TimeInterval

    /// Indique si le point de non-retour est franchi (batterie actuelle <= batterie requise).
    public var isPointOfNoReturnPassed: Bool {
        currentBatteryPercent <= batteryRequiredPercent
    }

    /// Indique si le retour est en situation critique ou à risque imminent.
    public var isReturnAtRisk: Bool {
        isPointOfNoReturnPassed ||
        homeReachability == .warning ||
        homeReachability == .critical ||
        homeReachability == .notReachable
    }

    /// Marge de batterie utilisable avant d'atteindre le seuil de RTH (en points de pourcentage).
    public var batteryMarginPoints: Int {
        currentBatteryPercent - batteryRequiredPercent
    }

    public init(
        distanceToHomeMeters: Double,
        currentAltitudeMeters: Double,
        rthAltitudeMeters: Double,
        windSpeedKmh: Double,
        headwindKmh: Double,
        estimatedTimeToHomeSeconds: TimeInterval,
        batteryRequiredPercent: Int,
        currentBatteryPercent: Int,
        safeTimeMarginSeconds: TimeInterval?,
        homeReachability: HomeReachability,
        autoTriggerDelaySeconds: TimeInterval
    ) {
        self.distanceToHomeMeters = distanceToHomeMeters
        self.currentAltitudeMeters = currentAltitudeMeters
        self.rthAltitudeMeters = rthAltitudeMeters
        self.windSpeedKmh = windSpeedKmh
        self.headwindKmh = headwindKmh
        self.estimatedTimeToHomeSeconds = estimatedTimeToHomeSeconds
        self.batteryRequiredPercent = batteryRequiredPercent
        self.currentBatteryPercent = currentBatteryPercent
        self.safeTimeMarginSeconds = safeTimeMarginSeconds
        self.homeReachability = homeReachability
        self.autoTriggerDelaySeconds = autoTriggerDelaySeconds
    }

    /// Calcule dynamiquement l'évaluation Smart RTH à partir de la télémétrie courante.
    public static func compute(
        droneLocation: CLLocationCoordinate2D?,
        homeLocation: CLLocationCoordinate2D?,
        currentAltitude: Double?,
        rthMinAltitude: Double = 30.0,
        windNorthSpeed: Double? = nil,
        windEastSpeed: Double? = nil,
        currentBattery: Int?,
        homeReachability: HomeReachability = .unknown,
        autoTriggerDelay: TimeInterval = 0.0
    ) -> SmartRTHAssessment? {
        guard let droneLoc = droneLocation,
              let homeLoc = homeLocation,
              let battery = currentBattery else {
            return nil
        }

        // Distance horizontale (Haversine via CLLocation)
        let droneCLLocation = CLLocation(latitude: droneLoc.latitude, longitude: droneLoc.longitude)
        let homeCLLocation = CLLocation(latitude: homeLoc.latitude, longitude: homeLoc.longitude)
        let horizontalDistance = droneCLLocation.distance(from: homeCLLocation)

        let altitude = max(0.0, currentAltitude ?? 0.0)
        let rthTargetAltitude = max(rthMinAltitude, 20.0)

        // Calcul du relèvement (azimut en radians) du drone vers le point Home
        let dLon = (homeLoc.longitude - droneLoc.longitude) * .pi / 180.0
        let lat1 = droneLoc.latitude * .pi / 180.0
        let lat2 = homeLoc.latitude * .pi / 180.0
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingToHomeRad = atan2(y, x)

        // Calcul du vent et de sa projection le long du vecteur de retour
        let vNorth = windNorthSpeed ?? 0.0
        let vEast = windEastSpeed ?? 0.0
        let windSpeedMps = sqrt(vNorth * vNorth + vEast * vEast)
        let windSpeedKmh = windSpeedMps * 3.6

        // Composante de vent le long de l'axe de retour :
        // Le vent (vNorth, vEast) souffle vers la direction atan2(vEast, vNorth)
        // Vent le long de la trajectoire : positif si vent arrière favorable, négatif si vent de face contraire
        let windAlongReturnMps = vNorth * cos(bearingToHomeRad) + vEast * sin(bearingToHomeRad)
        // headwind : positif si vent de face contraire (qui ralentit ou consomme plus)
        let headwindMps = -windAlongReturnMps
        let headwindKmh = headwindMps * 3.6

        // Vitesse de croisière nominale Anafi en RTH (~10.0 m/s soit 36 km/h)
        let nominalCruiseSpeedMps = 10.0
        // Vitesse sol effective estimée en tenant compte du vent (minimum 3.0 m/s de pénétration)
        let effectiveGroundSpeedMps = max(3.0, nominalCruiseSpeedMps - max(0.0, headwindMps * 0.75))

        // Temps de vol horizontal
        let horizontalFlightTimeSec = horizontalDistance / effectiveGroundSpeedMps

        // Montée si le drone est sous le plafond de sécurité RTH (montée à ~2.5 m/s)
        let climbDistance = max(0.0, rthTargetAltitude - altitude)
        let climbTimeSec = climbDistance / 2.5

        // Descente finale verticale au point Home (descente à ~2.0 m/s)
        let descentDistance = max(altitude, rthTargetAltitude)
        let descentTimeSec = descentDistance / 2.0

        // Temps total estimé en secondes
        let totalTimeSec = horizontalFlightTimeSec + climbTimeSec + descentTimeSec

        // Consommation nominale de la batterie :
        // Anafi consomme ~3.8 % de batterie par minute en vol normal stabilisé
        let nominalDischargePerMinute = 3.8

        // Facteur de surconsommation en cas de vent de face ou forte brise
        let windPowerPenaltyFactor: Double
        if headwindKmh > 5.0 {
            windPowerPenaltyFactor = 1.0 + min(0.75, (headwindKmh - 5.0) / 40.0)
        } else {
            windPowerPenaltyFactor = 1.0
        }

        let flightBatteryRequired = (totalTimeSec / 60.0) * nominalDischargePerMinute * windPowerPenaltyFactor

        // Réserve de sécurité obligatoire (atterrissage sécurisé, dérive GPS, vent de sol)
        let safetyBufferPercent = 8.0

        // Seuil batterie requis arrondi à l'entier supérieur, bridé entre 10% et 100%
        let requiredBatteryPercent = min(100, max(10, Int(ceil(flightBatteryRequired + safetyBufferPercent))))

        // Calcul de la marge temporelle avant d'atteindre le point de non-retour
        let batteryMargin = Double(battery - requiredBatteryPercent)
        let safeTimeMargin: TimeInterval?
        if batteryMargin > 0 {
            safeTimeMargin = (batteryMargin / nominalDischargePerMinute) * 60.0
        } else {
            safeTimeMargin = nil
        }

        return SmartRTHAssessment(
            distanceToHomeMeters: horizontalDistance,
            currentAltitudeMeters: altitude,
            rthAltitudeMeters: rthTargetAltitude,
            windSpeedKmh: windSpeedKmh,
            headwindKmh: headwindKmh,
            estimatedTimeToHomeSeconds: totalTimeSec,
            batteryRequiredPercent: requiredBatteryPercent,
            currentBatteryPercent: battery,
            safeTimeMarginSeconds: safeTimeMargin,
            homeReachability: homeReachability,
            autoTriggerDelaySeconds: autoTriggerDelay
        )
    }
}
