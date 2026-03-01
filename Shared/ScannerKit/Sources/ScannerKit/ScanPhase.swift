//
//  ScanPhase.swift
//  ScannerKit
//
//  Defines the phases of a scan session, used by the state machine
//  to drive the UI workflow.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import CatalogClient

/// The current phase of a scan workflow.
public enum ScanPhase: Sendable, Equatable {
    /// No scan in progress.
    case idle
    /// Capturing the sticker on the record spine.
    case capturingSticker
    /// Looking up the catalog based on parsed sticker code.
    case lookingUpCatalog
    /// Catalog match found.
    case catalogMatched(CatalogItem)
    /// No catalog match found for the parsed code.
    case catalogNotFound
    /// Capturing photos of the record (front, back, label, etc.).
    case capturingPhotos
    /// Uploading photos to the server.
    case uploading
    /// Server is processing images with Gemini.
    case processing
    /// Extraction results ready for DJ review.
    case reviewing(ExtractionResult)
    /// DJ approved the extraction, data written to catalog.
    case approved
    /// An error occurred.
    case error(String)
}
