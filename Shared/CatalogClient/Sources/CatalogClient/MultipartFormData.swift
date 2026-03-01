//
//  MultipartFormData.swift
//  CatalogClient
//
//  Value type for building multipart/form-data request bodies used by
//  the scan upload endpoint.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// Builds a multipart/form-data request body.
struct MultipartFormData: Sendable {
    let boundary: String

    private var parts: [Part] = []

    init() {
        boundary = "Boundary-\(UUID().uuidString)"
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        parts.append(.file(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    var body: Data {
        var data = Data()
        let crlf = "\r\n"

        for part in parts {
            data.append("--\(boundary)\(crlf)")

            switch part {
            case .field(let name, let value):
                data.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)")
                data.append(crlf)
                data.append(value)
                data.append(crlf)

            case .file(let name, let filename, let mimeType, let fileData):
                data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(crlf)")
                data.append("Content-Type: \(mimeType)\(crlf)")
                data.append(crlf)
                data.append(fileData)
                data.append(crlf)
            }
        }

        data.append("--\(boundary)--\(crlf)")
        return data
    }
}

// MARK: - Private

private enum Part: Sendable {
    case field(name: String, value: String)
    case file(name: String, filename: String, mimeType: String, data: Data)
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
