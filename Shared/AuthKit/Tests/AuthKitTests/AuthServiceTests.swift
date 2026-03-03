//
//  AuthServiceTests.swift
//  AuthKit
//
//  Tests for AuthService sign-in, refresh, and sign-out flows using
//  a custom URLProtocol to intercept network requests.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import AuthKit

@Suite("AuthService", .serialized)
struct AuthServiceTests {
    @Test("Sign in exchanges session token for JWT")
    func signInSuccess() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            if request.url?.path.hasSuffix("/sign-in/email") == true {
                let bodyData = request.httpBody ?? request.httpBodyStreamData()
                let body = try! JSONDecoder().decode(SignInRequestBody.self, from: bodyData!)
                #expect(body.email == "dj@wxyc.org")
                #expect(body.password == "password123")

                let json = """
                {
                    "token": "session-token-123",
                    "refreshToken": "unused",
                    "expiresIn": 3600,
                    "user": {
                        "id": "user-1",
                        "email": "dj@wxyc.org",
                        "name": "Test DJ",
                        "role": "dj"
                    }
                }
                """
                return (json.data(using: .utf8)!, 200)
            } else {
                // GET /token -- exchange session token for JWT
                #expect(request.httpMethod == "GET")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token-123")
                return ("{\"token\": \"jwt-token-456\"}".data(using: .utf8)!, 200)
            }
        }

        let session = try await service.signIn(email: "dj@wxyc.org", password: "password123")
        #expect(session.accessToken == "jwt-token-456")
        #expect(session.refreshToken == "session-token-123")
        #expect(session.user.email == "dj@wxyc.org")
        #expect(session.user.name == "Test DJ")
        #expect(session.user.role == "dj")
        #expect(!session.isExpired)
    }

    @Test("Sign in with invalid credentials throws invalidCredentials")
    func signInInvalidCredentials() async {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { _ in
            return ("Unauthorized".data(using: .utf8)!, 401)
        }

        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signIn(email: "bad@wxyc.org", password: "wrong")
        }
    }

    @Test("Sign in with server error throws serverError")
    func signInServerError() async {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { _ in
            return ("Internal Server Error".data(using: .utf8)!, 500)
        }

        do {
            _ = try await service.signIn(email: "dj@wxyc.org", password: "password123")
            Issue.record("Expected serverError to be thrown")
        } catch let error as AuthError {
            if case .serverError(let code, _) = error {
                #expect(code == 500)
            } else {
                Issue.record("Expected serverError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Sign in stores JWT as accessToken and session token as refreshToken")
    func signInStoresSession() async throws {
        let tokenStore = InMemoryTokenStore()
        let (service, mock) = makeServiceWithMock(tokenStore: tokenStore)

        mock.handler = { request in
            if request.url?.path.hasSuffix("/sign-in/email") == true {
                let json = """
                {
                    "token": "session-token",
                    "expiresIn": 3600,
                    "user": {"id": "u1", "email": "dj@wxyc.org"}
                }
                """
                return (json.data(using: .utf8)!, 200)
            } else {
                return ("{\"token\": \"jwt-token\"}".data(using: .utf8)!, 200)
            }
        }

        _ = try await service.signIn(email: "dj@wxyc.org", password: "pass")

        let stored = try tokenStore.retrieve()
        #expect(stored?.accessToken == "jwt-token")
        #expect(stored?.refreshToken == "session-token")
    }

    @Test("Refresh session sends GET with session token and returns new JWT")
    func refreshSuccess() async throws {
        let tokenStore = InMemoryTokenStore()
        let existingSession = AuthSession(
            accessToken: "old-jwt",
            refreshToken: "session-token-123",
            expiresAt: Date().addingTimeInterval(-100),
            user: AuthUser(id: "u1", email: "dj@wxyc.org", name: "Test DJ", role: "dj")
        )
        try tokenStore.store(existingSession)

        let (service, mock) = makeServiceWithMock(tokenStore: tokenStore)

        mock.handler = { request in
            #expect(request.url?.path.hasSuffix("/token") == true)
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token-123")
            #expect(request.httpBody == nil)
            return ("{\"token\": \"new-jwt\"}".data(using: .utf8)!, 200)
        }

        let refreshed = try await service.refreshSession()
        #expect(refreshed.accessToken == "new-jwt")
        #expect(refreshed.refreshToken == "session-token-123")
        #expect(refreshed.user.email == "dj@wxyc.org")
        #expect(refreshed.user.name == "Test DJ")
        #expect(refreshed.user.role == "dj")
    }

    @Test("Refresh with no stored session throws noStoredSession")
    func refreshNoSession() async {
        let (service, _) = makeServiceWithMock()

        await #expect(throws: AuthError.noStoredSession) {
            try await service.refreshSession()
        }
    }

    @Test("Sign out clears token store")
    func signOutClearsStore() async throws {
        let tokenStore = InMemoryTokenStore()
        let session = AuthSession(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            user: AuthUser(id: "u1", email: "dj@wxyc.org", name: nil, role: nil)
        )
        try tokenStore.store(session)

        let (service, mock) = makeServiceWithMock(tokenStore: tokenStore)
        mock.handler = { _ in ("".data(using: .utf8)!, 200) }

        try await service.signOut()

        let stored = try tokenStore.retrieve()
        #expect(stored == nil)
    }

    @Test("Session isExpired returns true when token is expired")
    func sessionExpiry() {
        let expired = AuthSession(
            accessToken: "t",
            refreshToken: "r",
            expiresAt: Date().addingTimeInterval(-10),
            user: AuthUser(id: "u1", email: "dj@wxyc.org", name: nil, role: nil)
        )
        #expect(expired.isExpired)

        let valid = AuthSession(
            accessToken: "t",
            refreshToken: "r",
            expiresAt: Date().addingTimeInterval(3600),
            user: AuthUser(id: "u1", email: "dj@wxyc.org", name: nil, role: nil)
        )
        #expect(!valid.isExpired)
    }
}

// MARK: - Test Helpers

private func makeServiceWithMock(
    tokenStore: TokenStoreProtocol = InMemoryTokenStore()
) -> (AuthService, MockURLProtocol) {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let service = AuthService(
        session: session,
        baseURL: "http://test.local/auth",
        tokenStore: tokenStore
    )

    return (service, MockURLProtocol.shared)
}

private struct SignInRequestBody: Codable {
    let email: String
    let password: String
}

// MARK: - Mock URLProtocol

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static let shared = MockURLProtocol()

    nonisolated(unsafe) var handler: ((URLRequest) -> (Data, Int))?

    private init() {
        super.init(request: URLRequest(url: URL(string: "http://unused")!), cachedResponse: nil, client: nil)
    }

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.shared.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (data, statusCode) = handler(request)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - URLRequest Body Helper

private extension URLRequest {
    /// Reads body data from httpBodyStream when httpBody is nil (common in URLProtocol handlers).
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 1024)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
