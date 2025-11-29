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

    var body: some View {
        NavigationView {
            List {
                ForEach(droneManager.drones, id: \.uid) { drone in
                    Button(action: {
                        droneManager.connectToDrone(drone)
                    }) {
                        HStack {
                            Text(drone.name ?? "Drone Inconnu")
                            Spacer()
                            if drone.uid == droneManager.connectedDrone?.uid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Drones Disponibles")
            .background(
                // Correction de la navigation: Utilisation d'un Binding dérivé
                NavigationLink(
                    destination: Group {
                        if let drone = droneManager.connectedDrone {
                            DroneControlView(drone: drone)
                        }
                    },
                    isActive: Binding(
                        get: { droneManager.connectedDrone != nil },
                        set: { if !$0 { droneManager.disconnect() } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

#Preview {
    ContentView()
}
