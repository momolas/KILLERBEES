//
//  VideoSection.swift
//  KILLERBEES
//

import SwiftUI
import GroundSdk

struct VideoSection: View {
    let stream: CameraLive?
    var isDroneConnected: Bool = true
    var onFrameCaptured: ((UIImage) -> Void)? = nil

    var body: some View {
        ZStack {
            if isDroneConnected, let stream {
                VideoPlayerView(stream: stream, onFrameCaptured: onFrameCaptured)
                    .background(.black)
            } else {
                ZStack {
                    Color.black
                    if isDroneConnected {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("Connexion au flux vidéo...")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(.red.opacity(0.85))

                            VStack(spacing: 4) {
                                Text("DRONE DÉCONNECTÉ")
                                    .font(.headline)
                                    .bold()
                                    .foregroundStyle(.white)

                                Text("Flux vidéo désactivé")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
