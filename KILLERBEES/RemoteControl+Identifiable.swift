//
//  RemoteControl+Identifiable.swift
//  KILLERBEES
//

import Foundation
import GroundSdk

extension RemoteControl: @retroactive Identifiable {
    public var id: String {
        uid
    }
}
