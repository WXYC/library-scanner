//
//  BatchCompletedView.swift
//  LibraryScanner
//
//  Summary view shown after a batch job finishes processing.
//  Displays completed/failed item counts and a button to start a new batch.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit
import CatalogClient

/// Displays the results of a completed batch job and offers a button
/// to start a new batch.
struct BatchCompletedView: View {
    let status: BatchJobStatus
    @Environment(\.scanSessionManager) private var sessionManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: status.failedItems > 0 ? "exclamationmark.circle" : "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(status.failedItems > 0 ? .orange : .green)

            Text("Batch Complete")
                .font(.title2)
                .bold()

            VStack(spacing: 8) {
                LabeledContent("Total Items", value: "\(status.totalItems)")
                LabeledContent("Completed", value: "\(status.completedItems)")
                if status.failedItems > 0 {
                    LabeledContent("Failed", value: "\(status.failedItems)")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 40)

            Button("New Batch") {
                sessionManager?.resetBatch()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
