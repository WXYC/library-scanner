//
//  BatchCompletedView.swift
//  LibraryScanner
//
//  Summary view shown after a batch job finishes processing.
//  Displays extraction results, matched album details, and navigation
//  to detail views for each scanned item.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit
import CatalogClient

/// Displays the results of a completed batch job and offers a button
/// to start a new batch. Tap a result card to see full details.
struct BatchCompletedView: View {
    let status: BatchJobStatus
    let artworkService: any ArtworkServiceProtocol
    let photoStorage: (any PhotoStorageProtocol)?
    @Environment(\.scanSessionManager) private var sessionManager

    var body: some View {
        ScrollView {
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

                if let results = status.results, !results.isEmpty {
                    LazyVStack(spacing: 16) {
                        ForEach(results, id: \.itemIndex) { result in
                            NavigationLink(value: result) {
                                BatchResultCard(result: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Button("New Batch") {
                    sessionManager?.resetBatch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical)
        }
        .navigationDestination(for: BatchResult.self) { result in
            BatchItemDetailView(
                result: result,
                photoURLs: photoURLsForResult(result),
                artworkService: artworkService
            )
        }
    }

    private func photoURLsForResult(_ result: BatchResult) -> [URL] {
        guard let manager = sessionManager,
              result.itemIndex < manager.batchItems.count else {
            return []
        }
        return manager.batchItems[result.itemIndex].photos.compactMap(\.fileURL)
    }
}

// MARK: - Result Card

/// Compact card showing a batch result summary with album, extraction, and status.
struct BatchResultCard: View {
    let result: BatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Item \(result.itemIndex + 1)",
                    systemImage: result.status == "completed" ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(result.status == "completed" ? .green : .red)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let album = result.matchedAlbum {
                MatchedAlbumView(album: album)
            } else if let extraction = result.extraction,
                      let artist = extraction.artistName?.value {
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let title = extraction.albumTitle?.value {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let extraction = result.extraction {
                ExtractionFieldsView(extraction: extraction)
            }

            if let error = result.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 12))
    }
}
