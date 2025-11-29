//
//  ContentView.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "ant.fill") // Using an ant as a placeholder for a bee/insect if bee isn't available in older SF Symbols, or just a generic insect. SF Symbols has "ladybug", "ant", etc. Let's try to find something relevant. "ant.fill" looks dangerous enough for now.
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.yellow)

            Text("KILLERBEES")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Welcome to the hive.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
