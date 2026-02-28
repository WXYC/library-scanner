//
//  BarcodeKitTests.swift
//  BarcodeKit
//
//  Placeholder tests for BarcodeKit. Full implementation in PR 5.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import BarcodeKit

@Suite("BarcodeKit")
struct BarcodeKitTests {
    @Test("BarcodeResult stores value and symbology")
    func barcodeResultInit() {
        let result = BarcodeResult(value: "012345678901", symbology: "EAN-13")
        #expect(result.value == "012345678901")
        #expect(result.symbology == "EAN-13")
    }
}
