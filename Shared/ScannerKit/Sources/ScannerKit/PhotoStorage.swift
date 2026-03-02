//
//  PhotoStorage.swift
//  ScannerKit
//
//  Protocol and file-system implementation for persisting captured
//  photos to the Caches directory during batch capture sessions.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation
import ScannerLogger

/// Persists captured photo data to disk and retrieves file URLs.
public protocol PhotoStorageProtocol: Sendable {
    /// Save photo data for a batch item, returning the file URL.
    func save(data: Data, batchItemId: UUID, photoIndex: Int) async throws -> URL

    /// Return file URLs for all photos belonging to a batch item, sorted by index.
    func photoURLs(for batchItemId: UUID) async throws -> [URL]

    /// Delete all stored batch photos.
    func deleteAll() async throws
}

/// File-system backed photo storage writing to `{rootDirectory}/BatchPhotos/{batchItemId}/{index}.heic`.
public final class FilePhotoStorage: PhotoStorageProtocol, @unchecked Sendable {
    private let rootDirectory: URL

    /// - Parameter rootDirectory: The root directory for photo storage.
    ///   Defaults to the user's caches directory.
    public init(rootDirectory: URL? = nil) {
        self.rootDirectory = rootDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    public func save(data: Data, batchItemId: UUID, photoIndex: Int) async throws -> URL {
        let dir = batchItemDirectory(for: batchItemId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(photoIndex).heic")
        try data.write(to: fileURL, options: .atomic)
        Log(.debug, category: .scan, "Saved photo \(photoIndex) for batch item \(batchItemId)")
        return fileURL
    }

    public func photoURLs(for batchItemId: UUID) async throws -> [URL] {
        let dir = batchItemDirectory(for: batchItemId)
        guard FileManager.default.fileExists(atPath: dir.path()) else {
            return []
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "heic" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func deleteAll() async throws {
        let batchPhotosDir = rootDirectory.appendingPathComponent("BatchPhotos")
        guard FileManager.default.fileExists(atPath: batchPhotosDir.path()) else { return }
        let contents = try FileManager.default.contentsOfDirectory(
            at: batchPhotosDir,
            includingPropertiesForKeys: nil
        )
        for item in contents {
            try FileManager.default.removeItem(at: item)
        }
        Log(.info, category: .scan, "Deleted all batch photos")
    }

    private func batchItemDirectory(for batchItemId: UUID) -> URL {
        rootDirectory
            .appendingPathComponent("BatchPhotos")
            .appendingPathComponent(batchItemId.uuidString)
    }
}
