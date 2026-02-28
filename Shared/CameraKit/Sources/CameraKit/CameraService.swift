//
//  CameraService.swift
//  CameraKit
//
//  Protocol and types for camera capture using AVCaptureSession.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

@preconcurrency import AVFoundation
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

/// Errors that can occur during camera operations.
public enum CameraError: Error, Sendable {
    case cameraUnavailable
    case permissionDenied
    case configurationFailed
    case captureFailed
}

/// Protocol for camera services. Allows mocking in tests.
public protocol CameraServiceProtocol: Sendable {
    /// The underlying capture session, exposed for SwiftUI preview layer integration.
    var previewSession: AVCaptureSession { get }

    /// Start the camera capture session.
    func startSession() async throws

    /// Stop the camera capture session.
    func stopSession() async

    /// Capture a single photo.
    func capturePhoto() async throws -> CapturedPhoto
}
