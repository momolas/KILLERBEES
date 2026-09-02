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
    @State private var videoController = VideoController()
    @State private var showErrorAlert = false

    init(drone: Drone) {
        self.drone = drone
    }

    var body: some View {
        VStack {
            VideoSection(stream: videoController.currentStream)

            Spacer()

            ControlButtonsSection(
                onTakeOff: { droneManager.takeOff() },
                onLand: { droneManager.land() }
            )
        }
        .padding()
        .navigationTitle(drone.name.isEmpty ? "Drone" : drone.name)
        .navigationBarTitleDisplayMode(.inline)
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
