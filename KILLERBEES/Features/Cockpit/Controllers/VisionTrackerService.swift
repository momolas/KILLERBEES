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

    var detectedBoxes: [CGRect] {
        detectedObjects.map(\.box)
    }

    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFirstDetection: Bool = true
    private var initialTargetArea: CGFloat = 1.0

    // Champ de vision (FOV) de la caméra de l'Anafi en radians
    private let horizontalFovRad: Double = 1.2043 // 69 degrés
    private let verticalFovRad: Double = 0.7330   // 42 degrés

    init() {}

    // MARK: - Analyse d'une Image

    func processFrame(
        _ cgImage: CGImage,
        onTargetData: (Double, Double, Double, Double, Bool) -> Void
    ) {
        guard isTrackingActive else { return }

        if let currentTarget = lockedTargetBox {
            trackLockedTarget(in: cgImage, currentBox: currentTarget, onTargetData: onTargetData)
        } else {
            detectObjects(in: cgImage)
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

        // 1. Requête Native Apple : Détection de Silhouettes et Corps Humains
        let humanRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let self, error == nil, let results = request.results as? [VNHumanObservation] else { return }
            for human in results where human.confidence > 0.4 {
                let box = self.convertVisionRectToSwiftUI(human.boundingBox)
                newObjects.append(DetectedObject(box: box, label: "HUMAIN", confidence: human.confidence))
            }
        }
        humanRequest.upperBodyOnly = false
        configureComputeDevices(for: humanRequest)

        // 2. Requête Native Apple : Reconnaissance d'Animaux
        let animalRequest = VNRecognizeAnimalsRequest { [weak self] request, error in
            guard let self, error == nil, let results = request.results as? [VNRecognizedObjectObservation] else { return }
            for animal in results where animal.confidence > 0.4 {
                let box = self.convertVisionRectToSwiftUI(animal.boundingBox)
                let topLabel = animal.labels.first?.identifier.lowercased() ?? "animal"
                let frenchLabel: String
                switch topLabel {
                case "dog": frenchLabel = "CHIEN"
                case "cat": frenchLabel = "CHAT"
                default: frenchLabel = "ANIMAL"
                }
                newObjects.append(DetectedObject(box: box, label: frenchLabel, confidence: animal.confidence))
            }
        }
        configureComputeDevices(for: animalRequest)

        // 3. Requête Native Apple : Détection de Saillance / Cibles d'Intérêt (Véhicules, Objets Mobiles)
        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { [weak self] request, error in
            guard let self, error == nil,
                  let result = (request.results as? [VNSaliencyImageObservation])?.first,
                  let salientObjects = result.salientObjects else { return }

            for salient in salientObjects where salient.confidence > 0.5 {
                let box = self.convertVisionRectToSwiftUI(salient.boundingBox)
                let alreadyCovered = newObjects.contains { $0.box.intersects(box) }
                if !alreadyCovered && box.width > 0.06 && box.height > 0.06 {
                    newObjects.append(DetectedObject(box: box, label: "CIBLE", confidence: salient.confidence))
                }
            }
        }
        configureComputeDevices(for: saliencyRequest)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([humanRequest, animalRequest, saliencyRequest])
            self.detectedObjects = newObjects
        } catch {
            print("Erreur analyse Apple Vision : \(error)")
        }
    }

    // MARK: - Poursuite Continue de Cible Verrouillée (VNTrackObjectRequest)

    private func trackLockedTarget(
        in cgImage: CGImage,
        currentBox: CGRect,
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

    // MARK: - Gestion du Verrouillage

    func lockTarget(at point: CGPoint) {
        if let tappedObject = detectedObjects.first(where: { $0.box.contains(point) }) {
            lockBox(tappedObject.box)
        } else {
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
        unlockTarget()
        lockedTargetBox = rect
        isTargetLocked = true
        isFirstDetection = true
        trackingRequest = nil
    }

    func unlockTarget() {
        lockedTargetBox = nil
        isTargetLocked = false
        trackingRequest = nil
        isFirstDetection = true
        sequenceHandler = VNSequenceRequestHandler()
    }

    func toggleTracking() {
        isTrackingActive.toggle()
        if !isTrackingActive {
            stopTracking()
        }
    }

    func stopTracking() {
        isTrackingActive = false
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
