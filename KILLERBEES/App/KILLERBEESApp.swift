//
//  KILLERBEESApp.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import ArsdkEngine
import GroundSdk
import SwiftUI
import UIKit

@main
struct KILLERBEESApp: App {
    @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase
    @State private var droneManager: DroneManager

    init() {
        _ = ArsdkEngine.self
        _droneManager = State(initialValue: DroneManager(groundSdk: GroundSdk()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(droneManager)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                UIApplication.shared.isIdleTimerDisabled = true
            case .inactive, .background:
                UIApplication.shared.isIdleTimerDisabled = false
            @unknown default:
                break
            }
        }
    }
}
