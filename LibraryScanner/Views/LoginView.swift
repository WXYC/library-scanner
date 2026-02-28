//
//  LoginView.swift
//  LibraryScanner
//
//  Login screen for authenticating with the WXYC better-auth service.
//  Shown when no valid session exists.
//
//  Created by Jake on 02/28/26.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import SwiftUI
import AuthKit

struct LoginView: View {
    @Environment(\.authManager) private var authManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("WXYC")
                        .font(.largeTitle)
                        .bold()
                    Text("Library Scanner")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(.rect(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(.fill.tertiary)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .padding(.horizontal)

                if let error = authManager?.error {
                    Text(errorMessage(for: error))
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await authManager?.signIn(email: email, password: password)
                    }
                } label: {
                    if authManager?.isLoading == true {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || password.isEmpty || authManager?.isLoading == true)
                .padding(.horizontal)

                Spacer()
                Spacer()
            }
            .navigationTitle("")
        }
    }

    private func errorMessage(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            "Invalid email or password."
        case .networkError:
            "Unable to connect. Check your network connection."
        case .serverError(let code, _):
            "Server error (\(code)). Try again later."
        default:
            "An error occurred. Try again."
        }
    }
}

#Preview {
    LoginView()
        .environment(\.authManager, AuthManager(tokenStore: InMemoryTokenStore()))
}
