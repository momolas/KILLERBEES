//
//  ContentView.swift
//  KILLERBEES
//
//  Refactored by Jules
//

import GroundSdk
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section(header: Text("Appareils à proximité")) {
                    ForEach(droneManager.drones, id: \.uid) { drone in
                        Button {
                            selectDrone(drone)
                        } label: {
                            DroneRow(drone: drone, isConnected: drone.uid == droneManager.connectedDrone?.uid)
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
            .onChange(of: droneManager.connectedDrone) {
                if droneManager.connectedDrone == nil {
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

// Composant pour une ligne de drone, plus propre
struct DroneRow: View {
    let drone: Drone
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(drone.name ?? "Drone Inconnu")
                    .font(.headline)
                Text("UID: \(drone.uid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
