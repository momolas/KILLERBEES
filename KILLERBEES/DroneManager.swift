//
//  DroneManager.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import Foundation
import GroundSdk
import SwiftUI

class DroneManager: ObservableObject {
    private let groundSdk: GroundSdk
    @Published var drones: [Drone] = []
    @Published var connectedDrone: Drone?

    private var droneListRef: Ref<[Drone]>?
    private var droneStateRef: Ref<DeviceState>?

    init(groundSdk: GroundSdk) {
        self.groundSdk = groundSdk
        scanForDrones()
    }

    private func scanForDrones() {
        droneListRef = groundSdk.getFacility(Facilities.droneList) { [weak self] droneList in
            self?.drones = droneList ?? []
        }
    }

    func connectToDrone(_ drone: Drone) {
        // Si on change de drone, on déconnecte l'ancien
        if let current = connectedDrone, current.uid != drone.uid {
            disconnect()
        }

        connectedDrone = drone

        // Surveillance de l'état de connexion
        droneStateRef = drone.getState { [weak self] state in
            guard let self = self else { return }
            print("Drone state: \(String(describing: state?.connectionState))")
            // Ici, on pourrait gérer des erreurs ou mettre à jour l'UI plus finement
        }

        // Connexion explicite
        let success = drone.connect()
        if !success {
            print("Échec de la demande de connexion au drone")
        }
    }

    func disconnect() {
        connectedDrone?.disconnect()
        connectedDrone = nil
        droneStateRef = nil
    }
}
