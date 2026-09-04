//
//  CoreAIVisionTracker.swift
//  KILLERBEES
//
//  Moteur de Vision 100% Natif Apple Core AI & Accelerate (Zéro dépendance tierce)
//  Inférence directe sur Apple Silicon (Apple Neural Engine / GPU unifié)
//

#if canImport(CoreAI)
import Accelerate
import CoreAI
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import QuartzCore

@available(iOS 27.0, macOS 27.0, *)
@Observable @MainActor
final class CoreAIVisionTracker {
    private var model: AIModel?
    private var inferenceFn: InferenceFunction?
    private var inputName: String = "images"
    private var outputName: String = "output0"
    private var protoName: String = "output1"

    var isModelReady: Bool = false
    private(set) var labels: [String] = []
    private(set) var modelInputSize: (width: Int, height: Int) = (640, 640)

    // Contexte de rendu partagé pour le pré-processing d'image
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    enum ModelTask {
        case detect
        case segment
        case obb
    }

    let task: ModelTask

    init(modelURL: URL, task: ModelTask = .detect) async {
        self.task = task
        await loadModel(from: modelURL)
    }

    convenience init?(named modelName: String, task: ModelTask = .detect) async {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "aimodel") else {
            print("⚠️ [CoreAI] Fichier \(modelName).aimodel non trouvé dans le bundle")
            return nil
        }
        await self.init(modelURL: url, task: task)
    }

    // MARK: - Initialisation & Spécialisation Matérielle

    private func loadModel(from url: URL) async {
        do {
            // 1. Spécialisation du modèle sur le Neural Engine / GPU
            let asset = try AIModelAsset(contentsOf: url)
            let specializedModel = try await AIModel(contentsOf: url, options: .default)

            guard let fnName = specializedModel.functionNames.first,
                  let fn = try specializedModel.loadFunction(named: fnName) else {
                print("❌ [CoreAI] Fonction d'inférence introuvable dans \(url.lastPathComponent)")
                return
            }

            self.model = specializedModel
            self.inferenceFn = fn
            self.inputName = fn.descriptor.inputNames.first ?? "images"
            self.outputName = fn.descriptor.outputNames.first ?? "output0"
            if fn.descriptor.outputNames.count > 1 {
                self.protoName = fn.descriptor.outputNames[1]
            }

            // 2. Extraction des noms de classes (labels COCO ou personnalisés)
            if let namesVal = asset.metadata["names", String.self] {
                self.labels = parseNames(from: namesVal)
            } else if let classesVal = asset.metadata["classes", String.self] {
                self.labels = classesVal.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }

            // 3. Détermination des dimensions d'entrée
            if let desc = fn.descriptor.inputDescriptor(of: inputName) {
                switch desc {
                case .image(let img):
                    self.modelInputSize = (width: img.width, height: img.height)
                case .ndArray(let arr):
                    if arr.shape.count >= 4 {
                        self.modelInputSize = (width: arr.shape[3], height: arr.shape[2])
                    }
                @unknown default:
                    break
                }
            }

            self.isModelReady = true
            print("⚡️ [CoreAI] Modèle \(url.lastPathComponent) prêt (\(modelInputSize.width)x\(modelInputSize.height), \(labels.count) classes).")
        } catch {
            print("❌ [CoreAI] Erreur de chargement: \(error)")
            self.isModelReady = false
        }
    }

    // MARK: - Inférence sur Frame Vidéo

    func analyzeFrame(
        _ cgImage: CGImage,
        confidenceThreshold: Float = 0.25
    ) async -> (objects: [DetectedObject], maskImage: CGImage?, inferenceMs: Double) {
        guard isModelReady, inferenceFn != nil else { return ([], nil, 0) }

        let frameWidth = cgImage.width
        let frameHeight = cgImage.height
        guard frameWidth > 0, frameHeight > 0 else { return ([], nil, 0) }

        let ciImage = CIImage(cgImage: cgImage)
        guard let inputTensor = makeInputNDArray(from: ciImage) else {
            return ([], nil, 0)
        }

        return await runInference(
            inputTensor: inputTensor,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            confidenceThreshold: confidenceThreshold
        )
    }

    func analyzeFrame(
        _ pixelBuffer: CVPixelBuffer,
        confidenceThreshold: Float = 0.25
    ) async -> (objects: [DetectedObject], maskImage: CGImage?, inferenceMs: Double) {
        guard isModelReady, inferenceFn != nil else { return ([], nil, 0) }

        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard frameWidth > 0, frameHeight > 0 else { return ([], nil, 0) }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let inputTensor = makeInputNDArray(from: ciImage) else {
            return ([], nil, 0)
        }

        return await runInference(
            inputTensor: inputTensor,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            confidenceThreshold: confidenceThreshold
        )
    }

    private func runInference(
        inputTensor: NDArray,
        frameWidth: Int,
        frameHeight: Int,
        confidenceThreshold: Float
    ) async -> (objects: [DetectedObject], maskImage: CGImage?, inferenceMs: Double) {
        guard let inferenceFn else { return ([], nil, 0) }
        let t0 = CACurrentMediaTime()
        do {
            var outputs = try await inferenceFn.run(inputs: [inputName: inputTensor])
            let dt = (CACurrentMediaTime() - t0) * 1000.0

            guard let primaryOutput = outputs.remove(outputName),
                  let primaryArray = primaryOutput.ndArray else {
                return ([], nil, dt)
            }

            switch task {
            case .detect:
                let detected = decodeDetectionBoxes(
                    ndArray: primaryArray,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    threshold: confidenceThreshold
                )
                return (detected, nil, dt)

            case .segment:
                var protoNDArray: NDArray? = nil
                if let protoOutput = outputs.remove(protoName) {
                    protoNDArray = protoOutput.ndArray
                }
                let (detected, mask) = decodeSegmentation(
                    detectionArray: primaryArray,
                    protoArray: protoNDArray,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    threshold: confidenceThreshold
                )
                return (detected, mask, dt)

            case .obb:
                let detected = decodeOrientedBoxes(
                    ndArray: primaryArray,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    threshold: confidenceThreshold
                )
                return (detected, nil, dt)
            }
        } catch {
            print("❌ [CoreAI] Erreur inférence: \(error)")
            return ([], nil, 0)
        }
    }

    // MARK: - Pré-processing Letterbox Natif

    private func makeInputNDArray(from ciImage: CIImage) -> NDArray? {
        let targetW = modelInputSize.width
        let targetH = modelInputSize.height
        guard targetW > 0, targetH > 0 else { return nil }

        let imgW = ciImage.extent.width
        let imgH = ciImage.extent.height
        guard imgW > 0, imgH > 0 else { return nil }

        let scale = min(CGFloat(targetW) / imgW, CGFloat(targetH) / imgH)
        let scaledW = imgW * scale
        let scaledH = imgH * scale
        let padX = (CGFloat(targetW) - scaledW) / 2.0
        let padY = (CGFloat(targetH) - scaledH) / 2.0

        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: padX, y: padY))
        let scaledImage = ciImage.transformed(by: transform)

        let blackBg = CIImage(color: CIColor.black).cropped(
            to: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        let composited = scaledImage.composited(over: blackBg)

        let bytesPerPixel = 4
        let bytesPerRow = targetW * bytesPerPixel
        var pixelBytes = [UInt8](repeating: 0, count: targetW * targetH * bytesPerPixel)
        let bounds = CGRect(x: 0, y: 0, width: targetW, height: targetH)

        ciContext.render(
            composited, toBitmap: &pixelBytes, rowBytes: bytesPerRow, bounds: bounds, format: .BGRA8,
            colorSpace: nil)

        // Conversion planar RGB: [1, 3, H, W] normalisé à [0.0, 1.0]
        let planeSize = targetW * targetH
        var planarFloats = [Float](repeating: 0, count: 3 * planeSize)
        let inv255: Float = 1.0 / 255.0

        for i in 0..<planeSize {
            let b = Float(pixelBytes[i * 4 + 0]) * inv255
            let g = Float(pixelBytes[i * 4 + 1]) * inv255
            let r = Float(pixelBytes[i * 4 + 2]) * inv255
            planarFloats[0 * planeSize + i] = r
            planarFloats[1 * planeSize + i] = g
            planarFloats[2 * planeSize + i] = b
        }

        return NDArray(scalars: planarFloats, shape: [1, 3, targetH, targetW])
    }

    // MARK: - Décodeurs de Tenseurs

    /// Décode un tenseur [1, 300, 6] en boîtes [0, 1] normalisées
    private func decodeDetectionBoxes(
        ndArray: NDArray,
        frameWidth: Int,
        frameHeight: Int,
        threshold: Float
    ) -> [DetectedObject] {
        let view = ndArray.view(as: Float.self)
        guard let span = view.contiguousElements else { return [] }

        let targetW = CGFloat(modelInputSize.width)
        let targetH = CGFloat(modelInputSize.height)
        let inW = CGFloat(frameWidth)
        let inH = CGFloat(frameHeight)

        let gain = min(targetW / inW, targetH / inH)
        let padX = (targetW - inW * gain) / 2.0
        let padY = (targetH - inH * gain) / 2.0

        var results = [DetectedObject]()
        let count = min(300, span.count / 6)

        for i in 0..<count {
            let base = i * 6
            let conf = span[base + 4]
            guard conf >= threshold else { continue }

            let x1 = CGFloat(span[base])
            let y1 = CGFloat(span[base + 1])
            let x2 = CGFloat(span[base + 2])
            let y2 = CGFloat(span[base + 3])
            let classIdx = Int(span[base + 5])

            // Dé-letterbox vers coordonnées normalisées [0, 1]
            let normX1 = max(0, min(1, ((x1 - padX) / gain) / inW))
            let normY1 = max(0, min(1, ((y1 - padY) / gain) / inH))
            let normX2 = max(0, min(1, ((x2 - padX) / gain) / inW))
            let normY2 = max(0, min(1, ((y2 - padY) / gain) / inH))

            let box = CGRect(
                x: normX1,
                y: normY1,
                width: max(0.01, normX2 - normX1),
                height: max(0.01, normY2 - normY1)
            )

            let corners = [
                CGPoint(x: box.minX, y: box.minY),
                CGPoint(x: box.maxX, y: box.minY),
                CGPoint(x: box.maxX, y: box.maxY),
                CGPoint(x: box.minX, y: box.maxY)
            ]
            let labelName = classIdx < labels.count ? labels[classIdx] : "Objet \(classIdx)"
            results.append(DetectedObject(
                box: box,
                label: labelName,
                confidence: conf,
                orientedAngleRad: 0.0,
                orientedCorners: corners,
                hasSilhouetteMask: false
            ))
        }

        return results
    }

    /// Décode un tenseur [1, 300, 7] en boîtes orientées OBB [cx, cy, w, h, angle, conf, cls]
    private func decodeOrientedBoxes(
        ndArray: NDArray,
        frameWidth: Int,
        frameHeight: Int,
        threshold: Float
    ) -> [DetectedObject] {
        let view = ndArray.view(as: Float.self)
        guard let span = view.contiguousElements else { return [] }

        let targetW = CGFloat(modelInputSize.width)
        let targetH = CGFloat(modelInputSize.height)
        let inW = CGFloat(frameWidth)
        let inH = CGFloat(frameHeight)

        let gain = min(targetW / inW, targetH / inH)
        let padX = (targetW - inW * gain) / 2.0
        let padY = (targetH - inH * gain) / 2.0

        var results = [DetectedObject]()
        let count = min(300, span.count / 7)

        for i in 0..<count {
            let base = i * 7
            let conf = span[base + 5]
            guard conf >= threshold else { continue }

            let cx = CGFloat(span[base])
            let cy = CGFloat(span[base + 1])
            let w = CGFloat(span[base + 2])
            let h = CGFloat(span[base + 3])
            let angleRad = Float(span[base + 4])
            let classIdx = Int(span[base + 6])

            // Dé-letterbox du centre et dimensions
            let unpadCX = (cx - padX) / gain
            let unpadCY = (cy - padY) / gain
            let unpadW = w / gain
            let unpadH = h / gain

            // Coordonnées normalisées de la bounding box alignée
            let normX = max(0, min(1, (unpadCX - unpadW / 2) / inW))
            let normY = max(0, min(1, (unpadCY - unpadH / 2) / inH))
            let normW = max(0.01, min(1, unpadW / inW))
            let normH = max(0.01, min(1, unpadH / inH))
            let aabb = CGRect(x: normX, y: normY, width: normW, height: normH)

            // Calcul trigonométrique des 4 sommets orientés normalisés
            let cosA = CGFloat(cos(angleRad))
            let sinA = CGFloat(sin(angleRad))
            let hw = unpadW / 2
            let hh = unpadH / 2

            let offsets: [(CGFloat, CGFloat)] = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
            let corners: [CGPoint] = offsets.map { dx, dy in
                let rx = unpadCX + (dx * cosA - dy * sinA)
                let ry = unpadCY + (dx * sinA + dy * cosA)
                return CGPoint(x: max(0, min(1, rx / inW)), y: max(0, min(1, ry / inH)))
            }

            let labelName = classIdx < labels.count ? labels[classIdx] : "Objet \(classIdx)"
            var object = DetectedObject(box: aabb, label: labelName, confidence: conf)
            object.orientedAngleRad = angleRad
            object.orientedCorners = corners
            results.append(object)
        }

        return results
    }

    /// Décode le tenseur de détection [1, 300, 38] et les prototypes [1, 32, 160, 160] en masques de silhouette
    private func decodeSegmentation(
        detectionArray: NDArray,
        protoArray: NDArray?,
        frameWidth: Int,
        frameHeight: Int,
        threshold: Float
    ) -> (objects: [DetectedObject], maskImage: CGImage?) {
        let detView = detectionArray.view(as: Float.self)
        guard let detSpan = detView.contiguousElements else { return ([], nil) }

        let targetW = CGFloat(modelInputSize.width)
        let targetH = CGFloat(modelInputSize.height)
        let inW = CGFloat(frameWidth)
        let inH = CGFloat(frameHeight)

        let gain = min(targetW / inW, targetH / inH)
        let padX = (targetW - inW * gain) / 2.0
        let padY = (targetH - inH * gain) / 2.0

        var objects = [DetectedObject]()
        let numDets = min(300, detSpan.count / 38)
        var maskCoeffsList = [[Float]]()

        for i in 0..<numDets {
            let base = i * 38
            let conf = detSpan[base + 4]
            guard conf >= threshold else { continue }

            let x1 = CGFloat(detSpan[base])
            let y1 = CGFloat(detSpan[base + 1])
            let x2 = CGFloat(detSpan[base + 2])
            let y2 = CGFloat(detSpan[base + 3])
            let classIdx = Int(detSpan[base + 5])

            let normX1 = max(0, min(1, ((x1 - padX) / gain) / inW))
            let normY1 = max(0, min(1, ((y1 - padY) / gain) / inH))
            let normX2 = max(0, min(1, ((x2 - padX) / gain) / inW))
            let normY2 = max(0, min(1, ((y2 - padY) / gain) / inH))

            let box = CGRect(
                x: normX1,
                y: normY1,
                width: max(0.01, normX2 - normX1),
                height: max(0.01, normY2 - normY1)
            )

            let corners = [
                CGPoint(x: box.minX, y: box.minY),
                CGPoint(x: box.maxX, y: box.minY),
                CGPoint(x: box.maxX, y: box.maxY),
                CGPoint(x: box.minX, y: box.maxY)
            ]
            let labelName = classIdx < labels.count ? labels[classIdx] : "Objet \(classIdx)"
            var obj = DetectedObject(box: box, label: labelName, confidence: conf)
            obj.hasSilhouetteMask = true
            obj.orientedCorners = corners
            obj.orientedAngleRad = 0.0
            objects.append(obj)

            // 32 coefficients de masque
            let coeffs = (0..<32).map { detSpan[base + 6 + $0] }
            maskCoeffsList.append(coeffs)
        }

        // Génération du masque de silhouette matriciel via Accelerate
        var combinedMaskCG: CGImage? = nil
        if let protoArray, !maskCoeffsList.isEmpty {
            let protoView = protoArray.view(as: Float.self)
            if let protoSpan = protoView.contiguousElements, protoSpan.count == 32 * 160 * 160 {
                combinedMaskCG = renderSegmentationMask(
                    protoSpan: protoSpan,
                    coeffsList: maskCoeffsList,
                    protoWidth: 160,
                    protoHeight: 160
                )
            }
        }

        return (objects, combinedMaskCG)
    }

    /// Rendu du masque matriciel via combinaison linéaire Accelerate vDSP
    private func renderSegmentationMask(
        protoSpan: Span<Float>,
        coeffsList: [[Float]],
        protoWidth: Int,
        protoHeight: Int
    ) -> CGImage? {
        let pixelsCount = protoWidth * protoHeight
        var accumulatedMask = [Float](repeating: 0, count: pixelsCount)

        protoSpan.withUnsafeBufferPointer { protoBuffer in
            guard let protoPtr = protoBuffer.baseAddress else { return }

            for coeffs in coeffsList {
                for c in 0..<32 {
                    let weight = coeffs[c]
                    let channelPtr = protoPtr.advanced(by: c * pixelsCount)
                    vDSP_vsma(channelPtr, 1, [weight], accumulatedMask, 1, &accumulatedMask, 1, vDSP_Length(pixelsCount))
                }
            }
        }

        // Application de la sigmoïde et seuillage à 0.5 (valeur > 0)
        var bitmapBytes = [UInt8](repeating: 0, count: pixelsCount)
        for i in 0..<pixelsCount {
            bitmapBytes[i] = accumulatedMask[i] > 0.0 ? 255 : 0
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(bitmapBytes) as CFData) else { return nil }

        return CGImage(
            width: protoWidth,
            height: protoHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: protoWidth,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Parsing des Métadonnées

    private func parseNames(from namesString: String) -> [String] {
        let cleaned = namesString
            .replacing("{" , with: "")
            .replacing("}", with: "")
            .replacing("'", with: "")
            .replacing("\"", with: "")

        let pairs = cleaned.components(separatedBy: ",")
        var dict = [Int: String]()
        for pair in pairs {
            let parts = pair.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let idx = Int(parts[0]) {
                dict[idx] = parts[1]
            }
        }

        if let maxIdx = dict.keys.max() {
            var labels = [String](repeating: "", count: maxIdx + 1)
            for (k, v) in dict {
                labels[k] = v
            }
            return labels
        }
        return []
    }
}
#endif
