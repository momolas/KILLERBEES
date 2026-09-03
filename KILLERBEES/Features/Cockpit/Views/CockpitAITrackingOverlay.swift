//
//  CockpitAITrackingOverlay.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitAITrackingOverlay: View {
    let detectedBoxes: [CGRect]
    let lockedBox: CGRect?
    let isTargetLocked: Bool
    let onSelectPoint: (CGPoint) -> Void
    let onSelectBox: (CGRect) -> Void
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

                // Boîte de sélection en cours de tracé (Drag)
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

                // Cibles Détectées Automatiquement (non verrouillées)
                if !isTargetLocked {
                    ForEach(detectedBoxes.indices, id: \.self) { index in
                        let box = detectedBoxes[index]
                        let screenRect = convertToScreenRect(box, in: viewSize)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.green, lineWidth: 2)

                            Text("CIBLE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green)
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

                    ZStack {
                        // Cadre de visée
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.red, lineWidth: 2.5)

                        // Réticule central
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.red)

                        // Badge de verrouillage
                        VStack {
                            Text("VERROUILLÉ")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(.capsule)
                                .shadow(radius: 3)
                            Spacer()
                        }
                        .offset(y: -22)
                    }
                    .frame(width: screenRect.width, height: screenRect.height)
                    .position(x: screenRect.midX, y: screenRect.midY)
                    .shadow(color: .red.opacity(0.5), radius: 6)
                }
            }
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
