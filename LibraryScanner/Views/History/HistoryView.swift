//
//  HistoryView.swift
//  LibraryScanner
//
//  Browse past batch scan jobs. Fetches job summaries from the
//  Backend-Service and displays them in a list with status badges.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import CatalogClient

/// Lists past batch scan jobs with status, item count, and date.
struct HistoryView: View {
    @Environment(\.catalogService) private var catalogService

    @State private var jobs: [BatchJobSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && jobs.isEmpty {
                    ProgressView("Loading jobs...")
                } else if let errorMessage, jobs.isEmpty {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if jobs.isEmpty {
                    ContentUnavailableView(
                        "No Scan History",
                        systemImage: "clock",
                        description: Text("Completed batch scans will appear here.")
                    )
                } else {
                    jobList
                }
            }
            .navigationTitle("History")
            .task {
                await loadJobs()
            }
            .refreshable {
                await loadJobs()
            }
        }
    }

    private var jobList: some View {
        List(jobs) { job in
            NavigationLink(value: job) {
                HistoryJobRow(job: job)
            }
        }
        .navigationDestination(for: BatchJobSummary.self) { job in
            HistoryJobDetailView(jobId: job.jobId)
        }
    }

    private func loadJobs() async {
        guard let catalogService else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await catalogService.listBatchJobs(limit: 50, offset: 0)
            jobs = result.jobs
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Job Row

private struct HistoryJobRow: View {
    let job: BatchJobSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formattedDate)
                    .font(.headline)
                Spacer()
                JobStatusBadge(status: job.status)
            }

            HStack(spacing: 16) {
                Label("\(job.totalItems) items", systemImage: "square.stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if job.completedItems > 0 {
                    Label("\(job.completedItems) done", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if job.failedItems > 0 {
                    Label("\(job.failedItems) failed", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: job.createdAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: job.createdAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return job.createdAt
    }
}

// MARK: - Status Badge

private struct JobStatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(.capsule)
    }

    private var statusColor: Color {
        switch status {
        case "completed": .green
        case "failed": .red
        case "processing": .blue
        default: .secondary
        }
    }
}
