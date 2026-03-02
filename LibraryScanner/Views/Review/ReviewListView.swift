//
//  ReviewListView.swift
//  LibraryScanner
//
//  Scrollable list of batch results for review. Each card shows a
//  reviewed/unreviewed badge and links to the editable detail view.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient

/// Displays a scrollable list of batch results that can be reviewed.
/// Only shows items with status "completed".
struct ReviewListView: View {
    let results: [BatchResult]
    let artworkService: (any ArtworkServiceProtocol)?
    let catalogService: (any CatalogServiceProtocol)?

    @State private var reviewedIndices: Set<Int> = []

    private var completedResults: [BatchResult] {
        results.filter { $0.status == "completed" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(completedResults, id: \.itemIndex) { result in
                    NavigationLink(value: result) {
                        ReviewResultCard(
                            result: result,
                            isReviewed: reviewedIndices.contains(result.itemIndex)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: BatchResult.self) { result in
            ReviewItemView(
                result: result,
                artworkService: artworkService,
                catalogService: catalogService,
                onSaved: {
                    reviewedIndices.insert(result.itemIndex)
                }
            )
        }
        .overlay {
            if completedResults.isEmpty {
                ContentUnavailableView(
                    "No Completed Items",
                    systemImage: "checkmark.circle",
                    description: Text("No items completed successfully in this batch.")
                )
            }
        }
    }
}

// MARK: - Review Result Card

private struct ReviewResultCard: View {
    let result: BatchResult
    let isReviewed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Item \(result.itemIndex + 1)",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.green)

                Spacer()

                if isReviewed {
                    Label("Reviewed", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let album = result.matchedAlbum {
                MatchedAlbumView(album: album)
            }

            if let extraction = result.extraction {
                ExtractionFieldsView(extraction: extraction)
            }
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 12))
    }
}
