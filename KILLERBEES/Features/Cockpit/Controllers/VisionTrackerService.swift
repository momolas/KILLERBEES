//
//  VisionTrackerService.swift
//  KILLERBEES
//
//  Created by Jules
//  Framework 100% Natif Apple Vision (https://developer.apple.com/documentation/vision)
//  Optimisé pour .cpuAndNeuralEngine (Apple Neural Engine + CPU)
//

import CoreGraphics
import CoreML
import Foundation
import SwiftUI
import Vision

struct DetectedObject: Identifiable, Sendable {
    let id = UUID()
    let box: CGRect // Coordonnées normalisées SwiftUI [0, 1] (origine haut-gauche)
    let label: String
    let confidence: Float
}

@Observable @MainActor
class VisionTrackerService {
    var isTrackingActive: Bool = false
    var detectedObjects: [DetectedObject] = []
    var lockedTargetBox: CGRect? = nil
    var isTargetLocked: Bool = false

    // Mode de Mission Actif
    var activeMissionMode: MissionMode = .chasse

    // Alertes & Détections Surveillance
    var detectedHumansCount: Int = 0
    var hasIntruderAlert: Bool = false

    // Vecteur de fuite & Mouvement de la Cible (Gibier / Chasse)
    var targetHeadingDeg: Double?
    var targetSpeedKmH: Double?
    var targetBearingCardinal: String?

    var detectedBoxes: [CGRect] {
        detectedObjects.map(\.box)
    }

    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFirstDetection: Bool = true
    private var initialTargetArea: CGFloat = 1.0

    private var previousBoxCenter: CGPoint?
    private var previousTimestamp: TimeInterval?

    // Champ de vision (FOV) de la caméra de l'Anafi en radians
    private let horizontalFovRad: Double = 1.2043 // 69 degrés
    private let verticalFovRad: Double = 0.7330   // 42 degrés

    init() {}

    private var isProcessing: Bool = false

    // MARK: - Analyse d'une Image

    func processFrame(
        _ cgImage: CGImage,
        droneHeading: Double = 0.0,
        droneAltitude: Double = 30.0,
        missionMode: MissionMode? = nil,
        onTargetData: @escaping (Double, Double, Double, Double, Bool) -> Void
    ) {
        if let missionMode {
            self.activeMissionMode = missionMode
        }
        guard isTrackingActive, !isProcessing else { return }
        isProcessing = true

        if let currentTarget = lockedTargetBox {
            trackLockedTarget(
                in: cgImage,
                currentBox: currentTarget,
                droneHeading: droneHeading,
                droneAltitude: droneAltitude,
                onTargetData: onTargetData
            )
            isProcessing = false
        } else {
            Task { [weak self] in
                guard let self else { return }
                self.detectObjects(in: cgImage)
                self.isProcessing = false
            }
        }
    }

    // MARK: - Configuration Matérielle Apple Silicon (.cpuAndNeuralEngine)

    /// Configure une requête Apple Vision pour privilégier le Neural Engine (ANE) et le CPU,
    /// excluant le GPU pour éviter toute saccade ou latence dans le rendu 60 FPS du cockpit.
    private func configureComputeDevices(for request: VNRequest) {
        guard let supportedStages = try? request.supportedComputeStageDevices else { return }

        for (stage, devices) in supportedStages {
            // 1. Priorité absolue à l'Apple Neural Engine (ANE)
            if let neuralEngine = devices.first(where: {
                if case .neuralEngine = $0 { return true }
                return false
            }) {
                request.setComputeDevice(neuralEngine, for: stage)
            } else if let cpu = devices.first(where: {
                // 2. Repli vers le CPU si le Neural Engine n'est pas disponible pour cette étape
                if case .cpu = $0 { return true }
                return false
            }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
    }

    // MARK: - Détection Native Apple Vision (Humains, Animaux, Cibles Saillantes)

    private func detectObjects(in cgImage: CGImage) {
        var newObjects: [DetectedObject] = []
        var requestsToPerform: [VNRequest] = []

        // 1. Requête Silhouettes Humaines (Prioritaire en Surveillance)
        if activeMissionMode == .surveillance || activeMissionMode == .chasse {
            let humanRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
                guard let self, error == nil, let results = request.results as? [VNHumanObservation] else { return }
                for human in results where human.confidence > 0.4 {
                    let box = self.convertVisionRectToSwiftUI(human.boundingBox)
                    newObjects.append(DetectedObject(box: box, label: "HUMAIN", confidence: human.confidence))
                }
            }
            humanRequest.upperBodyOnly = false
            configureComputeDevices(for: humanRequest)
            requestsToPerform.append(humanRequest)
        }

        // 2. Requête Animaux (Prioritaire en Chasse & Traque)
        if activeMissionMode == .chasse || activeMissionMode == .loisir {
            let animalRequest = VNRecognizeAnimalsRequest { [weak self] request, error in
                guard let self, error == nil, let results = request.results as? [VNRecognizedObjectObservation] else { return }
                for animal in results where animal.confidence > 0.4 {
                    let box = self.convertVisionRectToSwiftUI(animal.boundingBox)
                    let topLabel = animal.labels.first?.identifier.lowercased() ?? "animal"
                    let frenchLabel: String
                    switch topLabel {
                    case "dog": frenchLabel = "CHIEN"
                    case "cat": frenchLabel = "CHAT"
                    default: frenchLabel = "GIBIER"
                    }
                    newObjects.append(DetectedObject(box: box, label: frenchLabel, confidence: animal.confidence))
                }
            }
            configureComputeDevices(for: animalRequest)
            requestsToPerform.append(animalRequest)
        }

        // 3. Détection de Saillance / Cibles d'Intérêt (Tous modes)
        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { [weak self] request, error in
            guard let self, error == nil,
                  let result = (request.results as? [VNSaliencyImageObservation])?.first,
                  let salientObjects = result.salientObjects else { return }

            let defaultLabel: String
            switch self.activeMissionMode {
            case .surveillance: defaultLabel = "INTRUSION"
            case .chasse: defaultLabel = "GIBIER"
            case .loisir: defaultLabel = "SUJET"
            }

            for salient in salientObjects where salient.confidence > 0.5 {
                let box = self.convertVisionRectToSwiftUI(salient.boundingBox)
                let alreadyCovered = newObjects.contains { $0.box.intersects(box) }
                if !alreadyCovered && box.width > 0.06 && box.height > 0.06 {
                    newObjects.append(DetectedObject(box: box, label: defaultLabel, confidence: salient.confidence))
                }
            }
        }
        configureComputeDevices(for: saliencyRequest)
        requestsToPerform.append(saliencyRequest)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform(requestsToPerform)
            self.detectedObjects = newObjects

            // Mise à jour de la télémétrie de surveillance
            if activeMissionMode == .surveillance {
                self.detectedHumansCount = newObjects.filter { $0.label == "HUMAIN" }.count
                self.hasIntruderAlert = self.detectedHumansCount > 0
            } else {
                self.detectedHumansCount = 0
                self.hasIntruderAlert = false
            }
        } catch {
            print("Erreur analyse Apple Vision : \(error)")
        }
    }

    private func trackLockedTarget(
        in cgImage: CGImage,
        currentBox: CGRect,
        droneHeading: Double,
        droneAltitude: Double,
        onTargetData: (Double, Double, Double, Double, Bool) -> Void
    ) {
        let visionBox = convertSwiftUIRectToVision(currentBox)

        if trackingRequest == nil {
            let observation = VNDetectedObjectObservation(boundingBox: visionBox)
            let request = VNTrackObjectRequest(detectedObjectObservation: observation)
            request.trackingLevel = .accurate
            configureComputeDevices(for: request)
            trackingRequest = request
            initialTargetArea = max(currentBox.width * currentBox.height, 0.001)
            isFirstDetection = true
        }

        guard let request = trackingRequest else { return }

        do {
            try sequenceHandler.perform([request], on: cgImage)

            guard let results = request.results as? [VNDetectedObjectObservation],
                  let trackedObservation = results.first,
                  trackedObservation.confidence > 0.3 else {
                return
            }

            let newVisionBox = trackedObservation.boundingBox
            let newSwiftUIBox = convertVisionRectToSwiftUI(newVisionBox)
            self.lockedTargetBox = newSwiftUIBox
            self.isTargetLocked = true

            // Calcul des angles d'azimut et d'élévation
            let centerX = newSwiftUIBox.midX
            let centerY = newSwiftUIBox.midY

            // Calcul du vecteur de déplacement de la cible (Gibier)
            calculateTargetMotion(
                currentCenter: CGPoint(x: centerX, y: centerY),
                droneHeading: droneHeading,
                droneAltitude: droneAltitude
            )

            let deltaX = Double(centerX - 0.5) // [-0.5, 0.5]
            let deltaY = Double(0.5 - centerY) // [-0.5, 0.5], positif vers le haut

            let azimuth = deltaX * horizontalFovRad
            let elevation = deltaY * verticalFovRad

            let currentArea = newSwiftUIBox.width * newSwiftUIBox.height
            let changeOfScale = Double((currentArea - initialTargetArea) / initialTargetArea)
            let confidence = Double(trackedObservation.confidence)

            onTargetData(azimuth, elevation, changeOfScale, confidence, isFirstDetection)
            isFirstDetection = false

        } catch {
            print("Erreur suivi optique Apple Vision : \(error)")
        }
    }

    // MARK: - Analyse Dynamique du Mouvement (Vecteur de Fuite)

    private func calculateTargetMotion(currentCenter: CGPoint, droneHeading: Double, droneAltitude: Double) {
        let now = Date().timeIntervalSince1970
        guard let prevCenter = previousBoxCenter, let prevT = previousTimestamp else {
            previousBoxCenter = currentCenter
            previousTimestamp = now
            return
        }

        let dt = now - prevT
        guard dt >= 0.04 else { return }

        let dx = Double(currentCenter.x - prevCenter.x)
        let dy = Double(currentCenter.y - prevCenter.y)
        let pixelDistance = hypot(dx, dy)

        previousBoxCenter = currentCenter
        previousTimestamp = now

        if pixelDistance > 0.003 {
            let relativeAngleDeg = atan2(dx, -dy) * 180.0 / .pi
            var trueHeading = (droneHeading + relativeAngleDeg).truncatingRemainder(dividingBy: 360.0)
            if trueHeading < 0 { trueHeading += 360.0 }

            if let existingHeading = targetHeadingDeg {
                self.targetHeadingDeg = existingHeading * 0.6 + trueHeading * 0.4
            } else {
                self.targetHeadingDeg = trueHeading
            }
            self.targetBearingCardinal = cardinalDirection(from: self.targetHeadingDeg ?? trueHeading)

            let groundMetersPerScreenUnit = max(10.0, droneAltitude) * 1.37
            let groundDistanceMeters = pixelDistance * groundMetersPerScreenUnit
            let instantaneousSpeedKmH = (groundDistanceMeters / dt) * 3.6

            let clampedSpeed = min(75.0, instantaneousSpeedKmH)
            if let existingSpeed = targetSpeedKmH {
                self.targetSpeedKmH = existingSpeed * 0.6 + clampedSpeed * 0.4
            } else {
                self.targetSpeedKmH = clampedSpeed
            }
        } else {
            if let speed = targetSpeedKmH {
                self.targetSpeedKmH = max(0.0, speed * 0.85)
            }
        }
    }

    private func cardinalDirection(from degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return directions[index]
    }

    // MARK: - Gestion du Verrouillage Tactique & Aimantation Magnétique (Magnetic Snap)

    func lockTarget(at point: CGPoint) {
        // 1. Touche directe à l'intérieur d'une boîte existante
        if let directHit = detectedObjects.first(where: { $0.box.contains(point) }) {
            lockBox(directHit.box)
            return
        }

        // 2. Aimantation Magnétique (Magnetic Snap) :
        // Détecte la cible la plus proche dans un rayon tolérant de 10% de l'écran
        let snapRadius: CGFloat = 0.10
        let nearest = detectedObjects
            .map { obj -> (object: DetectedObject, distance: CGFloat) in
                let center = CGPoint(x: obj.box.midX, y: obj.box.midY)
                let dx = center.x - point.x
                let dy = center.y - point.y
                return (obj, sqrt(dx * dx + dy * dy))
            }
            .filter { $0.distance <= snapRadius }
            .min(by: { $0.distance < $1.distance })

        if let snapped = nearest {
            lockBox(snapped.object.box)
        } else {
            // 3. Tracé d'un cadre manuel centré sur le point
            let size: CGFloat = 0.15
            let manualBox = CGRect(
                x: max(0, min(point.x - size / 2, 1.0 - size)),
                y: max(0, min(point.y - size / 2, 1.0 - size)),
                width: size,
                height: size
            )
            lockBox(manualBox)
        }
    }

    func lockBox(_ rect: CGRect) {
        unlockTarget(silent: true)
        lockedTargetBox = rect
        isTargetLocked = true
        isFirstDetection = true
        trackingRequest = nil
        HapticFeedback.targetLocked()
    }

    func unlockTarget(silent: Bool = false) {
        if isTargetLocked && !silent {
            HapticFeedback.targetLost()
        }
        lockedTargetBox = nil
        isTargetLocked = false
        trackingRequest = nil
        isFirstDetection = true
        sequenceHandler = VNSequenceRequestHandler()
        targetHeadingDeg = nil
        targetSpeedKmH = nil
        targetBearingCardinal = nil
        previousBoxCenter = nil
        previousTimestamp = nil
    }

    func toggleTracking() {
        isTrackingActive.toggle()
        if !isTrackingActive {
            stopTracking()
        }
    }

    func stopTracking() {
        isTrackingActive = false
        isProcessing = false
        unlockTarget()
        detectedObjects.removeAll()
    }

    // MARK: - Conversion de Coordonnées

    private func convertVisionRectToSwiftUI(_ visionRect: CGRect) -> CGRect {
        CGRect(
            x: visionRect.origin.x,
            y: 1.0 - visionRect.origin.y - visionRect.size.height,
            width: visionRect.size.width,
            height: visionRect.size.height
        )
    }

    private func convertSwiftUIRectToVision(_ swiftUIRect: CGRect) -> CGRect {
        CGRect(
            x: swiftUIRect.origin.x,
            y: 1.0 - swiftUIRect.origin.y - swiftUIRect.size.height,
            width: swiftUIRect.size.width,
            height: swiftUIRect.size.height
        )
    }
}
