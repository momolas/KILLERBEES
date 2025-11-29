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
    @EnvironmentObject var droneManager: DroneManager
    @StateObject private var videoController = VideoController()

    var body: some View {
        VStack {
            if let streamView = videoController.streamView {
                VideoPlayerView(streamView: streamView)
                    .frame(height: 300)
                    .background(Color.black)
            } else {
                ZStack {
                    Color.black
                    Text("Connexion au flux vidéo...")
                        .foregroundColor(.white)
                }
                .frame(height: 300)
            }

            Spacer()

            HStack {
                Button(action: {
                    droneManager.takeOff()
                }) {
                    Text("Décoller")
                        .fontWeight(.bold)
                        .padding()
                        .frame(minWidth: 100)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    droneManager.land()
                }) {
                    Text("Atterrir")
                        .fontWeight(.bold)
                        .padding()
                        .frame(minWidth: 100)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 50)
        }
        .padding()
        .navigationTitle(drone.name ?? "Drone")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            videoController.setup(with: drone)
        }
        .onDisappear {
            videoController.cleanup()
        }
    }
}
