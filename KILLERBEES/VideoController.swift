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
    var isStreamingActive: Bool = false
    
    private var drone: Drone?
    private var streamServerRef: Ref<StreamServer>?
    private var cameraLiveRef: Ref<CameraLive>?
    private var droneStateRef: Ref<DeviceState>?

    init() {}

    func setup(with drone: Drone) {
        cleanup()
        self.drone = drone
        
        // Surveillance de l'état de connexion du drone pour le flux vidéo
        droneStateRef = drone.getState { [weak self] state in
            guard let self, let state else { return }
            if state.connectionState == .connected {
                self.startVideoStream()
            } else if state.connectionState == .disconnected {
                self.stopVideoStream()
            }
        }

        // Si le drone est déjà connecté, on initialise le flux immédiatement
        if drone.state.connectionState == .connected {
            startVideoStream()
        }
    }

    private func startVideoStream() {
        guard let drone, streamServerRef == nil else { return }

        streamServerRef = drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            guard let self, let server = streamServer else {
                self?.stopVideoStream()
                return
            }

            // 1. Activer le serveur de streaming si ce n'est pas déjà fait
            if !server.enabled {
                server.enabled = true
            }

            // 2. Ne souscrire au flux live qu'une seule fois pour éviter l'annulation cyclique
            if self.cameraLiveRef == nil {
                self.cameraLiveRef = server.live { [weak self] cameraLive in
                    guard let self else { return }
                    guard let live = cameraLive else {
                        self.currentStream = nil
                        self.isStreamingActive = false
                        return
                    }

                    // Répondre à la négociation de caméra demandée par le drone
                    if let requested = live.requestedCamera {
                        live.notifyCamera(requestedCamera: requested)
                    }

                    // Démarrer la lecture si elle est en pause ou arrêtée
                    if live.playState != .playing {
                        _ = live.play()
                    }

                    self.currentStream = live
                    self.isStreamingActive = (live.playState == .playing)
                }
            }
        }
    }

    private func stopVideoStream() {
        cameraLiveRef = nil
        streamServerRef = nil
        currentStream = nil
        isStreamingActive = false
    }

    func cleanup() {
        stopVideoStream()
        droneStateRef = nil
        drone = nil
    }
}

