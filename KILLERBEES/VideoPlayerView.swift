//
//  VideoPlayerView.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import SwiftUI
import GroundSdk

struct VideoPlayerView: UIViewRepresentable {
    let stream: CameraLive?

    func makeUIView(context: Context) -> StreamView {
        StreamView(frame: .zero)
    }

    func updateUIView(_ streamView: StreamView, context: Context) {
        streamView.setStream(stream: stream)
    }

    static func dismantleUIView(_ streamView: StreamView, coordinator: ()) {
        streamView.setStream(stream: nil)
    }
}
