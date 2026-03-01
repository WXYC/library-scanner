//
//  ScannerEnvironment.swift
//  ScannerKit
//
//  SwiftUI environment key for injecting ScanSessionManager into the
//  view hierarchy.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI

private struct ScanSessionManagerKey: EnvironmentKey {
    static let defaultValue: ScanSessionManager? = nil
}

public extension EnvironmentValues {
    var scanSessionManager: ScanSessionManager? {
        get { self[ScanSessionManagerKey.self] }
        set { self[ScanSessionManagerKey.self] = newValue }
    }
}
