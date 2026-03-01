//
//  BatchItem.swift
//  ScannerKit
//
//  Models for batch capture workflow: a BatchItem groups photos of a
//  single record, and BatchPhase tracks the batch state machine.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import CatalogClient

/// A single record in a batch capture session, grouping its photos
/// and any contextual metadata discovered during capture.
public struct BatchItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var photos: [CapturedPhotoEntry]
    public var catalogMatch: CatalogItem?
    public var stickerText: String?
    public var detectedUPC: String?

    public init(
        id: UUID = UUID(),
        photos: [CapturedPhotoEntry] = [],
        catalogMatch: CatalogItem? = nil,
        stickerText: String? = nil,
        detectedUPC: String? = nil
    ) {
        self.id = id
        self.photos = photos
        self.catalogMatch = catalogMatch
        self.stickerText = stickerText
        self.detectedUPC = detectedUPC
    }

    public static func == (lhs: BatchItem, rhs: BatchItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// The current phase of a batch capture workflow.
public enum BatchPhase: Sendable, Equatable {
    /// No batch in progress.
    case idle
    /// Actively capturing photos for a batch of records.
    case capturing
    /// Uploading batch to the server.
    case submitting
    /// Server is processing; polling for results.
    case polling(jobId: String)
    /// All items processed; results available.
    case completed(BatchJobStatus)
    /// An error occurred during batch processing.
    case error(String)
}
