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
        if stream == nil {
            context.coordinator.stopCaptureTimer()
        } else {
            context.coordinator.startCaptureTimer()
        }
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
            if parent.stream != nil {
                startCaptureTimer()
            }
        }

        func detach() {
            stopCaptureTimer()
            streamView = nil
        }

        func startCaptureTimer() {
            guard captureTimer == nil, parent.stream != nil else { return }
            captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
                guard let self, let streamView = self.streamView, self.parent.onFrameCaptured != nil, self.parent.stream != nil else { return }
                let image = streamView.snapshot
                if image.size.width > 0 && image.size.height > 0 {
                    self.parent.onFrameCaptured?(image)
                }
            }
        }

        func stopCaptureTimer() {
            captureTimer?.invalidate()
            captureTimer = nil
        }
    }
}
