//
//  Configuration.swift
//  ScannerSecrets
//
//  Public API for accessing obfuscated configuration values.
//  In debug builds, values are read from Info.plist (populated from
//  Debug.xcconfig). In release builds, values come from the generated
//  Secrets.swift (obfuscated at compile time).
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// Provides access to configuration values.
/// Debug builds read from Info.plist (via Debug.xcconfig).
/// Release builds use obfuscated values from Secrets.swift.
public enum Configuration: Sendable {
    /// The base URL for the WXYC Backend-Service API.
    public static var backendBaseURL: String {
        #if DEBUG
        infoPlistString(for: "BackendBaseURL") ?? "http://localhost:8080"
        #else
        Secrets.backendBaseURL
        #endif
    }

    /// The base URL for the WXYC Auth Service.
    public static var authBaseURL: String {
        #if DEBUG
        infoPlistString(for: "AuthBaseURL") ?? "http://localhost:8082/auth"
        #else
        Secrets.authBaseURL
        #endif
    }

    /// The base URL for the library-metadata-lookup service (Discogs artwork).
    public static var metadataLookupBaseURL: String {
        #if DEBUG
        infoPlistString(for: "MetadataLookupBaseURL") ?? "https://library-metadata-lookup-production.up.railway.app"
        #else
        Secrets.metadataLookupBaseURL
        #endif
    }

    // MARK: - Private

    private static func infoPlistString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
