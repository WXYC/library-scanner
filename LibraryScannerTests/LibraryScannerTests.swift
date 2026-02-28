//
//  LibraryScannerTests.swift
//  LibraryScanner
//
//  App-level tests. Package-level tests live in each package's Tests directory.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing

@Suite("LibraryScanner")
struct LibraryScannerTests {
    @Test("App target compiles")
    func appCompiles() {
        // Ensures the app target builds correctly
        #expect(true)
    }
}
