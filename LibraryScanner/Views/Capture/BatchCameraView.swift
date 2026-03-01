//
//  BatchCameraView.swift
//  LibraryScanner
//
//  Live camera preview with batch capture controls. Shows the camera feed
//  full-screen with overlay controls for capturing, advancing to the next
//  record, and submitting the batch.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit
import ScannerUI

/// Displays the camera preview and batch capture controls.
///
/// The camera starts automatically when this view appears and stops
/// when it disappears. The DJ workflow is "place, tap, flip, tap, repeat."
struct BatchCameraView: View {
    @Environment(\.scanSessionManager) private var sessionManager
    @State private var isCapturing = false
    @State private var cameraError: String?

    private var manager: ScanSessionManager? { sessionManager }
    private var currentItemPhotoCount: Int { manager?.currentBatchItem?.photos.count ?? 0 }
    private var itemCount: Int { manager?.batchItems.count ?? 0 }
    private var totalPhotos: Int { manager?.totalBatchPhotos ?? 0 }
    private var hasPhotos: Bool { totalPhotos > 0 }

    var body: some View {
        ZStack {
            cameraPreview
            controlOverlay
        }
        .ignoresSafeArea(.container, edges: .top)
        .task {
            do {
                try await manager?.startCamera()
            } catch {
                cameraError = error.localizedDescription
            }
        }
        .onDisappear {
            Task {
                await manager?.stopCamera()
            }
        }
    }
}

// MARK: - Camera Preview

private struct CameraPreviewSection: View {
    let session: AVCaptureSession

    var body: some View {
        CameraPreviewView(session: session)
    }
}

// MARK: - Subviews

private extension BatchCameraView {
    @ViewBuilder
    var cameraPreview: some View {
        if let error = cameraError {
            ContentUnavailableView(
                "Camera Unavailable",
                systemImage: "camera.fill",
                description: Text(error)
            )
        } else if let session = manager?.previewSession {
            CameraPreviewView(session: session)
        } else {
            Color.black
        }
    }

    var controlOverlay: some View {
        VStack {
            topBar
            Spacer()
            BatchItemStrip(items: manager?.batchItems ?? [])
            bottomControls
        }
    }

    var topBar: some View {
        HStack {
            Text("Item \(itemCount)")
                .font(.subheadline)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(.capsule)

            Spacer()

            Text("\(currentItemPhotoCount) photo\(currentItemPhotoCount == 1 ? "" : "s")")
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(.capsule)
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }

    var bottomControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                nextRecordButton
                captureButton
                submitButton
            }
        }
        .padding()
        .padding(.bottom)
        .background(.ultraThinMaterial)
    }

    var captureButton: some View {
        Button {
            guard !isCapturing else { return }
            isCapturing = true
            Task {
                defer { isCapturing = false }
                do {
                    try await manager?.capturePhotoForBatch()
                } catch {
                    cameraError = error.localizedDescription
                }
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
                    .opacity(isCapturing ? 0.5 : 1)
            }
        }
        .disabled(isCapturing)
    }

    var nextRecordButton: some View {
        Button {
            manager?.finalizeCurrentItem()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                Text("Next")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
        }
        .disabled(!hasPhotos || itemCount >= ScanSessionManager.maxBatchItems)
    }

    var submitButton: some View {
        Button {
            Task {
                await manager?.submitBatch()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                Text("Submit")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
        }
        .disabled(!hasPhotos)
    }
}

@preconcurrency import AVFoundation
