//
//  ScannerLoggerTests.swift
//  ScannerLogger
//
//  Tests for the ScannerLogger categories, levels, and configuration.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import ScannerLogger

@Suite("ScannerLogger", .serialized)
struct ScannerLoggerTests {
    @Test("LogLevel ordering is correct")
    func logLevelOrdering() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
    }

    @Test("Category raw values are correct")
    func categoryRawValues() {
        #expect(Category.general.rawValue == "General")
        #expect(Category.auth.rawValue == "Auth")
        #expect(Category.camera.rawValue == "Camera")
        #expect(Category.barcode.rawValue == "Barcode")
        #expect(Category.network.rawValue == "Network")
        #expect(Category.scan.rawValue == "Scan")
        #expect(Category.catalog.rawValue == "Catalog")
    }

    @Test("LoggerConfiguration minimum level filtering")
    func minimumLevelFiltering() {
        let config = LoggerConfiguration.shared
        let originalLevel = config.minimumLevel

        config.minimumLevel = .warning
        #expect(config.minimumLevel == .warning)

        config.minimumLevel = .debug
        #expect(config.minimumLevel == .debug)

        config.minimumLevel = originalLevel
    }

    @Test("Log function does not crash with any category")
    func logDoesNotCrash() {
        Log(.debug, category: .general, "debug message")
        Log(.info, category: .auth, "info message")
        Log(.warning, category: .camera, "warning message")
        Log(.error, category: .network, "error message")
    }

    @Test("Custom categories work")
    func customCategories() {
        let custom = Category(rawValue: "CustomTest")
        #expect(custom.rawValue == "CustomTest")
        Log(.info, category: custom, "custom category message")
    }
}
