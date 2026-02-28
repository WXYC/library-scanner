//
//  TokenStore.swift
//  AuthKit
//
//  Protocol and implementations for securely storing authentication tokens.
//  KeychainTokenStore persists tokens in the iOS Keychain.
//  InMemoryTokenStore is used for testing.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import Security

// MARK: - Protocol

/// Protocol for storing and retrieving authentication sessions.
public protocol TokenStoreProtocol: Sendable {
    /// Store an authentication session.
    func store(_ session: AuthSession) throws

    /// Retrieve the stored authentication session, if any.
    func retrieve() throws -> AuthSession?

    /// Clear all stored authentication data.
    func clear() throws
}

// MARK: - Keychain Implementation

/// Stores authentication sessions securely in the iOS Keychain.
public final class KeychainTokenStore: TokenStoreProtocol, @unchecked Sendable {
    private let service = "org.wxyc.library-scanner"
    private let account = "auth-session"
    private let lock = NSLock()

    public init() {}

    public func store(_ session: AuthSession) throws {
        lock.withLock {
            let data = try? JSONEncoder().encode(session)
            guard let data else { return }

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]

            // Delete any existing item
            SecItemDelete(query as CFDictionary)

            // Add the new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess {
                // Log but don't throw -- keychain errors shouldn't crash the app
                ScannerLogger.Log(.error, category: .auth, "Keychain store failed with status: \(status)")
            }
        }
    }

    public func retrieve() throws -> AuthSession? {
        lock.withLock {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            return try? JSONDecoder().decode(AuthSession.self, from: data)
        }
    }

    public func clear() throws {
        lock.withLock {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]

            SecItemDelete(query as CFDictionary)
        }
    }
}

// MARK: - In-Memory Implementation (Testing)

/// In-memory token store for use in tests. Not persisted.
public final class InMemoryTokenStore: TokenStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AuthSession?

    public init() {}

    public func store(_ session: AuthSession) throws {
        lock.withLock { stored = session }
    }

    public func retrieve() throws -> AuthSession? {
        lock.withLock { stored }
    }

    public func clear() throws {
        lock.withLock { stored = nil }
    }
}
