//
//  CameraKitTests.swift
//  CameraKit
//
//  Tests for CameraKit types and ImageProcessor.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import CameraKit

@Suite("CameraKit")
struct CameraKitTests {
    @Test("CapturedPhoto stores data and dimensions")
    func capturedPhotoInit() {
        let data = Data([0x00, 0x01, 0x02])
        let photo = CapturedPhoto(imageData: data, originalWidth: 4032, originalHeight: 3024)
        #expect(photo.imageData == data)
        #expect(photo.originalWidth == 4032)
        #expect(photo.originalHeight == 3024)
    }

    @Test("CameraError cases are constructible")
    func cameraErrorCases() {
        let errors: [CameraError] = [
            .cameraUnavailable,
            .permissionDenied,
            .configurationFailed,
            .captureFailed,
        ]
        #expect(errors.count == 4)
    }
}

@Suite("ImageProcessor")
struct ImageProcessorTests {
    /// Creates a JPEG image programmatically with the given dimensions.
    private static func makeJPEGData(width: Int, height: Int) -> Data {
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
        // Fill with a solid color so it's a valid image
        context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
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

    @Test("Processes JPEG to HEIF output")
    func processJPEGToHEIF() {
        let jpeg = ImageProcessorTests.makeJPEGData(width: 800, height: 600)
        let result = ImageProcessor.processToHEIF(jpeg)
        #expect(result != nil)
        #expect(result!.imageData.count > 0)
    }

    @Test("Large image is downscaled to max dimension")
    func downscalesLargeImage() {
        let jpeg = ImageProcessorTests.makeJPEGData(width: 4032, height: 3024)
        let result = ImageProcessor.processToHEIF(jpeg, maxDimension: 2048)
        #expect(result != nil)
        // Original dimensions should reflect the source image
        #expect(result!.originalWidth == 4032)
        #expect(result!.originalHeight == 3024)
        // Verify the output image is actually downscaled
        let source = CGImageSourceCreateWithData(result!.imageData as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        let outputWidth = properties[kCGImagePropertyPixelWidth] as! Int
        let outputHeight = properties[kCGImagePropertyPixelHeight] as! Int
        #expect(outputWidth <= 2048)
        #expect(outputHeight <= 2048)
    }

    @Test("Small image is not upscaled")
    func doesNotUpscaleSmallImage() {
        let jpeg = ImageProcessorTests.makeJPEGData(width: 640, height: 480)
        let result = ImageProcessor.processToHEIF(jpeg, maxDimension: 2048)
        #expect(result != nil)
        #expect(result!.originalWidth == 640)
        #expect(result!.originalHeight == 480)
        // Output should retain original dimensions
        let source = CGImageSourceCreateWithData(result!.imageData as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        let outputWidth = properties[kCGImagePropertyPixelWidth] as! Int
        let outputHeight = properties[kCGImagePropertyPixelHeight] as! Int
        #expect(outputWidth == 640)
        #expect(outputHeight == 480)
    }

    @Test("Invalid data returns nil")
    func invalidDataReturnsNil() {
        let garbage = Data([0xFF, 0xFE, 0xAB, 0xCD])
        let result = ImageProcessor.processToHEIF(garbage)
        #expect(result == nil)
    }
}
