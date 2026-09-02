//
//  Drone+Identifiable.swift
//  KILLERBEES
//

import GroundSdk

extension Drone: @retroactive Identifiable {
    public var id: String {
        uid
    }
}
