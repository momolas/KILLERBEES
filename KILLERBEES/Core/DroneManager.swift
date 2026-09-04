//
//  DroneManager.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import CoreLocation
import Foundation
import GroundSdk
enum TrackingMode: String, CaseIterable, Identifiable, Sendable {
    case lookAt = "LOOK-AT"
    case followMe = "FOLLOW-ME"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lookAt: return "Cadrage Look-At"
        case .followMe: return "Poursuite Follow-Me"
        }
    }

    var icon: String {
        switch self {
        case .lookAt: return "scope"
        case .followMe: return "figure.run"
        }
    }
}

@Observable @MainActor
class DroneManager {
    private let groundSdk: GroundSdk
    var drones: [Drone] = []
    var connectedDrone: Drone?
    var droneConnectionState: DeviceState.ConnectionState = .disconnected
    var droneConnectionCause: DeviceState.ConnectionStateCause = .none
    var isDroneConnected: Bool {
        droneConnectionState == .connected
    }
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
    var zoomLevel: Double = 1.0
    var maxZoomLevel: Double = 3.0

    // Mode de Mission Actif (Surveillance, Loisir, Chasse)
    var activeMissionMode: MissionMode = .chasse
    var isGameTrackingProfileActive: Bool = true
    var targetGroundCoordinate: CLLocationCoordinate2D?

    // Alertes de Sécurité
    var activeAlarmText: String?
    var isAlarmCritical: Bool = false

    // Mod FCC (Débridage Puissance Wi-Fi)
    var isFccMode: Bool = false
    var currentCountryCode: String = "FR"

    // Missions Autonomes MAVLink (FlightPlan)
    var flightPlanState: ActivablePilotingItfState = .unavailable
    var flightPlanUploadState: FlightPlanFileUploadState = .none
    var latestMissionItemExecuted: UInt?
    var isFlightPlanActive: Bool = false
    var waypoints: [CLLocationCoordinate2D] = []

    // Suivi de Cibles Autonome (Look-At & Follow-Me)
    var selectedTrackingMode: TrackingMode = .lookAt
    var activeTrackingMode: TrackingMode? = nil
    var isTrackingActive: Bool = false
    var trackingIssues: [String] = []

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
    private var wifiAccessPointRef: Ref<WifiAccessPoint>?
    private var flightPlanRef: Ref<FlightPlanPilotingItf>?
    private var targetTrackerRef: Ref<TargetTracker>?
    private var lookAtRef: Ref<LookAtPilotingItf>?
    private var followMeRef: Ref<FollowMePilotingItf>?

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
        droneConnectionState = drone.state.connectionState
        droneConnectionCause = drone.state.connectionStateCause

        // Surveillance de l'état de connexion
        droneStateRef = drone.getState { [weak self] state in
            guard let self, let state else { return }
            self.droneConnectionState = state.connectionState
            self.droneConnectionCause = state.connectionStateCause

            if state.connectionState == .connected {
                self.connectionError = nil
                self.applyFlightProfile(for: self.activeMissionMode)
            } else {
                self.stopPilotingTracking()
                if state.connectionState == .disconnected {
                    // Ne réinitialiser que si le drone n'est plus dans la liste des drones disponibles
                    if !self.drones.contains(where: { $0.uid == drone.uid }) {
                        if self.connectedDrone?.uid == drone.uid {
                            self.connectedDrone = nil
                            self.connectionError = "La connexion avec le drone a été interrompue."
                        }
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
            if let zoom = camera.zoom {
                self.zoomLevel = zoom.currentLevel
                self.maxZoomLevel = zoom.maxLossLessLevel
            }
        }

        // Surveillance des Alarmes de Sécurité
        alarmsRef = drone.getInstrument(Instruments.alarms) { [weak self] alarms in
            guard let self, let alarms else { return }
            self.updateAlarms(alarms)
        }

        // Surveillance et Configuration Wi-Fi (Mod FCC)
        wifiAccessPointRef = drone.getPeripheral(Peripherals.wifiAccessPoint) { [weak self] wifi in
            guard let self, let wifi else { return }
            self.currentCountryCode = wifi.country.value.rawValue
            self.isFccMode = (wifi.country.value == .unitedStates)
        }

        // Surveillance du Pilotage Autonome MAVLink (FlightPlan)
        flightPlanRef = drone.getPilotingItf(PilotingItfs.flightPlan) { [weak self] flightPlan in
            guard let self, let flightPlan else { return }
            self.flightPlanState = flightPlan.state
            self.flightPlanUploadState = flightPlan.latestUploadState
            self.latestMissionItemExecuted = flightPlan.latestMissionItemExecuted
            self.isFlightPlanActive = (flightPlan.state == .active)
        }

        // Surveillance du Suivi de Cible Visuel (TargetTracker)
        targetTrackerRef = drone.getPeripheral(Peripherals.targetTracker) { [weak self] tracker in
            guard let self, tracker != nil else { return }
        }

        // Surveillance du Mode Look-At
        lookAtRef = drone.getPilotingItf(PilotingItfs.lookAt) { [weak self] lookAt in
            guard let self, lookAt != nil else { return }
            self.updateTrackingState()
        }

        // Surveillance du Mode Follow-Me
        followMeRef = drone.getPilotingItf(PilotingItfs.followMe) { [weak self] followMe in
            guard let self, followMe != nil else { return }
            self.updateTrackingState()
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
        wifiAccessPointRef = nil
        flightPlanRef = nil
        targetTrackerRef = nil
        lookAtRef = nil
        followMeRef = nil
        activeTrackingMode = nil
        isTrackingActive = false
        trackingIssues = []
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
        flightPlanState = .unavailable
        flightPlanUploadState = .none
        latestMissionItemExecuted = nil
        isFlightPlanActive = false
        droneConnectionState = .disconnected
        droneConnectionCause = .none
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

    // MARK: - Contrôle du Zoom Caméra (Traque Discrète)

    func setZoomLevel(_ level: Double) {
        guard let camera = cameraRef?.value else { return }
        camera.zoom?.control(mode: .level, target: level)
        self.zoomLevel = level
    }

    func resetZoom() {
        guard let camera = cameraRef?.value else { return }
        camera.zoom?.resetLevel()
        self.zoomLevel = 1.0
    }

    // MARK: - Profils de Vol Multi-Missions (Surveillance, Loisir, Chasse)

    func setMissionMode(_ mode: MissionMode) {
        self.activeMissionMode = mode
        applyFlightProfile(for: mode)
    }

    func applyFlightProfile(for mode: MissionMode) {
        guard let drone = connectedDrone else { return }
        _ = drone.getPilotingItf(PilotingItfs.manualCopter) { [weak self] manualCopter in
            guard let self, let manualCopter else { return }
            manualCopter.maxYawRotationSpeed.value = mode.maxYawSpeed
            manualCopter.maxPitchRoll.value = mode.maxPitchRoll
            manualCopter.maxVerticalSpeed.value = mode.maxVerticalSpeed
            manualCopter.maxPitchRollVelocity?.value = (mode == .chasse ? 180.0 : (mode == .loisir ? 90.0 : 130.0))
            self.isGameTrackingProfileActive = (mode == .chasse)
        }
    }

    func toggleGameTrackingFlightProfile() {
        if activeMissionMode == .chasse {
            setMissionMode(.surveillance)
        } else {
            setMissionMode(.chasse)
        }
    }

    func applyGameTrackingFlightProfile() {
        setMissionMode(.chasse)
    }

    func resetFlightProfileToStandard() {
        setMissionMode(.loisir)
    }

    // MARK: - Calcul Position Sol de la Cible (Projection Géographique)

    func updateTargetGroundPosition(azimuthRad: Double, elevationRad: Double) {
        guard let droneCoord = droneCoordinate, let alt = altitude, alt > 1.0 else {
            targetGroundCoordinate = nil
            return
        }

        // Angle total d'élévation par rapport à l'horizon (gimbalPitch négatif vers le bas)
        let gimbalPitchRad = gimbalPitch * .pi / 180.0
        let totalElevationRad = gimbalPitchRad + elevationRad

        // Angle de dépression vers le sol
        let depressionAngleRad = abs(min(0.0, totalElevationRad))
        let clampedDepression = max(0.08, depressionAngleRad) // Min ~4.5° pour éviter distance infinie

        let distanceGroundMeters = alt / tan(clampedDepression)

        // Cap effectif vers la cible (Cap drone + azimut cible dans l'image)
        let targetBearingRad = (heading * .pi / 180.0) + azimuthRad

        // Projection Great-Circle
        let earthRadiusMeters = 6_378_137.0
        let lat1 = droneCoord.latitude * .pi / 180.0
        let lon1 = droneCoord.longitude * .pi / 180.0

        let dOverR = distanceGroundMeters / earthRadiusMeters
        let lat2 = asin(sin(lat1) * cos(dOverR) + cos(lat1) * sin(dOverR) * cos(targetBearingRad))
        let lon2 = lon1 + atan2(sin(targetBearingRad) * sin(dOverR) * cos(lat1),
                                cos(dOverR) - sin(lat1) * sin(lat2))

        let targetLat = lat2 * 180.0 / .pi
        let targetLon = lon2 * 180.0 / .pi

        self.targetGroundCoordinate = CLLocationCoordinate2D(latitude: targetLat, longitude: targetLon)
    }

    // MARK: - Mod FCC (Puissance & Réglementation Wi-Fi)

    func toggleFccMode(enabled: Bool) {
        guard let wifi = wifiAccessPointRef?.value else { return }
        wifi.country.value = enabled ? .unitedStates : .france
        wifi.environment.value = .outdoor
        self.isFccMode = enabled
        self.currentCountryCode = enabled ? "US" : "FR"
    }

    // MARK: - Missions Autonomes MAVLink (FlightPlan)

    func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        waypoints.append(coordinate)
    }

    func clearWaypoints() {
        waypoints.removeAll()
    }

    func uploadWaypointMission(altitude: Double = 15.0) {
        guard !waypoints.isEmpty else { return }
        guard let flightPlan = flightPlanRef?.value else { return }

        // Génération du fichier standard MAVLink (QGC WPL 120)
        var lines = ["QGC WPL 120"]

        // Élément 0 : Point de départ (Home / 1er Waypoint)
        let home = waypoints.first!
        lines.append(String(format: "0\t1\t0\t16\t0\t0\t0\t0\t%.7f\t%.7f\t%.1f\t1", home.latitude, home.longitude, altitude))

        // Élément 1 : Commande Décollage (NAV_TAKEOFF = 22)
        lines.append(String(format: "1\t0\t3\t22\t0\t0\t0\t0\t0\t0\t%.1f\t1", altitude))

        // Éléments 2...N : Waypoints de navigation (NAV_WAYPOINT = 16)
        for (index, wp) in waypoints.enumerated() {
            let itemIndex = index + 2
            lines.append(String(format: "%d\t0\t3\t16\t0\t0\t0\t0\t%.7f\t%.7f\t%.1f\t1", itemIndex, wp.latitude, wp.longitude, altitude))
        }

        // Dernier élément : Retour au point de départ RTH (NAV_RETURN_TO_LAUNCH = 20)
        let rthIndex = waypoints.count + 2
        lines.append(String(format: "%d\t0\t3\t20\t0\t0\t0\t0\t0\t0\t0\t1", rthIndex))

        let content = lines.joined(separator: "\n") + "\n"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("mission.mavlink")

        do {
            try content.write(to: tempUrl, atomically: true, encoding: .utf8)
            flightPlan.uploadFlightPlan(filepath: tempUrl.path)
        } catch {
            print("Erreur écriture fichier MAVLink : \(error)")
        }
    }

    func startFlightPlan() {
        guard let flightPlan = flightPlanRef?.value, flightPlan.state == .idle else { return }
        _ = flightPlan.activate(restart: true)
    }

    func pauseFlightPlan() {
        guard let flightPlan = flightPlanRef?.value, flightPlan.state == .active else { return }
        _ = flightPlan.deactivate()
    }

    func stopFlightPlan() {
        pauseFlightPlan()
    }

    // MARK: - Suivi Visuel par IA & Pilotage Autonome (Look-At & Follow-Me)

    func selectTrackingMode(_ mode: TrackingMode) {
        selectedTrackingMode = mode
        if isTrackingActive {
            startPilotingTracking(mode: mode)
        } else {
            updateTrackingState()
        }
    }

    func startPilotingTracking(mode: TrackingMode? = nil) {
        let targetMode = mode ?? selectedTrackingMode
        if targetMode == .lookAt {
            if followMeRef?.value?.state == .active {
                _ = followMeRef?.value?.deactivate()
            }
            if let lookAt = lookAtRef?.value, lookAt.state != .active {
                _ = lookAt.activate()
            }
        } else {
            if lookAtRef?.value?.state == .active {
                _ = lookAtRef?.value?.deactivate()
            }
            if let followMe = followMeRef?.value, followMe.state != .active {
                if followMe.followMode.supportedModes.contains(.relative) {
                    followMe.followMode.value = .relative
                }
                _ = followMe.activate()
            }
        }
        updateTrackingState()
    }

    func stopPilotingTracking() {
        if lookAtRef?.value?.state == .active {
            _ = lookAtRef?.value?.deactivate()
        }
        if followMeRef?.value?.state == .active {
            _ = followMeRef?.value?.deactivate()
        }
        activeTrackingMode = nil
        isTrackingActive = false
        updateTrackingState()
    }

    func sendTargetDetection(
        azimuth: Double,
        elevation: Double,
        changeOfScale: Double,
        confidence: Double,
        isNewTarget: Bool
    ) {
        guard let tracker = targetTrackerRef?.value else { return }

        // Si le mode de pilotage autonome n'est pas encore actif, l'activer
        if !isTrackingActive {
            startPilotingTracking()
        }

        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        let info = TargetDetectionInfo(
            targetAzimuth: azimuth,
            targetElevation: elevation,
            changeOfScale: changeOfScale,
            confidence: confidence,
            isNewTarget: isNewTarget,
            timestamp: timestamp
        )
        tracker.sendTargetDetectionInfo(info)
    }

    private func updateTrackingState() {
        if lookAtRef?.value?.state == .active {
            activeTrackingMode = .lookAt
            isTrackingActive = true
        } else if followMeRef?.value?.state == .active {
            activeTrackingMode = .followMe
            isTrackingActive = true
        } else {
            activeTrackingMode = nil
            isTrackingActive = false
        }

        var issues: [String] = []
        if selectedTrackingMode == .lookAt, let lookAt = lookAtRef?.value {
            for issue in lookAt.availabilityIssues {
                issues.append(issueDescription(issue))
            }
        } else if selectedTrackingMode == .followMe, let followMe = followMeRef?.value {
            for issue in followMe.availabilityIssues {
                issues.append(issueDescription(issue))
            }
        }
        trackingIssues = issues
    }

    private func issueDescription(_ issue: TrackingIssue) -> String {
        switch issue {
        case .droneNotFlying: return "Drone au sol"
        case .droneNotCalibrated: return "Drone non calibré"
        case .droneGpsInfoInaccurate: return "GPS drone imprécis"
        case .droneTooCloseToTarget: return "Trop près de la cible"
        case .droneTooCloseToGround: return "Trop près du sol"
        case .targetGpsInfoInaccurate: return "GPS cible imprécis"
        case .targetBarometerInfoInaccurate: return "Baromètre imprécis"
        case .targetDetectionInfoMissing: return "Cible visuelle non détectée"
        case .droneAboveMaxAltitude: return "Altitude maximale atteinte"
        case .droneOutOfGeofence: return "Hors de la zone de vol"
        case .droneTooFarFromTarget: return "Trop loin de la cible"
        case .targetHorizontalSpeedKO: return "Vitesse horizontale trop élevée"
        case .targetVerticalSpeedKO: return "Vitesse verticale trop élevée"
        case .targetAltitudeAccuracyKO: return "Altitude cible imprécise"
        }
    }
}
