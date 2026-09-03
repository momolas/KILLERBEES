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
    @State private var visionService = VisionTrackerService()
    @State private var isMapExpanded = false
    @State private var showErrorAlert = false

    init(drone: Drone) {
        self.drone = drone
    }

    var body: some View {
        ZStack {
            // 1. Flux vidéo bord-à-bord plein écran avec flux IA
            VideoSection(stream: videoController.currentStream) { image in
                if visionService.isTrackingActive, let cgImage = image.cgImage {
                    visionService.processFrame(cgImage) { azimuth, elevation, scale, confidence, isNew in
                        droneManager.sendTargetDetection(
                            azimuth: azimuth,
                            elevation: elevation,
                            changeOfScale: scale,
                            confidence: confidence,
                            isNewTarget: isNew
                        )
                    }
                }
            }
            .ignoresSafeArea()

            // 2. Superposition IA Tactile (Réticules & Verrouillage Cible)
            if visionService.isTrackingActive {
                CockpitAITrackingOverlay(
                    detectedBoxes: visionService.detectedBoxes,
                    lockedBox: visionService.lockedTargetBox,
                    isTargetLocked: visionService.isTargetLocked,
                    trackingMode: droneManager.selectedTrackingMode,
                    trackingIssues: droneManager.trackingIssues,
                    onSelectPoint: { visionService.lockTarget(at: $0) },
                    onSelectBox: { visionService.lockBox($0) },
                    onSelectMode: { droneManager.selectTrackingMode($0) },
                    onCancelLock: {
                        visionService.unlockTarget()
                        droneManager.stopPilotingTracking()
                    }
                )
                .ignoresSafeArea()
            }

            // 3. HUD superposé (Cockpit Overlay)
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
                    droneConnectionState: droneManager.droneConnectionState,
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

                    // Contrôles Nacelle, IA Tracking & Déclencheurs Médias (Droite)
                    HStack(alignment: .center, spacing: 10) {
                        // Bouton IA Tracking
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                visionService.toggleTracking()
                                if !visionService.isTrackingActive {
                                    droneManager.stopPilotingTracking()
                                }
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: visionService.isTargetLocked ? "scope" : (visionService.isTrackingActive ? "viewfinder.circle.fill" : "viewfinder"))
                                    .font(.system(size: 16, weight: .bold))
                                Text(visionService.isTargetLocked ? "LOCK" : (visionService.isTrackingActive ? "IA ON" : "IA"))
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(visionService.isTargetLocked ? .red : (visionService.isTrackingActive ? .green : .white))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(.circle)
                            .overlay(
                                Circle().strokeBorder(
                                    visionService.isTargetLocked ? Color.red : (visionService.isTrackingActive ? Color.green : Color.white.opacity(0.3)),
                                    lineWidth: 1.5
                                )
                            )
                        }
                        .accessibilityLabel("Activer le suivi par intelligence artificielle")

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

