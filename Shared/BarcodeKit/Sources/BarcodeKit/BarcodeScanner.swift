//
//  BarcodeScanner.swift
//  BarcodeKit
//
//  Protocol and types for UPC barcode detection using Apple Vision framework.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// Result of a barcode scan, containing the detected barcode value and type.
public struct BarcodeResult: Sendable, Equatable {
    public let value: String
    public let symbology: String

    public init(value: String, symbology: String) {
        self.value = value
        self.symbology = symbology
    }
}

/// Errors that can occur during barcode detection.
public enum BarcodeError: Error, Sendable {
    case invalidImageData
    case detectionFailed(String)
}

/// Protocol for barcode scanning services.
public protocol BarcodeScannerProtocol: Sendable {
    /// Detect barcodes in the given image data.
    func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult]
}
