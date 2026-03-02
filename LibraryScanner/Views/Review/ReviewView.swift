//
//  ReviewView.swift
//  LibraryScanner
//
//  Root view for the Review tab. Shows results from the most recent
//  completed batch for editing and saving metadata.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import ScannerKit
import CatalogClient

/// Root view for the Review tab. Displays editable results when a
/// batch is completed, or an empty state otherwise.
struct ReviewView: View {
    @Environment(\.scanSessionManager) private var sessionManager
    @Environment(\.catalogService) private var catalogService
    @Environment(\.artworkService) private var artworkService

    var body: some View {
        NavigationStack {
            Group {
                if let manager = sessionManager,
                   case .completed(let status) = manager.batchPhase,
                   let results = status.results, !results.isEmpty {
                    ReviewListView(
                        results: results,
                        artworkService: artworkService,
                        catalogService: catalogService
                    )
                } else {
                    ContentUnavailableView(
                        "No Results to Review",
                        systemImage: "checklist",
                        description: Text("Complete a batch scan to review results here.")
                    )
                }
            }
            .navigationTitle("Review")
        }
    }
}
