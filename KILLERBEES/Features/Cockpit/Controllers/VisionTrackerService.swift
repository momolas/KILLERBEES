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
import UltralyticsYOLO

struct DetectedObject: Identifiable, Sendable {
    let id = UUID()
    let box: CGRect // Coordonnées normalisées SwiftUI [0, 1] (origine haut-gauche)
    let label: String
    let confidence: Float
    var orientedAngleRad: Float? = nil // Angle d'orientation OBB en radians
    var orientedCorners: [CGPoint]? = nil // 4 sommets OBB normalisés [0, 1]
    var hasSilhouetteMask: Bool = false // Silhouette détourée au pixel près
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

    // Identification Précise de l'Espèce (Taxonomie Apple Vision)
    var targetSpeciesName: String?
    var targetSpeciesIcon: String?
    private var trackingFrameCounter: Int = 0

    var detectedBoxes: [CGRect] {
        detectedObjects.map(\.box)
    }

    private var trackingRequest: VNTrackObjectRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var isFirstDetection: Bool = true
    private var initialTargetArea: CGFloat = 1.0
    private var trackingLossCounter: Int = 0

    private var previousBoxCenter: CGPoint?
    private var previousTimestamp: TimeInterval?

    // Champ de vision (FOV) de la caméra de l'Anafi en radians
    private let horizontalFovRad: Double = 1.2043 // 69 degrés
    private let verticalFovRad: Double = 0.7330   // 42 degrés

    // MARK: - Moteur Ultralytics YOLO26 (Apple Neural Engine)
    private var yoloSeg: YOLO?
    private var yoloDetect: YOLO?
    private var isYoloSegReady: Bool = false
    private var isYoloDetectReady: Bool = false

    // Calque de silhouette d'instance (Effet vision thermique / nocturne)
    var segmentationMaskImage: CGImage? = nil
    var isThermalMaskEnabled: Bool = true

    init() {
        setupYOLO()
    }

    private func setupYOLO() {
        // 1. Modèle de Segmentation & OBB (Prioritaire)
        let segIdentifier: String
        if let segURL = Bundle.main.url(forResource: "yolo26n-seg", withExtension: "mlmodelc") {
            segIdentifier = segURL.path
        } else if let segPackageURL = Bundle.main.url(forResource: "yolo26n-seg", withExtension: "mlpackage") {
            segIdentifier = segPackageURL.path
        } else {
            segIdentifier = "yolo26n-seg"
        }

        yoloSeg = YOLO(segIdentifier, task: .segment, useGpu: false) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    print("⚡️ Ultralytics YOLO26n-SEG (Segmentation & OBB sur Neural Engine) initialisé.")
                    self?.isYoloSegReady = true
                case .failure(let error):
                    print("⚠️ Ultralytics YOLO26n-SEG indisponible (\(error)), repli sur détection.")
                    self?.isYoloSegReady = false
                }
            }
        }

        // 2. Modèle de Détection standard de secours
        let detIdentifier: String
        if let detURL = Bundle.main.url(forResource: "yolo26n", withExtension: "mlmodelc") {
            detIdentifier = detURL.path
        } else if let detPackageURL = Bundle.main.url(forResource: "yolo26n", withExtension: "mlpackage") {
            detIdentifier = detPackageURL.path
        } else {
            detIdentifier = "yolo26n"
        }

        yoloDetect = YOLO(detIdentifier, task: .detect, useGpu: false) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.isYoloDetectReady = true
                case .failure:
                    self?.isYoloDetectReady = false
                }
            }
        }
    }

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

    // MARK: - Détection d'Objets (YOLO26n-SEG + OBB + Repli Apple Vision)

    private func detectObjects(in cgImage: CGImage) {
        // Priorité 1 : Moteur YOLO26n-SEG (Segmentation + Boîtes + OBB)
        if isYoloSegReady, let yoloSeg {
            let segObjects = detectWithYOLOSeg(yoloSeg, in: cgImage)
            if !segObjects.isEmpty {
                self.detectedObjects = segObjects
                updateSurveillanceTelemetry(with: segObjects)
                return
            }
        }

        // Priorité 2 : Moteur YOLO26n Détection Standard
        if isYoloDetectReady, let yoloDetect {
            let detObjects = detectWithYOLODetect(yoloDetect, in: cgImage)
            if !detObjects.isEmpty {
                self.detectedObjects = detObjects
                self.segmentationMaskImage = nil
                updateSurveillanceTelemetry(with: detObjects)
                return
            }
        }

        // Priorité 3 : Repli sur Apple Vision
        self.segmentationMaskImage = nil
        detectObjectsWithAppleVision(in: cgImage)
    }

    private func detectWithYOLOSeg(_ yolo: YOLO, in cgImage: CGImage) -> [DetectedObject] {
        let result = yolo(cgImage)
        guard !result.boxes.isEmpty else {
            self.segmentationMaskImage = nil
            return []
        }

        // Masque de silhouette combiné pour affichage thermique dans le cockpit
        self.segmentationMaskImage = result.masks?.combinedMask
        let rawMasks = result.masks?.masks

        var objects: [DetectedObject] = []

        for (index, box) in result.boxes.enumerated() where box.conf > 0.25 {
            let swiftUIBox = box.xywhn
            var label = box.cls.uppercased()
            var conf = box.conf
            let clsLower = box.cls.lowercased()

            // Calcul de la boîte orientée (OBB) par analyse des moments de la silhouette
            let instanceMask = (rawMasks != nil && index < rawMasks!.count) ? rawMasks![index] : nil
            let (angleRad, corners) = calculateOrientation(from: instanceMask, box: swiftUIBox)

            if clsLower == "person" {
                label = "HUMAIN"
            } else if ["car", "truck", "bus", "motorcycle", "bicycle"].contains(clsLower) {
                label = "VÉHICULE"
            } else if ["dog", "cat", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "bird"].contains(clsLower) {
                let visionBox = convertSwiftUIRectToVision(swiftUIBox)
                if let species = classifyWildlifeSpecies(in: cgImage, visionRect: visionBox) {
                    label = "\(species.icon) \(species.label)"
                    conf = max(conf, species.confidence)
                } else {
                    switch clsLower {
                    case "dog": label = "🐾 CANIDÉ"
                    case "cat": label = "🐾 FÉLIN"
                    case "horse": label = "🐎 ÉQUIDÉ"
                    case "cow": label = "🐄 BOVIN"
                    case "sheep": label = "🐑 MOUTON"
                    case "bird": label = "🦆 OISEAU / GIBIER"
                    case "bear": label = "🐻 OURS"
                    default: label = "🐾 GIBIER"
                    }
                }

                // En mode chasse : cap instantané issu de l'axe tête-queue OBB dès la 1ère image
                if activeMissionMode == .chasse && index == 0 && lockedTargetBox == nil {
                    let headingDeg = Double((angleRad * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0))
                    self.targetHeadingDeg = headingDeg
                    self.targetBearingCardinal = cardinalDirection(from: headingDeg)
                }
            } else if activeMissionMode == .chasse {
                let visionBox = convertSwiftUIRectToVision(swiftUIBox)
                if let species = classifyWildlifeSpecies(in: cgImage, visionRect: visionBox) {
                    label = "\(species.icon) \(species.label)"
                    conf = max(conf, species.confidence)
                }
            }

            objects.append(DetectedObject(
                box: swiftUIBox,
                label: label,
                confidence: conf,
                orientedAngleRad: angleRad,
                orientedCorners: corners,
                hasSilhouetteMask: instanceMask != nil
            ))
        }

        return objects
    }

    private func detectWithYOLODetect(_ yolo: YOLO, in cgImage: CGImage) -> [DetectedObject] {
        let result = yolo(cgImage)
        guard !result.boxes.isEmpty else { return [] }

        var objects: [DetectedObject] = []

        for box in result.boxes where box.conf > 0.25 {
            let swiftUIBox = box.xywhn
            var label = box.cls.uppercased()
            var conf = box.conf
            let clsLower = box.cls.lowercased()

            if clsLower == "person" {
                label = "HUMAIN"
            } else if ["car", "truck", "bus", "motorcycle", "bicycle"].contains(clsLower) {
                label = "VÉHICULE"
            } else if ["dog", "cat", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "bird"].contains(clsLower) {
                let visionBox = convertSwiftUIRectToVision(swiftUIBox)
                if let species = classifyWildlifeSpecies(in: cgImage, visionRect: visionBox) {
                    label = "\(species.icon) \(species.label)"
                    conf = max(conf, species.confidence)
                } else {
                    switch clsLower {
                    case "dog": label = "🐾 CANIDÉ"
                    case "cat": label = "🐾 FÉLIN"
                    case "horse": label = "🐎 ÉQUIDÉ"
                    case "cow": label = "🐄 BOVIN"
                    case "sheep": label = "🐑 MOUTON"
                    case "bird": label = "🦆 OISEAU / GIBIER"
                    case "bear": label = "🐻 OURS"
                    default: label = "🐾 GIBIER"
                    }
                }
            } else if activeMissionMode == .chasse {
                let visionBox = convertSwiftUIRectToVision(swiftUIBox)
                if let species = classifyWildlifeSpecies(in: cgImage, visionRect: visionBox) {
                    label = "\(species.icon) \(species.label)"
                    conf = max(conf, species.confidence)
                }
            }

            let (_, corners) = fallbackCorners(for: swiftUIBox)
            objects.append(DetectedObject(
                box: swiftUIBox,
                label: label,
                confidence: conf,
                orientedAngleRad: 0.0,
                orientedCorners: corners,
                hasSilhouetteMask: false
            ))
        }

        return objects
    }

    // MARK: - Calcul Mathématique OBB (Analyse d'Inertie des Moments de Silhouette)

    private func calculateOrientation(from mask: [[Float]]?, box: CGRect) -> (angleRad: Float, corners: [CGPoint]) {
        guard let mask = mask, !mask.isEmpty, !mask[0].isEmpty else {
            return fallbackCorners(for: box)
        }

        let h = mask.count
        let w = mask[0].count

        var m00: Float = 0
        var m10: Float = 0
        var m01: Float = 0

        let minX = max(0, min(w - 1, Int(box.minX * CGFloat(w))))
        let maxX = max(0, min(w - 1, Int(box.maxX * CGFloat(w))))
        let minY = max(0, min(h - 1, Int(box.minY * CGFloat(h))))
        let maxY = max(0, min(h - 1, Int(box.maxY * CGFloat(h))))

        guard maxX > minX, maxY > minY else { return fallbackCorners(for: box) }

        let stepX = max(1, (maxX - minX) / 24)
        let stepY = max(1, (maxY - minY) / 24)

        for y in stride(from: minY, through: maxY, by: stepY) {
            for x in stride(from: minX, through: maxX, by: stepX) {
                if mask[y][x] > 0.45 {
                    m00 += 1
                    m10 += Float(x)
                    m01 += Float(y)
                }
            }
        }

        guard m00 >= 4 else { return fallbackCorners(for: box) }

        let cx = m10 / m00
        let cy = m01 / m00

        var mu20: Float = 0
        var mu02: Float = 0
        var mu11: Float = 0

        for y in stride(from: minY, through: maxY, by: stepY) {
            let dy = Float(y) - cy
            for x in stride(from: minX, through: maxX, by: stepX) {
                if mask[y][x] > 0.45 {
                    let dx = Float(x) - cx
                    mu20 += dx * dx
                    mu02 += dy * dy
                    mu11 += dx * dy
                }
            }
        }

        // Angle d'orientation principal theta
        let angleRad = 0.5 * atan2(2.0 * mu11, mu20 - mu02)
        let normalizedCx = CGFloat(cx / Float(w))
        let normalizedCy = CGFloat(cy / Float(h))
        let halfW = box.width / 2.0
        let halfH = box.height / 2.0

        let cosA = CGFloat(cos(angleRad))
        let sinA = CGFloat(sin(angleRad))

        let p1 = CGPoint(x: normalizedCx - halfW * cosA + halfH * sinA, y: normalizedCy - halfW * sinA - halfH * cosA)
        let p2 = CGPoint(x: normalizedCx + halfW * cosA + halfH * sinA, y: normalizedCy + halfW * sinA - halfH * cosA)
        let p3 = CGPoint(x: normalizedCx + halfW * cosA - halfH * sinA, y: normalizedCy + halfW * sinA + halfH * cosA)
        let p4 = CGPoint(x: normalizedCx - halfW * cosA - halfH * sinA, y: normalizedCy - halfW * sinA + halfH * cosA)

        return (angleRad, [p1, p2, p3, p4])
    }

    private func fallbackCorners(for box: CGRect) -> (angleRad: Float, corners: [CGPoint]) {
        let corners = [
            CGPoint(x: box.minX, y: box.minY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY),
            CGPoint(x: box.minX, y: box.maxY)
        ]
        return (0.0, corners)
    }

    private func detectObjectsWithAppleVision(in cgImage: CGImage) {
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
                for animal in results where animal.confidence > 0.35 {
                    let box = self.convertVisionRectToSwiftUI(animal.boundingBox)
                    var label = "🐾 GIBIER"
                    var conf = animal.confidence

                    // Classification taxonomique précise de l'espèce
                    if let species = self.classifyWildlifeSpecies(in: cgImage, visionRect: animal.boundingBox) {
                        label = "\(species.icon) \(species.label)"
                        conf = max(conf, species.confidence)
                    } else {
                        let topLabel = animal.labels.first?.identifier.lowercased() ?? "animal"
                        if topLabel == "dog" {
                            label = "🐾 QUADRUPÈDE"
                        } else if topLabel == "cat" {
                            label = "🐾 FÉLIN"
                        }
                    }
                    newObjects.append(DetectedObject(box: box, label: label, confidence: conf))
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
                    var label = defaultLabel
                    var conf = salient.confidence
                    if self.activeMissionMode == .chasse,
                       let species = self.classifyWildlifeSpecies(in: cgImage, visionRect: salient.boundingBox) {
                        label = "\(species.icon) \(species.label)"
                        conf = max(conf, species.confidence)
                    }
                    newObjects.append(DetectedObject(box: box, label: label, confidence: conf))
                }
            }
        }
        configureComputeDevices(for: saliencyRequest)
        requestsToPerform.append(saliencyRequest)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform(requestsToPerform)
            self.detectedObjects = newObjects
            updateSurveillanceTelemetry(with: newObjects)
        } catch {
            print("Erreur analyse Apple Vision : \(error)")
        }
    }

    private func updateSurveillanceTelemetry(with objects: [DetectedObject]) {
        if activeMissionMode == .surveillance {
            self.detectedHumansCount = objects.filter { $0.label == "HUMAIN" }.count
            self.hasIntruderAlert = self.detectedHumansCount > 0
        } else {
            self.detectedHumansCount = 0
            self.hasIntruderAlert = false
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
                handleTrackingLoss(in: cgImage, lastBox: currentBox)
                return
            }

            trackingLossCounter = 0
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

            // Affinage périodique de l'espèce sur la cible verrouillée (toutes les 12 frames)
            trackingFrameCounter += 1
            if trackingFrameCounter % 12 == 0 {
                if let species = classifyWildlifeSpecies(in: cgImage, visionRect: newVisionBox) {
                    self.targetSpeciesName = species.label
                    self.targetSpeciesIcon = species.icon
                }
            }

            onTargetData(azimuth, elevation, changeOfScale, confidence, isFirstDetection)
            isFirstDetection = false

        } catch {
            print("Erreur suivi optique Apple Vision : \(error)")
        }
    }

    // MARK: - Gestion du Décrochage & Ré-Acquisition Intelligente (YOLO)

    private func handleTrackingLoss(in cgImage: CGImage, lastBox: CGRect) {
        trackingLossCounter += 1

        // 1. Décrochage bref (3 à 25 frames, ~0.1 à 0.8s) : tentative de ré-accrochage automatique via YOLO
        if trackingLossCounter >= 3 && trackingLossCounter <= 25 {
            if let yolo = (yoloSeg ?? yoloDetect) {
                let yoloResult = yolo(cgImage)
                if let candidate = yoloResult.boxes.first(where: {
                    hypot($0.xywhn.midX - lastBox.midX, $0.xywhn.midY - lastBox.midY) < 0.18
                }) {
                    let reVisionBox = convertSwiftUIRectToVision(candidate.xywhn)
                    let observation = VNDetectedObjectObservation(boundingBox: reVisionBox)
                    let newRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    newRequest.trackingLevel = .accurate
                    configureComputeDevices(for: newRequest)
                    self.trackingRequest = newRequest
                    self.lockedTargetBox = candidate.xywhn
                    self.trackingLossCounter = 0
                    print("🎯 Ré-accrochage automatique de la cible via YOLO !")
                    return
                }
            }
        }

        // 2. Décrochage prolongé (> 35 frames, > 1.2s) : perte définitive et notification haptique
        if trackingLossCounter > 35 {
            unlockTarget(silent: false)
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
        targetSpeciesName = nil
        targetSpeciesIcon = nil
        segmentationMaskImage = nil
        trackingFrameCounter = 0
        trackingLossCounter = 0
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

    // MARK: - Classification Taxonomique Apple Vision (1300+ Taxons)

    private func classifyWildlifeSpecies(
        in cgImage: CGImage,
        visionRect: CGRect
    ) -> (label: String, icon: String, confidence: Float)? {
        guard visionRect.width > 0.02, visionRect.height > 0.02 else { return nil }

        let originX = max(0.0, visionRect.origin.x - 0.02)
        let originY = max(0.0, visionRect.origin.y - 0.02)
        let width = min(1.0 - originX, visionRect.width + 0.04)
        let height = min(1.0 - originY, visionRect.height + 0.04)

        guard width > 0.02, height > 0.02 else { return nil }

        let classifyRequest = VNClassifyImageRequest()
        classifyRequest.regionOfInterest = CGRect(x: originX, y: originY, width: width, height: height)
        configureComputeDevices(for: classifyRequest)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([classifyRequest])
            guard let observations = classifyRequest.results as? [VNClassificationObservation] else {
                return nil
            }

            for obs in observations where obs.confidence > 0.10 {
                if let match = mapToWildlifeTaxon(obs.identifier) {
                    return (match.label, match.icon, obs.confidence)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func mapToWildlifeTaxon(_ identifier: String) -> (label: String, icon: String)? {
        let id = identifier.lowercased()

        // 1. Sanglier & Suidés
        if id == "boar" || id.contains("boar") || id == "pig" || id.hasPrefix("pig_") || id == "warthog" || id == "swine" {
            return ("SANGLIER", "🐗")
        }
        // 2. Chevreuil & Bovidés des bois / Caprinés sauvages
        if id == "roe" || id.hasPrefix("roe_") || id == "chamois" || id == "ibex" {
            return ("CHEVREUIL", "🦌")
        }
        // 3. Cerf & Biche
        if id == "deer" || id.contains("deer") || id == "stag" || id == "fawn" {
            return ("CERF / BICHE", "🦌")
        }
        // 4. Grand Cerf & Élan
        if id == "elk" || id == "moose" {
            return ("GRAND CERF / ÉLAN", "🦌")
        }
        // 5. Renard
        if id == "fox" || id.hasPrefix("fox_") {
            return ("RENARD", "🦊")
        }
        // 6. Loup & Canidés sauvages
        if id == "coyote_wolf" || id == "wolf" || (id.contains("wolf") && !id.contains("hound")) || id == "jackal" {
            return ("LOUP", "🐺")
        }
        // 7. Lièvre & Lapin
        if id == "rabbit" || id == "hare" || id.contains("hare") || id.contains("cottontail") {
            return ("LIÈVRE / LAPIN", "🐇")
        }
        // 8. Blaireau & Rongeurs sauvages
        if id == "badger" || id == "marmot" || id == "beaver" || id == "rodent" {
            return ("BLAIREAU / RONGEUR", "🦫")
        }
        // 9. Gibier à plumes / Oiseaux
        if id == "bird" || id.contains("bird") || id == "duck" || id == "pheasant" || id == "partridge" || id == "quail" {
            return ("OISEAU / GIBIER", "🦆")
        }
        // 10. Ours
        if id == "bear" || (id.contains("bear") && !id.contains("teddy") && !id.contains("polar")) {
            return ("OURS", "🐻")
        }
        // 11. Chiens de chasse / Chiens errants
        if id == "dog" || id == "bulldog" || id == "sheepdog" || id == "prairie_dog" {
            return ("CHIEN", "🐕")
        }
        // 12. Félins sauvages / Chats
        if id == "cat" || id == "adult_cat" || id == "bobcat" || id == "lynx" {
            return ("FÉLIN / LYNX", "🐈")
        }
        // 13. Chevaux
        if id == "horse" || id == "jockey_horse" {
            return ("CHEVAL", "🐎")
        }
        // 14. Bovins
        if id == "cow" || id == "bull" || id == "ox" {
            return ("BOVIN", "🐄")
        }
        // 15. Ovins & Mouflons
        if id == "sheep" || id == "ram" || id == "mouflon" {
            return ("MOUTON / MOUFLON", "🐑")
        }
        // 16. Caprins
        if id == "goat" {
            return ("CHÈVRE", "🐐")
        }

        return nil
    }
}
