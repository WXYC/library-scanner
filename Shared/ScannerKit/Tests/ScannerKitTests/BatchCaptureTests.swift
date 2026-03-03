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

    @Test("BatchPhase importing is distinct from idle and capturing")
    func importingPhase() {
        #expect(BatchPhase.importing != BatchPhase.idle)
        #expect(BatchPhase.importing != BatchPhase.capturing)
        #expect(BatchPhase.importing == BatchPhase.importing)
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

// MARK: - Polling Tests

@Suite("ScanSessionManager Polling")
struct PollingTests {
    @Test("startPolling transitions to completed when status is completed")
    @MainActor
    func startPollingCompletes() async throws {
        let catalogService = MockCatalogService()
        catalogService.batchStatusResult = BatchJobStatus(
            jobId: "job-1", status: "completed", totalItems: 1,
            completedItems: 1, failedItems: 0, results: []
        )
        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-1", initialDelay: .milliseconds(10))

        // Give the polling loop time to run
        try await Task.sleep(for: .milliseconds(300))

        if case .completed(let status) = manager.batchPhase {
            #expect(status.jobId == "job-1")
            #expect(status.status == "completed")
        } else {
            Issue.record("Expected completed phase, got \(manager.batchPhase)")
        }
    }

    @Test("startPolling transitions to completed when status is failed")
    @MainActor
    func startPollingFailed() async throws {
        let catalogService = MockCatalogService()
        catalogService.batchStatusResult = BatchJobStatus(
            jobId: "job-2", status: "failed", totalItems: 1,
            completedItems: 0, failedItems: 1, results: []
        )
        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-2", initialDelay: .milliseconds(10))

        try await Task.sleep(for: .milliseconds(300))

        if case .completed(let status) = manager.batchPhase {
            #expect(status.status == "failed")
        } else {
            Issue.record("Expected completed phase, got \(manager.batchPhase)")
        }
    }

    @Test("startPolling retries when status is processing")
    @MainActor
    func startPollingRetries() async throws {
        let catalogService = MockCatalogService()
        var callCount = 0
        catalogService.batchStatusHandler = { jobId in
            callCount += 1
            if callCount >= 3 {
                return BatchJobStatus(
                    jobId: jobId, status: "completed", totalItems: 1,
                    completedItems: 1, failedItems: 0, results: []
                )
            }
            return BatchJobStatus(
                jobId: jobId, status: "processing", totalItems: 1,
                completedItems: 0, failedItems: 0, results: nil
            )
        }

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-3", initialDelay: .milliseconds(10))

        try await Task.sleep(for: .milliseconds(500))

        #expect(catalogService.batchStatusCallCount >= 3)
        if case .completed = manager.batchPhase {
            // Expected
        } else {
            Issue.record("Expected completed phase, got \(manager.batchPhase)")
        }
    }

    @Test("startPolling transitions to error on network failure")
    @MainActor
    func startPollingNetworkError() async throws {
        let catalogService = MockCatalogService()
        catalogService.batchStatusError = CatalogError.networkError("Connection lost")

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-4", initialDelay: .milliseconds(10))

        try await Task.sleep(for: .milliseconds(300))

        if case .error = manager.batchPhase {
            // Expected
        } else {
            Issue.record("Expected error phase, got \(manager.batchPhase)")
        }
    }

    @Test("cancelPolling prevents completion transition")
    @MainActor
    func cancelPollingPreventsTransition() async throws {
        let catalogService = MockCatalogService()
        // Return processing so it keeps polling
        catalogService.batchStatusHandler = { jobId in
            // Delay to simulate network
            try await Task.sleep(for: .milliseconds(50))
            return BatchJobStatus(
                jobId: jobId, status: "completed", totalItems: 1,
                completedItems: 1, failedItems: 0, results: []
            )
        }

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-5", initialDelay: .milliseconds(200))

        // Cancel before the first poll completes
        manager.cancelPolling()
        try await Task.sleep(for: .milliseconds(300))

        // Phase should not have changed to completed
        if case .completed = manager.batchPhase {
            Issue.record("Should not have transitioned to completed after cancel")
        }
    }

    @Test("resetBatch cancels active polling")
    @MainActor
    func resetBatchCancelsPolling() async throws {
        let catalogService = MockCatalogService()
        catalogService.batchStatusHandler = { jobId in
            try await Task.sleep(for: .milliseconds(100))
            return BatchJobStatus(
                jobId: jobId, status: "completed", totalItems: 1,
                completedItems: 1, failedItems: 0, results: []
            )
        }

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startPolling(jobId: "job-6", initialDelay: .milliseconds(200))

        manager.resetBatch()
        try await Task.sleep(for: .milliseconds(400))

        #expect(manager.batchPhase == .idle)
        #expect(manager.batchItems.isEmpty)
    }

    @Test("submitBatch auto-starts polling after success")
    @MainActor
    func submitBatchAutoStartsPolling() async throws {
        let catalogService = MockCatalogService()
        catalogService.submitBatchResult = BatchJobCreated(
            jobId: "job-auto", status: "pending", totalItems: 1
        )
        catalogService.batchStatusResult = BatchJobStatus(
            jobId: "job-auto", status: "completed", totalItems: 1,
            completedItems: 1, failedItems: 0, results: []
        )

        let manager = makeBatchManager(catalogService: catalogService)
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        await manager.submitBatch()

        // Give polling time to run
        try await Task.sleep(for: .milliseconds(200))

        if case .completed(let status) = manager.batchPhase {
            #expect(status.jobId == "job-auto")
        } else {
            Issue.record("Expected completed phase, got \(manager.batchPhase)")
        }
    }
}

// MARK: - Camera Wrapper Tests

@Suite("ScanSessionManager Camera")
struct CameraWrapperTests {
    @Test("startCamera calls cameraService.startSession()")
    @MainActor
    func startCamera() async throws {
        let cameraService = MockCameraService()
        let manager = makeBatchManager(cameraService: cameraService)
        try await manager.startCamera()
        #expect(cameraService.startSessionCalled)
    }

    @Test("stopCamera calls cameraService.stopSession()")
    @MainActor
    func stopCamera() async {
        let cameraService = MockCameraService()
        let manager = makeBatchManager(cameraService: cameraService)
        await manager.stopCamera()
        #expect(cameraService.stopSessionCalled)
    }

    @Test("capturePhotoForBatch captures photo and adds to current batch item")
    @MainActor
    func capturePhotoForBatch() async throws {
        let cameraService = MockCameraService()
        cameraService.capturePhotoResult = CapturedPhoto(
            imageData: Data([0xAA, 0xBB]), originalWidth: 200, originalHeight: 200
        )
        let manager = makeBatchManager(cameraService: cameraService)
        manager.startBatchCapture()

        try await manager.capturePhotoForBatch()

        #expect(cameraService.capturePhotoCalled)
        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[0].photos[0].data == Data([0xAA, 0xBB]))
        #expect(manager.batchItems[0].photos[0].type == "front")
    }

    @Test("capturePhotoForBatch runs barcode detection on first photo")
    @MainActor
    func captureRunsBarcodeOnFirst() async throws {
        let barcodeScanner = MockBarcodeScanner()
        barcodeScanner.barcodes = [BarcodeResult(value: "012345678901", symbology: "ean13")]
        let manager = makeBatchManager(barcodeScanner: barcodeScanner)
        manager.startBatchCapture()

        try await manager.capturePhotoForBatch()

        #expect(barcodeScanner.detectBarcodesCalled == 1)
        #expect(manager.batchItems[0].detectedUPC == "012345678901")
    }

    @Test("capturePhotoForBatch skips barcode detection on subsequent photos")
    @MainActor
    func captureSkipsBarcodeOnSubsequent() async throws {
        let barcodeScanner = MockBarcodeScanner()
        barcodeScanner.barcodes = [BarcodeResult(value: "012345678901", symbology: "ean13")]
        let manager = makeBatchManager(barcodeScanner: barcodeScanner)
        manager.startBatchCapture()

        try await manager.capturePhotoForBatch()
        try await manager.capturePhotoForBatch()

        #expect(barcodeScanner.detectBarcodesCalled == 1)
        #expect(manager.batchItems[0].photos.count == 2)
        #expect(manager.batchItems[0].photos[1].type == "photo")
    }

    @Test("capturePhotoForBatch handles barcode detection failure gracefully")
    @MainActor
    func captureBarcodeFailureGraceful() async throws {
        let barcodeScanner = MockBarcodeScanner()
        barcodeScanner.detectError = BarcodeError.detectionFailed("No barcodes")
        let manager = makeBatchManager(barcodeScanner: barcodeScanner)
        manager.startBatchCapture()

        try await manager.capturePhotoForBatch()

        // Photo should still be added even if barcode fails
        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[0].detectedUPC == nil)
    }
}

// MARK: - Photo Storage Integration Tests

@Suite("ScanSessionManager PhotoStorage")
struct PhotoStorageIntegrationTests {
    @Test("addPhotoToCurrentItem saves to photoStorage")
    @MainActor
    func addPhotoSavesToStorage() async throws {
        let storage = MockPhotoStorage()
        let manager = makeBatchManager(photoStorage: storage)
        manager.startBatchCapture()
        let batchItemId = manager.batchItems[0].id

        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        // Give fire-and-forget task time to run
        try await Task.sleep(for: .milliseconds(50))

        #expect(storage.saveCalls.count == 1)
        #expect(storage.saveCalls[0].batchItemId == batchItemId)
        #expect(storage.saveCalls[0].photoIndex == 0)
        #expect(storage.saveCalls[0].data == Data([0x01]))
    }

    @Test("addPhotoToCurrentItem sets fileURL on entry")
    @MainActor
    func addPhotoSetsFileURL() async throws {
        let storage = MockPhotoStorage()
        let manager = makeBatchManager(photoStorage: storage)
        manager.startBatchCapture()

        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        // Give fire-and-forget task time to save and update fileURL
        try await Task.sleep(for: .milliseconds(200))

        #expect(manager.batchItems[0].photos[0].fileURL != nil)
    }

    @Test("resetBatch calls photoStorage deleteAll")
    @MainActor
    func resetBatchDeletesPhotos() async throws {
        let storage = MockPhotoStorage()
        let manager = makeBatchManager(photoStorage: storage)
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        manager.resetBatch()

        // Give fire-and-forget task time to run
        try await Task.sleep(for: .milliseconds(50))

        #expect(storage.deleteAllCalled)
    }

    @Test("capture without photoStorage still works")
    @MainActor
    func captureWithoutStorage() {
        let manager = makeBatchManager()
        manager.startBatchCapture()
        manager.addPhotoToCurrentItem(data: Data([0x01]), type: "front")

        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[0].photos[0].fileURL == nil)
    }
}

// MARK: - Photo Import Tests

@Suite("ScanSessionManager Photo Import")
struct PhotoImportTests {
    @Test("startPhotoImport transitions to importing with queued photos")
    @MainActor
    func startPhotoImport() {
        let manager = makeBatchManager()
        let photos = [Data([0x01]), Data([0x02]), Data([0x03])]
        manager.startPhotoImport(photoData: photos)
        #expect(manager.batchPhase == .importing)
        #expect(manager.batchItems.count == 1)
        #expect(manager.batchItems[0].photos.isEmpty)
        #expect(manager.importQueue.count == 3)
        #expect(manager.importIndex == 0)
    }

    @Test("currentImportPhoto returns photo at current index")
    @MainActor
    func currentImportPhoto() {
        let manager = makeBatchManager()
        manager.startPhotoImport(photoData: [Data([0x01]), Data([0x02])])
        #expect(manager.currentImportPhoto == Data([0x01]))
    }

    @Test("currentImportPhoto returns nil when queue exhausted")
    @MainActor
    func currentImportPhotoExhausted() {
        let manager = makeBatchManager()
        manager.startPhotoImport(photoData: [])
        #expect(manager.currentImportPhoto == nil)
        #expect(manager.isImportQueueExhausted)
    }

    @Test("assignCurrentImportPhoto processes HEIF and adds to current item")
    @MainActor
    func assignCurrentImportPhoto() async {
        let manager = makeBatchManager()
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData, pngData])
        let added = await manager.assignCurrentImportPhoto()
        #expect(added)
        #expect(manager.importIndex == 1)
        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[0].photos[0].type == "front")
    }

    @Test("assignCurrentImportPhoto assigns 'front' to first, 'photo' to subsequent")
    @MainActor
    func assignPhotoTypes() async {
        let manager = makeBatchManager()
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData, pngData])
        _ = await manager.assignCurrentImportPhoto()
        _ = await manager.assignCurrentImportPhoto()
        #expect(manager.batchItems[0].photos[0].type == "front")
        #expect(manager.batchItems[0].photos[1].type == "photo")
    }

    @Test("assignCurrentImportPhoto returns false for invalid data and advances")
    @MainActor
    func assignInvalidData() async {
        let manager = makeBatchManager()
        manager.startPhotoImport(photoData: [Data([0x00, 0x01])])
        let added = await manager.assignCurrentImportPhoto()
        #expect(!added)
        #expect(manager.importIndex == 1)
        #expect(manager.batchItems[0].photos.isEmpty)
    }

    @Test("skipCurrentImportPhoto advances without adding")
    @MainActor
    func skipImportPhoto() {
        let manager = makeBatchManager()
        manager.startPhotoImport(photoData: [Data([0x01]), Data([0x02])])
        manager.skipCurrentImportPhoto()
        #expect(manager.importIndex == 1)
        #expect(manager.batchItems[0].photos.isEmpty)
    }

    @Test("finalizeCurrentItem works during import phase")
    @MainActor
    func finalizeCurrentItemDuringImport() async {
        let manager = makeBatchManager()
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData, pngData, pngData])
        _ = await manager.assignCurrentImportPhoto()
        manager.finalizeCurrentItem()
        _ = await manager.assignCurrentImportPhoto()
        #expect(manager.batchItems.count == 2)
        #expect(manager.batchItems[0].photos.count == 1)
        #expect(manager.batchItems[1].photos.count == 1)
        // Second item's first photo should be tagged "front"
        #expect(manager.batchItems[1].photos[0].type == "front")
    }

    @Test("finishImport clears queue and index")
    @MainActor
    func finishImport() async {
        let manager = makeBatchManager()
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData])
        _ = await manager.assignCurrentImportPhoto()
        manager.finishImport()
        #expect(manager.importQueue.isEmpty)
        #expect(manager.importIndex == 0)
    }

    @Test("barcode detection runs on first photo of each import item")
    @MainActor
    func importBarcodeDetection() async {
        let barcodeScanner = MockBarcodeScanner()
        barcodeScanner.barcodes = [BarcodeResult(value: "012345678901", symbology: "ean13")]
        let manager = makeBatchManager(barcodeScanner: barcodeScanner)
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData, pngData])
        _ = await manager.assignCurrentImportPhoto()
        _ = await manager.assignCurrentImportPhoto()
        #expect(barcodeScanner.detectBarcodesCalled == 1)
        #expect(manager.batchItems[0].detectedUPC == "012345678901")
    }

    @Test("resetBatch clears import state")
    @MainActor
    func resetBatchClearsImport() {
        let manager = makeBatchManager()
        manager.startPhotoImport(photoData: [Data([0x01])])
        manager.resetBatch()
        #expect(manager.importQueue.isEmpty)
        #expect(manager.importIndex == 0)
        #expect(manager.batchPhase == .idle)
    }

    @Test("addImportedPhoto saves to photoStorage")
    @MainActor
    func importSavesToStorage() async throws {
        let storage = MockPhotoStorage()
        let manager = makeBatchManager(photoStorage: storage)
        let pngData = makeMinimalPNG()
        manager.startPhotoImport(photoData: [pngData])
        _ = await manager.assignCurrentImportPhoto()
        try await Task.sleep(for: .milliseconds(50))
        #expect(storage.saveCalls.count == 1)
    }
}

// MARK: - Test Helpers

@MainActor
private func makeBatchManager(
    catalogService: MockCatalogService = MockCatalogService(),
    cameraService: MockCameraService = MockCameraService(),
    barcodeScanner: MockBarcodeScanner = MockBarcodeScanner(),
    photoStorage: MockPhotoStorage? = nil
) -> ScanSessionManager {
    ScanSessionManager(
        catalogService: catalogService,
        cameraService: cameraService,
        barcodeScanner: barcodeScanner,
        photoStorage: photoStorage
    )
}

/// A valid 2x2 red PNG that ImageProcessor.processToHEIF() can convert.
private func makeMinimalPNG() -> Data {
    Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00,
        0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x02, 0x08, 0x02, 0x00, 0x00, 0x00, 0xFD,
        0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00, 0x01, 0x73, 0x52, 0x47,
        0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00, 0x00, 0x44,
        0x65, 0x58, 0x49, 0x66, 0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00,
        0x00, 0x08, 0x00, 0x01, 0x87, 0x69, 0x00, 0x04, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x00, 0x1A, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x03, 0xA0, 0x01, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00, 0x00, 0xA0, 0x02, 0x00, 0x04, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0xA0, 0x03, 0x00, 0x04,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00,
        0x00, 0x00, 0xED, 0x18, 0xBC, 0xAA, 0x00, 0x00, 0x00, 0x10,
        0x49, 0x44, 0x41, 0x54, 0x08, 0x1D, 0x63, 0xFC, 0xCF, 0x00,
        0x02, 0x4C, 0x60, 0x92, 0x01, 0x00, 0x0D, 0x1D, 0x01, 0x03,
        0xAA, 0xD3, 0xE9, 0xB5, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
        0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ])
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
    var batchStatusHandler: ((String) async throws -> BatchJobStatus)?
    var batchStatusCallCount = 0
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
        batchStatusCallCount += 1
        if let handler = batchStatusHandler { return try await handler(jobId) }
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
    private let _previewSession = AVCaptureSession()
    var previewSession: AVCaptureSession { _previewSession }

    var startSessionCalled = false
    var stopSessionCalled = false
    var capturePhotoCalled = false
    var capturePhotoResult = CapturedPhoto(imageData: Data([0xFF]), originalWidth: 100, originalHeight: 100)

    func startSession() async throws {
        startSessionCalled = true
    }

    func stopSession() async {
        stopSessionCalled = true
    }

    func capturePhoto() async throws -> CapturedPhoto {
        capturePhotoCalled = true
        return capturePhotoResult
    }
}

final class MockBarcodeScanner: BarcodeScannerProtocol, @unchecked Sendable {
    var barcodes: [BarcodeResult] = []
    var detectBarcodesCalled = 0
    var detectError: (any Error)?

    func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult] {
        detectBarcodesCalled += 1
        if let error = detectError { throw error }
        return barcodes
    }
}

final class MockPhotoStorage: PhotoStorageProtocol, @unchecked Sendable {
    struct SaveCall: Sendable {
        let data: Data
        let batchItemId: UUID
        let photoIndex: Int
    }

    var saveCalls: [SaveCall] = []
    var deleteAllCalled = false
    var storedURLs: [UUID: [URL]] = [:]

    func save(data: Data, batchItemId: UUID, photoIndex: Int) async throws -> URL {
        saveCalls.append(SaveCall(data: data, batchItemId: batchItemId, photoIndex: photoIndex))
        let url = URL(filePath: "/tmp/BatchPhotos/\(batchItemId.uuidString)/\(photoIndex).heic")
        storedURLs[batchItemId, default: []].append(url)
        return url
    }

    func photoURLs(for batchItemId: UUID) async throws -> [URL] {
        storedURLs[batchItemId] ?? []
    }

    func deleteAll() async throws {
        deleteAllCalled = true
        storedURLs.removeAll()
    }
}
