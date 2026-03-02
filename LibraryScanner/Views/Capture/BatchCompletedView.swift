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

private struct BatchResultCard: View {
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
            } else if let albumId = result.matchedAlbumId {
                Text("Matched album #\(albumId)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

/// Displays matched album details with artist, title, library code, and catalog link.
private struct MatchedAlbumView: View {
    let album: MatchedAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(album.artistName)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(album.albumTitle)
                .font(.subheadline)

            HStack {
                Label(album.libraryCode, systemImage: "books.vertical")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(album.formatName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.fill.tertiary)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Shared Extraction Views

/// Displays non-nil extraction fields with confidence indicators.
struct ExtractionFieldsView: View {
    let extraction: ExtractionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = extraction.labelName {
                ExtractionRow(name: "Label", field: label)
            }
            if let catalog = extraction.catalogNumber {
                ExtractionRow(name: "Catalog #", field: catalog)
            }
            if let upc = extraction.upc {
                ExtractionRow(name: "UPC", field: upc)
            }
            if let review = extraction.reviewText {
                ExtractionRow(name: "Review", field: review)
            }
        }
    }
}

/// A single extraction field with its name, value, and confidence badge.
struct ExtractionRow: View {
    let name: String
    let field: ExtractionField

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(field.value)
                    .font(.subheadline)
                Spacer()
                ConfidenceBadge(confidence: field.confidence)
            }
        }
    }
}

/// Small colored badge showing extraction confidence.
struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(.capsule)
    }

    private var badgeColor: Color {
        switch confidence {
        case 0.8...: .green
        case 0.5...: .orange
        default: .red
        }
    }
}
