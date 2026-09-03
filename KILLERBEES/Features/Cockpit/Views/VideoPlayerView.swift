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
    var onFrameCaptured: ((UIImage) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> StreamView {
        let streamView = StreamView(frame: .zero)
        streamView.renderingScaleType = .crop
        streamView.renderingPaddingFill = .none
        streamView.setStream(stream: stream)
        context.coordinator.attach(to: streamView)
        return streamView
    }

    func updateUIView(_ streamView: StreamView, context: Context) {
        streamView.setStream(stream: stream)
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ streamView: StreamView, coordinator: Coordinator) {
        coordinator.detach()
        streamView.setStream(stream: nil)
    }

    class Coordinator {
        var parent: VideoPlayerView
        private weak var streamView: StreamView?
        private var captureTimer: Timer?

        init(_ parent: VideoPlayerView) {
            self.parent = parent
        }

        func attach(to view: StreamView) {
            self.streamView = view
            startCaptureTimer()
        }

        func detach() {
            captureTimer?.invalidate()
            captureTimer = nil
            streamView = nil
        }

        private func startCaptureTimer() {
            captureTimer?.invalidate()
            captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
                guard let self, let streamView = self.streamView, self.parent.onFrameCaptured != nil else { return }
                let image = streamView.snapshot
                if image.size.width > 0 && image.size.height > 0 {
                    self.parent.onFrameCaptured?(image)
                }
            }
        }
    }
}
