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
            context.coordinator.stopCaptureTask()
        } else {
            context.coordinator.startCaptureTask()
        }
    }

    static func dismantleUIView(_ streamView: StreamView, coordinator: Coordinator) {
        coordinator.detach()
        streamView.setStream(stream: nil)
    }

    @MainActor
    class Coordinator {
        var parent: VideoPlayerView
        private weak var streamView: StreamView?
        private var captureTask: Task<Void, Never>?

        init(_ parent: VideoPlayerView) {
            self.parent = parent
        }

        func attach(to view: StreamView) {
            self.streamView = view
            if parent.stream != nil {
                startCaptureTask()
            }
        }

        func detach() {
            stopCaptureTask()
            streamView = nil
        }

        func startCaptureTask() {
            guard captureTask == nil, parent.stream != nil else { return }
            captureTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .milliseconds(66))
                    } catch {
                        break
                    }
                    guard let self,
                          let streamView = self.streamView,
                          self.parent.onFrameCaptured != nil,
                          self.parent.stream != nil else {
                        break
                    }
                    let image = streamView.snapshot
                    if image.size.width > 0 && image.size.height > 0 {
                        self.parent.onFrameCaptured?(image)
                    }
                }
            }
        }

        func stopCaptureTask() {
            captureTask?.cancel()
            captureTask = nil
        }
    }
}
