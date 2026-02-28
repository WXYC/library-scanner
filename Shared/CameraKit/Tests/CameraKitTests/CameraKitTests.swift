//
//  CameraKitTests.swift
//  CameraKit
//
//  Placeholder tests for CameraKit. Full implementation in PR 5.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import Testing
@testable import CameraKit

@Suite("CameraKit")
struct CameraKitTests {
    @Test("CapturedPhoto stores data and dimensions")
    func capturedPhotoInit() {
        let data = Data([0x00, 0x01, 0x02])
        let photo = CapturedPhoto(imageData: data, originalWidth: 4032, originalHeight: 3024)
        #expect(photo.imageData == data)
        #expect(photo.originalWidth == 4032)
        #expect(photo.originalHeight == 3024)
    }
}
