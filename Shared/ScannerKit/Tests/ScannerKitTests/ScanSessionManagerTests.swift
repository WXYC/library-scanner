//
//  ScanSessionManagerTests.swift
//  ScannerKit
//
//  Tests for the ScanSessionManager state machine, verifying all phase
//  transitions for the single-scan workflow.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import ScannerKit
import CatalogClient
import CameraKit
import BarcodeKit

@Suite("ScanSessionManager")
struct ScanSessionManagerTests {
    @Test("Initial state is idle with no photos or matched item")
    @MainActor
    func initialState() {
        let manager = makeManager()
        #expect(manager.phase == .idle)
        #expect(manager.capturedPhotos.isEmpty)
        #expect(manager.matchedItem == nil)
        #expect(manager.stickerText == nil)
        #expect(manager.detectedUPC == nil)
    }

    @Test("startScan transitions to capturingSticker")
    @MainActor
    func startScan() {
        let manager = makeManager()
        manager.startScan()
        #expect(manager.phase == .capturingSticker)
    }

    @Test("lookupCatalog with match transitions to catalogMatched")
    @MainActor
    func lookupCatalogWithMatch() async {
        let catalogService = MockCatalogService()
        let item = CatalogItem(
            id: 42, artistName: "Radiohead", albumTitle: "OK Computer",
            codeLetters: "RH", codeArtistNumber: 1, codeNumber: 3,
            genreName: "ROCK", formatName: "CD", label: "Parlophone"
        )
        catalogService.lookupResult = [item]

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        await manager.lookupCatalog(codeLetters: "RH", codeArtistNumber: "01", codeNumber: 3)

        #expect(manager.phase == .catalogMatched(item))
        #expect(manager.matchedItem == item)
        #expect(manager.stickerText == "RH 01/3")
    }

    @Test("lookupCatalog with empty result transitions to catalogNotFound")
    @MainActor
    func lookupCatalogEmpty() async {
        let catalogService = MockCatalogService()
        catalogService.lookupResult = []

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        await manager.lookupCatalog(codeLetters: "XX", codeArtistNumber: "99", codeNumber: 1)

        #expect(manager.phase == .catalogNotFound)
        #expect(manager.matchedItem == nil)
    }

    @Test("lookupCatalog error transitions to error phase")
    @MainActor
    func lookupCatalogError() async {
        let catalogService = MockCatalogService()
        catalogService.lookupError = CatalogError.networkError("offline")

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        await manager.lookupCatalog(codeLetters: "AB", codeArtistNumber: "01", codeNumber: nil)

        if case .error = manager.phase {
            // Expected -- error phase reached
        } else {
            Issue.record("Expected error phase, got \(manager.phase)")
        }
    }

    @Test("skipCatalogLookup transitions to capturingPhotos")
    @MainActor
    func skipCatalogLookup() {
        let manager = makeManager()
        manager.startScan()
        manager.skipCatalogLookup()
        #expect(manager.phase == .capturingPhotos)
    }

    @Test("proceedToCapture from catalogMatched transitions to capturingPhotos")
    @MainActor
    func proceedFromMatched() {
        let catalogService = MockCatalogService()
        let item = CatalogItem(
            id: 1, artistName: "Test", albumTitle: "Album",
            codeLetters: "TS", codeArtistNumber: 1, codeNumber: 1,
            genreName: "ROCK", formatName: "LP", label: nil
        )
        catalogService.lookupResult = [item]

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        manager.proceedToCapture()
        #expect(manager.phase == .capturingPhotos)
    }

    @Test("addPhoto appends and respects max 5 limit")
    @MainActor
    func addPhotoLimit() {
        let manager = makeManager()
        manager.startScan()
        manager.skipCatalogLookup()

        for i in 0..<7 {
            manager.addPhoto(data: Data([UInt8(i)]), type: "photo\(i)")
        }

        #expect(manager.capturedPhotos.count == 5)
    }

    @Test("removePhoto removes at index")
    @MainActor
    func removePhoto() {
        let manager = makeManager()
        manager.startScan()
        manager.skipCatalogLookup()

        manager.addPhoto(data: Data([0x01]), type: "front")
        manager.addPhoto(data: Data([0x02]), type: "back")
        manager.addPhoto(data: Data([0x03]), type: "label")

        manager.removePhoto(at: 1)

        #expect(manager.capturedPhotos.count == 2)
        #expect(manager.capturedPhotos[0].type == "front")
        #expect(manager.capturedPhotos[1].type == "label")
    }

    @Test("submitScan transitions through uploading to reviewing")
    @MainActor
    func submitScanSuccess() async {
        let catalogService = MockCatalogService()
        let extraction = ExtractionResult(
            labelName: ExtractionField(value: "Elektra", confidence: 0.95),
            catalogNumber: nil,
            reviewText: ExtractionField(value: "Great album", confidence: 0.80),
            upc: nil
        )
        catalogService.submitScanResult = extraction

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        manager.skipCatalogLookup()
        manager.addPhoto(data: Data([0x01]), type: "front")

        await manager.submitScan()

        if case .reviewing(let result) = manager.phase {
            #expect(result.labelName?.value == "Elektra")
            #expect(result.reviewText?.value == "Great album")
        } else {
            Issue.record("Expected reviewing phase, got \(manager.phase)")
        }
    }

    @Test("submitScan error transitions to error phase")
    @MainActor
    func submitScanError() async {
        let catalogService = MockCatalogService()
        catalogService.submitScanError = CatalogError.serverError(500, "Internal")

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        manager.skipCatalogLookup()
        manager.addPhoto(data: Data([0x01]), type: "front")

        await manager.submitScan()

        if case .error = manager.phase {
            // Expected
        } else {
            Issue.record("Expected error phase, got \(manager.phase)")
        }
    }

    @Test("approveExtraction calls updateAlbum and upsertReview then transitions to approved")
    @MainActor
    func approveExtraction() async {
        let catalogService = MockCatalogService()
        let item = CatalogItem(
            id: 42, artistName: "Test", albumTitle: "Album",
            codeLetters: "TS", codeArtistNumber: 1, codeNumber: 1,
            genreName: "ROCK", formatName: "LP", label: nil
        )
        catalogService.lookupResult = [item]
        let extraction = ExtractionResult(
            labelName: ExtractionField(value: "Elektra", confidence: 0.95),
            catalogNumber: nil,
            reviewText: ExtractionField(value: "Great album", confidence: 0.80),
            upc: nil
        )
        catalogService.submitScanResult = extraction

        let manager = makeManager(catalogService: catalogService)
        manager.startScan()
        await manager.lookupCatalog(codeLetters: "TS", codeArtistNumber: "01", codeNumber: 1)
        manager.proceedToCapture()
        manager.addPhoto(data: Data([0x01]), type: "front")
        await manager.submitScan()

        await manager.approveExtraction(
            labelName: "Elektra",
            reviewText: "Great album"
        )

        #expect(manager.phase == .approved)
        #expect(catalogService.updateAlbumCalled)
        #expect(catalogService.upsertReviewCalled)
        #expect(catalogService.lastUpdateAlbumId == 42)
        #expect(catalogService.lastUpdateLabel == "Elektra")
        #expect(catalogService.lastReviewText == "Great album")
    }

    @Test("reset clears all state")
    @MainActor
    func reset() {
        let manager = makeManager()
        manager.startScan()
        manager.skipCatalogLookup()
        manager.addPhoto(data: Data([0x01]), type: "front")

        manager.reset()

        #expect(manager.phase == .idle)
        #expect(manager.capturedPhotos.isEmpty)
        #expect(manager.matchedItem == nil)
        #expect(manager.stickerText == nil)
        #expect(manager.detectedUPC == nil)
    }
}

// MARK: - Test Helpers

@MainActor
private func makeManager(
    catalogService: MockCatalogService = MockCatalogService(),
    cameraService: MockCameraService = MockCameraService(),
    barcodeScanner: MockBarcodeScanner = MockBarcodeScanner()
) -> ScanSessionManager {
    ScanSessionManager(
        catalogService: catalogService,
        cameraService: cameraService,
        barcodeScanner: barcodeScanner
    )
}

// Mocks are defined in BatchCaptureTests.swift
