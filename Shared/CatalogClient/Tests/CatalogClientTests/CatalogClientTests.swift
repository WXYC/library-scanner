//
//  CatalogClientTests.swift
//  CatalogClient
//
//  Placeholder tests for CatalogClient. Full implementation in PR 6.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import CatalogClient

@Suite("CatalogClient")
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
}
