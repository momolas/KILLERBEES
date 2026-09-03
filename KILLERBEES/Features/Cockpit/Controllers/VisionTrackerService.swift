//
//  VisionTrackerService.swift
//  KILLERBEES
//
//  Created by Jules
//

import CoreGraphics
import Foundation
import SwiftUI
import Vision

@Observable @MainActor
class VisionTrackerService {
    var isTrackingActive: Bool = false
    var detectedBoxes: [CGRect] = [] // Coordonnées normalisées SwiftUI [0, 1] (origine haut-gauche)
    var lockedTargetBox: CGRect? = nil
    var isTargetLocked: Bool = false

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

    // MARK: - Détection Automatique de Silhouettes (Human Detection)

    private func detectObjects(in cgImage: CGImage) {
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let self, error == nil, let results = request.results as? [VNHumanObservation] else {
                return
            }

            Task { @MainActor in
                self.detectedBoxes = results.map { observation in
                    self.convertVisionRectToSwiftUI(observation.boundingBox)
                }
            }
        }

        request.upperBodyOnly = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
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
        // Vérifier si le point touche une boîte déjà détectée
        if let tappedBox = detectedBoxes.first(where: { $0.contains(point) }) {
            lockBox(tappedBox)
        } else {
            // Créer une boîte personnalisée autour du tap (ex: 15% de largeur/hauteur)
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
            detectedBoxes.removeAll()
        }
    }

    // MARK: - Conversion de Coordonnées

    // Vision : origine bas-gauche
    // SwiftUI : origine haut-gauche
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
