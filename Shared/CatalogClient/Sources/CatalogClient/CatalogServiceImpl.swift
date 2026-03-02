//
//  CatalogServiceImpl.swift
//  CatalogClient
//
//  URLSession-based implementation of CatalogServiceProtocol. Communicates
//  with the Backend-Service catalog and scanner endpoints.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import AuthKit
import ScannerLogger

/// URLSession-based catalog API client.
public final class CatalogService: CatalogServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let tokenProvider: any TokenProvider

    /// - Parameters:
    ///   - session: The URLSession to use for requests.
    ///   - baseURL: The Backend-Service base URL (e.g., `Configuration.backendBaseURL`).
    ///   - tokenProvider: Provides valid access tokens for authenticated requests.
    public init(
        session: URLSession = .shared,
        baseURL: String,
        tokenProvider: any TokenProvider
    ) {
        self.session = session
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    // MARK: - CatalogServiceProtocol

    public func lookupByCode(
        codeLetters: String,
        codeArtistNumber: String,
        codeNumber: Int?
    ) async throws -> [CatalogItem] {
        var queryItems = [
            URLQueryItem(name: "code_letters", value: codeLetters),
            URLQueryItem(name: "code_artist_number", value: codeArtistNumber),
        ]
        if let codeNumber {
            queryItems.append(URLQueryItem(name: "code_number", value: String(codeNumber)))
        }

        let request = try await authenticatedRequest(
            method: "GET",
            path: "/library",
            queryItems: queryItems
        )

        Log(.info, category: .network, "Looking up catalog by code: \(codeLetters) \(codeArtistNumber)")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)
        return try decode([CatalogItem].self, from: data)
    }

    public func search(
        artist: String?,
        title: String?,
        limit: Int
    ) async throws -> [CatalogItem] {
        var queryItems: [URLQueryItem] = []
        if let artist {
            queryItems.append(URLQueryItem(name: "artist_name", value: artist))
        }
        if let title {
            queryItems.append(URLQueryItem(name: "album_title", value: title))
        }
        queryItems.append(URLQueryItem(name: "n", value: String(limit)))

        let request = try await authenticatedRequest(
            method: "GET",
            path: "/library",
            queryItems: queryItems
        )

        Log(.info, category: .network, "Searching catalog: artist=\(artist ?? "nil"), title=\(title ?? "nil")")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)
        return try decode([CatalogItem].self, from: data)
    }

    public func submitScan(
        images: [Data],
        photoTypes: [String],
        catalogItemId: Int?,
        stickerText: String?,
        detectedUPC: String?
    ) async throws -> ExtractionResult {
        var form = MultipartFormData()

        if let catalogItemId {
            form.addField(name: "catalog_item_id", value: String(catalogItemId))
        }
        if let stickerText {
            form.addField(name: "sticker_text", value: stickerText)
        }
        if let detectedUPC {
            form.addField(name: "detected_upc", value: detectedUPC)
        }

        for (index, imageData) in images.enumerated() {
            let photoType = index < photoTypes.count ? photoTypes[index] : "photo"
            form.addFile(
                name: "images",
                filename: "\(photoType).heic",
                mimeType: "image/heic",
                data: imageData
            )
        }

        let token = try await tokenProvider.validAccessToken()
        let url = URL(string: "\(baseURL)/library/scan")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.body

        Log(.info, category: .network, "Submitting scan with \(images.count) image(s)")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)

        let scanResponse = try decode(ScanResponse.self, from: data)
        return scanResponse.extraction
    }

    public func submitBatch(
        items: [BatchManifestItem],
        images: [Data]
    ) async throws -> BatchJobCreated {
        var form = MultipartFormData()

        let manifestData = try JSONEncoder().encode(items)
        let manifestString = String(data: manifestData, encoding: .utf8) ?? "[]"
        form.addField(name: "manifest", value: manifestString)

        for (index, imageData) in images.enumerated() {
            form.addFile(
                name: "images",
                filename: "image_\(index).heic",
                mimeType: "image/heic",
                data: imageData
            )
        }

        let token = try await tokenProvider.validAccessToken()
        let url = URL(string: "\(baseURL)/library/scan/batch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.body

        Log(.info, category: .network, "Submitting batch with \(images.count) image(s) across \(items.count) item(s)")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)
        return try decode(BatchJobCreated.self, from: data)
    }

    public func batchStatus(jobId: String) async throws -> BatchJobStatus {
        let request = try await authenticatedRequest(
            method: "GET",
            path: "/library/scan/batch/\(jobId)"
        )

        Log(.info, category: .network, "Polling batch status for job \(jobId)")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)
        return try decode(BatchJobStatus.self, from: data)
    }

    public func updateAlbum(
        albumId: Int,
        label: String?,
        albumTitle: String?
    ) async throws {
        var body: [String: Any] = ["album_id": albumId]
        if let label {
            body["label"] = label
        }
        if let albumTitle {
            body["album_title"] = albumTitle
        }

        let request = try await authenticatedRequest(
            method: "PATCH",
            path: "/library",
            jsonBody: body
        )

        Log(.info, category: .network, "Updating album \(albumId)")

        let (_, response) = try await performRequest(request)
        try handleResponse(response)
    }

    public func upsertReview(
        albumId: Int,
        review: String,
        author: String?
    ) async throws {
        var body: [String: Any] = [
            "album_id": albumId,
            "review": review,
        ]
        if let author {
            body["author"] = author
        }

        let request = try await authenticatedRequest(
            method: "PUT",
            path: "/library/reviews",
            jsonBody: body
        )

        Log(.info, category: .network, "Upserting review for album \(albumId)")

        let (_, response) = try await performRequest(request)
        try handleResponse(response)
    }

    public func listBatchJobs(
        limit: Int,
        offset: Int
    ) async throws -> PaginatedBatchJobs {
        let request = try await authenticatedRequest(
            method: "GET",
            path: "/library/scan/batch",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
            ]
        )

        Log(.info, category: .network, "Listing batch jobs (limit=\(limit), offset=\(offset))")

        let (data, response) = try await performRequest(request)
        try handleResponse(response)
        return try decode(PaginatedBatchJobs.self, from: data)
    }

    // MARK: - Private

    private func authenticatedRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: [String: Any]? = nil
    ) async throws -> URLRequest {
        let token = try await tokenProvider.validAccessToken()

        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }

        return request
    }

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
        case 401:
            throw CatalogError.unauthorized
        case 404:
            throw CatalogError.notFound
        default:
            throw CatalogError.serverError(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
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

// MARK: - Response Wrappers

/// Wraps the scan endpoint response which nests extraction inside an object.
private struct ScanResponse: Decodable {
    let extraction: ExtractionResult
    let matchedAlbumId: Int?
}
