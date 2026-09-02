//
//  KILLERBEESApp.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import SwiftUI
import GroundSdk
import ArsdkEngine

@main
struct KILLERBEESApp: App {
    @State private var droneManager: DroneManager

    init() {
        // Force le linkage et l'enregistrement runtime d'ArsdkEngine pour GroundSdk
        _ = ArsdkEngine.self
        _droneManager = State(initialValue: DroneManager(groundSdk: GroundSdk()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(droneManager)
        }
    }
}
