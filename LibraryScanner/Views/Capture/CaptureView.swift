//
//  CaptureView.swift
//  LibraryScanner
//
//  Top-level capture tab view. Switches display based on the current
//  batch phase from ScanSessionManager.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit

/// Root view for the Capture tab. Displays the appropriate subview
/// based on the current batch capture phase.
struct CaptureView: View {
    @Environment(\.scanSessionManager) private var sessionManager

    var body: some View {
        NavigationStack {
            Group {
                if let manager = sessionManager {
                    phaseContent(for: manager)
                } else {
                    ContentUnavailableView(
                        "Not Available",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Session manager not configured.")
                    )
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func phaseContent(for manager: ScanSessionManager) -> some View {
        switch manager.batchPhase {
        case .idle:
            IdleCaptureView()
        case .capturing:
            BatchCameraView()
        case .submitting, .polling:
            BatchProgressView()
        case .completed(let status):
            BatchCompletedView(status: status)
        case .error(let message):
            BatchErrorView(message: message)
        }
    }
}

/// Shown when no batch is in progress. Provides a button to start scanning.
private struct IdleCaptureView: View {
    @Environment(\.scanSessionManager) private var sessionManager

    var body: some View {
        ContentUnavailableView {
            Label("Ready to Scan", systemImage: "camera.viewfinder")
        } description: {
            Text("Place records under the camera and tap to capture photos of each one.")
        } actions: {
            Button("Start Scanning") {
                sessionManager?.startBatchCapture()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

/// Shown when a batch submission error occurs. Offers retry and reset options.
private struct BatchErrorView: View {
    let message: String
    @Environment(\.scanSessionManager) private var sessionManager

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                sessionManager?.startBatchCapture()
            }
            .buttonStyle(.borderedProminent)

            Button("New Batch") {
                sessionManager?.resetBatch()
            }
            .buttonStyle(.bordered)
        }
    }
}
