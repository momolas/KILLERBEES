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
        }
    }

    // MARK: - Détection des Drones

    private func scanForDrones() {
        droneListRef = groundSdk.getDroneList { [weak self] droneList in
            guard let self else { return }
            self.drones = (droneList ?? []).compactMap { self.groundSdk.getDrone(uid: $0.uid) }
        }
    }

    // MARK: - Détection & Gestion du SkyController

    private func scanForRemoteControls() {
        rcListRef = groundSdk.getRemoteControlList { [weak self] rcList in
            guard let self else { return }
            self.remoteControls = (rcList ?? []).compactMap { self.groundSdk.getRemoteControl(uid: $0.uid) }

            // Auto-connexion à la première télécommande détectée (ex: branchée via USB)
            if let firstRC = self.remoteControls.first, self.connectedRemoteControl == nil {
                self.connectToRemoteControl(firstRC)
            } else if self.remoteControls.isEmpty {
                self.connectedRemoteControl = nil
                self.rcBatteryLevel = nil
                self.discoveredDronesViaRC = []
                self.knownDronesViaRC = []
            }
        }
    }

    func connectToRemoteControl(_ rc: RemoteControl) {
        connectedRemoteControl = rc

        // 1. Observer l'état de connexion de la télécommande
        rcStateRef = rc.getState { [weak self] state in
            guard let self, let state else { return }
            if state.connectionState == .disconnected {
                if self.connectedRemoteControl?.uid == rc.uid {
                    self.connectedRemoteControl = nil
                    self.rcBatteryLevel = nil
                    self.discoveredDronesViaRC = []
                    self.knownDronesViaRC = []
                }
            } else if state.connectionState == .connected {
                self.monitorRCDevices(rc)
            }
        }

        // 2. Lancer la connexion matérielle
        _ = rc.connect()
    }

    private func monitorRCDevices(_ rc: RemoteControl) {
        // Observer la batterie du SkyController
        rcBatteryRef = rc.getInstrument(Instruments.batteryInfo) { [weak self] battery in
            guard let self else { return }
            self.rcBatteryLevel = battery?.batteryLevel
        }

        // Observer le DroneFinder pour détecter les drones via radio longue portée
        droneFinderRef = rc.getPeripheral(Peripherals.droneFinder) { [weak self] finder in
            guard let self, let finder else { return }
            self.discoveredDronesViaRC = finder.discoveredDrones
            self.knownDronesViaRC = finder.knownDrones
            self.isDroneFinderScanning = (finder.state == .scanning)
        }

        // Actualiser la recherche de drones via la télécommande
        droneFinderRef?.value?.refresh(useBackupRadio: true)
    }

    func refreshDroneFinder() {
        droneFinderRef?.value?.refresh(useBackupRadio: true)
    }

    func connectViaDroneFinder(_ discoveredDrone: DiscoveredDrone, password: String? = nil) {
        guard let finder = droneFinderRef?.value else { return }
        if let password, !password.isEmpty {
            _ = finder.connect(discoveredDrone: discoveredDrone, password: password)
        } else {
            _ = finder.connect(discoveredDrone: discoveredDrone)
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
            if state.connectionState == .disconnected {
                if self.connectedDrone?.uid == drone.uid {
                    self.connectedDrone = nil
                    self.connectionError = "La connexion avec le drone a été interrompue."
                }
            }
        }

        // Connexion explicite (GroundSdk route via le SkyController s'il est connecté)
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
