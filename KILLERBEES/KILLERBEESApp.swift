//
//  KILLERBEESApp.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import SwiftUI
import GroundSdk

@main
struct KILLERBEESApp: App {
	let groundSdk = GroundSdk()
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(DroneManager(groundSdk: groundSdk))
		}
	}
}
