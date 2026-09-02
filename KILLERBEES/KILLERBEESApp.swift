//
//  KILLERBEESApp.swift
//  KILLERBEES
//
//  Created by Mo on 23/04/2023.
//

import SwiftUI
import GroundSdk
import ArsdkEngine

@main
struct KILLERBEESApp: App {
    @State private var droneManager: DroneManager

    init() {
        signal(SIGABRT) { _ in
            print("🚨🚨🚨 SIGABRT CAUGHT - PRINTING BACKTRACE:")
            var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
            let frames = backtrace(&callstack, 128)
            if let symbols = backtrace_symbols(&callstack, frames) {
                for i in 0..<Int(frames) {
                    if let sym = symbols[i] {
                        print("  [\(i)] \(String(cString: sym))")
                    }
                }
                free(symbols)
            }
            exit(1)
        }

        NSSetUncaughtExceptionHandler { exception in
            print("💥 CRASH EXCEPTION: \(exception.name.rawValue): \(exception.reason ?? "no reason")")
            print("💥 CALL STACK:\n\(exception.callStackSymbols.joined(separator: "\n"))")
        }
        
        _ = ArsdkEngine.self
        _droneManager = State(initialValue: DroneManager(groundSdk: GroundSdk()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(droneManager)
        }
    }
}
