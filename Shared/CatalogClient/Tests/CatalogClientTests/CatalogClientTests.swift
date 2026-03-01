//
//  CatalogClientTests.swift
//  CatalogClient
//
//  Tests for CatalogClient model types, error handling, and JSON decoding.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import CatalogClient

@Suite("CatalogClient Models")
struct CatalogClientTests {
    @Test("CatalogItem libraryCode formatting")
    func libraryCodeFormat() {
        let item = CatalogItem(
            id: 1,
            artistName: "Sample Artists",
            albumTitle: "Sample This!",
            codeLetters: "SA",
            codeArtistNumber: 2,
            codeNumber: 1,
            genreName: "HIP HOP",
            formatName: "LP",
            label: "Elektra"
        )
        #expect(item.libraryCode == "HIP HOP SA 02/01")
    }

    @Test("ExtractionField stores value and confidence")
    func extractionField() {
        let field = ExtractionField(value: "Elektra", confidence: 0.95)
        #expect(field.value == "Elektra")
        #expect(field.confidence == 0.95)
    }

    @Test("CatalogItem decodes from snake_case JSON")
    func catalogItemDecodesSnakeCase() throws {
        let json = """
        {
            "id": 42,
            "artist_name": "Radiohead",
            "album_title": "OK Computer",
            "code_letters": "RH",
            "code_artist_number": 1,
            "code_number": 3,
            "genre_name": "ROCK",
            "format_name": "CD",
            "label": "Parlophone"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(CatalogItem.self, from: json)
        #expect(item.id == 42)
        #expect(item.artistName == "Radiohead")
        #expect(item.albumTitle == "OK Computer")
        #expect(item.codeLetters == "RH")
        #expect(item.codeArtistNumber == 1)
        #expect(item.codeNumber == 3)
        #expect(item.genreName == "ROCK")
        #expect(item.formatName == "CD")
        #expect(item.label == "Parlophone")
    }

    @Test("CatalogItem decodes with null label")
    func catalogItemDecodesNullLabel() throws {
        let json = """
        {
            "id": 1,
            "artist_name": "Unknown",
            "album_title": "Mystery",
            "code_letters": "UN",
            "code_artist_number": 1,
            "code_number": 1,
            "genre_name": "MISC",
            "format_name": "LP",
            "label": null
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(CatalogItem.self, from: json)
        #expect(item.label == nil)
    }
}

@Suite("Batch Models")
struct BatchModelTests {
    @Test("BatchJobCreated decodes from camelCase JSON")
    func batchJobCreatedDecodes() throws {
        let json = """
        {
            "jobId": "abc-123",
            "status": "pending",
            "totalItems": 3
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BatchJobCreated.self, from: json)
        #expect(result.jobId == "abc-123")
        #expect(result.status == "pending")
        #expect(result.totalItems == 3)
    }

    @Test("BatchJobStatus decodes with fixed field names")
    func batchJobStatusDecodes() throws {
        let json = """
        {
            "jobId": "abc-123",
            "status": "processing",
            "totalItems": 3,
            "completedItems": 1,
            "failedItems": 0,
            "results": [
                {
                    "itemIndex": 0,
                    "status": "completed",
                    "extraction": {
                        "labelName": {"value": "Elektra", "confidence": 0.95},
                        "catalogNumber": null,
                        "reviewText": null,
                        "upc": null
                    },
                    "matchedAlbumId": 42,
                    "errorMessage": null
                }
            ],
            "createdAt": "2026-02-28T12:00:00Z",
            "updatedAt": "2026-02-28T12:01:00Z"
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(BatchJobStatus.self, from: json)
        #expect(status.jobId == "abc-123")
        #expect(status.status == "processing")
        #expect(status.totalItems == 3)
        #expect(status.completedItems == 1)
        #expect(status.failedItems == 0)
        #expect(status.results?.count == 1)
        #expect(status.createdAt == "2026-02-28T12:00:00Z")
        #expect(status.updatedAt == "2026-02-28T12:01:00Z")
    }

    @Test("BatchResult decodes with itemIndex and errorMessage")
    func batchResultDecodes() throws {
        let json = """
        {
            "itemIndex": 2,
            "status": "failed",
            "extraction": null,
            "matchedAlbumId": null,
            "errorMessage": "Image too blurry"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BatchResult.self, from: json)
        #expect(result.itemIndex == 2)
        #expect(result.status == "failed")
        #expect(result.extraction == nil)
        #expect(result.matchedAlbumId == nil)
        #expect(result.errorMessage == "Image too blurry")
    }

    @Test("BatchManifestItem encodes context correctly")
    func batchManifestItemEncodes() throws {
        let item = BatchManifestItem(
            imageCount: 2,
            photoTypes: ["front", "back"],
            context: BatchContext(
                catalogItemId: 42,
                stickerText: "ROCK RH 01/03",
                detectedUPC: nil,
                artistName: "Radiohead",
                albumTitle: "OK Computer"
            )
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(decoded["imageCount"] as? Int == 2)
        #expect(decoded["photoTypes"] as? [String] == ["front", "back"])

        let context = decoded["context"] as! [String: Any]
        #expect(context["catalogItemId"] as? Int == 42)
        #expect(context["stickerText"] as? String == "ROCK RH 01/03")
        #expect(context["artistName"] as? String == "Radiohead")
        #expect(context["albumTitle"] as? String == "OK Computer")
    }

    @Test("BatchJobStatus decodes with nil results")
    func batchJobStatusNilResults() throws {
        let json = """
        {
            "jobId": "def-456",
            "status": "pending",
            "totalItems": 5,
            "completedItems": 0,
            "failedItems": 0
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(BatchJobStatus.self, from: json)
        #expect(status.results == nil)
        #expect(status.createdAt == nil)
        #expect(status.updatedAt == nil)
    }
}

@Suite("CatalogError")
struct CatalogErrorTests {
    @Test("Error cases are constructible and equatable")
    func errorCases() {
        #expect(CatalogError.unauthorized == CatalogError.unauthorized)
        #expect(CatalogError.notFound == CatalogError.notFound)
        #expect(CatalogError.badRequest("test") == CatalogError.badRequest("test"))
        #expect(CatalogError.badRequest("a") != CatalogError.badRequest("b"))
        #expect(CatalogError.serverError(500, "err") == CatalogError.serverError(500, "err"))
        #expect(CatalogError.networkError("timeout") == CatalogError.networkError("timeout"))
        #expect(CatalogError.decodingError("bad") == CatalogError.decodingError("bad"))
    }

    @Test("Error conforms to Error protocol")
    func errorConformsToError() {
        let error: any Error = CatalogError.unauthorized
        #expect(error is CatalogError)
    }
}
