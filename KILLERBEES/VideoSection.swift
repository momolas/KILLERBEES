//
//  VideoSection.swift
//  KILLERBEES
//

import SwiftUI
import GroundSdk

struct VideoSection: View {
    let stream: CameraLive?

    var body: some View {
        if let stream {
            VideoPlayerView(stream: stream)
                .frame(height: 300)
                .background(.black)
                .clipShape(.rect(cornerRadius: 16))
        } else {
            ZStack {
                Color.black
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Connexion au flux vidéo...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(height: 300)
            .clipShape(.rect(cornerRadius: 16))
        }
    }
}
