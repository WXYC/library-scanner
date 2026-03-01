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
