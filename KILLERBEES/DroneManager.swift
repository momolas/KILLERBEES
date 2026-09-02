//
//  DroneManager.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import CoreLocation
import Foundation
import GroundSdk
import SwiftUI

@Observable @MainActor
class DroneManager {
    private let groundSdk: GroundSdk
    var drones: [Drone] = []
    var connectedDrone: Drone?
    var droneBatteryLevel: Int?
    var flyingState: FlyingIndicatorsState = .landed

    // Télémétrie de vol en temps réel
    var altitude: Double?
    var verticalSpeed: Double?
    var groundSpeed: Double?
    var satelliteCount: Int?
    var isGpsFixed: Bool = false
    var droneCoordinate: CLLocationCoordinate2D?
    var homeCoordinate: CLLocationCoordinate2D?
    var radioRssi: Int?
    var radioSignalQuality: Int?
    var isRthActive: Bool = false

    // Horizon Artificiel & Cap
    var pitch: Double = 0.0
    var roll: Double = 0.0
    var heading: Double = 0.0

    // Nacelle (Gimbal) & Caméra
    var gimbalPitch: Double = 0.0
    var isRecording: Bool = false
    var canTakePhoto: Bool = true

    // Alertes de Sécurité
    var activeAlarmText: String?
    var isAlarmCritical: Bool = false

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
    private var droneBatteryRef: Ref<BatteryInfo>?
    private var flyingIndicatorsRef: Ref<FlyingIndicators>?
    private var altimeterRef: Ref<Altimeter>?
    private var speedometerRef: Ref<Speedometer>?
    private var gpsRef: Ref<Gps>?
    private var radioRef: Ref<Radio>?
    private var returnHomeRef: Ref<ReturnHomePilotingItf>?
    private var attitudeRef: Ref<AttitudeIndicator>?
    private var compassRef: Ref<Compass>?
    private var gimbalRef: Ref<Gimbal>?
    private var cameraRef: Ref<MainCamera>?
    private var alarmsRef: Ref<Alarms>?

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

        // Surveillance de la batterie du drone
        droneBatteryRef = drone.getInstrument(Instruments.batteryInfo) { [weak self] battery in
            guard let self else { return }
            self.droneBatteryLevel = battery?.batteryLevel
        }

        // Surveillance de l'état de vol
        flyingIndicatorsRef = drone.getInstrument(Instruments.flyingIndicators) { [weak self] indicators in
            guard let self, let indicators else { return }
            self.flyingState = indicators.state ?? .landed
        }

        // Surveillance de l'altimètre
        altimeterRef = drone.getInstrument(Instruments.altimeter) { [weak self] altimeter in
            guard let self else { return }
            self.altitude = altimeter?.takeoffRelativeAltitude
            self.verticalSpeed = altimeter?.verticalSpeed
        }

        // Surveillance de la vitesse sol
        speedometerRef = drone.getInstrument(Instruments.speedometer) { [weak self] speedometer in
            guard let self else { return }
            self.groundSpeed = speedometer?.groundSpeed
        }

        // Surveillance du GPS
        gpsRef = drone.getInstrument(Instruments.gps) { [weak self] gps in
            guard let self else { return }
            self.satelliteCount = gps?.satelliteCount
            self.isGpsFixed = gps?.fixed ?? false
            if let loc = gps?.lastKnownLocation {
                self.droneCoordinate = loc.coordinate
                if self.homeCoordinate == nil {
                    self.homeCoordinate = loc.coordinate
                }
            }
        }

        // Surveillance de la liaison radio
        radioRef = drone.getInstrument(Instruments.radio) { [weak self] radio in
            guard let self else { return }
            self.radioRssi = radio?.rssi
            self.radioSignalQuality = radio?.linkSignalQuality
        }

        // Surveillance du Return-To-Home
        returnHomeRef = drone.getPilotingItf(PilotingItfs.returnHome) { [weak self] returnHome in
            guard let self else { return }
            self.isRthActive = (returnHome?.state == .active)
        }

        // Surveillance de l'Horizon Artificiel (Attitude)
        attitudeRef = drone.getInstrument(Instruments.attitudeIndicator) { [weak self] attitude in
            guard let self, let attitude else { return }
            self.pitch = attitude.pitch ?? 0.0
            self.roll = attitude.roll ?? 0.0
        }

        // Surveillance du Cap (Boussole)
        compassRef = drone.getInstrument(Instruments.compass) { [weak self] compass in
            guard let self, let compass else { return }
            self.heading = compass.heading ?? 0.0
        }

        // Surveillance de la Nacelle (Gimbal)
        gimbalRef = drone.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            guard let self, let gimbal else { return }
            if let currentPitch = gimbal.currentAttitude[.pitch] {
                self.gimbalPitch = currentPitch
            }
        }

        // Surveillance de la Caméra (MainCamera)
        cameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] camera in
            guard let self, let camera else { return }
            let state = camera.recordingState.functionState
            self.isRecording = (state == .started || state == .starting)
            self.canTakePhoto = camera.canStartPhotoCapture
        }

        // Surveillance des Alarmes de Sécurité
        alarmsRef = drone.getInstrument(Instruments.alarms) { [weak self] alarms in
            guard let self, let alarms else { return }
            self.updateAlarms(alarms)
        }

        // Connexion explicite (GroundSdk route via le SkyController s'il est connecté)
        _ = drone.connect()
    }

    private func updateAlarms(_ alarms: Alarms) {
        let autoLanding = alarms.getAlarm(kind: .automaticLandingBatteryIssue)
        let wind = alarms.getAlarm(kind: .wind)
        let power = alarms.getAlarm(kind: .power)
        let motorError = alarms.getAlarm(kind: .motorError)

        if autoLanding.level != .off {
            activeAlarmText = "Atterrissage d'urgence batterie"
            isAlarmCritical = true
        } else if wind.level != .off {
            activeAlarmText = "Alerte : Vent violent détecté !"
            isAlarmCritical = (wind.level == .critical)
        } else if power.level != .off {
            activeAlarmText = "Alerte : Batterie critique"
            isAlarmCritical = true
        } else if motorError.level != .off {
            activeAlarmText = "Alerte : Anomalie moteur"
            isAlarmCritical = true
        } else {
            activeAlarmText = nil
            isAlarmCritical = false
        }
    }

    func disconnect() {
        connectedDrone?.disconnect()
        connectedDrone = nil
        droneStateRef = nil
        droneBatteryRef = nil
        flyingIndicatorsRef = nil
        altimeterRef = nil
        speedometerRef = nil
        gpsRef = nil
        radioRef = nil
        returnHomeRef = nil
        attitudeRef = nil
        compassRef = nil
        gimbalRef = nil
        cameraRef = nil
        alarmsRef = nil
        droneBatteryLevel = nil
        flyingState = .landed
        altitude = nil
        verticalSpeed = nil
        groundSpeed = nil
        satelliteCount = nil
        isGpsFixed = false
        droneCoordinate = nil
        homeCoordinate = nil
        radioRssi = nil
        radioSignalQuality = nil
        isRthActive = false
        pitch = 0.0
        roll = 0.0
        heading = 0.0
        gimbalPitch = 0.0
        isRecording = false
        canTakePhoto = true
        activeAlarmText = nil
        isAlarmCritical = false
        connectionError = nil
    }

    // MARK: - Pilotage & Nacelle & Médias

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

    func triggerReturnHome() {
        guard let returnHome = returnHomeRef?.value else { return }
        _ = returnHome.activate()
    }

    func cancelReturnHome() {
        guard let returnHome = returnHomeRef?.value else { return }
        _ = returnHome.deactivate()
    }

    func setGimbalPitch(_ pitch: Double) {
        guard let gimbal = gimbalRef?.value else { return }
        gimbal.control(mode: .position, yaw: nil, pitch: pitch, roll: nil)
        self.gimbalPitch = pitch
    }

    func takePhoto() {
        guard let camera = cameraRef?.value, camera.canStartPhotoCapture else { return }
        camera.startPhotoCapture()
    }

    func toggleRecording() {
        guard let camera = cameraRef?.value else { return }
        let state = camera.recordingState.functionState
        if state == .started || state == .starting {
            camera.stopRecording()
        } else if camera.canStartRecord {
            camera.startRecording()
        }
    }
}
