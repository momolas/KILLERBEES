//
//  Bee.swift
//  KILLERBEES
//
//  Created by Jules on 24/04/2023.
//

import Foundation

struct Bee: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let dangerLevel: Int // 1 to 5
}
