//
//  VisionBarcodeScanner.swift
//  BarcodeKit
//
//  Barcode detection using Apple Vision framework, targeting UPC/EAN symbologies
//  commonly found on vinyl record sleeves and inserts.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import ScannerLogger
import Vision

/// Detects barcodes in image data using the Vision framework.
public final class VisionBarcodeScanner: BarcodeScannerProtocol, @unchecked Sendable {

    public init() {}

    public func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult] {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            Log(.warning, category: .barcode, "Invalid image data for barcode detection")
            throw BarcodeError.invalidImageData
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.upce, .ean8, .ean13]

        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            Log(.error, category: .barcode, "Barcode detection failed: \(error)")
            throw BarcodeError.detectionFailed(error.localizedDescription)
        }

        guard let observations = request.results else {
            return []
        }

        let results = observations.compactMap { observation -> BarcodeResult? in
            guard let value = observation.payloadStringValue else { return nil }
            return BarcodeResult(
                value: value,
                symbology: observation.symbology.rawValue
            )
        }

        if !results.isEmpty {
            Log(.info, category: .barcode, "Detected \(results.count) barcode(s)")
        }

        return results
    }
}
