//
//  PhotoImportView.swift
//  LibraryScanner
//
//  Sequential photo assignment view for library imports. Shows imported
//  photos one at a time for the user to assign to batch items.
//
//  Created by Jake on 03/03/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit

/// Steps through imported photos one at a time, letting the user assign
/// each to the current batch item or start a new item group.
struct PhotoImportView: View {
    @Environment(\.scanSessionManager) private var sessionManager
    @State private var isProcessing = false
    @State private var previewImage: UIImage?

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
            await loadPreviewImage()
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
                Text("Photo \(manager.importIndex + 1) of \(manager.importQueue.count)")
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
                    guard !isProcessing else { return }
                    isProcessing = true
                    Task {
                        _ = await manager?.assignCurrentImportPhoto()
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
                .disabled(isProcessing || queueDone)

                Button {
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
                    manager?.resetBatch()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Submit Batch") {
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

    func loadPreviewImage() async {
        guard let data = manager?.currentImportPhoto else {
            previewImage = nil
            return
        }
        previewImage = UIImage(data: data)
    }
}
