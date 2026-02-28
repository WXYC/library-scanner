//
//  PhotoCaptureService.swift
//  CameraKit
//
//  AVCaptureSession-based camera service for capturing photos of vinyl records.
//  Uses a serial DispatchQueue for session configuration, bridged to async/await.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

@preconcurrency import AVFoundation
import ScannerLogger

/// Concrete camera service that captures photos using AVCaptureSession.
///
/// Marked `@unchecked Sendable` because AVCaptureSession requires configuration
/// on a serial DispatchQueue, which doesn't map cleanly to actor isolation.
public final class PhotoCaptureService: CameraServiceProtocol, @unchecked Sendable {
    public let previewSession: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let sessionQueue: DispatchQueue

    public init() {
        self.previewSession = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
        self.sessionQueue = DispatchQueue(label: "org.wxyc.library-scanner.camera")
    }

    public func startSession() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                Log(.warning, category: .camera, "Camera permission denied by user")
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            Log(.warning, category: .camera, "Camera permission denied or restricted")
            throw CameraError.permissionDenied
        case .authorized:
            break
        @unknown default:
            break
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.cameraUnavailable)
                    return
                }
                do {
                    try self.configureSession()
                    self.previewSession.startRunning()
                    Log(.info, category: .camera, "Camera session started")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stopSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.previewSession.stopRunning()
                Log(.info, category: .camera, "Camera session stopped")
                continuation.resume()
            }
        }
    }

    public func capturePhoto() async throws -> CapturedPhoto {
        let delegate = PhotoCaptureDelegate()

        let settings = AVCapturePhotoSettings()
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings.photoQualityPrioritization = .balanced
        }

        photoOutput.capturePhoto(with: settings, delegate: delegate)

        let photoData = try await delegate.result()

        guard let captured = ImageProcessor.processToHEIF(photoData) else {
            Log(.error, category: .camera, "Failed to process captured photo to HEIF")
            throw CameraError.captureFailed
        }

        Log(.info, category: .camera, "Photo captured: \(captured.originalWidth)x\(captured.originalHeight)")
        return captured
    }

    // MARK: - Private

    private func configureSession() throws {
        previewSession.beginConfiguration()
        defer { previewSession.commitConfiguration() }

        previewSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            Log(.error, category: .camera, "Back camera unavailable")
            throw CameraError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            Log(.error, category: .camera, "Failed to create camera input: \(error)")
            throw CameraError.configurationFailed
        }

        guard previewSession.canAddInput(input) else {
            Log(.error, category: .camera, "Cannot add camera input to session")
            throw CameraError.configurationFailed
        }
        previewSession.addInput(input)

        guard previewSession.canAddOutput(photoOutput) else {
            Log(.error, category: .camera, "Cannot add photo output to session")
            throw CameraError.configurationFailed
        }
        previewSession.addOutput(photoOutput)
    }
}

// MARK: - PhotoCaptureDelegate

/// Bridges AVCapturePhotoCaptureDelegate callbacks to async/await.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, Error>?

    func result() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CameraError.captureFailed)
            continuation = nil
            return
        }

        continuation?.resume(returning: data)
        continuation = nil
    }
}
