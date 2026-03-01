//
//  BatchProgressView.swift
//  LibraryScanner
//
//  Progress indicator shown during batch submission and server processing.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit

/// Displays a progress indicator and status text while the batch is
/// being uploaded or processed by the server.
struct BatchProgressView: View {
    @Environment(\.scanSessionManager) private var sessionManager

    private var statusText: String {
        guard let manager = sessionManager else { return "" }
        switch manager.batchPhase {
        case .submitting:
            return "Uploading batch..."
        case .polling:
            return "Processing..."
        default:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}
