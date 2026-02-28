//
//  ScannerLogger.swift
//  ScannerLogger
//
//  Unified logging API wrapping os.Logger with scan-specific categories.
//  Provides a global Log function for consistent logging throughout the app.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import os
import Foundation

// MARK: - Log Level

/// Log severity levels, ordered from least to most severe.
public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        }
    }
}

// MARK: - Category

/// Type-safe log categories for filtering and organization.
public struct Category: Hashable, RawRepresentable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let general = Category(rawValue: "General")
    public static let auth = Category(rawValue: "Auth")
    public static let camera = Category(rawValue: "Camera")
    public static let barcode = Category(rawValue: "Barcode")
    public static let network = Category(rawValue: "Network")
    public static let scan = Category(rawValue: "Scan")
    public static let catalog = Category(rawValue: "Catalog")
}

// MARK: - Configuration

/// Global logger configuration. Thread-safe singleton.
public final class LoggerConfiguration: @unchecked Sendable {
    public static let shared = LoggerConfiguration()

    private let lock = NSLock()
    private var _minimumLevel: LogLevel = .debug

    public var minimumLevel: LogLevel {
        get { lock.withLock { _minimumLevel } }
        set { lock.withLock { _minimumLevel = newValue } }
    }

    private init() {}
}

// MARK: - Logger Cache

/// Caches os.Logger instances by category to avoid repeated allocation.
private final class OSLoggerCache: @unchecked Sendable {
    static let shared = OSLoggerCache()

    private let lock = NSLock()
    private var loggers: [Category: os.Logger] = [:]
    private let subsystem = Bundle.main.bundleIdentifier ?? "org.wxyc.library-scanner"

    func logger(for category: Category) -> os.Logger {
        lock.withLock {
            if let cached = loggers[category] {
                return cached
            }
            let logger = os.Logger(subsystem: subsystem, category: category.rawValue)
            loggers[category] = logger
            return logger
        }
    }
}

// MARK: - Global Log Function

/// Log a message with the specified level and category.
///
/// - Parameters:
///   - level: The severity level of the log message.
///   - category: The category for filtering (defaults to `.general`).
///   - message: The message to log.
public func Log(_ level: LogLevel, category: Category = .general, _ message: String) {
    guard level >= LoggerConfiguration.shared.minimumLevel else { return }
    let logger = OSLoggerCache.shared.logger(for: category)
    logger.log(level: level.osLogType, "\(message)")
}
