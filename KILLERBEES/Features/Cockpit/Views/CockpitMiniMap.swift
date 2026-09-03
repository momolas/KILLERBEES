//
//  CockpitMiniMap.swift
//  KILLERBEES
//
//  Created by Jules
//

import CoreLocation
import MapKit
import SwiftUI

struct CockpitMiniMap: View {
    let droneCoordinate: CLLocationCoordinate2D?
    let homeCoordinate: CLLocationCoordinate2D?
    let heading: Double
    let waypoints: [CLLocationCoordinate2D]
    var onAddWaypoint: ((CLLocationCoordinate2D) -> Void)?
    @Binding var isExpanded: Bool

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapReader { mapProxy in
                Map(position: $cameraPosition) {
                    // Position Drone
                    if let droneCoord = droneCoordinate {
                        Annotation("Drone", coordinate: droneCoord) {
                            Image(systemName: "airplane")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.blue)
                                .clipShape(.circle)
                                .rotationEffect(.degrees(heading - 90))
                                .shadow(radius: 3)
                        }
                    }

                    // Point de départ (Home)
                    if let homeCoord = homeCoordinate {
                        Annotation("Départ", coordinate: homeCoord) {
                            Image(systemName: "house.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.green)
                                .clipShape(.circle)
                                .shadow(radius: 3)
                        }
                    }

                    // Tracé de la Mission Waypoints MAVLink
                    if waypoints.count >= 2 {
                        MapPolyline(coordinates: waypoints)
                            .stroke(Color.cyan, lineWidth: 2.5)
                    }

                    // Marqueurs Waypoints
                    ForEach(waypoints.indices, id: \.self) { index in
                        Annotation("WP \(index + 1)", coordinate: waypoints[index]) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 22, height: 22)
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .onTapGesture { screenCoord in
                    guard isExpanded, let coord = mapProxy.convert(screenCoord, from: .local) else { return }
                    onAddWaypoint?(coord)
                }
            }

            // Bouton agrandissement / réduction
            Button(isExpanded ? "Réduire la carte" : "Agrandir la carte",
                   systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(.circle)
            .padding(6)
        }
        .frame(width: isExpanded ? 300 : 120, height: isExpanded ? 220 : 90)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .onAppear {
            updateCamera()
        }
        .onChange(of: droneCoordinate?.latitude) { _, _ in
            updateCamera()
        }
    }

    private func updateCamera() {
        if let coord = droneCoordinate {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
        }
    }
}
