//
//  AuthEnvironment.swift
//  AuthKit
//
//  SwiftUI environment key for injecting AuthManager into the view hierarchy.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI

private struct AuthManagerKey: EnvironmentKey {
    static let defaultValue: AuthManager? = nil
}

public extension EnvironmentValues {
    var authManager: AuthManager? {
        get { self[AuthManagerKey.self] }
        set { self[AuthManagerKey.self] = newValue }
    }
}
