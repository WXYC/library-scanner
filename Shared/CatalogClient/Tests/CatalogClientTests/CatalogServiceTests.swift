//
//  CatalogServiceTests.swift
//  CatalogClient
//
//  Tests for CatalogServiceImpl using MockURLProtocol to intercept
//  network requests and verify correct endpoint mapping.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
import AuthKit
@testable import CatalogClient

@Suite("CatalogService", .serialized)
struct CatalogServiceTests {
    @Test("lookupByCode sends GET with code query params and Bearer header")
    func lookupByCode() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            #expect(request.httpMethod == "GET")
            let url = request.url!
            #expect(url.path.hasSuffix("/library"))
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let params = Dictionary(
                uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) }
            )
            #expect(params["code_letters"] == "RH")
            #expect(params["code_artist_number"] == "01")
            #expect(params["code_number"] == "3")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

            let json = """
            [{
                "id": 42,
                "artist_name": "Radiohead",
                "album_title": "OK Computer",
                "code_letters": "RH",
                "code_artist_number": 1,
                "code_number": 3,
                "genre_name": "ROCK",
                "format_name": "CD",
                "label": "Parlophone"
            }]
            """
            return (json.data(using: .utf8)!, 200)
        }

        let items = try await service.lookupByCode(
            codeLetters: "RH",
            codeArtistNumber: "01",
            codeNumber: 3
        )
        #expect(items.count == 1)
        #expect(items[0].artistName == "Radiohead")
        #expect(items[0].codeNumber == 3)
    }

    @Test("lookupByCode with nil codeNumber omits it from query")
    func lookupByCodeNilNumber() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let paramNames = components.queryItems!.map(\.name)
            #expect(!paramNames.contains("code_number"))
            return ("[]".data(using: .utf8)!, 200)
        }

        let items = try await service.lookupByCode(
            codeLetters: "AB",
            codeArtistNumber: "01",
            codeNumber: nil
        )
        #expect(items.isEmpty)
    }

    @Test("lookupByCode 401 throws unauthorized")
    func lookupByCodeUnauthorized() async {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { _ in
            return ("Unauthorized".data(using: .utf8)!, 401)
        }

        await #expect(throws: CatalogError.unauthorized) {
            try await service.lookupByCode(codeLetters: "AB", codeArtistNumber: "01", codeNumber: nil)
        }
    }

    @Test("search sends GET with artist and title params")
    func search() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            #expect(request.httpMethod == "GET")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let params = Dictionary(
                uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) }
            )
            #expect(params["artist_name"] == "Radiohead")
            #expect(params["album_title"] == "OK Computer")
            #expect(params["n"] == "10")

            return ("[]".data(using: .utf8)!, 200)
        }

        let items = try await service.search(artist: "Radiohead", title: "OK Computer", limit: 10)
        #expect(items.isEmpty)
    }

    @Test("search omits nil params")
    func searchNilParams() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let paramNames = components.queryItems!.map(\.name)
            #expect(!paramNames.contains("artist_name"))
            #expect(paramNames.contains("album_title"))
            #expect(paramNames.contains("n"))
            return ("[]".data(using: .utf8)!, 200)
        }

        _ = try await service.search(artist: nil, title: "OK Computer", limit: 5)
    }

    @Test("submitScan sends POST multipart and returns ExtractionResult")
    func submitScan() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url!.path.hasSuffix("/library/scan"))
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data; boundary="))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

            let json = """
            {
                "extraction": {
                    "labelName": {"value": "Elektra", "confidence": 0.95},
                    "catalogNumber": {"value": "9 60774-2", "confidence": 0.88},
                    "reviewText": null,
                    "upc": null
                },
                "matchedAlbumId": 42
            }
            """
            return (json.data(using: .utf8)!, 200)
        }

        let result = try await service.submitScan(
            images: [Data([0x01])],
            photoTypes: ["front"],
            catalogItemId: 42,
            stickerText: "ROCK RH 01/03",
            detectedUPC: nil
        )
        #expect(result.labelName?.value == "Elektra")
        #expect(result.labelName?.confidence == 0.95)
        #expect(result.catalogNumber?.value == "9 60774-2")
        #expect(result.reviewText == nil)
    }

    @Test("updateAlbum sends PATCH with JSON body")
    func updateAlbum() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.path.hasSuffix("/library"))
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            if let bodyData = request.bodyData {
                let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
                #expect(body["album_id"] as? Int == 42)
                #expect(body["label"] as? String == "Parlophone")
                #expect(body["album_title"] as? String == nil)
            }

            return (Data(), 200)
        }

        try await service.updateAlbum(albumId: 42, label: "Parlophone", albumTitle: nil)
    }

    @Test("upsertReview sends PUT with JSON body")
    func upsertReview() async throws {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url!.path.hasSuffix("/library/reviews"))
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            if let bodyData = request.bodyData {
                let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
                #expect(body["album_id"] as? Int == 42)
                #expect(body["review"] as? String == "Great album")
                #expect(body["author"] as? String == "DJ Test")
            }

            return (Data(), 200)
        }

        try await service.upsertReview(albumId: 42, review: "Great album", author: "DJ Test")
    }

    @Test("submitBatch throws badRequest (not yet implemented)")
    func submitBatchNotImplemented() async {
        let (service, _) = makeServiceWithMock()

        await #expect(throws: CatalogError.badRequest("Not yet implemented")) {
            try await service.submitBatch(images: [], photoTypes: [])
        }
    }

    @Test("batchStatus throws badRequest (not yet implemented)")
    func batchStatusNotImplemented() async {
        let (service, _) = makeServiceWithMock()

        await #expect(throws: CatalogError.badRequest("Not yet implemented")) {
            try await service.batchStatus(jobId: "test-job")
        }
    }

    @Test("Server 404 throws notFound")
    func serverNotFoundError() async {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { _ in
            return ("Not Found".data(using: .utf8)!, 404)
        }

        await #expect(throws: CatalogError.notFound) {
            try await service.lookupByCode(codeLetters: "XX", codeArtistNumber: "99", codeNumber: 1)
        }
    }

    @Test("Server 500 throws serverError")
    func serverInternalError() async {
        let (service, mock) = makeServiceWithMock()

        mock.handler = { _ in
            return ("Internal Server Error".data(using: .utf8)!, 500)
        }

        do {
            _ = try await service.lookupByCode(codeLetters: "AB", codeArtistNumber: "01", codeNumber: 1)
            Issue.record("Expected serverError to be thrown")
        } catch let error as CatalogError {
            if case .serverError(let code, _) = error {
                #expect(code == 500)
            } else {
                Issue.record("Expected serverError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Test Helpers

private func makeServiceWithMock() -> (CatalogService, MockURLProtocol) {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let service = CatalogService(
        session: session,
        baseURL: "http://test.local",
        tokenProvider: MockTokenProvider()
    )

    return (service, MockURLProtocol.shared)
}

// MARK: - URLRequest Body Helper

private extension URLRequest {
    /// Reads the body data from either httpBody or httpBodyStream.
    /// URLSession may convert httpBody to httpBodyStream during transmission.
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        return data.isEmpty ? nil : data
    }
}

// MARK: - Mocks

private struct MockTokenProvider: TokenProvider {
    func validAccessToken() async throws -> String {
        "test-token"
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static let shared = MockURLProtocol()

    nonisolated(unsafe) var handler: ((URLRequest) -> (Data, Int))?

    private init() {
        super.init(request: URLRequest(url: URL(string: "http://unused")!), cachedResponse: nil, client: nil)
    }

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.shared.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (data, statusCode) = handler(request)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
