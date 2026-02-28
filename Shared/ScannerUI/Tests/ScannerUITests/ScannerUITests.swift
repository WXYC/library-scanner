//
//  ScannerUITests.swift
//  ScannerUI
//
//  Placeholder tests for ScannerUI. Full implementation in PR 6.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import ScannerUI

@Suite("ScannerUI")
struct ScannerUITests {
    @Test("ConfidenceBadge can be created with confidence value")
    func confidenceBadgeInit() {
        let badge = ConfidenceBadge(confidence: 0.95)
        #expect(badge.confidence == 0.95)
    }
}
