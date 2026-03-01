//
//  ScanSessionManager.swift
//  ScannerKit
//
//  Observable state machine driving the single-scan workflow. Manages
//  phase transitions from sticker capture through extraction review.
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
public struct CapturedPhotoEntry: Sendable {
    public let data: Data
    public let type: String

    public init(data: Data, type: String) {
        self.data = data
        self.type = type
    }
}

/// Drives the single-scan workflow through phase transitions.
///
/// Views observe `phase` to determine which screen to show.
/// All state mutations happen on the main actor.
@MainActor
@Observable
public final class ScanSessionManager {
    /// The current phase of the scan workflow.
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
}
