//
//  ReviewItemView.swift
//  LibraryScanner
//
//  Editable detail view for a single batch result. DJs can edit the
//  label name and review text, then save changes to the catalog.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient
import ScannerUI

/// Editable detail view for reviewing and saving extracted metadata.
struct ReviewItemView: View {
    let result: BatchResult
    let artworkService: (any ArtworkServiceProtocol)?
    let catalogService: (any CatalogServiceProtocol)?
    let onSaved: () -> Void

    @State private var artworkURL: URL?
    @State private var labelText: String = ""
    @State private var reviewText: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkSection(artworkURL: artworkURL)

                if let album = result.matchedAlbum {
                    AlbumInfoSection(album: album)
                } else {
                    noMatchMessage
                }

                if let extraction = result.extraction {
                    editableFieldsSection(extraction)
                }

                if result.matchedAlbum != nil, result.extraction != nil {
                    saveSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Item \(result.itemIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            setUpInitialValues()
            await loadArtwork()
        }
    }

    // MARK: - No Match Message

    private var noMatchMessage: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Catalog Match")
                .font(.headline)
            Text("This item cannot be saved without a matched album in the catalog.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Editable Fields

    private func editableFieldsSection(_ extraction: ExtractionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let labelField = extraction.labelName {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ConfidenceBadge(confidence: labelField.confidence)
                    }
                    TextField("Label name", text: $labelText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let reviewField = extraction.reviewText {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ConfidenceBadge(confidence: reviewField.confidence)
                    }
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        )
                }
            }

            if let catalog = extraction.catalogNumber {
                ExtractionRow(name: "Catalog #", field: catalog)
            }
            if let upc = extraction.upc {
                ExtractionRow(name: "UPC", field: upc)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Save Section

    private var saveSection: some View {
        VStack(spacing: 12) {
            if isSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save to Catalog")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSaving)
            }

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func setUpInitialValues() {
        labelText = result.extraction?.labelName?.value ?? ""
        reviewText = result.extraction?.reviewText?.value ?? ""
    }

    private func loadArtwork() async {
        guard let album = result.matchedAlbum, let artworkService else { return }
        do {
            artworkURL = try await artworkService.fetchArtworkURL(
                artist: album.artistName,
                album: album.albumTitle
            )
        } catch {
            // Artwork is supplementary; don't show errors for it
        }
    }

    private func save() async {
        guard let catalogService, let albumId = result.matchedAlbumId else { return }
        isSaving = true
        saveError = nil
        do {
            if !labelText.isEmpty {
                try await catalogService.updateAlbum(albumId: albumId, label: labelText, albumTitle: nil)
            }
            if !reviewText.isEmpty {
                try await catalogService.upsertReview(albumId: albumId, review: reviewText, author: nil)
            }
            isSaved = true
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
