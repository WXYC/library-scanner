//
//  CameraService.swift
//  CameraKit
//
//  Protocol and placeholder for camera capture using AVCaptureSession.
//  Implementation in PR 5.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// A captured photo with its data and metadata.
public struct CapturedPhoto: Sendable {
    /// The photo as HEIF data, downscaled to max 2048px.
    public let imageData: Data
    /// The original image dimensions before downscaling.
    public let originalWidth: Int
    public let originalHeight: Int

    public init(imageData: Data, originalWidth: Int, originalHeight: Int) {
        self.imageData = imageData
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
    }
}

/// Protocol for camera services. Allows mocking in tests.
public protocol CameraServiceProtocol: Sendable {
    /// Start the camera capture session.
    func startSession() async throws

    /// Stop the camera capture session.
    func stopSession() async

    /// Capture a single photo.
    func capturePhoto() async throws -> CapturedPhoto
}
