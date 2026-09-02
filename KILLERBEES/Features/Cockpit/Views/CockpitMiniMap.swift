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
    @Binding var isExpanded: Bool

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
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
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
            )

            // Bouton agrandissement / réduction
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
            }
            .padding(6)
        }
        .frame(width: isExpanded ? 260 : 120, height: isExpanded ? 190 : 90)
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
