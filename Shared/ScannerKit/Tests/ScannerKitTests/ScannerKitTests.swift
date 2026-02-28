//
//  ScannerKitTests.swift
//  ScannerKit
//
//  Placeholder tests for ScannerKit. Full implementation in PR 6.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import ScannerKit

@Suite("ScannerKit")
struct ScannerKitTests {
    @Test("ScanPhase idle is the initial state")
    func initialPhase() {
        let phase = ScanPhase.idle
        #expect(phase == .idle)
    }

    @Test("ScanPhase error carries message")
    func errorPhase() {
        let phase = ScanPhase.error("Network timeout")
        if case .error(let message) = phase {
            #expect(message == "Network timeout")
        } else {
            Issue.record("Expected error phase")
        }
    }
}
