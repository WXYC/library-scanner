//
//  CatalogService.swift
//  CatalogClient
//
//  Protocol and models for communicating with the Backend-Service catalog
//  and scanner endpoints.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

// MARK: - Models

/// A catalog item from the library_artist_view in the database.
public struct CatalogItem: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let artistName: String
    public let albumTitle: String
    public let codeLetters: String
    public let codeArtistNumber: Int
    public let codeNumber: Int
    public let genreName: String
    public let formatName: String
    public let label: String?

    enum CodingKeys: String, CodingKey {
        case id
        case artistName = "artist_name"
        case albumTitle = "album_title"
        case codeLetters = "code_letters"
        case codeArtistNumber = "code_artist_number"
        case codeNumber = "code_number"
        case genreName = "genre_name"
        case formatName = "format_name"
        case label
    }

    public init(
        id: Int,
        artistName: String,
        albumTitle: String,
        codeLetters: String,
        codeArtistNumber: Int,
        codeNumber: Int,
        genreName: String,
        formatName: String,
        label: String?
    ) {
        self.id = id
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.codeLetters = codeLetters
        self.codeArtistNumber = codeArtistNumber
        self.codeNumber = codeNumber
        self.genreName = genreName
        self.formatName = formatName
        self.label = label
    }

    /// The formatted library code (e.g., "HIP HOP SA 02/01").
    public var libraryCode: String {
        "\(genreName) \(codeLetters) \(String(format: "%02d", codeArtistNumber))/\(String(format: "%02d", codeNumber))"
    }
}

/// Result of a Gemini extraction with confidence scores.
public struct ExtractionResult: Sendable, Codable, Equatable {
    public let labelName: ExtractionField?
    public let catalogNumber: ExtractionField?
    public let reviewText: ExtractionField?
    public let upc: ExtractionField?

    public init(labelName: ExtractionField?, catalogNumber: ExtractionField?, reviewText: ExtractionField?, upc: ExtractionField?) {
        self.labelName = labelName
        self.catalogNumber = catalogNumber
        self.reviewText = reviewText
        self.upc = upc
    }
}

/// A single extracted field with value and confidence.
public struct ExtractionField: Sendable, Codable, Equatable {
    public let value: String
    public let confidence: Double

    public init(value: String, confidence: Double) {
        self.value = value
        self.confidence = confidence
    }
}

/// Status of a batch scan job.
public struct BatchJobStatus: Sendable, Codable, Equatable {
    public let id: String
    public let status: String
    public let imageCount: Int
    public let completedCount: Int
    public let results: [BatchResult]?

    public init(id: String, status: String, imageCount: Int, completedCount: Int, results: [BatchResult]?) {
        self.id = id
        self.status = status
        self.imageCount = imageCount
        self.completedCount = completedCount
        self.results = results
    }
}

/// Result of a single image in a batch job.
public struct BatchResult: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let imageIndex: Int
    public let status: String
    public let extraction: ExtractionResult?
    public let matchedAlbumId: Int?
    public let error: String?

    public init(id: Int, imageIndex: Int, status: String, extraction: ExtractionResult?, matchedAlbumId: Int?, error: String?) {
        self.id = id
        self.imageIndex = imageIndex
        self.status = status
        self.extraction = extraction
        self.matchedAlbumId = matchedAlbumId
        self.error = error
    }
}

// MARK: - Protocol

/// Protocol for catalog API operations.
public protocol CatalogServiceProtocol: Sendable {
    /// Search for a catalog item by library code.
    func lookupByCode(codeLetters: String, codeArtistNumber: String, codeNumber: Int?) async throws -> [CatalogItem]

    /// Search for a catalog item by artist and/or title.
    func search(artist: String?, title: String?, limit: Int) async throws -> [CatalogItem]

    /// Submit images for single scan extraction.
    func submitScan(images: [Data], photoTypes: [String], catalogItemId: Int?, stickerText: String?, detectedUPC: String?) async throws -> ExtractionResult

    /// Submit a batch of images for async processing.
    func submitBatch(images: [Data], photoTypes: [String]) async throws -> String

    /// Poll batch job status.
    func batchStatus(jobId: String) async throws -> BatchJobStatus

    /// Update album fields (label, title) after DJ approval.
    func updateAlbum(albumId: Int, label: String?, albumTitle: String?) async throws

    /// Upsert a review for an album.
    func upsertReview(albumId: Int, review: String, author: String?) async throws
}
