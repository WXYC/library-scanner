//
//  BatchItemStrip.swift
//  LibraryScanner
//
//  Horizontal strip showing captured batch items as numbered circles
//  with photo counts. Provides visual confirmation of capture progress.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit

/// A horizontal scroll view displaying each batch item as a numbered
/// circle with the photo count underneath.
struct BatchItemStrip: View {
    let items: [BatchItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    BatchItemBadge(index: index + 1, photoCount: item.photos.count)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

/// A single item badge showing the item number and photo count.
private struct BatchItemBadge: View {
    let index: Int
    let photoCount: Int

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(photoCount > 0 ? .blue : .gray.opacity(0.5))
                    .frame(width: 36, height: 36)
                Text("\(index)")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
            }
            Text("\(photoCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
