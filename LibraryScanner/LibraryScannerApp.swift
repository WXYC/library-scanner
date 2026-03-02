//
//  LibraryScannerApp.swift
//  LibraryScanner
//
//  App entry point. Creates shared services (auth, catalog, camera, barcode,
//  artwork, photo storage) and injects them into the view hierarchy via
//  SwiftUI environment.
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

    let artworkService: any ArtworkServiceProtocol
    let photoStorage: any PhotoStorageProtocol

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
        let storage = FilePhotoStorage()
        let session = ScanSessionManager(
            catalogService: catalog,
            cameraService: camera,
            barcodeScanner: barcode,
            photoStorage: storage
        )

        _authManager = State(initialValue: auth)
        _sessionManager = State(initialValue: session)
        artworkService = ArtworkService(baseURL: Configuration.metadataLookupBaseURL)
        photoStorage = storage
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
            .environment(\.artworkService, artworkService)
            .environment(\.photoStorage, photoStorage)
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

// MARK: - Environment Keys

private struct ArtworkServiceKey: EnvironmentKey {
    static let defaultValue: (any ArtworkServiceProtocol)? = nil
}

private struct PhotoStorageKey: EnvironmentKey {
    static let defaultValue: (any PhotoStorageProtocol)? = nil
}

extension EnvironmentValues {
    var artworkService: (any ArtworkServiceProtocol)? {
        get { self[ArtworkServiceKey.self] }
        set { self[ArtworkServiceKey.self] = newValue }
    }

    var photoStorage: (any PhotoStorageProtocol)? {
        get { self[PhotoStorageKey.self] }
        set { self[PhotoStorageKey.self] = newValue }
    }
}
