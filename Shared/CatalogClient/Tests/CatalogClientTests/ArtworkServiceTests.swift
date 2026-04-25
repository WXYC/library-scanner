//
//  ArtworkServiceTests.swift
//  CatalogClient
//
//  Tests for ArtworkService using MockURLProtocol to verify request
//  format and response parsing for lookup-based artwork fetching.
//
//  Created by Jake on 03/01/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import CatalogClient

@Suite("ArtworkService", .serialized)
struct ArtworkServiceTests {
    @Test("fetchArtworkURL sends single POST to /api/v1/lookup")
    func sendsLookupRequest() async throws {
        let (service, mock) = makeArtworkServiceWithMock()
        var requestCount = 0

        mock.handler = { request in
            requestCount += 1
            #expect(request.httpMethod == "POST")
            #expect(request.url!.path.hasSuffix("/api/v1/lookup"))
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
            #expect(contentType == "application/json")

            if let bodyData = request.bodyData {
                let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
                #expect(body["artist"] as? String == "Stereolab")
                #expect(body["album"] as? String == "Aluminum Tunes")
                #expect(body["raw_message"] as? String == "Stereolab - Aluminum Tunes")
            }

            return (lookupResponseJSON(artworkURL: "https://img.discogs.com/abc/600x600.jpg"), 200)
        }

        let url = try await service.fetchArtworkURL(artist: "Stereolab", album: "Aluminum Tunes")
        #expect(requestCount == 1)
        #expect(url == URL(string: "https://img.discogs.com/abc/600x600.jpg"))
    }

    @Test("fetchArtworkURL returns artwork URL from lookup response")
    func returnsArtworkURL() async throws {
        let (service, mock) = makeArtworkServiceWithMock()

        mock.handler = { _ in
            return (lookupResponseJSON(artworkURL: "https://img.discogs.com/highres/600x600.jpg"), 200)
        }

        let url = try await service.fetchArtworkURL(artist: "Cat Power", album: "Moon Pix")
        #expect(url?.absoluteString == "https://img.discogs.com/highres/600x600.jpg")
    }

    @Test("fetchArtworkURL returns nil when no results")
    func nilWhenNoResults() async throws {
        let (service, mock) = makeArtworkServiceWithMock()
        var requestCount = 0

        mock.handler = { _ in
            requestCount += 1
            return (emptyLookupResponseJSON(), 200)
        }

        let url = try await service.fetchArtworkURL(artist: "Unknown", album: "Nobody")
        #expect(url == nil)
        #expect(requestCount == 1)
    }

    @Test("fetchArtworkURL returns nil when artwork is nil")
    func nilWhenNoArtwork() async throws {
        let (service, mock) = makeArtworkServiceWithMock()

        mock.handler = { _ in
            return (lookupResponseJSON(artworkURL: nil), 200)
        }

        let url = try await service.fetchArtworkURL(artist: "Jessica Pratt", album: "On Your Own Love Again")
        #expect(url == nil)
    }

    @Test("fetchArtworkURL returns nil when result has no artwork object")
    func nilWhenNoArtworkObject() async throws {
        let (service, mock) = makeArtworkServiceWithMock()

        mock.handler = { _ in
            return (lookupResponseWithoutArtworkJSON(), 200)
        }

        let url = try await service.fetchArtworkURL(artist: "Juana Molina", album: "DOGA")
        #expect(url == nil)
    }

    @Test("fetchArtworkURL throws on network error")
    func throwsOnNetworkError() async {
        let (service, mock) = makeArtworkServiceWithMock()
        mock.handler = nil

        await #expect(throws: CatalogError.self) {
            _ = try await service.fetchArtworkURL(artist: "Autechre", album: "Confield")
        }
    }

    @Test("fetchArtworkURL throws on server error")
    func throwsOnServerError() async {
        let (service, mock) = makeArtworkServiceWithMock()

        mock.handler = { _ in
            return ("Service Unavailable".data(using: .utf8)!, 503)
        }

        do {
            _ = try await service.fetchArtworkURL(artist: "Autechre", album: "Confield")
            Issue.record("Expected error to be thrown")
        } catch let error as CatalogError {
            if case .serverError(let code, _) = error {
                #expect(code == 503)
            } else {
                Issue.record("Expected serverError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Test Helpers

private func makeArtworkServiceWithMock() -> (ArtworkService, MockArtworkURLProtocol) {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockArtworkURLProtocol.self]
    let session = URLSession(configuration: config)

    let service = ArtworkService(
        session: session,
        baseURL: "http://test.local"
    )

    return (service, MockArtworkURLProtocol.shared)
}

private func lookupResponseJSON(artworkURL: String?) -> Data {
    let artworkField: String
    if let artworkURL {
        artworkField = """
        {
                        "release_id": 123,
                        "release_url": "https://www.discogs.com/release/123",
                        "artwork_url": "\(artworkURL)"
                    }
        """
    } else {
        artworkField = """
        {
                        "release_id": 123,
                        "release_url": "https://www.discogs.com/release/123",
                        "artwork_url": null
                    }
        """
    }
    return """
    {
        "results": [
            {
                "library_item": {
                    "id": 1,
                    "call_number": "R-12345",
                    "library_url": "http://wxyc.info/catalog/12345"
                },
                "artwork": \(artworkField)
            }
        ],
        "search_type": "direct"
    }
    """.data(using: .utf8)!
}

private func emptyLookupResponseJSON() -> Data {
    """
    {
        "results": [],
        "search_type": "none"
    }
    """.data(using: .utf8)!
}

private func lookupResponseWithoutArtworkJSON() -> Data {
    """
    {
        "results": [
            {
                "library_item": {
                    "id": 1,
                    "call_number": "R-12345",
                    "library_url": "http://wxyc.info/catalog/12345"
                }
            }
        ],
        "search_type": "direct"
    }
    """.data(using: .utf8)!
}

// MARK: - URLRequest Body Helper

private extension URLRequest {
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

// MARK: - Mock

private final class MockArtworkURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static let shared = MockArtworkURLProtocol()

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
        guard let handler = MockArtworkURLProtocol.shared.handler else {
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
