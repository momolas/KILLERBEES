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
    @State private var isLeisureGridEnabled = false
    @State private var isDeclutterMode = false
    @State private var isTacticalHUDEnabled = false
    @State private var showErrorAlert = false

    init(drone: Drone) {
        self.drone = drone
    }

    var body: some View {
        ZStack {
            // 1. Flux vidéo bord-à-bord plein écran avec flux IA
            ZStack {
                VideoSection(
                    stream: videoController.currentStream,
                    isDroneConnected: droneManager.isDroneConnected,
                    onFrameCaptured: handleCapturedFrame
                )

                if isLeisureGridEnabled {
                    CockpitCompositionGridView()
                }
            }
            .ignoresSafeArea()

            // 2. Horizon Artificiel Militaire Central (Pitch Ladder & Heading Tape HUD)
            // Affiché uniquement si le mode tactique est explicitement activé et que l'écran n'est pas épuré
            if isTacticalHUDEnabled && !isDeclutterMode {
                CockpitMilitaryPitchLadderHUD(
                    pitch: droneManager.pitch,
                    roll: droneManager.roll,
                    heading: droneManager.heading
                )
                .ignoresSafeArea()
            }

            // 3. Superposition IA Tactile (Réticules & Verrouillage Cible)
            if droneManager.isDroneConnected && visionService.isTrackingActive {
                CockpitAITrackingOverlay(
                    detectedObjects: visionService.detectedObjects,
                    lockedBox: visionService.lockedTargetBox,
                    isTargetLocked: visionService.isTargetLocked,
                    trackingMode: droneManager.selectedTrackingMode,
                    trackingIssues: droneManager.trackingIssues,
                    isDroneTrackingActive: droneManager.isTrackingActive,
                    segmentationMask: visionService.segmentationMaskImage,
                    isThermalMaskEnabled: visionService.isThermalMaskEnabled,
                    onSelectPoint: {
                        visionService.lockTarget(at: $0)
                        droneManager.startPilotingTracking()
                    },
                    onSelectBox: {
                        visionService.lockBox($0)
                        droneManager.startPilotingTracking()
                    },
                    onSelectMode: { droneManager.selectTrackingMode($0) },
                    onCancelLock: {
                        visionService.unlockTarget()
                        droneManager.stopPilotingTracking()
                    }
                )
                .ignoresSafeArea()
            }

            // 4. HUD superposé (Cockpit Overlay)
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
                    activeMissionMode: droneManager.activeMissionMode,
                    droneConnectionState: droneManager.droneConnectionState,
                    smartRTH: droneManager.smartRTH,
                    isDeclutterMode: isDeclutterMode,
                    onToggleDeclutter: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isDeclutterMode.toggle()
                        }
                    },
                    isTacticalHUDEnabled: isTacticalHUDEnabled,
                    onToggleTacticalHUD: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isTacticalHUDEnabled.toggle()
                        }
                    },
                    onToggleFcc: { droneManager.toggleFccMode(enabled: !droneManager.isFccMode) },
                    onSelectMissionMode: { droneManager.setMissionMode($0) },
                    onDismiss: { dismiss() }
                )
                .padding(.top, 4)

                // Ligne Supérieure d'Instruments Périmétriques
                if isDeclutterMode {
                    HStack {
                        // En mode épuré : télémétrie ultra-compacte en capsule discrète plaquée à gauche
                        HStack(spacing: 8) {
                            if let alt = droneManager.altitude {
                                Text("ALT \(alt, format: .number.precision(.fractionLength(1)))m")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            if let spd = droneManager.groundSpeed {
                                Text("VIT \((spd * 3.6), format: .number.precision(.fractionLength(1)))km/h")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(.capsule)
                        .padding(.leading, 6)
                        .padding(.top, 2)

                        Spacer()
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        // HAUT GAUCHE : Télémétrie (Altitude, Vitesse) plaquée contre le bord gauche
                        CockpitTelemetryHUD(
                            altitude: droneManager.altitude,
                            verticalSpeed: droneManager.verticalSpeed,
                            groundSpeed: droneManager.groundSpeed
                        )
                        .padding(.leading, 6)

                        Spacer(minLength: 4)

                        // HAUT CENTRE : Bannières d'alerte & Badges de statut compacts
                        VStack(spacing: 3) {
                            if droneManager.activeAlarmText != nil {
                                CockpitAlarmBanner(
                                    message: droneManager.activeAlarmText,
                                    isCritical: droneManager.isAlarmCritical
                                )
                            }

                            if droneManager.flyingState == .flying || droneManager.isRthActive {
                                CockpitSmartRTHBadge(
                                    smartRTH: droneManager.smartRTH,
                                    isRthActive: droneManager.isRthActive,
                                    onTriggerRth: {
                                        HapticFeedback.tap()
                                        droneManager.triggerReturnHome()
                                    },
                                    onCancelRth: {
                                        HapticFeedback.tap()
                                        droneManager.cancelReturnHome()
                                    },
                                    onCancelAutoTrigger: {
                                        HapticFeedback.tap()
                                        droneManager.cancelRthAutoTrigger()
                                    }
                                )
                            }

                            switch droneManager.activeMissionMode {
                            case .chasse:
                                if visionService.isTargetLocked {
                                    CockpitGameVectorBadge(
                                        headingDeg: visionService.targetHeadingDeg,
                                        speedKmH: visionService.targetSpeedKmH,
                                        cardinal: visionService.targetBearingCardinal,
                                        speciesName: visionService.targetSpeciesName,
                                        speciesIcon: visionService.targetSpeciesIcon,
                                        isProfileActive: droneManager.isGameTrackingProfileActive,
                                        onToggleProfile: {
                                            droneManager.toggleGameTrackingFlightProfile()
                                        }
                                    )
                                }

                            case .surveillance:
                                CockpitSurveillanceBadge(
                                    hasIntruderAlert: visionService.hasIntruderAlert,
                                    detectedHumansCount: visionService.detectedHumansCount,
                                    onCaptureSnapshot: {
                                        droneManager.takePhoto()
                                    }
                                )

                            case .loisir:
                                CockpitLeisureBadge(
                                    isGridEnabled: $isLeisureGridEnabled,
                                    isRecording: droneManager.isRecording
                                )
                            }
                        }

                        Spacer(minLength: 4)

                        // HAUT DROITE : Horizon Artificiel & Boussole Compact plaqué contre le bord droit
                        if !isTacticalHUDEnabled {
                            CockpitAttitudeIndicator(
                                pitch: droneManager.pitch,
                                roll: droneManager.roll,
                                heading: droneManager.heading
                            )
                            .padding(.trailing, 6)
                        }
                    }
                    .padding(.top, 2)
                }

                // CENTRE : Vaste espace libre garanti pour la visibilité du flux caméra
                Spacer()

                if !isDeclutterMode {
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
                        .padding(.bottom, 4)
                    }
                }

                // Zone Basse : Mini-Carte (Plaquée Gauche), Contrôles de Vol (Centre Bas), Caméra (Plaquée Droite)
                HStack(alignment: .bottom, spacing: 8) {
                    if !isDeclutterMode {
                        // BAS GAUCHE : Mini-Carte MapKit PiP
                        CockpitMiniMap(
                            droneCoordinate: droneManager.droneCoordinate,
                            homeCoordinate: droneManager.homeCoordinate,
                            heading: droneManager.heading,
                            waypoints: droneManager.waypoints,
                            targetCoordinate: droneManager.targetGroundCoordinate,
                            onAddWaypoint: { droneManager.addWaypoint($0) },
                            isExpanded: $isMapExpanded
                        )
                        .padding(.leading, 6)

                        Spacer(minLength: 4)

                        // BAS CENTRE : Commandes de Vol Décollage / Atterrissage / RTH & Statut
                        VStack(spacing: 4) {
                            if !droneManager.isDroneConnected || visionService.isTrackingActive || visionService.isTargetLocked {
                                CockpitMissionStatusBar(
                                    isConnected: droneManager.isDroneConnected,
                                    isTargetLocked: visionService.isTargetLocked,
                                    isTrackingActive: visionService.isTrackingActive,
                                    trackingMode: droneManager.selectedTrackingMode,
                                    flyingState: droneManager.flyingState,
                                    altitude: droneManager.altitude
                                )
                            }

                            CockpitBottomBar(
                                flyingState: droneManager.flyingState,
                                isRthActive: droneManager.isRthActive,
                                onTakeOff: {
                                    HapticFeedback.tap()
                                    droneManager.takeOff()
                                },
                                onLand: {
                                    HapticFeedback.tap()
                                    droneManager.land()
                                },
                                onToggleRth: {
                                    HapticFeedback.tap()
                                    if droneManager.isRthActive {
                                        droneManager.cancelReturnHome()
                                    } else {
                                        droneManager.triggerReturnHome()
                                    }
                                }
                            )
                        }
                    }

                    Spacer(minLength: 4)

                    // BAS DROITE : Contrôles Caméra, Zoom & Bouton IA
                    HStack(alignment: .center, spacing: 8) {
                        // Bouton IA Tracking
                        Button {
                            HapticFeedback.tap()
                            withAnimation(.spring(response: 0.3)) {
                                visionService.toggleTracking()
                                if !visionService.isTrackingActive {
                                    droneManager.stopPilotingTracking()
                                }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: visionService.isTargetLocked ? "scope" : (visionService.isTrackingActive ? "viewfinder.circle.fill" : "viewfinder"))
                                    .font(.system(size: 15, weight: .bold))
                                Text(visionService.isTargetLocked ? "LOCK" : (visionService.isTrackingActive ? "IA ON" : "IA"))
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(visionService.isTargetLocked ? .red : (visionService.isTrackingActive ? .green : .white))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(.circle)
                            .overlay(
                                Circle().strokeBorder(
                                    visionService.isTargetLocked ? .red : (visionService.isTrackingActive ? .green : .white.opacity(0.3)),
                                    lineWidth: 1.5
                                )
                            )
                        }
                        .disabled(!droneManager.isDroneConnected)
                        .opacity(droneManager.isDroneConnected ? 1.0 : 0.35)
                        .accessibilityLabel("Activer le suivi par intelligence artificielle")

                        if !isDeclutterMode {
                            CockpitZoomControl(
                                currentZoom: droneManager.zoomLevel,
                                onSelectZoom: { level in
                                    droneManager.setZoomLevel(level)
                                }
                            )
                        }

                        CockpitCameraCaptureView(
                            isRecording: droneManager.isRecording,
                            canTakePhoto: droneManager.canTakePhoto,
                            onTakePhoto: { droneManager.takePhoto() },
                            onToggleRecording: { droneManager.toggleRecording() }
                        )
                    }
                    .padding(.trailing, 6)
                }
                .padding(.bottom, 4)
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
        .onChange(of: droneManager.isDroneConnected) { _, isConnected in
            if !isConnected {
                videoController.stopVideoStream()
                visionService.stopTracking()
                droneManager.stopPilotingTracking()
            } else {
                videoController.setup(with: drone)
            }
        }
        .onAppear {
            videoController.setup(with: drone)
        }
        .onDisappear {
            videoController.cleanup()
        }
    }

    // MARK: - Traitement du Flux Vidéo & Télémétrie de Cible

    private func handleCapturedFrame(_ image: UIImage) {
        guard visionService.isTrackingActive, let cgImage = image.cgImage else { return }
        visionService.processFrame(
            cgImage,
            droneHeading: droneManager.heading,
            droneAltitude: droneManager.altitude ?? 30.0,
            missionMode: droneManager.activeMissionMode
        ) { azimuth, elevation, scale, confidence, isNew in
            droneManager.sendTargetDetection(
                azimuth: azimuth,
                elevation: elevation,
                changeOfScale: scale,
                confidence: confidence,
                isNewTarget: isNew
            )
            droneManager.updateTargetGroundPosition(
                azimuthRad: azimuth,
                elevationRad: elevation
            )
        }
    }
}

