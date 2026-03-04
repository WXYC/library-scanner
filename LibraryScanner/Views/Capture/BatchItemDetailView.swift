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

    /// Artist name from matched album or extraction.
    private var artistName: String? {
        result.matchedAlbum?.artistName ?? result.extraction?.artistName?.value
    }

    /// Album title from matched album or extraction.
    private var albumTitle: String? {
        result.matchedAlbum?.albumTitle ?? result.extraction?.albumTitle?.value
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkSection(artworkURL: artworkURL)

                if let artistName {
                    VStack(spacing: 4) {
                        Text(artistName)
                            .font(.title3)
                            .bold()
                        if let albumTitle {
                            Text(albumTitle)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let album = result.matchedAlbum {
                    AlbumInfoSection(album: album)
                }

                if let extraction = result.extraction {
                    ExtractionFieldsView(extraction: extraction)
                        .padding(.horizontal)
                }

                LinksSection(
                    artistName: artistName,
                    albumTitle: albumTitle,
                    matchedAlbumId: result.matchedAlbumId
                )

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
        guard let artistName, let albumTitle else { return }
        do {
            artworkURL = try await artworkService.fetchArtworkURL(
                artist: artistName,
                album: albumTitle
            )
        } catch {
            // Artwork is supplementary; don't show errors for it
        }
    }
}

// MARK: - Links Section

private struct LinksSection: View {
    let artistName: String?
    let albumTitle: String?
    let matchedAlbumId: Int?

    var body: some View {
        let hasLinks = discogsURL != nil || catalogURL != nil
        if hasLinks {
            VStack(spacing: 12) {
                if let url = discogsURL {
                    Link(destination: url) {
                        Label("Search on Discogs", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let url = catalogURL {
                    Link(destination: url) {
                        Label("View in Card Catalog", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
    }

    private var discogsURL: URL? {
        guard let artistName, let albumTitle else { return nil }
        let query = "\(artistName) \(albumTitle)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.discogs.com/search?q=\(query)&type=release")
    }

    private var catalogURL: URL? {
        guard let matchedAlbumId else { return nil }
        return URL(string: "https://dj.wxyc.org/catalog/\(matchedAlbumId)")
    }
}
