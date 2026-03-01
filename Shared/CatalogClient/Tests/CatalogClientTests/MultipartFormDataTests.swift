//
//  MultipartFormDataTests.swift
//  CatalogClient
//
//  Tests for multipart form data builder used by scan upload.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
import Foundation
@testable import CatalogClient

@Suite("MultipartFormData")
struct MultipartFormDataTests {
    @Test("Content type includes boundary")
    func contentTypeIncludesBoundary() {
        let form = MultipartFormData()
        #expect(form.contentType.hasPrefix("multipart/form-data; boundary="))
        #expect(form.contentType.count > "multipart/form-data; boundary=".count)
    }

    @Test("Body contains text field with correct headers")
    func bodyContainsTextField() throws {
        var form = MultipartFormData()
        form.addField(name: "sticker_text", value: "ROCK AB 01/05")

        let body = form.body
        let bodyString = String(data: body, encoding: .utf8)!

        #expect(bodyString.contains("Content-Disposition: form-data; name=\"sticker_text\""))
        #expect(bodyString.contains("ROCK AB 01/05"))
    }

    @Test("Body contains file data with correct headers")
    func bodyContainsFileData() throws {
        var form = MultipartFormData()
        let imageData = Data("HEIC-DATA".utf8)
        form.addFile(name: "images", filename: "photo.heic", mimeType: "image/heic", data: imageData)

        let body = form.body
        let bodyString = String(data: body, encoding: .utf8)!

        #expect(bodyString.contains("Content-Disposition: form-data; name=\"images\"; filename=\"photo.heic\""))
        #expect(bodyString.contains("Content-Type: image/heic"))
        #expect(bodyString.contains("HEIC-DATA"))
        #expect(body.count > imageData.count)
    }

    @Test("Multiple fields and files produce valid body")
    func multipleFieldsAndFiles() throws {
        var form = MultipartFormData()
        form.addField(name: "catalog_item_id", value: "42")
        form.addField(name: "sticker_text", value: "JAZZ TM 03/02")
        form.addFile(name: "images", filename: "front.heic", mimeType: "image/heic", data: Data([0x01, 0x02]))
        form.addFile(name: "images", filename: "back.heic", mimeType: "image/heic", data: Data([0x03, 0x04]))

        let body = form.body
        let bodyString = String(data: body, encoding: .utf8)!
        let boundary = form.boundary

        // Should have opening boundary for each part + closing boundary
        let boundaryCount = bodyString.components(separatedBy: "--\(boundary)").count - 1
        #expect(boundaryCount == 5) // 4 parts + 1 closing

        #expect(bodyString.contains("catalog_item_id"))
        #expect(bodyString.contains("JAZZ TM 03/02"))
        #expect(bodyString.contains("front.heic"))
        #expect(bodyString.contains("back.heic"))
    }

    @Test("Body ends with closing boundary")
    func bodyEndsWithClosingBoundary() {
        var form = MultipartFormData()
        form.addField(name: "test", value: "value")

        let body = form.body
        let bodyString = String(data: body, encoding: .utf8)!
        let boundary = form.boundary

        #expect(bodyString.hasSuffix("--\(boundary)--\r\n"))
    }
}
