//
//  DroneRow.swift
//  KILLERBEES
//

import SwiftUI
import GroundSdk

struct DroneRow: View {
    let drone: Drone
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(drone.name.isEmpty ? "Drone Inconnu" : drone.name)
                    .font(.headline)
                Text("UID: \(drone.uid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
