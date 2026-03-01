//
//  CatalogError.swift
//  CatalogClient
//
//  Errors that can occur during catalog API operations.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Foundation

/// Errors from catalog API operations.
public enum CatalogError: Error, Sendable, Equatable {
    case unauthorized
    case badRequest(String)
    case notFound
    case serverError(Int, String)
    case networkError(String)
    case decodingError(String)
}
