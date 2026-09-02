//
//  CockpitGimbalControl.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitGimbalControl: View {
    let currentPitch: Double
    let onPitchChange: (Double) -> Void

    @State private var localPitch: Double = 0.0
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Indicateur d'angle de la caméra
            Text("\(Int(isDragging ? localPitch : currentPitch))°")
                .font(.caption2)
                .bold()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(.capsule)

            // Slider tactile vertical de nacelle
            GeometryReader { geometry in
                let height = geometry.size.height
                let normalizedPosition = CGFloat((1.0 - (((isDragging ? localPitch : currentPitch) + 90.0) / 180.0))) * height

                ZStack(alignment: .top) {
                    // Rail de guidage
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .frame(width: 6)

                    // Ligne centrale (0° horizon)
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 14, height: 2)
                        .position(x: geometry.size.width / 2, y: height / 2)

                    // Curseur de contrôle tactile
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .position(x: geometry.size.width / 2, y: min(max(normalizedPosition, 11), height - 11))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let clampedY = min(max(value.location.y, 0), height)
                            let ratio = 1.0 - Double(clampedY / height)
                            let targetPitch = (ratio * 180.0) - 90.0
                            localPitch = targetPitch
                            onPitchChange(targetPitch)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 36, height: 120)

            // Bouton réalignement horizon (0°)
            Button("Horizon", systemImage: "camera.viewfinder") {
                localPitch = 0.0
                onPitchChange(0.0)
            }
            .labelStyle(.iconOnly)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(.circle)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
    }
}
