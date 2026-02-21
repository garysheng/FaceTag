//
//  FaceTagApp.swift
//  FaceTag
//
//  Forked from SpecBridge by Jason Dukes
//

import SwiftUI
import MWDATCore

@main
struct FaceTagApp: App {
    @StateObject private var settings = AppSettings()

    init() {
        try? Wearables.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
        }
    }
}
