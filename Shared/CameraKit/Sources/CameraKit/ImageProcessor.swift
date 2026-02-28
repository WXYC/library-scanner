//
//  ImageProcessor.swift
//  CameraKit
//
//  Pure-function HEIF conversion and downscaling, extracted for testability.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Handles image conversion to HEIF format with optional downscaling.
public enum ImageProcessor {

    /// Converts image data to HEIF format, downscaling if any dimension exceeds `maxDimension`.
    ///
    /// - Parameters:
    ///   - imageData: Source image data (JPEG, PNG, HEIF, etc.).
    ///   - maxDimension: Maximum allowed pixel dimension for either width or height.
    /// - Returns: A `CapturedPhoto` with HEIF data and original dimensions, or `nil` if processing fails.
    public static func processToHEIF(_ imageData: Data, maxDimension: Int = 2048) -> CapturedPhoto? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let originalWidth = cgImage.width
        let originalHeight = cgImage.height

        let imageToEncode: CGImage
        let maxSide = max(originalWidth, originalHeight)

        if maxSide > maxDimension {
            let scale = Double(maxDimension) / Double(maxSide)
            let targetWidth = Int(Double(originalWidth) * scale)
            let targetHeight = Int(Double(originalHeight) * scale)

            let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
            let hasAlpha = cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast
                && cgImage.alphaInfo != .noneSkipFirst
            let bitmapInfo = hasAlpha
                ? CGImageAlphaInfo.premultipliedLast.rawValue
                : CGImageAlphaInfo.noneSkipLast.rawValue
            guard let context = CGContext(
                      data: nil,
                      width: targetWidth,
                      height: targetHeight,
                      bitsPerComponent: 8,
                      bytesPerRow: 0,
                      space: colorSpace,
                      bitmapInfo: bitmapInfo
                  )
            else {
                return nil
            }

            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

            guard let scaledImage = context.makeImage() else {
                return nil
            }
            imageToEncode = scaledImage
        } else {
            imageToEncode = cgImage
        }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]
        CGImageDestinationAddImage(destination, imageToEncode, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return CapturedPhoto(
            imageData: outputData as Data,
            originalWidth: originalWidth,
            originalHeight: originalHeight
        )
    }
}
