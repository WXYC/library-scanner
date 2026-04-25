//
//  ArtworkService.swift
//  CatalogClient
//
//  Protocol and URLSession implementation for fetching album artwork
//  from library-metadata-lookup's lookup endpoint.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import ScannerLogger

// MARK: - Protocol

/// Fetches album artwork URLs from the library-metadata-lookup service.
public protocol ArtworkServiceProtocol: Sendable {
    /// Search for album artwork by artist and album name.
    /// Returns a high-resolution artwork URL, or nil if no results.
    func fetchArtworkURL(artist: String, album: String) async throws -> URL?
}

// MARK: - Models

/// Response from `POST /api/v1/lookup`.
struct LookupResponse: Decodable, Sendable {
    let results: [LookupResultItem]
}

/// A single lookup result pairing a library item with optional artwork.
struct LookupResultItem: Decodable, Sendable {
    let artwork: ArtworkResult?
}

/// Artwork metadata from a Discogs match.
struct ArtworkResult: Decodable, Sendable {
    let artworkUrl: String?

    enum CodingKeys: String, CodingKey {
        case artworkUrl = "artwork_url"
    }
}

// MARK: - Implementation

/// URLSession-based artwork service that queries library-metadata-lookup.
public final class ArtworkService: ArtworkServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String

    /// - Parameters:
    ///   - session: The URLSession to use for requests.
    ///   - baseURL: The library-metadata-lookup base URL.
    public init(
        session: URLSession = .shared,
        baseURL: String
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func fetchArtworkURL(artist: String, album: String) async throws -> URL? {
        let body = try JSONSerialization.data(withJSONObject: [
            "artist": artist,
            "album": album,
        ])

        let lookupURL = URL(string: "\(baseURL)/api/v1/lookup")!
        var request = URLRequest(url: lookupURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        Log(.info, category: .network, "Looking up artwork: \(artist) - \(album)")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)

        let lookupResponse = try decode(LookupResponse.self, from: data)
        guard let artworkUrlString = lookupResponse.results.first?.artwork?.artworkUrl else {
            Log(.info, category: .network, "No artwork found for \(artist) - \(album)")
            return nil
        }

        return URL(string: artworkUrlString)
    }

    // MARK: - Private

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw CatalogError.networkError(error.localizedDescription)
        }
    }

    private func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 404:
            throw CatalogError.notFound
        default:
            throw CatalogError.serverError(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CatalogError.decodingError(error.localizedDescription)
        }
    }
}

/// No-op artwork service that always returns nil. Used as a fallback
/// when the artwork service environment value is not configured.
public struct NoOpArtworkService: ArtworkServiceProtocol {
    public init() {}

    public func fetchArtworkURL(artist: String, album: String) async throws -> URL? {
        nil
    }
}
