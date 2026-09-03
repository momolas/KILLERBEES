//
//  VideoSection.swift
//  KILLERBEES
//

import SwiftUI
import GroundSdk

struct VideoSection: View {
    let stream: CameraLive?
    var onFrameCaptured: ((UIImage) -> Void)? = nil

    var body: some View {
        ZStack {
            if let stream {
                VideoPlayerView(stream: stream, onFrameCaptured: onFrameCaptured)
                    .background(.black)
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Connexion au flux vidéo...")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
