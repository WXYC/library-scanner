//
//  PhotoStorageTests.swift
//  ScannerKit
//
//  Tests for PhotoStorage file-system implementation. Uses a temp
//  directory to verify save, load, and cleanup operations.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import ScannerKit

@Suite("PhotoStorage")
struct PhotoStorageTests {
    @Test("save writes file to expected path")
    func saveWritesFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)
        let batchItemId = UUID()
        let data = Data("test-photo-data".utf8)

        let url = try await storage.save(data: data, batchItemId: batchItemId, photoIndex: 0)

        let expected = tempDir
            .appendingPathComponent("BatchPhotos")
            .appendingPathComponent(batchItemId.uuidString)
            .appendingPathComponent("0.heic")
        #expect(url == expected)
        let savedData = try Data(contentsOf: url)
        #expect(savedData == data)

        try FileManager.default.removeItem(at: tempDir)
    }

    @Test("save creates subdirectories")
    func saveCreatesSubdirectories() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)
        let batchItemId = UUID()

        _ = try await storage.save(data: Data([0x01]), batchItemId: batchItemId, photoIndex: 0)

        let batchDir = tempDir
            .appendingPathComponent("BatchPhotos")
            .appendingPathComponent(batchItemId.uuidString)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: batchDir.path(), isDirectory: &isDir))
        #expect(isDir.boolValue)

        try FileManager.default.removeItem(at: tempDir)
    }

    @Test("photoURLs returns saved files in order")
    func photoURLsReturnsSorted() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)
        let batchItemId = UUID()

        _ = try await storage.save(data: Data([0x01]), batchItemId: batchItemId, photoIndex: 2)
        _ = try await storage.save(data: Data([0x02]), batchItemId: batchItemId, photoIndex: 0)
        _ = try await storage.save(data: Data([0x03]), batchItemId: batchItemId, photoIndex: 1)

        let urls = try await storage.photoURLs(for: batchItemId)
        #expect(urls.count == 3)
        #expect(urls[0].lastPathComponent == "0.heic")
        #expect(urls[1].lastPathComponent == "1.heic")
        #expect(urls[2].lastPathComponent == "2.heic")

        try FileManager.default.removeItem(at: tempDir)
    }

    @Test("photoURLs returns empty for unknown batchItemId")
    func photoURLsEmptyForUnknown() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)

        let urls = try await storage.photoURLs(for: UUID())
        #expect(urls.isEmpty)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("deleteAll removes all batch photo directories")
    func deleteAllCleansUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)

        _ = try await storage.save(data: Data([0x01]), batchItemId: UUID(), photoIndex: 0)
        _ = try await storage.save(data: Data([0x02]), batchItemId: UUID(), photoIndex: 0)

        try await storage.deleteAll()

        let batchPhotosDir = tempDir.appendingPathComponent("BatchPhotos")
        let contents = try? FileManager.default.contentsOfDirectory(atPath: batchPhotosDir.path())
        #expect(contents?.isEmpty ?? true)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("save with same index overwrites")
    func saveOverwrites() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FilePhotoStorage(rootDirectory: tempDir)
        let batchItemId = UUID()
        let original = Data("original".utf8)
        let replacement = Data("replacement".utf8)

        let url1 = try await storage.save(data: original, batchItemId: batchItemId, photoIndex: 0)
        let url2 = try await storage.save(data: replacement, batchItemId: batchItemId, photoIndex: 0)

        #expect(url1 == url2)
        let savedData = try Data(contentsOf: url2)
        #expect(savedData == replacement)

        try FileManager.default.removeItem(at: tempDir)
    }
}
