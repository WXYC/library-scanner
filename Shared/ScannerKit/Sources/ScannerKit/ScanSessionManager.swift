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
import CatalogClient
import CameraKit
import BarcodeKit
import ScannerLogger

/// A captured photo with its image data and descriptive type label.
public struct CapturedPhotoEntry: Sendable, Equatable {
    public let data: Data
    public let type: String

    public init(data: Data, type: String) {
        self.data = data
        self.type = type
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

    public init(
        catalogService: any CatalogServiceProtocol,
        cameraService: any CameraServiceProtocol,
        barcodeScanner: any BarcodeScannerProtocol
    ) {
        self.catalogService = catalogService
        self.cameraService = cameraService
        self.barcodeScanner = barcodeScanner
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

        batchItems[lastIndex].photos.append(CapturedPhotoEntry(data: data, type: type))
        Log(.info, category: .scan, "Batch item \(lastIndex): added photo (\(type)), total batch photos: \(totalBatchPhotos)")
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
        } catch {
            batchPhase = .error(error.localizedDescription)
            Log(.error, category: .scan, "Batch submission failed: \(error)")
        }
    }

    /// Reset all batch state to idle.
    public func resetBatch() {
        Log(.info, category: .scan, "Resetting batch")
        batchPhase = .idle
        batchItems = []
    }
}
