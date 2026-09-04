//
//  CockpitOrientedBoxView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Rendu d'une boîte englobante orientée (OBB) ou standard avec étiquette et indicateur d'axe.
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
