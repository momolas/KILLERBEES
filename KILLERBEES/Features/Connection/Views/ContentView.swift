//
//  ContentView.swift
//  KILLERBEES
//
//  Created by Jules
//  Dashboard Bento Tactique Pré-Vol (Inspiré d'OpenFlight)
//

import GroundSdk
import SwiftUI

struct ContentView: View {
    @SwiftUI.Environment(DroneManager.self) private var droneManager: DroneManager
    @State private var navigationPath = NavigationPath()

    init() {}

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Fond sombre OLED avec dégradé tactique
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.07, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    // En-tête Tactique de l'application
                    DashboardHeaderView(
                        isDroneConnected: droneManager.isDroneConnected,
                        isRcConnected: droneManager.rcConnectionState == .connected,
                        isFccMode: droneManager.isFccMode,
                        onToggleFcc: {
                            HapticFeedback.tap()
                            droneManager.toggleFccMode(enabled: !droneManager.isFccMode)
                        }
                    )

                    // Grille Bento Scrollable
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            // Tuiles Principales Côte à Côte
                            HStack(alignment: .top, spacing: 14) {
                                // 1. Tuile Bento Drone Anafi
                                DashboardDroneCard(
                                    connectedDrone: droneManager.connectedDrone,
                                    isConnected: droneManager.isDroneConnected,
                                    batteryLevel: droneManager.droneBatteryLevel,
                                    satelliteCount: droneManager.satelliteCount,
                                    isGpsFixed: droneManager.isGpsFixed,
                                    availableDrones: droneManager.drones,
                                    onSelectDrone: { drone in
                                        HapticFeedback.tap()
                                        selectDrone(drone)
                                    }
                                )
                                .frame(maxWidth: .infinity, alignment: .top)

                                // 2. Tuile Bento SkyController 3
                                DashboardRemoteCard(
                                    remoteControl: droneManager.connectedRemoteControl,
                                    isConnected: droneManager.rcConnectionState == .connected,
                                    batteryLevel: droneManager.rcBatteryLevel,
                                    isScanning: droneManager.isDroneFinderScanning
                                )
                                .frame(maxWidth: .infinity, alignment: .top)
                            }

                            // 3. Tuile Bento Sélecteur de Mission (Surveillance, Loisir, Chasse)
                            DashboardMissionCard(
                                selectedMode: droneManager.activeMissionMode,
                                onSelectMode: { mode in
                                    droneManager.setMissionMode(mode)
                                }
                            )

                            // 4. Tuile Bento Checklist Pré-vol
                            DashboardPreflightCard(isFccMode: droneManager.isFccMode)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    }

                    // Bouton Maître d'Entrée dans le Cockpit (FLY)
                    VStack(spacing: 6) {
                        Button {
                            HapticFeedback.targetLocked()
                            enterCockpit()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: droneManager.isDroneConnected ? "arrow.right.circle.fill" : "exclamationmark.circle")
                                    .font(.title3)
                                Text(droneManager.isDroneConnected ? "ENTRER DANS LE COCKPIT" : "EN ATTENTE DE CONNEXION DRONE")
                                    .font(.headline)
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(droneManager.isDroneConnected ? .green : .secondary)
                        .clipShape(.rect(cornerRadius: 14))
                        .disabled(!droneManager.isDroneConnected && droneManager.connectedDrone == nil)
                        .shadow(color: droneManager.isDroneConnected ? Color.green.opacity(0.35) : Color.clear, radius: 8)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { droneUid in
                if let drone = droneManager.drones.first(where: { $0.uid == droneUid }) ?? droneManager.connectedDrone {
                    DroneControlView(drone: drone)
                } else {
                    ContentUnavailableView(
                        "Drone introuvable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("La connexion avec ce drone a été perdue.")
                    )
                }
            }
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

    private func enterCockpit() {
        if let drone = droneManager.connectedDrone ?? droneManager.drones.first {
            droneManager.connectToDrone(drone)
            navigationPath.append(drone.uid)
        }
    }
}

#Preview {
    ContentView()
        .environment(DroneManager(groundSdk: GroundSdk()))
}
