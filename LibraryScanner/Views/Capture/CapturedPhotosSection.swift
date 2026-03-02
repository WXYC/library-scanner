//
//  CapturedPhotosSection.swift
//  LibraryScanner
//
//  Horizontal scroll of captured photo thumbnails with tap-to-expand
//  full-screen presentation. Loads photos from local file URLs.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import UIKit

/// Horizontal scroll of captured photo thumbnails. Tap a photo to
/// view it full-screen in a sheet.
struct CapturedPhotosSection: View {
    let photoURLs: [URL]

    @State private var selectedPhotoURL: IdentifiableURL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured Photos")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(photoURLs, id: \.self) { url in
                        PhotoThumbnail(url: url)
                            .onTapGesture {
                                selectedPhotoURL = IdentifiableURL(url: url)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selectedPhotoURL) { item in
            FullScreenPhotoView(url: item.url)
        }
    }
}

// MARK: - Identifiable URL Wrapper

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnail: View {
    let url: URL

    var body: some View {
        Group {
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 80)
                    .background(.fill.quaternary)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Full-Screen Photo

private struct FullScreenPhotoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "photo",
                        description: Text("The photo could not be loaded.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
