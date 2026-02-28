//
//  ConfidenceBadge.swift
//  ScannerUI
//
//  A small badge that displays the confidence level of an extraction result.
//  Green for high confidence, yellow for medium, red for low.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI

/// Displays a confidence score as a colored badge.
public struct ConfidenceBadge: View {
    let confidence: Double

    public init(confidence: Double) {
        self.confidence = confidence
    }

    public var body: some View {
        Text(formattedConfidence)
            .font(.caption2)
            .bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(.rect(cornerRadius: 4))
    }

    private var formattedConfidence: String {
        "\(Int(confidence * 100))%"
    }

    private var badgeColor: Color {
        switch confidence {
        case 0.8...: .green
        case 0.5..<0.8: .yellow
        default: .red
        }
    }
}

#Preview {
    VStack {
        ConfidenceBadge(confidence: 0.95)
        ConfidenceBadge(confidence: 0.65)
        ConfidenceBadge(confidence: 0.30)
    }
}
