//
//  CockpitCameraCaptureView.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitCameraCaptureView: View {
    let isRecording: Bool
    let canTakePhoto: Bool
    let onTakePhoto: () -> Void
    let onToggleRecording: () -> Void

    @State private var photoFlash: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Déclencheur Photo
            Button(action: handleTakePhoto) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 48, height: 48)

                    Circle()
                        .fill(photoFlash ? .yellow : .white)
                        .frame(width: 38, height: 38)
                }
            }
            .disabled(!canTakePhoto)
            .opacity(canTakePhoto ? 1.0 : 0.5)
            .accessibilityLabel("Prendre une photo")

            // Déclencheur Vidéo
            Button(action: onToggleRecording) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 48, height: 48)

                    if isRecording {
                        Rectangle()
                            .fill(.red)
                            .frame(width: 20, height: 20)
                            .clipShape(.rect(cornerRadius: 4))
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 38, height: 38)
                    }
                }
            }
            .accessibilityLabel(isRecording ? "Arrêter l'enregistrement vidéo" : "Démarrer l'enregistrement vidéo")
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 6)
    }

    private func handleTakePhoto() {
        photoFlash = true
        onTakePhoto()
        withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
            photoFlash = false
        }
    }
}
