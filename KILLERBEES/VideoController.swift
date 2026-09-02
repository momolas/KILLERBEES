//
//  VideoController.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import GroundSdk
import SwiftUI

@Observable @MainActor
class VideoController {
    var currentStream: CameraLive?
    private var drone: Drone?
    private var streamServerRef: Ref<StreamServer>?
    private var cameraLiveRef: Ref<CameraLive>?

    init() {}

    func setup(with drone: Drone) {
        self.drone = drone
        startVideoStream()
    }

    private func startVideoStream() {
        guard let drone else { return }

        // On récupère le StreamServer
        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            guard let self, let server = streamServer else { return }

            // On active le flux
            server.enabled = true

            // On surveille le flux live
            self.cameraLiveRef = server.live { [weak self] cameraLive in
                guard let self else { return }
                guard let live = cameraLive else {
                    self.currentStream = nil
                    return
                }

                // Si le flux n'est pas démarré, on le lance
                if live.playState != .playing {
                    _ = live.play()
                }

                self.currentStream = live
            }
        }
    }

    func cleanup() {
        cameraLiveRef = nil
        streamServerRef = nil
        currentStream = nil
        drone = nil
    }
}
