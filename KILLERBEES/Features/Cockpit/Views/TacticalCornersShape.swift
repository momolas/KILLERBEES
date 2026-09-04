//
//  TacticalCornersShape.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

/// Forme géométrique des coins tactiques pour boîtes englobantes de détection.
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
