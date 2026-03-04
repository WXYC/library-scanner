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
public struct ExtractionResult: Sendable, Codable, Hashable {
    public let artistName: ExtractionField?
    public let albumTitle: ExtractionField?
    public let labelName: ExtractionField?
    public let catalogNumber: ExtractionField?
    public let reviewText: ExtractionField?
    public let upc: ExtractionField?

    public init(
        artistName: ExtractionField? = nil,
        albumTitle: ExtractionField? = nil,
        labelName: ExtractionField? = nil,
        catalogNumber: ExtractionField? = nil,
        reviewText: ExtractionField? = nil,
        upc: ExtractionField? = nil
    ) {
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.labelName = labelName
        self.catalogNumber = catalogNumber
        self.reviewText = reviewText
        self.upc = upc
    }
}

/// A single extracted field with value and confidence.
public struct ExtractionField: Sendable, Codable, Hashable {
    public let value: String
    public let confidence: Double

    public init(value: String, confidence: Double) {
        self.value = value
        self.confidence = confidence
    }
}

/// Response from batch job creation (`POST /library/scan/batch`).
public struct BatchJobCreated: Sendable, Codable, Equatable {
    public let jobId: String
    public let status: String
    public let totalItems: Int

    public init(jobId: String, status: String, totalItems: Int) {
        self.jobId = jobId
        self.status = status
        self.totalItems = totalItems
    }
}

/// Status of a batch scan job (`GET /library/scan/batch/:jobId`).
public struct BatchJobStatus: Sendable, Codable, Equatable {
    public let jobId: String
    public let status: String
    public let totalItems: Int
    public let completedItems: Int
    public let failedItems: Int
    public let results: [BatchResult]?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        jobId: String,
        status: String,
        totalItems: Int,
        completedItems: Int,
        failedItems: Int,
        results: [BatchResult]?,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.totalItems = totalItems
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.results = results
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Result of a single item in a batch job.
public struct BatchResult: Sendable, Codable, Hashable {
    public let itemIndex: Int
    public let status: String
    public let extraction: ExtractionResult?
    public let matchedAlbumId: Int?
    public let matchedAlbum: MatchedAlbum?
    public let errorMessage: String?

    public init(
        itemIndex: Int,
        status: String,
        extraction: ExtractionResult?,
        matchedAlbumId: Int?,
        matchedAlbum: MatchedAlbum? = nil,
        errorMessage: String?
    ) {
        self.itemIndex = itemIndex
        self.status = status
        self.extraction = extraction
        self.matchedAlbumId = matchedAlbumId
        self.matchedAlbum = matchedAlbum
        self.errorMessage = errorMessage
    }
}

/// Album details for a matched catalog item returned in batch results.
public struct MatchedAlbum: Sendable, Codable, Hashable {
    public let id: Int
    public let artistName: String
    public let albumTitle: String
    public let codeLetters: String
    public let codeArtistNumber: Int
    public let codeNumber: Int
    public let genreName: String
    public let formatName: String
    public let label: String?

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

    /// The formatted library code (e.g., "ROCK AB 01/03").
    public var libraryCode: String {
        "\(genreName) \(codeLetters) \(String(format: "%02d", codeArtistNumber))/\(String(format: "%02d", codeNumber))"
    }
}

/// Describes one item in a batch submission manifest.
public struct BatchManifestItem: Sendable, Codable, Equatable {
    public let imageCount: Int
    public let photoTypes: [String]
    public let context: BatchContext

    public init(imageCount: Int, photoTypes: [String], context: BatchContext) {
        self.imageCount = imageCount
        self.photoTypes = photoTypes
        self.context = context
    }
}

/// Contextual metadata for a batch item, aiding server-side matching.
public struct BatchContext: Sendable, Codable, Equatable {
    public let catalogItemId: Int?
    public let stickerText: String?
    public let detectedUPC: String?
    public let artistName: String?
    public let albumTitle: String?

    public init(
        catalogItemId: Int? = nil,
        stickerText: String? = nil,
        detectedUPC: String? = nil,
        artistName: String? = nil,
        albumTitle: String? = nil
    ) {
        self.catalogItemId = catalogItemId
        self.stickerText = stickerText
        self.detectedUPC = detectedUPC
        self.artistName = artistName
        self.albumTitle = albumTitle
    }
}

/// Summary of a batch job (without individual results).
public struct BatchJobSummary: Sendable, Codable, Identifiable, Hashable {
    public let jobId: String
    public let status: String
    public let totalItems: Int
    public let completedItems: Int
    public let failedItems: Int
    public let createdAt: String
    public let updatedAt: String

    public var id: String { jobId }

    public init(
        jobId: String,
        status: String,
        totalItems: Int,
        completedItems: Int,
        failedItems: Int,
        createdAt: String,
        updatedAt: String
    ) {
        self.jobId = jobId
        self.status = status
        self.totalItems = totalItems
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Paginated list of batch job summaries.
public struct PaginatedBatchJobs: Sendable, Codable, Equatable {
    public let jobs: [BatchJobSummary]
    public let total: Int
    public let limit: Int
    public let offset: Int

    public init(jobs: [BatchJobSummary], total: Int, limit: Int, offset: Int) {
        self.jobs = jobs
        self.total = total
        self.limit = limit
        self.offset = offset
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

    /// Submit a batch of items with images for async processing.
    func submitBatch(items: [BatchManifestItem], images: [Data]) async throws -> BatchJobCreated

    /// Poll batch job status.
    func batchStatus(jobId: String) async throws -> BatchJobStatus

    /// Update album fields (label, title) after DJ approval.
    func updateAlbum(albumId: Int, label: String?, albumTitle: String?) async throws

    /// Upsert a review for an album.
    func upsertReview(albumId: Int, review: String, author: String?) async throws

    /// List batch jobs for the authenticated user with pagination.
    func listBatchJobs(limit: Int, offset: Int) async throws -> PaginatedBatchJobs
}
