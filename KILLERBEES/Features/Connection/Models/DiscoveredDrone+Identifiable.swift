//
//  DiscoveredDrone+Identifiable.swift
//  KILLERBEES
//

import Foundation
import GroundSdk

extension DiscoveredDrone: @retroactive Identifiable {
    public var id: String {
        uid
    }
}
