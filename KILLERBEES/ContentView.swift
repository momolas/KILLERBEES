//
//  ContentView.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import GroundSdk
import SwiftUI

class DroneManager: ObservableObject {
	private let groundSdk: GroundSdk
	@Published var drones: [Drone] = []
	@Published var connectedDrone: Drone?
	
	private var droneListRef: Ref<[Drone]>?
	
	init(groundSdk: GroundSdk) {
		self.groundSdk = groundSdk
		scanForDrones()
	}
	
	private func scanForDrones() {
		droneListRef = groundSdk.getFacility(Facilities.droneList) { [weak self] droneList in
			self?.drones = droneList ?? []
		}
	}
	
	func connectToDrone(_ drone: Drone) {
		connectedDrone = drone
	}
}

class VideoController: ObservableObject {
	private var drone: Drone?
	private var cameraLive: Ref<CameraLive>?
	
	@Published var streamView: StreamView?
	
	init(drone: Drone) {
		self.drone = drone
		setupVideoStream()
	}
	
	private func setupVideoStream() {
		cameraLive = drone?.getPeripheral(Peripherals.streamServer)?.live { [weak self] cameraLive in
			if let live = cameraLive {
				if live.state != .started {
					live.play()
				}
				self?.streamView = StreamView(stream: live.stream)
			}
		}
	}
	
	func takeOff() {
		drone?.getPeripheral(Peripherals.pilotingItf)?.takeOff()
	}
	
	func land() {
		drone?.getPeripheral(Peripherals.pilotingItf)?.land()
	}
}

struct ContentView: View {
	@EnvironmentObject var droneManager: DroneManager
	
	var body: some View {
		NavigationView {
			List {
				ForEach(droneManager.drones, id: \.uid) { drone in
					Button(action: {
						droneManager.connectToDrone(drone)
					}) {
						Text(drone.name ?? "Drone Inconnu")
					}
				}
			}
			.navigationTitle("Drones Disponibles")
			.navigationDestination(isPresented: .constant(droneManager.connectedDrone != nil)) {
				if let connectedDrone = droneManager.connectedDrone {
					DroneControlView(drone: connectedDrone)
				}
			}
		}
	}
}

struct DroneControlView: View {
	let drone: Drone
	@StateObject private var videoController: VideoController
	
	init(drone: Drone) {
		self.drone = drone
		_videoController = StateObject(wrappedValue: VideoController(drone: drone))
	}
	
	var body: some View {
		VStack {
			if let streamView = videoController.streamView {
				VideoPlayerView(streamView: streamView)
					.frame(height: 300)
					.background(Color.black)
			} else {
				Text("Chargement du flux vidéo...")
					.foregroundColor(.gray)
			}
			
			HStack {
				Button("Décoller") {
					videoController.takeOff()
				}
				.padding()
				.background(Color.green)
				.foregroundColor(.white)
				.cornerRadius(10)
				
				Button("Atterrir") {
					videoController.land()
				}
				.padding()
				.background(Color.red)
				.foregroundColor(.white)
				.cornerRadius(10)
			}
		}
		.padding()
		.navigationTitle(drone.name ?? "Drone")
	}
}

struct VideoPlayerView: UIViewRepresentable {
	let streamView: StreamView
	
	func makeUIView(context: Context) -> UIView {
		return streamView
	}
	
	func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
	ContentView()
}
