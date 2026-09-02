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

    var remoteControls: [RemoteControl] = []
    var connectedRemoteControl: RemoteControl?
    var rcConnectionState: DeviceState.ConnectionState = .disconnected
    var rcBatteryLevel: Int?
    var discoveredDronesViaRC: [DiscoveredDrone] = []
    var knownDronesViaRC: [KnownDrone] = []
    var isDroneFinderScanning: Bool = false

    var connectionError: String?

    private var droneListRef: Ref<[DroneListEntry]>?
    private var droneStateRef: Ref<DeviceState>?

    private var rcListRef: Ref<[RemoteControlListEntry]>?
    private var rcStateRef: Ref<DeviceState>?
    private var rcBatteryRef: Ref<BatteryInfo>?
    private var droneFinderRef: Ref<DroneFinder>?
    private var autoConnectionRef: Ref<AutoConnection>?

    init(groundSdk: GroundSdk) {
        self.groundSdk = groundSdk
        setupAutoConnection()
        scanForDrones()
        scanForRemoteControls()
    }

    // MARK: - Auto-Connexion Intelligente

    private func setupAutoConnection() {
        autoConnectionRef = groundSdk.getFacility(Facilities.autoConnection) { [weak self] autoConnection in
            guard let self, let autoConnection else { return }
            if autoConnection.state == .stopped {
                _ = autoConnection.start()
            }
            if let drone = autoConnection.drone {
                if self.connectedDrone == nil || self.connectedDrone?.uid != drone.uid {
                    self.connectToDrone(drone)
                }
            }
        }
    }

    // MARK: - Détection des Drones

    private func scanForDrones() {
        droneListRef = groundSdk.getDroneList { [weak self] droneList in
            guard let self else { return }
            self.drones = (droneList ?? []).compactMap { self.groundSdk.getDrone(uid: $0.uid) }
            
            // Auto-connexion au premier drone disponible s'il n'y a pas de drone actif
            if self.connectedDrone == nil, let firstDrone = self.drones.first {
                self.connectToDrone(firstDrone)
            }
        }
    }

    // MARK: - Détection & Gestion du SkyController

    private func scanForRemoteControls() {
        rcListRef = groundSdk.getRemoteControlList { [weak self] rcList in
            guard let self else { return }
            self.remoteControls = (rcList ?? []).compactMap { self.groundSdk.getRemoteControl(uid: $0.uid) }

            if let activeRC = self.connectedRemoteControl {
                // Vérifier si la télécommande active est toujours dans la liste
                if !self.remoteControls.contains(where: { $0.uid == activeRC.uid }) {
                    self.connectedRemoteControl = self.remoteControls.first
                    if let newRC = self.connectedRemoteControl {
                        self.connectToRemoteControl(newRC)
                    } else {
                        self.resetRCState()
                    }
                }
            } else if let firstRC = self.remoteControls.first {
                self.connectToRemoteControl(firstRC)
            } else {
                self.resetRCState()
            }
        }
    }

    private func resetRCState() {
        connectedRemoteControl = nil
        rcConnectionState = .disconnected
        rcBatteryLevel = nil
        discoveredDronesViaRC = []
        knownDronesViaRC = []
    }

    func connectToRemoteControl(_ rc: RemoteControl) {
        connectedRemoteControl = rc

        // 1. Observer l'état de connexion de la télécommande
        rcStateRef = rc.getState { [weak self] state in
            guard let self, let state else { return }
            self.rcConnectionState = state.connectionState

            if state.connectionState == .connected {
                self.monitorRCDevices(rc)
            } else if state.connectionState == .disconnected {
                // Si la télécommande n'est plus détectée dans la liste des périphériques
                if !self.remoteControls.contains(where: { $0.uid == rc.uid }) {
                    self.resetRCState()
                }
            }
        }

        // 2. Lancer la connexion matérielle si nécessaire
        _ = rc.connect()
    }

    private func monitorRCDevices(_ rc: RemoteControl) {
        // Observer la batterie du SkyController
        rcBatteryRef = rc.getInstrument(Instruments.batteryInfo) { [weak self] battery in
            guard let self else { return }
            self.rcBatteryLevel = battery?.batteryLevel
        }

        // Observer le DroneFinder pour détecter et auto-connecter le drone associé
        droneFinderRef = rc.getPeripheral(Peripherals.droneFinder) { [weak self] finder in
            guard let self, let finder else { return }
            self.discoveredDronesViaRC = finder.discoveredDrones
            self.knownDronesViaRC = finder.knownDrones
            self.isDroneFinderScanning = (finder.state == .scanning)

            // Auto-connexion directe au drone associé / mémorisé par le SkyController
            if self.connectedDrone == nil {
                if let knownDrone = finder.knownDrones.first,
                   let drone = self.groundSdk.getDrone(uid: knownDrone.uid) {
                    self.connectToDrone(drone)
                } else if let knownDiscovered = finder.discoveredDrones.first(where: { $0.known }),
                          let drone = self.groundSdk.getDrone(uid: knownDiscovered.uid) {
                    self.connectToDrone(drone)
                } else if let firstDiscovered = finder.discoveredDrones.first {
                    self.connectViaDroneFinder(firstDiscovered)
                }
            }
        }

        // Actualiser la recherche de drones via la télécommande
        droneFinderRef?.value?.refresh(useBackupRadio: true)
    }

    func refreshDroneFinder() {
        droneFinderRef?.value?.refresh(useBackupRadio: true)
    }

    func connectToDiscoveredDrone(_ discoveredDrone: DiscoveredDrone) {
        if let drone = groundSdk.getDrone(uid: discoveredDrone.uid) {
            connectToDrone(drone)
        } else {
            connectViaDroneFinder(discoveredDrone)
        }
    }

    func connectViaDroneFinder(_ discoveredDrone: DiscoveredDrone, password: String? = nil) {
        guard let finder = droneFinderRef?.value else { return }
        if let password, !password.isEmpty {
            _ = finder.connect(discoveredDrone: discoveredDrone, password: password)
        } else {
            _ = finder.connect(discoveredDrone: discoveredDrone)
        }
    }

    func connectToKnownDrone(_ knownDrone: KnownDrone) {
        if let drone = groundSdk.getDrone(uid: knownDrone.uid) {
            connectToDrone(drone)
        }
    }

    // MARK: - Connexion Drone

    func connectToDrone(_ drone: Drone) {
        if connectedDrone?.uid == drone.uid {
            return
        }

        connectionError = nil

        // Si on change de drone, on déconnecte l'ancien
        if let current = connectedDrone, current.uid != drone.uid {
            disconnect()
        }

        connectedDrone = drone

        // Surveillance de l'état de connexion
        droneStateRef = drone.getState { [weak self] state in
            guard let self, let state else { return }
            if state.connectionState == .connected {
                self.connectionError = nil
            } else if state.connectionState == .disconnected {
                // Ne réinitialiser que si le drone n'est plus dans la liste des drones disponibles
                if !self.drones.contains(where: { $0.uid == drone.uid }) {
                    if self.connectedDrone?.uid == drone.uid {
                        self.connectedDrone = nil
                        self.connectionError = "La connexion avec le drone a été interrompue."
                    }
                }
            }
        }

        // Connexion explicite (GroundSdk route via le SkyController s'il est connecté)
        _ = drone.connect()
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
        _ = drone.getPilotingItf(PilotingItfs.manualCopter) { pilotingItf in
            pilotingItf?.takeOff()
        }
    }

    func land() {
        guard let drone = connectedDrone else { return }
        _ = drone.getPilotingItf(PilotingItfs.manualCopter) { pilotingItf in
            pilotingItf?.land()
        }
    }
}
