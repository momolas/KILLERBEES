//
//  VideoPlayerView.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import SwiftUI
import GroundSdk

struct VideoPlayerView: UIViewRepresentable {
    let streamView: StreamView

    func makeUIView(context: Context) -> UIView {
        return streamView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
