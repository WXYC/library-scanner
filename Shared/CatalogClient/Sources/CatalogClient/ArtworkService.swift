//
//  ArtworkService.swift
//  CatalogClient
//
//  Protocol and URLSession implementation for fetching album artwork
//  from library-metadata-lookup's Discogs integration. Uses a two-step
//  fetch: search for release_id, then get high-res artwork URL.
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
    /// Returns a high-resolution (600x600) artwork URL, or nil if no results.
    func fetchArtworkURL(artist: String, album: String) async throws -> URL?
}

// MARK: - Models

/// Response from `POST /api/v1/discogs/search`.
struct DiscogsSearchResponse: Decodable, Sendable {
    let results: [DiscogsSearchResult]
}

/// A single search result with a release ID and thumbnail.
struct DiscogsSearchResult: Decodable, Sendable {
    let releaseId: Int
    let artist: String?
    let title: String?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case releaseId = "release_id"
        case artist
        case title
        case thumbnailUrl = "thumbnail_url"
    }
}

/// Response from `GET /api/v1/discogs/release/{id}`.
struct DiscogsReleaseResponse: Decodable, Sendable {
    let releaseId: Int
    let title: String?
    let artist: String?
    let artworkUrl: String?

    enum CodingKeys: String, CodingKey {
        case releaseId = "release_id"
        case title
        case artist
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
        // Step 1: Search for release
        let searchBody = try JSONSerialization.data(withJSONObject: [
            "artist": artist,
            "album": album,
        ])

        let searchURL = URL(string: "\(baseURL)/api/v1/discogs/search")!
        var searchRequest = URLRequest(url: searchURL)
        searchRequest.httpMethod = "POST"
        searchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        searchRequest.httpBody = searchBody

        Log(.info, category: .network, "Searching Discogs for artwork: \(artist) - \(album)")

        let (searchData, searchResponse) = try await performRequest(searchRequest)
        try handleResponse(searchResponse)

        let searchResult = try decode(DiscogsSearchResponse.self, from: searchData)
        guard let topResult = searchResult.results.first else {
            Log(.info, category: .network, "No Discogs results for \(artist) - \(album)")
            return nil
        }

        // Step 2: Get release details for high-res artwork
        let releaseURL = URL(string: "\(baseURL)/api/v1/discogs/release/\(topResult.releaseId)")!
        var releaseRequest = URLRequest(url: releaseURL)
        releaseRequest.httpMethod = "GET"

        let (releaseData, releaseResponse) = try await performRequest(releaseRequest)
        try handleResponse(releaseResponse)

        let release = try decode(DiscogsReleaseResponse.self, from: releaseData)
        guard let artworkUrlString = release.artworkUrl else {
            Log(.info, category: .network, "No artwork URL for release \(topResult.releaseId)")
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
