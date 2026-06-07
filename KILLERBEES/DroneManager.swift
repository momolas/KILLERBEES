//
//  DroneManager.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import Foundation
import GroundSdk
import SwiftUI

@Observable @MainActor
class DroneManager {
    private let groundSdk: GroundSdk
    var drones: [Drone] = []
    var connectedDrone: Drone?

    var connectionError: String?

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
        connectionError = nil

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
            connectionError = "Impossible de se connecter au drone."
        }
    }

    func disconnect() {
        connectedDrone?.disconnect()
        connectedDrone = nil
        droneStateRef = nil
        connectionError = nil
    }

    // MARK: - Pilotage

    func takeOff() {
        guard let drone = connectedDrone else { return }
        // On récupère l'interface de pilotage (PilotingItf)
        // Note: GroundSdk gère le cache des références, mais pour une action ponctuelle
        // on peut le récupérer directement si on ne surveille pas l'état en continu ici.
        // Cependant, getPeripheral renvoie une Ref qui doit être gardée si on veut observer.
        // Pour une action "fire and forget", on peut juste accéder à l'interface si elle est connue,
        // mais le pattern sûr est via getPeripheral.

        _ = drone.getPeripheral(Peripherals.pilotingItf) { pilotingItf in
            pilotingItf?.takeOff()
        }
    }

    func land() {
        guard let drone = connectedDrone else { return }
        _ = drone.getPeripheral(Peripherals.pilotingItf) { pilotingItf in
            pilotingItf?.land()
        }
    }
}
