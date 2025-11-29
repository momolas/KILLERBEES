//
//  VideoController.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import GroundSdk
import SwiftUI

class VideoController: ObservableObject {
    @Published var streamView: StreamView?
    private var drone: Drone?
    private var streamServerRef: Ref<StreamServer>?
    private var cameraLiveRef: Ref<CameraLive>?

    // Initialisation vide, configuration retardée
    init() {}

    func setup(with drone: Drone) {
        self.drone = drone
        startVideoStream()
    }

    private func startVideoStream() {
        guard let drone = drone else { return }

        // On récupère le StreamServer
        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            guard let self = self, let server = streamServer else { return }

            // On active le flux
            server.enabled = true

            // On surveille le flux live
            self.cameraLiveRef = server.live { cameraLive in
                guard let live = cameraLive else {
                    self.streamView = nil
                    return
                }

                // Si le flux n'est pas démarré, on le lance
                if live.playState != .playing {
                    _ = live.play()
                }

                // Mise à jour de la vue si nécessaire
                if self.streamView?.stream != live.stream {
                    self.streamView = StreamView(stream: live.stream)
                }
            }
        }
    }

    func takeOff() {
        drone?.getPeripheral(Peripherals.pilotingItf) { pilotingItf in
            pilotingItf?.takeOff()
        }
    }

    func land() {
        drone?.getPeripheral(Peripherals.pilotingItf) { pilotingItf in
            pilotingItf?.land()
        }
    }

    func cleanup() {
        // Libération des références
        cameraLiveRef = nil
        streamServerRef = nil
        streamView = nil
        drone = nil
    }
}
