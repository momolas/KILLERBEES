//
//  KnownDrone+Identifiable.swift
//  KILLERBEES
//

import Foundation
import GroundSdk

extension KnownDrone: @retroactive Identifiable {
    public var id: String {
        uid
    }
}
