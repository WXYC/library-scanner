//
//  BatchItemDetailView.swift
//  LibraryScanner
//
//  Detail screen for a single batch result. Shows album artwork from
//  Discogs, matched album info, extraction results, and captured photos.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient

/// Full-screen detail view for a single scanned batch item.
struct BatchItemDetailView: View {
    let result: BatchResult
    let photoURLs: [URL]
    let artworkService: any ArtworkServiceProtocol

    @State private var artworkURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkSection(artworkURL: artworkURL)

                if let album = result.matchedAlbum {
                    AlbumInfoSection(album: album)
                }

                if let extraction = result.extraction {
                    ExtractionFieldsView(extraction: extraction)
                        .padding(.horizontal)
                }

                if !photoURLs.isEmpty {
                    CapturedPhotosSection(photoURLs: photoURLs)
                }

                if let error = result.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Item \(result.itemIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        guard let album = result.matchedAlbum else { return }
        do {
            artworkURL = try await artworkService.fetchArtworkURL(
                artist: album.artistName,
                album: album.albumTitle
            )
        } catch {
            // Artwork is supplementary; don't show errors for it
        }
    }
}
