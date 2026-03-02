//
//  Configuration.swift
//  ScannerSecrets
//
//  Public API for accessing obfuscated configuration values.
//  The actual secrets are generated into Secrets.swift (git-ignored)
//  by the generate_secrets.sh script.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// Provides access to obfuscated configuration values.
/// Values are deobfuscated at runtime from the generated Secrets.swift file.
public enum Configuration: Sendable {
    /// The base URL for the WXYC Backend-Service API.
    /// Example: "https://api.wxyc.org" in production, "http://localhost:8080" in development.
    public static var backendBaseURL: String {
        #if DEBUG
        "http://localhost:8080"
        #else
        Secrets.backendBaseURL
        #endif
    }

    /// The base URL for the WXYC Auth Service.
    /// Example: "https://api.wxyc.org/auth" in production, "http://localhost:8082/auth" in development.
    public static var authBaseURL: String {
        #if DEBUG
        "http://localhost:8082/auth"
        #else
        Secrets.authBaseURL
        #endif
    }

    /// The base URL for the library-metadata-lookup service (Discogs artwork).
    /// Production URL is the same in both debug and release since it's a public API.
    public static var metadataLookupBaseURL: String {
        #if DEBUG
        "https://library-metadata-lookup-production.up.railway.app"
        #else
        Secrets.metadataLookupBaseURL
        #endif
    }
}
