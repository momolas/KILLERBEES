//
//  ContentView.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import GroundSdk
import SwiftUI

struct ContentView: View {
    @SwiftUI.Environment(DroneManager.self) private var droneManager: DroneManager
    @State private var navigationPath = NavigationPath()

    init() {}

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                SkyControllerSection()

                Section("Drones disponibles") {
                    if droneManager.drones.isEmpty {
                        Text("Aucun drone détecté à proximité.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(droneManager.drones) { drone in
                            let isConnected = drone.uid == droneManager.connectedDrone?.uid
                            Button {
                                selectDrone(drone)
                            } label: {
                                DroneRow(drone: drone, isConnected: isConnected)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("KILLERBEES")
            .navigationDestination(for: String.self) { droneUid in
                if let drone = droneManager.drones.first(where: { $0.uid == droneUid }) {
                    DroneControlView(drone: drone)
                } else {
                    ContentUnavailableView(
                        "Drone introuvable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("La connexion avec ce drone a été perdue.")
                    )
                }
            }
            // Gestion du retour arrière automatique si déconnexion
            .onChange(of: droneManager.connectedDrone) { _, newValue in
                if newValue == nil {
                    navigationPath = NavigationPath()
                }
            }
        }
    }

    private func selectDrone(_ drone: Drone) {
        droneManager.connectToDrone(drone)
        navigationPath.append(drone.uid)
    }
}

#Preview {
    ContentView()
        .environment(DroneManager(groundSdk: GroundSdk()))
}
