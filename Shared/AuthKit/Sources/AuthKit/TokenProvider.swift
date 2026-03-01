//
//  TokenProvider.swift
//  AuthKit
//
//  Protocol for providing valid access tokens to service clients.
//  AuthManager conforms to this, allowing CatalogClient to depend on
//  the protocol rather than the concrete manager.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

/// Provides a valid access token for authenticated API requests.
/// Implementations should handle token refresh internally.
public protocol TokenProvider: Sendable {
    func validAccessToken() async throws -> String
}

extension AuthManager: TokenProvider {}
