//
//  DroneControlView.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import SwiftUI
import GroundSdk

struct DroneControlView: View {
    let drone: Drone
    @SwiftUI.Environment(DroneManager.self) private var droneManager: DroneManager
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var videoController = VideoController()
    @State private var isMapExpanded = false
    @State private var showErrorAlert = false

    init(drone: Drone) {
        self.drone = drone
    }

    var body: some View {
        ZStack {
            // 1. Flux vidéo bord-à-bord plein écran
            VideoSection(stream: videoController.currentStream)
                .ignoresSafeArea()

            // 2. HUD superposé (Cockpit Overlay)
            VStack {
                // Barre Supérieure
                CockpitTopBar(
                    droneName: drone.name,
                    droneBattery: droneManager.droneBatteryLevel,
                    rcBattery: droneManager.rcBatteryLevel,
                    flyingState: droneManager.flyingState,
                    satelliteCount: droneManager.satelliteCount,
                    isGpsFixed: droneManager.isGpsFixed,
                    radioSignalQuality: droneManager.radioSignalQuality,
                    isRthActive: droneManager.isRthActive,
                    isFccMode: droneManager.isFccMode,
                    onToggleFcc: { droneManager.toggleFccMode(enabled: !droneManager.isFccMode) },
                    onDismiss: { dismiss() }
                )
                .padding(.top, 8)

                // Bannière d'Alerte Vol (si active)
                CockpitAlarmBanner(
                    message: droneManager.activeAlarmText,
                    isCritical: droneManager.isAlarmCritical
                )
                .padding(.top, 2)

                // Télémétrie Supérieure (Altitude, Vitesse, Attitude)
                HStack(alignment: .top) {
                    CockpitTelemetryHUD(
                        altitude: droneManager.altitude,
                        verticalSpeed: droneManager.verticalSpeed,
                        groundSpeed: droneManager.groundSpeed
                    )

                    Spacer()

                    // Horizon Artificiel & Boussole
                    CockpitAttitudeIndicator(
                        pitch: droneManager.pitch,
                        roll: droneManager.roll,
                        heading: droneManager.heading
                    )
                    .padding(.trailing)
                }
                .padding(.top, 4)

                Spacer()

                // Bandeau de Mission Autonome MAVLink (si waypoints ou mission active)
                if isMapExpanded || !droneManager.waypoints.isEmpty || droneManager.isFlightPlanActive {
                    CockpitFlightPlanOverlay(
                        flightPlanState: droneManager.flightPlanState,
                        flightPlanUploadState: droneManager.flightPlanUploadState,
                        waypointCount: droneManager.waypoints.count,
                        currentMissionItem: droneManager.latestMissionItemExecuted,
                        isFlightPlanActive: droneManager.isFlightPlanActive,
                        onUploadMission: { droneManager.uploadWaypointMission() },
                        onStartMission: { droneManager.startFlightPlan() },
                        onPauseMission: { droneManager.pauseFlightPlan() },
                        onClearWaypoints: { droneManager.clearWaypoints() }
                    )
                    .padding(.bottom, 6)
                }

                // Zone Médiane / Basse : Mini-Carte (Gauche), Commandes Caméra & Nacelle (Droite), Barre de Vol (Centre)
                HStack(alignment: .bottom, spacing: 12) {
                    // Mini-Carte MapKit PiP (Bas Gauche)
                    CockpitMiniMap(
                        droneCoordinate: droneManager.droneCoordinate,
                        homeCoordinate: droneManager.homeCoordinate,
                        heading: droneManager.heading,
                        waypoints: droneManager.waypoints,
                        onAddWaypoint: { droneManager.addWaypoint($0) },
                        isExpanded: $isMapExpanded
                    )
                    .padding(.leading)

                    Spacer()

                    // Commandes de Vol Décollage / Atterrissage / RTH
                    CockpitBottomBar(
                        flyingState: droneManager.flyingState,
                        isRthActive: droneManager.isRthActive,
                        onTakeOff: { droneManager.takeOff() },
                        onLand: { droneManager.land() },
                        onToggleRth: {
                            if droneManager.isRthActive {
                                droneManager.cancelReturnHome()
                            } else {
                                droneManager.triggerReturnHome()
                            }
                        }
                    )

                    Spacer()

                    // Contrôles Nacelle & Déclencheurs Médias (Droite)
                    HStack(alignment: .center, spacing: 10) {
                        CockpitGimbalControl(
                            currentPitch: droneManager.gimbalPitch,
                            onPitchChange: { newPitch in
                                droneManager.setGimbalPitch(newPitch)
                            }
                        )

                        CockpitCameraCaptureView(
                            isRecording: droneManager.isRecording,
                            canTakePhoto: droneManager.canTakePhoto,
                            onTakePhoto: { droneManager.takePhoto() },
                            onToggleRecording: { droneManager.toggleRecording() }
                        )
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .alert("Erreur de connexion", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                droneManager.connectionError = nil
            }
        } message: {
            if let error = droneManager.connectionError {
                Text(error)
            }
        }
        .onChange(of: droneManager.connectionError) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .onAppear {
            videoController.setup(with: drone)
        }
        .onDisappear {
            videoController.cleanup()
        }
    }
}

