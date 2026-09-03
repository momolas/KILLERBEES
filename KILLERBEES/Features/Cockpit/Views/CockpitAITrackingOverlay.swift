//
//  CockpitAITrackingOverlay.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitAITrackingOverlay: View {
    let detectedObjects: [DetectedObject]
    let lockedBox: CGRect?
    let isTargetLocked: Bool
    let trackingMode: TrackingMode
    let trackingIssues: [String]
    let onSelectPoint: (CGPoint) -> Void
    let onSelectBox: (CGRect) -> Void
    let onSelectMode: (TrackingMode) -> Void
    let onCancelLock: () -> Void

    @State private var dragStartPoint: CGPoint?
    @State private var dragCurrentPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size

            ZStack {
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

                // Cibles Détectées Automatiquement par YOLO (non verrouillées)
                if !isTargetLocked {
                    ForEach(detectedObjects) { object in
                        let screenRect = convertToScreenRect(object.box, in: viewSize)
                        let color = colorForLabel(object.label)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(color, lineWidth: 2)

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

                // Cible Verrouillée Active (Locked Target)
                if let locked = lockedBox {
                    let screenRect = convertToScreenRect(locked, in: viewSize)
                    let lockColor: Color = (trackingMode == .followMe) ? .orange : .red

                    ZStack {
                        // Cadre de visée
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lockColor, lineWidth: 2.5)

                        // Réticule central
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lockColor)

                        // Badge de verrouillage avec mode actif
                        VStack {
                            Text(trackingMode == .followMe ? "🚀 FOLLOW-ME ACTIF" : "🎯 LOOK-AT ACTIF")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(lockColor)
                                .foregroundStyle(.white)
                                .clipShape(.capsule)
                                .shadow(radius: 3)
                            Spacer()
                        }
                        .offset(y: -22)
                    }
                    .frame(width: screenRect.width, height: screenRect.height)
                    .position(x: screenRect.midX, y: screenRect.midY)
                    .shadow(color: lockColor.opacity(0.5), radius: 6)
                }

                // Sélecteur Tactique Haut : LOOK-AT vs FOLLOW-ME
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(TrackingMode.allCases) { mode in
                            Button {
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

                    // Guide de pilotage ou avertissement de vol
                    if !isTargetLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 9))
                            Text("TOUCHEZ UNE CIBLE OU TRACEZ UN CADRE")
                                .font(.system(size: 9, weight: .black))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.85))
                        .foregroundStyle(.black)
                        .clipShape(.capsule)
                        .shadow(radius: 2)
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
                    }

                    Spacer()
                }
            }
        }
    }

    private func colorForLabel(_ label: String) -> Color {
        switch label {
        case "CIBLE", "CIBLE D'INTÉRÊT", "VOITURE", "CAMION", "BUS", "MOTO", "VÉLO":
            return .cyan
        case "HUMAIN":
            return .green
        case "CHIEN", "CHAT", "CHEVAL", "ANIMAL":
            return .yellow
        case "BATEAU", "AVION":
            return .mint
        default:
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
