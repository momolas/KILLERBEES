//
//  SkyControllerSection.swift
//  KILLERBEES
//
//  Created by Jules
//

import GroundSdk
import SwiftUI

struct SkyControllerSection: View {
    @SwiftUI.Environment(DroneManager.self) private var droneManager: DroneManager

    init() {}

    var body: some View {
        Section("Télécommande SkyController") {
            if let rc = droneManager.connectedRemoteControl {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rc.name)
                                .font(.headline)
                            switch droneManager.rcConnectionState {
                            case .connected:
                                Text("Pont USB & Radio longue portée actif")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            case .connecting:
                                Text("Connexion en cours...")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            case .disconnected, .disconnecting:
                                Text("Déconnecté")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let battery = droneManager.rcBatteryLevel {
                            HStack(spacing: 4) {
                                Image(systemName: "battery.75percent")
                                    .foregroundStyle(.green)
                                Text("\(battery)%")
                                    .font(.subheadline)
                                    .bold()
                            }
                        }
                    }
                    
                    HStack {
                        if droneManager.isDroneFinderScanning {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Recherche active...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Recherche en veille")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Scanner", systemImage: "arrow.clockwise") {
                            droneManager.refreshDroneFinder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
                
                // Drones découverts par le DroneFinder du SkyController
                if !droneManager.discoveredDronesViaRC.isEmpty {
                    ForEach(droneManager.discoveredDronesViaRC) { discoveredDrone in
                        let isConnected = (droneManager.connectedDrone?.uid == discoveredDrone.uid)
                        let isKnown = discoveredDrone.known || droneManager.knownDronesViaRC.contains(where: { $0.uid == discoveredDrone.uid })
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(discoveredDrone.name.isEmpty ? "Drone Parrot" : discoveredDrone.name)
                                    .font(.subheadline)
                                    .bold()
                                
                                if isConnected {
                                    Text("Connecté • Signal : \(discoveredDrone.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else if isKnown {
                                    Text("Associé au SkyController • Signal : \(discoveredDrone.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("Nouveau drone détecté • Signal : \(discoveredDrone.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if isKnown {
                                Button("Connecter", systemImage: "bolt.fill") {
                                    droneManager.connectToDiscoveredDrone(discoveredDrone)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Button("Appairer", systemImage: "link") {
                                    droneManager.connectViaDroneFinder(discoveredDrone)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                } else if !droneManager.knownDronesViaRC.isEmpty {
                    ForEach(droneManager.knownDronesViaRC) { knownDrone in
                        let isConnected = (droneManager.connectedDrone?.uid == knownDrone.uid)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(knownDrone.name.isEmpty ? "Drone Associé" : knownDrone.name)
                                    .font(.subheadline)
                                    .bold()
                                Text(isConnected ? "Connecté au SkyController" : "Drone associé au SkyController")
                                    .font(.caption2)
                                    .foregroundStyle(isConnected ? .green : .secondary)
                            }
                            
                            Spacer()
                            
                            if isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Connecter", systemImage: "bolt.fill") {
                                    droneManager.connectToKnownDrone(knownDrone)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aucun drone détecté à proximité")
                            .font(.footnote)
                            .bold()
                            .foregroundStyle(.orange)
                        Text("• Assurez-vous que le drone est allumé.\n• Si le drone n'est pas encore appairé au SkyController, appuyez 4 fois rapidement sur le bouton d'alimentation du drone pour lancer l'appairage.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aucune télécommande branchée")
                            .font(.subheadline)
                            .bold()
                        Text("Branchez l'iPhone au SkyController via USB pour la longue portée.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
