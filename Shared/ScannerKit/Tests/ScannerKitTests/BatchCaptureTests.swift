//
//  BatchCaptureTests.swift
//  ScannerKit
//
//  Tests for batch capture models and ScanSessionManager batch state
//  management methods.
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

// MARK: - BatchItem Model Tests

@Suite("BatchItem")
struct BatchItemTests {
    @Test("BatchItem inits with UUID and empty photos")
    func batchItemInit() {
        let item = BatchItem()
        #expect(item.photos.isEmpty)
        #expect(item.catalogMatch == nil)
        #expect(item.stickerText == nil)
        #expect(item.detectedUPC == nil)
    }

    @Test("BatchItem is Equatable by id")
    func batchItemEquatable() {
        let item1 = BatchItem()
        var item2 = item1
        item2.photos.append(CapturedPhotoEntry(data: Data([0x01]), type: "front"))
        // Same id means equal (Equatable via Identifiable default or custom)
        #expect(item1.id == item2.id)
    }
}

// MARK: - BatchPhase Tests

@Suite("BatchPhase")
struct BatchPhaseTests {
    @Test("BatchPhase equality for simple cases")
    func phaseEquality() {
        #expect(BatchPhase.idle == BatchPhase.idle)
        #expect(BatchPhase.capturing == BatchPhase.capturing)
        #expect(BatchPhase.submitting == BatchPhase.submitting)
        #expect(BatchPhase.idle != BatchPhase.capturing)
    }

    @Test("BatchPhase polling carries jobId")
    func pollingCarriesJobId() {
        let phase = BatchPhase.polling(jobId: "abc-123")
        if case .polling(let jobId) = phase {
            #expect(jobId == "abc-123")
        } else {
            Issue.record("Expected polling phase")
        }
    }

    @Test("BatchPhase error carries message")
    func errorCarriesMessage() {
        let phase = BatchPhase.error("Upload failed")
        if case .error(let message) = phase {
            #expect(message == "Upload failed")
        } else {
            Issue.record("Expected error phase")
        }
    }
}

// MARK: - Batch State Management Tests

@Suite("ScanSessionManager Batch")
struct BatchStateManagementTests {
    @Test("Initial batch state is idle with empty items")
    @MainActor
    func initialBatchState() {
        let manager = makeBatchManager()
        #expect(manager.batchPhase == .idle)
        #expect(manager.batchItems.isEmpty)
        #expect(manager.totalBatchPhotos == 0)
        #expect(manager.currentBatchItem == nil)
    }

    @Test("startBatchCapture transitions to capturing and creates first item")
    @MainActor
    func startBatchCapture() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        #expect(manager.batchPhase == .capturing)
        #expect(manager.batchItems.count == 1)
        #expect(manager.batchItems[0].photos.isEmpty)
    }

    @Test("addPhotoToCurrentItem adds photo to last batch item")
    @MainActor
    func addPhotoToCurrentItem() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[0].photos[0].type == "front")
        #expect(manager.totalBatchPhotos == 1)
    }

    @Test("addPhotoToCurrentItem respects per-item max of 5")
    @MainActor
    func addPhotoPerItemMax() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        for i in 0..<7 {
            manager.addPhotoToCurrentItem(data: Data([UInt8(i)]), type: "photo\(i)")
        }
        #expect(manager.batchItems[0].photos.count == 5)
    }

    @Test("finalizeCurrentItem creates a new empty BatchItem")
    @MainActor
    func finalizeCurrentItem() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        manager.finalizeCurrentItem()
        #expect(manager.batchItems.count == 2)
        #expect(manager.batchItems[1].photos.isEmpty)
    }

    @Test("finalizeCurrentItem when max items (10) reached stays on last item")
    @MainActor
    func finalizeCurrentItemMaxReached() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        // Already have 1 item, add 9 more to reach max
        for _ in 0..<9 {
            manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
            manager.finalizeCurrentItem()
        }
        #expect(manager.batchItems.count == ScanSessionManager.maxBatchItems)

        // Try to add one more -- should not increase count
        manager.finalizeCurrentItem()
        #expect(manager.batchItems.count == ScanSessionManager.maxBatchItems)
    }

    @Test("removeItemFromBatch removes by index")
    @MainActor
    func removeItemFromBatch() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        manager.finalizeCurrentItem()
        manager.addPhotoToCurrentItem(data: Data([0x02]), type: "back")
        #expect(manager.batchItems.count == 2)

        manager.removeItemFromBatch(at: 0)
        #expect(manager.batchItems.count == 1)
        #expect(manager.batchItems[0].photos[0].type == "back")
    }

    @Test("Total batch photo count computed correctly")
    @MainActor
    func totalBatchPhotoCount() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        manager.addPhotoToCurrentItem(data: Data([0x02]), type: "back")
        manager.finalizeCurrentItem()
        manager.addPhotoToCurrentItem(data: Data([0x03]), type: "front")
        #expect(manager.totalBatchPhotos == 3)
    }

    @Test("submitBatch transitions to submitting then polling on success")
    @MainActor
    func submitBatchSuccess() async {
        let catalogService = MockCatalogService()
        catalogService.submitBatchResult = BatchJobCreated(
            jobId: "job-abc",
            status: "pending",
            totalItems: 1
        )

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        await manager.submitBatch()

        if case .polling(let jobId) = manager.batchPhase {
            #expect(jobId == "job-abc")
        } else {
            Issue.record("Expected polling phase, got \(manager.batchPhase)")
        }
    }

    @Test("submitBatch error transitions to error phase")
    @MainActor
    func submitBatchError() async {
        let catalogService = MockCatalogService()
        catalogService.submitBatchError = CatalogError.serverError(500, "Internal")

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        await manager.submitBatch()

        if case .error = manager.batchPhase {
            // Expected
        } else {
            Issue.record("Expected error phase, got \(manager.batchPhase)")
        }
    }

    @Test("submitBatch builds correct manifest from batchItems")
    @MainActor
    func submitBatchManifest() async {
        let catalogService = MockCatalogService()
        catalogService.submitBatchResult = BatchJobCreated(
            jobId: "job-xyz",
            status: "pending",
            totalItems: 2
        )

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        manager.addPhotoToCurrentItem(data: Data([0x02]), type: "back")
        manager.finalizeCurrentItem()
        manager.addPhotoToCurrentItem(data: Data([0x03]), type: "front")

        await manager.submitBatch()

        #expect(catalogService.lastSubmitBatchItems?.count == 2)
        #expect(catalogService.lastSubmitBatchItems?[0].imageCount == 2)
        #expect(catalogService.lastSubmitBatchItems?[0].photoTypes == ["front", "back"])
        #expect(catalogService.lastSubmitBatchItems?[1].imageCount == 1)
        #expect(catalogService.lastSubmitBatchItems?[1].photoTypes == ["front"])
        #expect(catalogService.lastSubmitBatchImages?.count == 3)
    }

    @Test("resetBatch clears all batch state to idle")
    @MainActor
    func resetBatch() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")
        manager.finalizeCurrentItem()

        manager.resetBatch()

        #expect(manager.batchPhase == .idle)
        #expect(manager.batchItems.isEmpty)
        #expect(manager.totalBatchPhotos == 0)
    }
}

// MARK: - Test Helpers

@MainActor
private func makeBatchManager(
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

// MARK: - Mocks

final class MockCatalogService: CatalogServiceProtocol, @unchecked Sendable {
    var lookupResult: [CatalogItem] = []
    var lookupError: (any Error)?
    var submitScanResult: ExtractionResult?
    var submitScanError: (any Error)?
    var submitBatchResult: BatchJobCreated?
    var submitBatchError: (any Error)?
    var batchStatusResult: BatchJobStatus?
    var batchStatusError: (any Error)?
    var updateAlbumCalled = false
    var upsertReviewCalled = false
    var lastUpdateAlbumId: Int?
    var lastUpdateLabel: String?
    var lastReviewText: String?
    var lastSubmitBatchItems: [BatchManifestItem]?
    var lastSubmitBatchImages: [Data]?

    func lookupByCode(codeLetters: String, codeArtistNumber: String, codeNumber: Int?) async throws -> [CatalogItem] {
        if let error = lookupError { throw error }
        return lookupResult
    }

    func search(artist: String?, title: String?, limit: Int) async throws -> [CatalogItem] {
        []
    }

    func submitScan(images: [Data], photoTypes: [String], catalogItemId: Int?, stickerText: String?, detectedUPC: String?) async throws -> ExtractionResult {
        if let error = submitScanError { throw error }
        return submitScanResult ?? ExtractionResult(labelName: nil, catalogNumber: nil, reviewText: nil, upc: nil)
    }

    func submitBatch(items: [BatchManifestItem], images: [Data]) async throws -> BatchJobCreated {
        lastSubmitBatchItems = items
        lastSubmitBatchImages = images
        if let error = submitBatchError { throw error }
        return submitBatchResult ?? BatchJobCreated(jobId: "mock", status: "pending", totalItems: 0)
    }

    func batchStatus(jobId: String) async throws -> BatchJobStatus {
        if let error = batchStatusError { throw error }
        return batchStatusResult ?? BatchJobStatus(
            jobId: jobId, status: "pending", totalItems: 0,
            completedItems: 0, failedItems: 0, results: nil
        )
    }

    func updateAlbum(albumId: Int, label: String?, albumTitle: String?) async throws {
        updateAlbumCalled = true
        lastUpdateAlbumId = albumId
        lastUpdateLabel = label
    }

    func upsertReview(albumId: Int, review: String, author: String?) async throws {
        upsertReviewCalled = true
        lastReviewText = review
    }
}

@preconcurrency import AVFoundation

final class MockCameraService: CameraServiceProtocol, @unchecked Sendable {
    var previewSession: AVCaptureSession { AVCaptureSession() }

    func startSession() async throws {}
    func stopSession() async {}
    func capturePhoto() async throws -> CapturedPhoto {
        CapturedPhoto(imageData: Data([0xFF]), originalWidth: 100, originalHeight: 100)
    }
}

final class MockBarcodeScanner: BarcodeScannerProtocol, @unchecked Sendable {
    var barcodes: [BarcodeResult] = []

    func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult] {
        barcodes
    }
}
