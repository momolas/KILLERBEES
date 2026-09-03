//
//  VisionTrackerService.swift
//  KILLERBEES
//
//  Created by Jules
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

    private var yoloModel: VNCoreMLModel?
    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFirstDetection: Bool = true
    private var initialTargetArea: CGFloat = 1.0

    // Champ de vision (FOV) de la caméra de l'Anafi en radians
    private let horizontalFovRad: Double = 1.2043 // 69 degrés
    private let verticalFovRad: Double = 0.7330   // 42 degrés

    init() {
        setupYoloModel()
    }

    private func setupYoloModel() {
        guard let modelUrl = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc") else {
            print("Modèle yolov8n.mlmodelc non trouvé dans le bundle")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Utilise l'Apple Neural Engine (ANE)
            let coreMlModel = try MLModel(contentsOf: modelUrl, configuration: config)
            self.yoloModel = try VNCoreMLModel(for: coreMlModel)
            print("Modèle YOLOv8n chargé avec succès sur le Neural Engine !")
        } catch {
            print("Erreur initialisation YOLOv8n : \(error)")
        }
    }

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

    // MARK: - Détection Automatique Multi-Classes (YOLOv8 CoreML & Vision)

    private func detectObjects(in cgImage: CGImage) {
        if let yoloModel {
            let request = VNCoreMLRequest(model: yoloModel) { [weak self] request, error in
                guard let self, error == nil,
                      let observations = request.results as? [VNRecognizedObjectObservation] else {
                    return
                }

                let objects = observations.compactMap { obs -> DetectedObject? in
                    guard let topLabel = obs.labels.first, topLabel.confidence >= 0.35 else {
                        return nil
                    }

                    let swiftUIBox = self.convertVisionRectToSwiftUI(obs.boundingBox)
                    let translated = self.translateLabel(topLabel.identifier)
                    return DetectedObject(
                        box: swiftUIBox,
                        label: translated,
                        confidence: topLabel.confidence
                    )
                }

                Task { @MainActor in
                    self.detectedObjects = objects
                }
            }

            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        } else {
            // Fallback natif Apple Human Detection
            let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
                guard let self, error == nil, let results = request.results as? [VNHumanObservation] else {
                    return
                }

                let objects = results.map { observation in
                    DetectedObject(
                        box: self.convertVisionRectToSwiftUI(observation.boundingBox),
                        label: "HUMAIN",
                        confidence: observation.confidence
                    )
                }

                Task { @MainActor in
                    self.detectedObjects = objects
                }
            }
            request.upperBodyOnly = false
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
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
            trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
            trackingRequest?.trackingLevel = .accurate
            initialTargetArea = max(currentBox.width * currentBox.height, 0.001)
            isFirstDetection = true
        }

        guard let request = trackingRequest else { return }

        do {
            try sequenceHandler.perform([request], on: cgImage)

            guard let results = request.results as? [VNDetectedObjectObservation],
                  let trackedObservation = results.first,
                  trackedObservation.confidence > 0.3 else {
                // Perte de cible
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
            print("Erreur suivi optique : \(error)")
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
            unlockTarget()
            detectedObjects.removeAll()
        }
    }

    // MARK: - Traduction des Labels COCO

    private func translateLabel(_ identifier: String) -> String {
        switch identifier.lowercased() {
        case "person": return "HUMAIN"
        case "car": return "VOITURE"
        case "motorcycle": return "MOTO"
        case "bicycle": return "VÉLO"
        case "bus": return "BUS"
        case "truck": return "CAMION"
        case "boat": return "BATEAU"
        case "airplane": return "AVION"
        case "dog": return "CHIEN"
        case "cat": return "CHAT"
        case "horse": return "CHEVAL"
        case "sheep": return "MOUTON"
        case "cow": return "BOVIN"
        default: return identifier.uppercased()
        }
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
