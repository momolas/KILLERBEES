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
            if let streamView = videoController.streamView {
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

            Spacer()

            HStack {
                Button(action: {
                    droneManager.takeOff()
                }) {
                    Text("Décoller")
                        .bold()
                        .padding()
                        .frame(minWidth: 120)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 12))
                }

                Button(action: {
                    droneManager.land()
                }) {
                    Text("Atterrir")
                        .bold()
                        .padding()
                        .frame(minWidth: 120)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding(.bottom)
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
