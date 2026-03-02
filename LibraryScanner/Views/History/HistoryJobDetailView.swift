//
//  HistoryJobDetailView.swift
//  LibraryScanner
//
//  Detail view for a single historical batch job. Loads full results
//  via batchStatus and displays them as read-only result cards.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient

/// Loads and displays the full results of a past batch job.
struct HistoryJobDetailView: View {
    let jobId: String

    @Environment(\.catalogService) private var catalogService
    @Environment(\.artworkService) private var artworkService

    @State private var status: BatchJobStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading results...")
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let status {
                jobResultsView(status)
            }
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStatus()
        }
    }

    private func jobResultsView(_ status: BatchJobStatus) -> some View {
        ScrollView {
            VStack(spacing: 24) {
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
            }
            .padding(.vertical)
        }
        .navigationDestination(for: BatchResult.self) { result in
            BatchItemDetailView(
                result: result,
                photoURLs: [],
                artworkService: artworkService ?? PlaceholderArtworkService()
            )
        }
    }

    private func loadStatus() async {
        guard let catalogService else { return }
        isLoading = true
        errorMessage = nil
        do {
            status = try await catalogService.batchStatus(jobId: jobId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// Fallback artwork service that returns no artwork.
private struct PlaceholderArtworkService: ArtworkServiceProtocol {
    func fetchArtworkURL(artist: String, album: String) async throws -> URL? {
        nil
    }
}
