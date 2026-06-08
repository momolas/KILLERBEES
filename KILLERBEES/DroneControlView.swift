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
    @SwiftUI.Environment(DroneManager.self) var droneManager: DroneManager
    @State private var videoController = VideoController()
    @State private var showErrorAlert = false

    var body: some View {
        VStack {
            VideoSection(streamView: videoController.streamView)

            Spacer()

            ControlButtonsSection(
                onTakeOff: { droneManager.takeOff() },
                onLand: { droneManager.land() }
            )
        }
        .padding()
        .navigationTitle(drone.name ?? "Drone")
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

struct VideoSection: View {
    let streamView: StreamView?

    var body: some View {
        if let streamView {
            VideoPlayerView(streamView: streamView)
                .frame(height: 300)
                .background(.black)
        } else {
            ZStack {
                Color.black
                Text("Connexion au flux vidéo...")
                    .foregroundStyle(.white)
            }
            .frame(height: 300)
        }
    }
}

struct ControlButtonsSection: View {
    let onTakeOff: () -> Void
    let onLand: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button("Décoller", systemImage: "arrow.up.circle.fill", action: onTakeOff)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)

            Button("Atterrir", systemImage: "arrow.down.circle.fill", action: onLand)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
        }
        .padding(.bottom)
    }
}
