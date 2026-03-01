//
//  LibraryScannerApp.swift
//  LibraryScanner
//
//  App entry point. Creates shared services (auth, catalog, camera, barcode)
//  and injects them into the view hierarchy via SwiftUI environment.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import AuthKit
import ScannerSecrets
import CatalogClient
import CameraKit
import BarcodeKit
import ScannerKit
import ScannerLogger

@main
struct LibraryScannerApp: App {
    @State private var authManager: AuthManager
    @State private var sessionManager: ScanSessionManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if !DEBUG
        LoggerConfiguration.shared.minimumLevel = .info
        #endif

        let auth = AuthManager()
        let catalog = CatalogService(
            baseURL: Configuration.backendBaseURL,
            tokenProvider: auth
        )
        let camera = PhotoCaptureService()
        let barcode = VisionBarcodeScanner()
        let session = ScanSessionManager(
            catalogService: catalog,
            cameraService: camera,
            barcodeScanner: barcode
        )

        _authManager = State(initialValue: auth)
        _sessionManager = State(initialValue: session)
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
            .environment(\.scanSessionManager, sessionManager)
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
