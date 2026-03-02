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

// MARK: - Artwork Section

private struct ArtworkSection: View {
    let artworkURL: URL?

    var body: some View {
        if let artworkURL {
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                case .failure:
                    ArtworkPlaceholder()
                case .empty:
                    ProgressView()
                        .frame(width: 200, height: 200)
                @unknown default:
                    ArtworkPlaceholder()
                }
            }
            .frame(maxWidth: 200, maxHeight: 200)
        } else {
            ArtworkPlaceholder()
        }
    }
}

private struct ArtworkPlaceholder: View {
    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 60))
            .foregroundStyle(.secondary)
            .frame(width: 200, height: 200)
            .background(.fill.quaternary)
            .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Album Info Section

private struct AlbumInfoSection: View {
    let album: MatchedAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(album.artistName)
                .font(.headline)
            Text(album.albumTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("Library Code", value: album.libraryCode)
            LabeledContent("Format", value: album.formatName)
            LabeledContent("Genre", value: album.genreName)
            if let label = album.label {
                LabeledContent("Label", value: label)
            }
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
    }
}
