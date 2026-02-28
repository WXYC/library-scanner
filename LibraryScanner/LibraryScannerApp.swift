//
//  LibraryScannerApp.swift
//  LibraryScanner
//
//  App entry point. Checks for an existing authentication session on launch
//  and switches between LoginView and MainTabView accordingly.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import AuthKit
import ScannerLogger

@main
struct LibraryScannerApp: App {
    @State private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if !DEBUG
        LoggerConfiguration.shared.minimumLevel = .info
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environment(\.authManager, authManager)
            .onAppear {
                authManager.checkExistingSession()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, authManager.isAuthenticated {
                    Task {
                        await authManager.refreshSession()
                    }
                }
            }
        }
    }
}
