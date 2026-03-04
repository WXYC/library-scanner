//
//  ScanSessionManager.swift
//  ScannerKit
//
//  Observable state machine driving scan workflows. Manages phase
//  transitions for both single-scan and batch capture modes.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
@preconcurrency import AVFoundation
import CatalogClient
import CameraKit
import BarcodeKit
import ScannerLogger

/// A captured photo with its image data and descriptive type label.
public struct CapturedPhotoEntry: Sendable, Equatable {
    public let data: Data
    public let type: String
    /// File URL where the photo was persisted to disk, if available.
    public var fileURL: URL?

    public init(data: Data, type: String, fileURL: URL? = nil) {
        self.data = data
        self.type = type
        self.fileURL = fileURL
    }
}

/// Drives single-scan and batch capture workflows through phase transitions.
///
/// Views observe `phase` for single-scan and `batchPhase` for batch mode
/// to determine which screen to show. All state mutations happen on the main actor.
@MainActor
@Observable
public final class ScanSessionManager {
    // MARK: - Single-Scan State

    /// The current phase of the single-scan workflow.
    public private(set) var phase: ScanPhase = .idle

    /// Photos captured during this scan session.
    public private(set) var capturedPhotos: [CapturedPhotoEntry] = []

    /// The catalog item matched by sticker lookup, if any.
    public private(set) var matchedItem: CatalogItem?

    /// The sticker text parsed from the record spine.
    public private(set) var stickerText: String?

    /// UPC barcode detected on the record, if any.
    public private(set) var detectedUPC: String?

    /// Maximum number of photos per scan session.
    public static let maxPhotos = 5

    // MARK: - Batch State

    /// The current phase of the batch capture workflow.
    public private(set) var batchPhase: BatchPhase = .idle

    /// Items in the current batch, each grouping photos of one record.
    public private(set) var batchItems: [BatchItem] = []

    /// Maximum number of items in a single batch.
    public static let maxBatchItems = 10

    /// Maximum total photos across all items in a batch.
    public static let maxTotalBatchPhotos = 50

    // MARK: - Import State

    /// Total number of photos selected for import.
    public private(set) var importQueueCount: Int = 0

    /// Index of the photo currently being reviewed during import.
    public private(set) var importIndex: Int = 0

    /// Whether all import photos have been assigned or skipped.
    public var isImportQueueExhausted: Bool {
        importIndex >= importQueueCount
    }

    /// Total number of photos across all batch items.
    public var totalBatchPhotos: Int {
        batchItems.reduce(0) { $0 + $1.photos.count }
    }

    /// The last item in the batch, or nil if the batch is empty.
    public var currentBatchItem: BatchItem? {
        batchItems.last
    }

    private let catalogService: any CatalogServiceProtocol
    private let cameraService: any CameraServiceProtocol
    private let barcodeScanner: any BarcodeScannerProtocol
    private let photoStorage: (any PhotoStorageProtocol)?
    private var pollingTask: Task<Void, Never>?

    public init(
        catalogService: any CatalogServiceProtocol,
        cameraService: any CameraServiceProtocol,
        barcodeScanner: any BarcodeScannerProtocol,
        photoStorage: (any PhotoStorageProtocol)? = nil
    ) {
        self.catalogService = catalogService
        self.cameraService = cameraService
        self.barcodeScanner = barcodeScanner
        self.photoStorage = photoStorage
    }

    // MARK: - Phase Transitions

    /// Begin a new scan session.
    public func startScan() {
        Log(.info, category: .scan, "Starting new scan session")
        phase = .capturingSticker
    }

    /// Look up a catalog item by library code parsed from the sticker.
    public func lookupCatalog(
        codeLetters: String,
        codeArtistNumber: String,
        codeNumber: Int?
    ) async {
        phase = .lookingUpCatalog
        stickerText = "\(codeLetters) \(codeArtistNumber)/\(codeNumber.map(String.init) ?? "?")"

        Log(.info, category: .scan, "Looking up catalog: \(stickerText ?? "")")

        do {
            let items = try await catalogService.lookupByCode(
                codeLetters: codeLetters,
                codeArtistNumber: codeArtistNumber,
                codeNumber: codeNumber
            )

            if let item = items.first {
                matchedItem = item
                phase = .catalogMatched(item)
                Log(.info, category: .scan, "Catalog match: \(item.artistName) - \(item.albumTitle)")
            } else {
                phase = .catalogNotFound
                Log(.info, category: .scan, "No catalog match found")
            }
        } catch {
            phase = .error(error.localizedDescription)
            Log(.error, category: .scan, "Catalog lookup failed: \(error)")
        }
    }

    /// Skip the catalog lookup step and proceed directly to photo capture.
    public func skipCatalogLookup() {
        Log(.info, category: .scan, "Skipping catalog lookup")
        phase = .capturingPhotos
    }

    /// Proceed from catalog match/not-found to photo capture.
    public func proceedToCapture() {
        Log(.info, category: .scan, "Proceeding to photo capture")
        phase = .capturingPhotos
    }

    /// Add a captured photo to the session.
    public func addPhoto(data: Data, type: String) {
        guard capturedPhotos.count < Self.maxPhotos else {
            Log(.warning, category: .scan, "Max photos (\(Self.maxPhotos)) reached, ignoring")
            return
        }

        capturedPhotos.append(CapturedPhotoEntry(data: data, type: type))
        Log(.info, category: .scan, "Added photo \(capturedPhotos.count)/\(Self.maxPhotos) (\(type))")
    }

    /// Remove a captured photo at the given index.
    public func removePhoto(at index: Int) {
        guard capturedPhotos.indices.contains(index) else { return }
        capturedPhotos.remove(at: index)
        Log(.info, category: .scan, "Removed photo at index \(index), \(capturedPhotos.count) remaining")
    }

    /// Submit captured photos to the server for extraction.
    public func submitScan() async {
        phase = .uploading
        Log(.info, category: .scan, "Submitting \(capturedPhotos.count) photo(s) for extraction")

        do {
            let result = try await catalogService.submitScan(
                images: capturedPhotos.map(\.data),
                photoTypes: capturedPhotos.map(\.type),
                catalogItemId: matchedItem?.id,
                stickerText: stickerText,
                detectedUPC: detectedUPC
            )

            phase = .reviewing(result)
            Log(.info, category: .scan, "Extraction complete, entering review")
        } catch {
            phase = .error(error.localizedDescription)
            Log(.error, category: .scan, "Scan submission failed: \(error)")
        }
    }

    /// Approve the extraction results and write them to the catalog.
    public func approveExtraction(
        labelName: String?,
        reviewText: String?
    ) async {
        guard let albumId = matchedItem?.id else {
            phase = .error("No matched album to update")
            return
        }

        Log(.info, category: .scan, "Approving extraction for album \(albumId)")

        do {
            if let labelName {
                try await catalogService.updateAlbum(
                    albumId: albumId,
                    label: labelName,
                    albumTitle: nil
                )
            }

            if let reviewText {
                try await catalogService.upsertReview(
                    albumId: albumId,
                    review: reviewText,
                    author: nil
                )
            }

            phase = .approved
            Log(.info, category: .scan, "Extraction approved and saved")
        } catch {
            phase = .error(error.localizedDescription)
            Log(.error, category: .scan, "Approval failed: \(error)")
        }
    }

    /// Reset all state to idle for a new scan.
    public func reset() {
        Log(.info, category: .scan, "Resetting scan session")
        phase = .idle
        capturedPhotos = []
        matchedItem = nil
        stickerText = nil
        detectedUPC = nil
    }

    // MARK: - Batch Capture

    /// Begin a new batch capture session.
    public func startBatchCapture() {
        Log(.info, category: .scan, "Starting batch capture")
        batchPhase = .capturing
        batchItems = [BatchItem()]
    }

    /// Add a photo to the current (last) batch item.
    public func addPhotoToCurrentItem(data: Data, type: String) {
        guard !batchItems.isEmpty else { return }
        let lastIndex = batchItems.count - 1
        guard batchItems[lastIndex].photos.count < Self.maxPhotos else {
            Log(.warning, category: .scan, "Per-item photo limit (\(Self.maxPhotos)) reached")
            return
        }

        let photoIndex = batchItems[lastIndex].photos.count
        batchItems[lastIndex].photos.append(CapturedPhotoEntry(data: data, type: type))
        Log(.info, category: .scan, "Batch item \(lastIndex): added photo (\(type)), total batch photos: \(totalBatchPhotos)")

        if let storage = photoStorage {
            let batchItemId = batchItems[lastIndex].id
            Task { [weak self] in
                do {
                    let url = try await storage.save(data: data, batchItemId: batchItemId, photoIndex: photoIndex)
                    guard let self, self.batchItems.indices.contains(lastIndex),
                          self.batchItems[lastIndex].id == batchItemId else { return }
                    self.batchItems[lastIndex].photos[photoIndex].fileURL = url
                } catch {
                    Log(.warning, category: .scan, "Failed to save photo to disk: \(error)")
                }
            }
        }
    }

    /// Finalize the current item and create a new empty one for the next record.
    public func finalizeCurrentItem() {
        guard batchItems.count < Self.maxBatchItems else {
            Log(.warning, category: .scan, "Max batch items (\(Self.maxBatchItems)) reached")
            return
        }

        batchItems.append(BatchItem())
        Log(.info, category: .scan, "Finalized item, starting item \(batchItems.count)")
    }

    /// Remove a batch item at the given index.
    public func removeItemFromBatch(at index: Int) {
        guard batchItems.indices.contains(index) else { return }
        batchItems.remove(at: index)
        Log(.info, category: .scan, "Removed batch item at index \(index), \(batchItems.count) remaining")
    }

    /// Submit the batch to the server for async processing.
    public func submitBatch() async {
        batchPhase = .submitting
        Log(.info, category: .scan, "Submitting batch with \(batchItems.count) item(s), \(totalBatchPhotos) photo(s)")

        let manifestItems = batchItems.map { item in
            BatchManifestItem(
                imageCount: item.photos.count,
                photoTypes: item.photos.map(\.type),
                context: BatchContext(
                    catalogItemId: item.catalogMatch?.id,
                    stickerText: item.stickerText,
                    detectedUPC: item.detectedUPC,
                    artistName: item.catalogMatch?.artistName,
                    albumTitle: item.catalogMatch?.albumTitle
                )
            )
        }
        let allImages = batchItems.flatMap { $0.photos.map(\.data) }

        do {
            let result = try await catalogService.submitBatch(items: manifestItems, images: allImages)
            batchPhase = .polling(jobId: result.jobId)
            Log(.info, category: .scan, "Batch submitted, job ID: \(result.jobId)")
            startPolling(jobId: result.jobId)
        } catch {
            batchPhase = .error(error.localizedDescription)
            Log(.error, category: .scan, "Batch submission failed: \(error)")
        }
    }

    // MARK: - Photo Import

    /// Begin a photo import session. Photos are loaded lazily by the view layer.
    ///
    /// - Parameter count: The number of photos the user selected.
    public func startPhotoImport(count: Int) {
        Log(.info, category: .scan, "Starting photo import with \(count) photos")
        cancelPolling()
        batchPhase = .importing
        batchItems = [BatchItem()]
        importQueueCount = count
        importIndex = 0
    }

    /// Add an imported photo to the current batch item after HEIF conversion.
    ///
    /// Runs barcode detection on the first photo of each item. Returns `false`
    /// if the image data could not be converted to HEIF.
    public func addImportedPhoto(data: Data) async -> Bool {
        guard !batchItems.isEmpty else { return false }
        let lastIndex = batchItems.count - 1
        guard batchItems[lastIndex].photos.count < Self.maxPhotos else {
            Log(.warning, category: .scan, "Per-item photo limit (\(Self.maxPhotos)) reached")
            return false
        }

        guard let processed = ImageProcessor.processToHEIF(data) else {
            Log(.warning, category: .scan, "Failed to process imported photo to HEIF")
            return false
        }

        let isFirstPhoto = batchItems[lastIndex].photos.isEmpty
        let type = isFirstPhoto ? "front" : "photo"
        addPhotoToCurrentItem(data: processed.imageData, type: type)

        if isFirstPhoto {
            do {
                let barcodes = try await barcodeScanner.detectBarcodes(in: processed.imageData)
                if let upc = barcodes.first?.value, batchItems.indices.contains(lastIndex) {
                    batchItems[lastIndex].detectedUPC = upc
                    Log(.info, category: .scan, "Detected UPC from import: \(upc)")
                }
            } catch {
                Log(.warning, category: .scan, "Barcode detection failed on import: \(error)")
            }
        }

        return true
    }

    /// Assign photo data to the current batch item and advance the import index.
    ///
    /// The view layer is responsible for loading the photo data from the
    /// `PhotosPickerItem` before calling this method, keeping memory usage
    /// to one photo at a time.
    public func assignImportPhoto(data: Data) async -> Bool {
        guard !isImportQueueExhausted else { return false }
        let result = await addImportedPhoto(data: data)
        importIndex += 1
        return result
    }

    /// Skip the current import photo without adding it.
    public func skipCurrentImportPhoto() {
        guard importIndex < importQueueCount else { return }
        importIndex += 1
        Log(.info, category: .scan, "Skipped import photo at index \(importIndex - 1)")
    }

    /// Clear the import count and index. Does not change the batch phase.
    public func finishImport() {
        Log(.info, category: .scan, "Import finished: \(batchItems.count) items, \(totalBatchPhotos) photos")
        importQueueCount = 0
        importIndex = 0
    }

    /// Reset all batch state to idle.
    public func resetBatch() {
        Log(.info, category: .scan, "Resetting batch")
        cancelPolling()
        batchPhase = .idle
        batchItems = []
        importQueueCount = 0
        importIndex = 0

        if let storage = photoStorage {
            Task {
                do {
                    try await storage.deleteAll()
                } catch {
                    Log(.warning, category: .scan, "Failed to delete batch photos: \(error)")
                }
            }
        }
    }

    // MARK: - Polling

    /// Begin polling the server for batch job status.
    ///
    /// - Parameters:
    ///   - jobId: The batch job identifier to poll.
    ///   - initialDelay: Delay between polls (doubles each retry, capped at 15s).
    ///     Defaults to 2 seconds; use `.milliseconds(10)` in tests.
    public func startPolling(jobId: String, initialDelay: Duration = .seconds(2)) {
        cancelPolling()
        Log(.info, category: .scan, "Starting polling for job \(jobId)")
        pollingTask = Task { [weak self] in
            await self?.pollLoop(jobId: jobId, initialDelay: initialDelay)
        }
    }

    /// Cancel any active polling task.
    public func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollLoop(jobId: String, initialDelay: Duration) async {
        var delay = initialDelay
        let maxDelay: Duration = .seconds(15)

        while !Task.isCancelled {
            do {
                let status = try await catalogService.batchStatus(jobId: jobId)
                guard !Task.isCancelled else { return }
                if status.status == "completed" || status.status == "failed" {
                    batchPhase = .completed(status)
                    Log(.info, category: .scan, "Batch job \(jobId) finished: \(status.status)")
                    return
                }
                try await Task.sleep(for: delay)
                delay = min(delay * 2, maxDelay)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                batchPhase = .error(error.localizedDescription)
                Log(.error, category: .scan, "Polling failed for job \(jobId): \(error)")
                return
            }
        }
    }

    // MARK: - Camera

    /// The underlying capture session for preview layer integration.
    public var previewSession: AVCaptureSession {
        cameraService.previewSession
    }

    /// Start the camera capture session.
    public func startCamera() async throws {
        try await cameraService.startSession()
    }

    /// Stop the camera capture session.
    public func stopCamera() async {
        await cameraService.stopSession()
    }

    /// Capture a photo and add it to the current batch item.
    ///
    /// Runs barcode detection on the first photo of each item (the front cover
    /// is most likely to have a UPC). Subsequent photos skip barcode detection.
    public func capturePhotoForBatch() async throws {
        let photo = try await cameraService.capturePhoto()
        let isFirstPhoto = currentBatchItem?.photos.isEmpty ?? true
        let type = isFirstPhoto ? "front" : "photo"
        addPhotoToCurrentItem(data: photo.imageData, type: type)

        if isFirstPhoto {
            do {
                let barcodes = try await barcodeScanner.detectBarcodes(in: photo.imageData)
                if let upc = barcodes.first?.value, !batchItems.isEmpty {
                    batchItems[batchItems.count - 1].detectedUPC = upc
                    Log(.info, category: .scan, "Detected UPC: \(upc)")
                }
            } catch {
                Log(.warning, category: .scan, "Barcode detection failed: \(error)")
            }
        }
    }
}
