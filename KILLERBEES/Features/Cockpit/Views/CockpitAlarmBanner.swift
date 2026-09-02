//
//  CockpitAlarmBanner.swift
//  KILLERBEES
//
//  Created by Jules
//

import SwiftUI

struct CockpitAlarmBanner: View {
    let message: String?
    let isCritical: Bool

    var body: some View {
        if let message {
            HStack(spacing: 8) {
                Image(systemName: isCritical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(isCritical ? .white : .black)

                Text(message)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(isCritical ? .white : .black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isCritical ? Color.red.opacity(0.9) : Color.yellow.opacity(0.9))
            .clipShape(.capsule)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
