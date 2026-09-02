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
            Button {
                photoFlash = true
                onTakePhoto()
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    photoFlash = false
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 48, height: 48)

                    Circle()
                        .fill(photoFlash ? Color.yellow : Color.white)
                        .frame(width: 38, height: 38)
                }
            }
            .disabled(!canTakePhoto)
            .opacity(canTakePhoto ? 1.0 : 0.5)

            // Déclencheur Vidéo
            Button {
                onToggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 48, height: 48)

                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 38, height: 38)
                    }
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.3), radius: 6)
    }
}
