//
//  ContentView.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import SwiftUI

struct ContentView: View {
    // Sample data
    let bees = [
        Bee(name: "Killer Bee", description: "Aggressive and dangerous.", dangerLevel: 5),
        Bee(name: "Bumblebee", description: "Fuzzy and mostly harmless.", dangerLevel: 1),
        Bee(name: "Honey Bee", description: "Produces honey, stings if provoked.", dangerLevel: 2),
        Bee(name: "Carpenter Bee", description: "Drills into wood.", dangerLevel: 1)
    ]

    var body: some View {
        NavigationView {
            List(bees) { bee in
                HStack {
                    Image(systemName: "ant.fill")
                        .foregroundColor(colorForDangerLevel(bee.dangerLevel))

                    VStack(alignment: .leading) {
                        Text(bee.name)
                            .font(.headline)
                        Text(bee.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if bee.dangerLevel >= 4 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("KILLERBEES")
        }
    }

    func colorForDangerLevel(_ level: Int) -> Color {
        switch level {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        default: return .primary
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
