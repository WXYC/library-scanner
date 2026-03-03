//
//  AuthService.swift
//  AuthKit
//
//  Protocol and implementation for authenticating with the WXYC better-auth
//  service. Handles sign-in, token refresh, and session management.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import ScannerSecrets
import ScannerLogger

// MARK: - Protocol

/// Protocol for authentication operations against the WXYC better-auth server.
public protocol AuthServiceProtocol: Sendable {
    /// Sign in with email and password. Returns an auth session on success.
    func signIn(email: String, password: String) async throws -> AuthSession

    /// Refresh the current session using the stored refresh token.
    func refreshSession() async throws -> AuthSession

    /// Sign out and clear stored credentials.
    func signOut() async throws
}

// MARK: - Models

/// Represents an authenticated session with access and refresh tokens.
public struct AuthSession: Sendable, Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let user: AuthUser

    public init(accessToken: String, refreshToken: String, expiresAt: Date, user: AuthUser) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }

    /// Whether the access token has expired or is about to expire (within 60 seconds).
    public var isExpired: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

/// Represents the authenticated user.
public struct AuthUser: Sendable, Codable, Equatable {
    public let id: String
    public let email: String
    public let name: String?
    public let role: String?

    public init(id: String, email: String, name: String?, role: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
    }
}

// MARK: - Errors

/// Errors that can occur during authentication.
public enum AuthError: Error, Sendable, Equatable {
    case invalidCredentials
    case networkError(String)
    case tokenExpired
    case noStoredSession
    case serverError(Int, String)
    case decodingError(String)
}

// MARK: - Implementation

/// Authenticates with the WXYC better-auth server over HTTP.
public final class AuthService: AuthServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let tokenStore: TokenStoreProtocol

    public init(
        session: URLSession = .shared,
        baseURL: String = Configuration.authBaseURL,
        tokenStore: TokenStoreProtocol = KeychainTokenStore()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        let url = URL(string: "\(baseURL)/sign-in/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SignInRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        Log(.info, category: .auth, "Signing in as \(email)")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let authResponse = try decodeResponse(SignInResponse.self, from: data)

            // Exchange the session token for a JWT via the better-auth JWT plugin.
            // The backend's requirePermissions middleware validates JWTs, not session tokens.
            let jwt = try await fetchJWT(sessionToken: authResponse.token)
            let authSession = authResponse.toAuthSession(jwt: jwt)
            try tokenStore.store(authSession)
            Log(.info, category: .auth, "Sign-in successful")
            return authSession
        case 401:
            throw AuthError.invalidCredentials
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Fetches a JWT from better-auth's token endpoint using a session token.
    private func fetchJWT(sessionToken: String) async throws -> String {
        let url = URL(string: "\(baseURL)/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw AuthError.serverError(httpResponse.statusCode, "Failed to fetch JWT")
        }

        let tokenResponse = try decodeResponse(TokenResponse.self, from: data)
        return tokenResponse.token
    }

    public func refreshSession() async throws -> AuthSession {
        guard let stored = try? tokenStore.retrieve() else {
            throw AuthError.noStoredSession
        }

        // better-auth JWT plugin: GET /token with session Bearer header returns {"token": "ey..."}
        // refreshToken holds the session token; accessToken holds the JWT.
        let url = URL(string: "\(baseURL)/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(stored.refreshToken)", forHTTPHeaderField: "Authorization")

        Log(.info, category: .auth, "Refreshing session")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let tokenResponse = try decodeResponse(TokenResponse.self, from: data)
            let refreshedSession = AuthSession(
                accessToken: tokenResponse.token,
                refreshToken: stored.refreshToken,
                expiresAt: Date().addingTimeInterval(3600),
                user: stored.user
            )
            try tokenStore.store(refreshedSession)
            Log(.info, category: .auth, "Session refreshed")
            return refreshedSession
        case 401:
            try? tokenStore.clear()
            throw AuthError.tokenExpired
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.serverError(httpResponse.statusCode, message)
        }
    }

    public func signOut() async throws {
        if let stored = try? tokenStore.retrieve() {
            let url = URL(string: "\(baseURL)/sign-out")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(stored.accessToken)", forHTTPHeaderField: "Authorization")

            _ = try? await performRequest(request)
        }

        try tokenStore.clear()
        Log(.info, category: .auth, "Signed out")
    }

    // MARK: - Private

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AuthError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Request/Response Types

private struct SignInRequest: Codable {
    let email: String
    let password: String
}

/// Response from better-auth JWT plugin `GET /token`.
private struct TokenResponse: Codable {
    let token: String
}

struct SignInResponse: Codable {
    let token: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: UserResponse?

    struct UserResponse: Codable {
        let id: String
        let email: String
        let name: String?
        let role: String?
    }

    func toAuthSession(jwt: String) -> AuthSession {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn ?? 3600))
        return AuthSession(
            accessToken: jwt,
            refreshToken: token,
            expiresAt: expiresAt,
            user: AuthUser(
                id: user?.id ?? "",
                email: user?.email ?? "",
                name: user?.name,
                role: user?.role
            )
        )
    }
}
