//
//  AuthManager.swift
//  AuthKit
//
//  Observable state manager for authentication. Views observe this to
//  determine whether to show the login screen or the main app.
//  Handles automatic token refresh on app foreground.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import ScannerLogger

/// Observable authentication state manager.
/// Views observe `isAuthenticated` to switch between login and main content.
@MainActor
@Observable
public final class AuthManager {
    public private(set) var isAuthenticated = false
    public private(set) var currentUser: AuthUser?
    public private(set) var isLoading = false
    public private(set) var error: AuthError?

    private let authService: AuthServiceProtocol
    private let tokenStore: TokenStoreProtocol

    public init(
        authService: AuthServiceProtocol? = nil,
        tokenStore: TokenStoreProtocol = KeychainTokenStore()
    ) {
        self.tokenStore = tokenStore
        self.authService = authService ?? AuthService(tokenStore: tokenStore)
    }

    /// Check for an existing session on app launch.
    public func checkExistingSession() {
        guard let session = try? tokenStore.retrieve() else {
            isAuthenticated = false
            return
        }

        if session.isExpired {
            Task { await refreshSession() }
        } else {
            currentUser = session.user
            isAuthenticated = true
        }
    }

    /// Sign in with email and password.
    public func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let session = try await authService.signIn(email: email, password: password)
            currentUser = session.user
            isAuthenticated = true
        } catch let authError as AuthError {
            error = authError
            Log(.error, category: .auth, "Sign-in failed: \(authError)")
        } catch {
            self.error = .networkError(error.localizedDescription)
            Log(.error, category: .auth, "Sign-in failed: \(error)")
        }

        isLoading = false
    }

    /// Sign out and clear session.
    public func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            Log(.warning, category: .auth, "Sign-out request failed: \(error)")
        }

        currentUser = nil
        isAuthenticated = false
        error = nil
    }

    /// Refresh the current session. Called when the app comes to foreground.
    public func refreshSession() async {
        do {
            let session = try await authService.refreshSession()
            currentUser = session.user
            isAuthenticated = true
        } catch {
            Log(.warning, category: .auth, "Session refresh failed, signing out: \(error)")
            currentUser = nil
            isAuthenticated = false
        }
    }

    /// Returns the current valid access token, refreshing if needed.
    /// Used by CatalogClient for authenticated API calls.
    public func validAccessToken() async throws -> String {
        guard let session = try? tokenStore.retrieve() else {
            throw AuthError.noStoredSession
        }

        if session.isExpired {
            let refreshed = try await authService.refreshSession()
            return refreshed.accessToken
        }

        return session.accessToken
    }
}
