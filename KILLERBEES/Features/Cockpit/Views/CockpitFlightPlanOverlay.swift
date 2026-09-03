//
//  CockpitFlightPlanOverlay.swift
//  KILLERBEES
//
//  Created by Jules
//

import GroundSdk
import SwiftUI

struct CockpitFlightPlanOverlay: View {
    let flightPlanState: ActivablePilotingItfState
    let flightPlanUploadState: FlightPlanFileUploadState
    let waypointCount: Int
    let currentMissionItem: UInt?
    let isFlightPlanActive: Bool
    let onUploadMission: () -> Void
    let onStartMission: () -> Void
    let onPauseMission: () -> Void
    let onClearWaypoints: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Indicateur de statut
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.filled.curvepath")
                    .font(.caption)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSION AUTONOME")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    if isFlightPlanActive {
                        Text("En vol : WP \(currentMissionItem.map { "\($0)" } ?? "1")")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.green)
                    } else if flightPlanUploadState == .uploading {
                        Text("Transfert MAVLink...")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if flightPlanState == .idle {
                        Text("Plan MAVLink Prêt")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.cyan)
                    } else {
                        Text("\(waypointCount) waypoints")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
            }

            Divider()
                .frame(height: 20)
                .background(.white.opacity(0.3))

            // Actions de mission
            if isFlightPlanActive {
                Button("Pause", systemImage: "pause.fill") {
                    onPauseMission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            } else if flightPlanState == .idle {
                Button("Lancer Mission", systemImage: "play.fill") {
                    onStartMission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            } else if waypointCount > 0 {
                Button("Envoyer MAVLink", systemImage: "arrow.up.doc.fill") {
                    onUploadMission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
                .disabled(flightPlanUploadState == .uploading)
            }

            if waypointCount > 0 && !isFlightPlanActive {
                Button("Effacer", systemImage: "trash") {
                    onClearWaypoints()
                }
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(6)
                .background(.white.opacity(0.15))
                .clipShape(.circle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}
