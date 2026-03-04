//
//  AlbumDisplayViews.swift
//  LibraryScanner
//
//  Shared view components for displaying album artwork, info, and
//  extraction results. Used by capture, review, and history views.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient
import ScannerUI

// MARK: - Artwork

/// Displays album artwork from an async URL, or a placeholder if unavailable.
struct ArtworkSection: View {
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

struct ArtworkPlaceholder: View {
    var body: some View {
        Image(systemName: "music.note")
            .font(.system(size: 60))
            .foregroundStyle(.secondary)
            .frame(width: 200, height: 200)
            .background(.fill.quaternary)
            .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Album Info

/// Displays matched album details with artist, title, library code, and catalog info.
struct AlbumInfoSection: View {
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

// MARK: - Extraction Fields

/// Displays non-nil extraction fields with confidence indicators.
struct ExtractionFieldsView: View {
    let extraction: ExtractionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artist = extraction.artistName {
                ExtractionRow(name: "Artist", field: artist)
            }
            if let album = extraction.albumTitle {
                ExtractionRow(name: "Album", field: album)
            }
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

// MARK: - Matched Album

/// Displays matched album details in a compact card format.
struct MatchedAlbumView: View {
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
