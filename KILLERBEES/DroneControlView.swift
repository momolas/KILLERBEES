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
                CockpitTopBar(
                    droneName: drone.name,
                    droneBattery: droneManager.droneBatteryLevel,
                    rcBattery: droneManager.rcBatteryLevel,
                    flyingState: droneManager.flyingState,
                    onDismiss: { dismiss() }
                )
                .padding(.top, 8)

                Spacer()

                CockpitBottomBar(
                    flyingState: droneManager.flyingState,
                    onTakeOff: { droneManager.takeOff() },
                    onLand: { droneManager.land() }
                )
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

