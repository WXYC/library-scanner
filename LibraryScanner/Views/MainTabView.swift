//
//  MainTabView.swift
//  LibraryScanner
//
//  Root tab view shown after authentication. Provides tabs for
//  batch capture, review, history, and settings.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import AuthKit

struct MainTabView: View {
    @Environment(\.authManager) private var authManager

    var body: some View {
        TabView {
            Tab("Capture", systemImage: "camera") {
                CaptureView()
            }

            Tab("Review", systemImage: "checklist") {
                ReviewView()
            }

            Tab("History", systemImage: "clock") {
                HistoryView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @Environment(\.authManager) private var authManager

    var body: some View {
        NavigationStack {
            List {
                if let user = authManager?.currentUser {
                    Section("Account") {
                        LabeledContent("Email", value: user.email)
                        if let name = user.name {
                            LabeledContent("Name", value: name)
                        }
                        if let role = user.role {
                            LabeledContent("Role", value: role)
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authManager?.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.authManager, AuthManager(tokenStore: InMemoryTokenStore()))
}
