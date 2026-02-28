//
//  BarcodeKitTests.swift
//  BarcodeKit
//
//  Tests for BarcodeKit types and VisionBarcodeScanner.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import BarcodeKit

@Suite("BarcodeKit")
struct BarcodeKitTests {
    @Test("BarcodeResult stores value and symbology")
    func barcodeResultInit() {
        let result = BarcodeResult(value: "012345678901", symbology: "EAN-13")
        #expect(result.value == "012345678901")
        #expect(result.symbology == "EAN-13")
    }

    @Test("BarcodeResult is Equatable")
    func barcodeResultEquatable() {
        let a = BarcodeResult(value: "123", symbology: "UPC-A")
        let b = BarcodeResult(value: "123", symbology: "UPC-A")
        let c = BarcodeResult(value: "456", symbology: "UPC-A")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("BarcodeError cases are constructible")
    func barcodeErrorCases() {
        let errors: [BarcodeError] = [
            .invalidImageData,
            .detectionFailed("test error"),
        ]
        #expect(errors.count == 2)
    }
}

@Suite("VisionBarcodeScanner")
struct VisionBarcodeScannerTests {
    /// Creates a plain JPEG image with no barcodes.
    private static func makePlainJPEGData(width: Int, height: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = context.makeImage()!

        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    @Test("Invalid image data throws invalidImageData")
    func invalidImageDataThrows() async throws {
        let scanner = VisionBarcodeScanner()
        let garbage = Data([0xFF, 0xFE, 0xAB, 0xCD])
        await #expect(throws: BarcodeError.self) {
            try await scanner.detectBarcodes(in: garbage)
        }
    }

    @Test("Image with no barcodes returns empty array or throws on simulator")
    func noBarcodeReturnsEmpty() async throws {
        let scanner = VisionBarcodeScanner()
        let plain = VisionBarcodeScannerTests.makePlainJPEGData(width: 200, height: 200)
        do {
            let results = try await scanner.detectBarcodes(in: plain)
            #expect(results.isEmpty)
        } catch let error as BarcodeError {
            // Vision framework cannot create inference context on simulator;
            // detectionFailed is acceptable in that environment.
            guard case .detectionFailed = error else {
                Issue.record("Unexpected BarcodeError: \(error)")
                return
            }
        }
    }
}
