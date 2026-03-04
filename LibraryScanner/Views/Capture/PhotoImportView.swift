//
//  PhotoImportView.swift
//  LibraryScanner
//
//  Sequential photo assignment view for library imports. Shows imported
//  photos one at a time for the user to assign to batch items. Photos
//  are loaded lazily from PhotosPickerItem references to avoid holding
//  all images in memory at once.
//
//  Created by Jake on 03/03/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import PhotosUI
import SwiftUI
import ScannerKit

/// Steps through imported photos one at a time, letting the user assign
/// each to the current batch item or start a new item group.
///
/// Photos are loaded lazily: only the current photo is in memory at any
/// time. Raw data from `PhotosPickerItem` is passed directly to
/// `ScanSessionManager.assignImportPhoto(data:)` which handles HEIF
/// conversion internally.
struct PhotoImportView: View {
    @Environment(\.scanSessionManager) private var sessionManager
    @Binding var items: [PhotosPickerItem]
    @State private var isProcessing = false
    @State private var previewImage: UIImage?
    @State private var currentPhotoData: Data?

    private var manager: ScanSessionManager? { sessionManager }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            Spacer()

            photoPreview

            Spacer()

            BatchItemStrip(items: manager?.batchItems ?? [])

            bottomControls
        }
        .task(id: manager?.importIndex) {
            await loadCurrentPhoto()
        }
    }
}

// MARK: - Subviews

private extension PhotoImportView {
    var progressHeader: some View {
        HStack {
            Text("Item \(manager?.batchItems.count ?? 0)")
                .font(.subheadline)
                .bold()

            Spacer()

            if let manager, !manager.isImportQueueExhausted {
                Text("Photo \(manager.importIndex + 1) of \(manager.importQueueCount)")
                    .font(.subheadline)
            }

            Spacer()

            Text("\(manager?.currentBatchItem?.photos.count ?? 0) in item")
                .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    var photoPreview: some View {
        Group {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal)
            } else if manager?.isImportQueueExhausted == true {
                ContentUnavailableView(
                    "All Photos Reviewed",
                    systemImage: "checkmark.circle",
                    description: Text("Tap Submit Batch to process your records.")
                )
            } else {
                ProgressView("Loading photo\u{2026}")
            }
        }
    }

    var bottomControls: some View {
        let hasPhotos = (manager?.totalBatchPhotos ?? 0) > 0
        let queueDone = manager?.isImportQueueExhausted == true
        let atMaxItems = (manager?.batchItems.count ?? 0) >= ScanSessionManager.maxBatchItems
        let currentItemHasPhotos = (manager?.currentBatchItem?.photos.count ?? 0) > 0

        return VStack(spacing: 12) {
            HStack(spacing: 24) {
                Button {
                    manager?.finalizeCurrentItem()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("Next Item")
                            .font(.caption2)
                    }
                }
                .disabled(!currentItemHasPhotos || atMaxItems)

                Button {
                    guard !isProcessing, let data = currentPhotoData else { return }
                    isProcessing = true
                    Task {
                        _ = await manager?.assignImportPhoto(data: data)
                        currentPhotoData = nil
                        isProcessing = false
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                        Text("Add to Item")
                            .font(.caption2)
                    }
                }
                .disabled(isProcessing || queueDone || currentPhotoData == nil)

                Button {
                    currentPhotoData = nil
                    manager?.skipCurrentImportPhoto()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                        Text("Skip")
                            .font(.caption2)
                    }
                }
                .disabled(queueDone)
            }

            HStack {
                Button("Cancel") {
                    items = []
                    manager?.resetBatch()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Submit Batch") {
                    items = []
                    manager?.finishImport()
                    Task {
                        await manager?.submitBatch()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasPhotos)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    /// Load the current photo on demand from the PhotosPickerItem.
    /// Only one photo is in memory at a time.
    func loadCurrentPhoto() async {
        guard let manager, !manager.isImportQueueExhausted else {
            previewImage = nil
            currentPhotoData = nil
            return
        }

        let index = manager.importIndex
        guard index < items.count else {
            previewImage = nil
            currentPhotoData = nil
            return
        }

        let item = items[index]
        if let data = try? await item.loadTransferable(type: Data.self) {
            currentPhotoData = data
            previewImage = UIImage(data: data)
        } else {
            currentPhotoData = nil
            previewImage = nil
        }
    }
}
