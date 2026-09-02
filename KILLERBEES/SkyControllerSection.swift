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
                            Text("Pont USB & Radio longue portée actif")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    
                    if droneManager.isDroneFinderScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Recherche de drones via la télécommande...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Drones découverts par le DroneFinder du SkyController
                if !droneManager.discoveredDronesViaRC.isEmpty {
                    ForEach(droneManager.discoveredDronesViaRC) { discoveredDrone in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(discoveredDrone.name)
                                    .font(.subheadline)
                                    .bold()
                                Text("Signal : \(discoveredDrone.rssi) dBm • \(discoveredDrone.connectionSecurity.description)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Appairer") {
                                droneManager.connectViaDroneFinder(discoveredDrone)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
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
