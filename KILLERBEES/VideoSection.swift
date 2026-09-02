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
        } else {
            ZStack {
                Color.black
                Text("Connexion au flux vidéo...")
                    .foregroundStyle(.white)
            }
            .frame(height: 300)
        }
    }
}
