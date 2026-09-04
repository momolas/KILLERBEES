//
//  CockpitAITrackingOverlay.swift
//  KILLERBEES
//
//  Created by Jules
//  Cockpit HUD Tactique Apple Vision avec Micro-Animations & Retours Haptiques
//

import SwiftUI

struct TacticalCornersShape: Shape {
    let length: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(length, min(rect.width, rect.height) / 2)
        
        // Haut Gauche
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        
        // Haut Droite
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        
        // Bas Droite
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        
        // Bas Gauche
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        
        return path
    }
}

struct CockpitThermalSilhouetteLayer: View {
    let cgImage: CGImage
    let color: Color

    var body: some View {
        Image(decorative: cgImage, scale: 1.0, orientation: .up)
            .resizable()
            .scaledToFill()
            .colorMultiply(color)
            .opacity(0.40)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

struct CockpitOrientedBoxView: View {
    let object: DetectedObject
    let viewSize: CGSize
    let color: Color

    var body: some View {
        if let corners = object.orientedCorners, corners.count == 4 {
            let screenCorners = corners.map { CGPoint(x: $0.x * viewSize.width, y: $0.y * viewSize.height) }

            ZStack {
                // Polygone orienté OBB
                Path { path in
                    path.move(to: screenCorners[0])
                    path.addLine(to: screenCorners[1])
                    path.addLine(to: screenCorners[2])
                    path.addLine(to: screenCorners[3])
                    path.closeSubpath()
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                .background(
                    Path { path in
                        path.move(to: screenCorners[0])
                        path.addLine(to: screenCorners[1])
                        path.addLine(to: screenCorners[2])
                        path.addLine(to: screenCorners[3])
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.08))
                )

                // Indicateur de Cap Tête/Axe
                if let angleRad = object.orientedAngleRad {
                    let centerX = (screenCorners[0].x + screenCorners[2].x) / 2
                    let centerY = (screenCorners[0].y + screenCorners[2].y) / 2
                    let headingDeg = Double((angleRad * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0))

                    Image(systemName: "location.north.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                        .rotationEffect(.degrees(headingDeg))
                        .position(x: centerX, y: centerY)
                }

                // Badge de Label
                let topCorner = screenCorners.min(by: { $0.y < $1.y }) ?? screenCorners[0]
                Text("\(object.label) \(Int(object.confidence * 100))%")
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(color)
                    .foregroundStyle(.black)
                    .clipShape(.rect(cornerRadius: 3))
                    .position(x: topCorner.x, y: max(14, topCorner.y - 12))
            }
        } else {
            let screenRect = convertToScreenRect(object.box, in: viewSize)
            ZStack(alignment: .topLeading) {
                TacticalCornersShape(length: 12)
                    .stroke(color, lineWidth: 2)

                Text("\(object.label) \(Int(object.confidence * 100))%")
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(color)
                    .foregroundStyle(.black)
                    .clipShape(.rect(cornerRadius: 3))
                    .offset(x: 2, y: -16)
            }
            .frame(width: screenRect.width, height: screenRect.height)
            .position(x: screenRect.midX, y: screenRect.midY)
        }
    }

    private func convertToScreenRect(_ normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.origin.x * size.width,
            y: normalized.origin.y * size.height,
            width: normalized.size.width * size.width,
            height: normalized.size.height * size.height
        )
    }
}

struct CockpitAITrackingOverlay: View {
    let detectedObjects: [DetectedObject]
    let lockedBox: CGRect?
    let isTargetLocked: Bool
    let trackingMode: TrackingMode
    let trackingIssues: [String]
    var segmentationMask: CGImage? = nil
    var isThermalMaskEnabled: Bool = true
    let onSelectPoint: (CGPoint) -> Void
    let onSelectBox: (CGRect) -> Void
    let onSelectMode: (TrackingMode) -> Void
    let onCancelLock: () -> Void

    @State private var dragStartPoint: CGPoint?
    @State private var dragCurrentPoint: CGPoint?
    @State private var pulseScale: CGFloat = 1.0
    @State private var reticleRotation: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size

            ZStack {
                // 0. Calque de Silhouette Thermique / Fluo
                if isThermalMaskEnabled, let mask = segmentationMask {
                    CockpitThermalSilhouetteLayer(
                        cgImage: mask,
                        color: (trackingMode == .followMe) ? .orange : Color(red: 0.1, green: 0.95, blue: 0.45)
                    )
                }

                // Zone tactile transparente pour interactions
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 15)
                            .onChanged { value in
                                if dragStartPoint == nil {
                                    dragStartPoint = value.startLocation
                                }
                                dragCurrentPoint = value.location
                            }
                            .onEnded { value in
                                if let start = dragStartPoint {
                                    let end = value.location
                                    let minX = min(start.x, end.x) / viewSize.width
                                    let minY = min(start.y, end.y) / viewSize.height
                                    let width = abs(end.x - start.x) / viewSize.width
                                    let height = abs(end.y - start.y) / viewSize.height

                                    if width > 0.05 && height > 0.05 {
                                        let customBox = CGRect(x: minX, y: minY, width: width, height: height)
                                        onSelectBox(customBox)
                                    }
                                }
                                dragStartPoint = nil
                                dragCurrentPoint = nil
                            }
                    )
                    .onTapGesture { tapPoint in
                        if isTargetLocked {
                            onCancelLock()
                        } else {
                            let normalized = CGPoint(
                                x: tapPoint.x / viewSize.width,
                                y: tapPoint.y / viewSize.height
                            )
                            onSelectPoint(normalized)
                        }
                    }

                // Boîte de sélection en cours de tracé (Drag manuel)
                if let start = dragStartPoint, let current = dragCurrentPoint {
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: abs(current.x - start.x),
                        height: abs(current.y - start.y)
                    )
                    Rectangle()
                        .strokeBorder(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .background(Color.yellow.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                // Cibles Détectées Automatiquement avec Boîtes Orientées OBB
                if !isTargetLocked {
                    ForEach(detectedObjects) { object in
                        let color = colorForLabel(object.label)
                        CockpitOrientedBoxView(object: object, viewSize: viewSize, color: color)
                    }
                }

                // Cible Verrouillée Active avec Micro-Animation Tactique
                if let locked = lockedBox {
                    let screenRect = convertToScreenRect(locked, in: viewSize)
                    let lockColor: Color = (trackingMode == .followMe) ? .orange : .red

                    ZStack {
                        // Cercle de pulsation externe
                        Circle()
                            .stroke(lockColor.opacity(0.4), lineWidth: 1.5)
                            .frame(width: max(screenRect.width, screenRect.height) * 1.35, height: max(screenRect.width, screenRect.height) * 1.35)
                            .scaleEffect(pulseScale)

                        // 4 Coins militaires resserrés
                        TacticalCornersShape(length: 16)
                            .stroke(lockColor, lineWidth: 2.8)

                        // Réticule central à croix dynamique
                        ZStack {
                            Circle()
                                .strokeBorder(lockColor, lineWidth: 1)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(lockColor)
                        }

                        // Badge supérieur de verrouillage
                        VStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 5, height: 5)
                                Text(trackingMode == .followMe ? "🚀 FOLLOW-ME ACTIF" : "🎯 LOOK-AT ACTIF")
                                    .font(.system(size: 9, weight: .black))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(lockColor)
                            .foregroundStyle(.white)
                            .clipShape(.capsule)
                            .shadow(radius: 4)

                            Spacer()
                        }
                        .offset(y: -24)
                    }
                    .frame(width: screenRect.width, height: screenRect.height)
                    .position(x: screenRect.midX, y: screenRect.midY)
                    .shadow(color: lockColor.opacity(0.6), radius: 8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            pulseScale = 1.12
                        }
                    }
                }

                // Sélecteur Tactique Haut : LOOK-AT vs FOLLOW-ME
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(TrackingMode.allCases) { mode in
                            Button {
                                HapticFeedback.modeChanged()
                                onSelectMode(mode)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 10, weight: .bold))
                                    Text(mode.rawValue)
                                        .font(.system(size: 10, weight: .black))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(trackingMode == mode ? (mode == .followMe ? Color.orange : Color.green) : Color.black.opacity(0.65))
                                .foregroundStyle(trackingMode == mode ? Color.black : Color.white)
                                .clipShape(.capsule)
                                .overlay(
                                    Capsule().strokeBorder(
                                        trackingMode == mode ? Color.white.opacity(0.4) : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                                )
                            }
                        }
                    }
                    .padding(.top, 58)

                    // Bandeau de Statut Contextuel de Mission
                    if !isTargetLocked {
                        HStack(spacing: 5) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 9))
                            Text("TOUCHEZ UNE CIBLE (AIMANTATION AUTO)")
                                .font(.system(size: 9, weight: .black))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.85))
                        .foregroundStyle(.black)
                        .clipShape(.capsule)
                        .shadow(radius: 3)
                    } else if let issue = trackingIssues.first(where: { $0 != "Cible visuelle non détectée" }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text(issue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow)
                        .foregroundStyle(.black)
                        .clipShape(.capsule)
                        .shadow(radius: 2)
                    } else {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(trackingMode == .followMe ? Color.orange : Color.green)
                                .frame(width: 6, height: 6)
                            Text(trackingMode == .followMe ? "POURSUITE DYNAMIQUE EN COURS" : "CADRAGE NACELLE ACTIF")
                                .font(.system(size: 9, weight: .black))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(radius: 3)
                    }

                    Spacer()
                }
            }
        }
    }

    private func colorForLabel(_ label: String) -> Color {
        switch label {
        case "VOITURE", "CAMION", "BUS", "MOTO", "VÉLO", "TRAIN", "HÉLICOPTÈRE", "VÉHICULE", "CAMION / BUS", "CIBLE", "CIBLE D'INTÉRÊT":
            return .cyan
        case "BATEAU", "AVION":
            return .mint
        case "HUMAIN":
            return .green
        case "CHIEN", "CHAT", "CHEVAL", "ANIMAL":
            return .yellow
        default:
            if label.contains("🐾") || label.contains("🦌") || label.contains("🐗") || label.contains("🦊") || label.contains("🐺") || label.contains("🦆") || label.contains("🐻") || label.contains("🐕") || label.contains("🐈") || label.contains("🐎") || label.contains("🐄") || label.contains("🐑") || label.contains("🐐") || label.contains("🦫") || label.contains("🐇") || label.contains("🐘") || label.contains("🦓") || label.contains("🦒") {
                return .yellow
            }
            return .green
        }
    }

    private func convertToScreenRect(_ normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.origin.x * size.width,
            y: normalized.origin.y * size.height,
            width: normalized.size.width * size.width,
            height: normalized.size.height * size.height
        )
    }
}
