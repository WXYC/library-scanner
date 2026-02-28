# Library Scanner

iPhone app for photographing vinyl records and extracting metadata via the Backend-Service's Gemini Vision API integration. Part of the WXYC ecosystem.

## Project Overview

WXYC has ~72,000 physical records. Many are missing metadata: label name, catalog number, and DJ review text. This app photographs records and routes images through the Backend-Service to Google Gemini for structured text extraction. Results are reviewed by the DJ and written back to the catalog database.

## Core Instructions

- Target iOS 18.6 minimum.
- Swift 6.2 or later, using modern Swift concurrency.
- SwiftUI backed by `@Observable` classes for shared data.
- Do not introduce third-party frameworks without asking first (URLSession only for networking).
- Avoid UIKit unless requested.
- iPhone only (no iPad, watchOS, macOS, or tvOS).

## Build System

XcodeGen (`project.yml`) generates the Xcode project. After modifying `project.yml` or any `Package.swift`, run:

```bash
xcodegen generate
```

## Coding Style

- File headers on all Swift files (except `Package.swift`):
  ```swift
  //
  //  Filename.swift
  //  PackageName
  //
  //  Brief description.
  //
  //  Created by Author Name on MM/DD/YY.
  //  Copyright (c) YYYY WXYC. All rights reserved.
  //
  ```
- Use `@Observable` classes, never `ObservableObject`.
- Async/await throughout, no Combine, no GCD.
- Protocol-based services, dependency injection via SwiftUI Environment.
- Use `foregroundStyle()` not `foregroundColor()`.
- Use `clipShape(.rect(cornerRadius:))` not `cornerRadius()`.
- Use `Tab` API not `tabItem()`.
- Use `NavigationStack` not `NavigationView`.
- Use `Task.sleep(for:)` not `Task.sleep(nanoseconds:)`.
- Avoid `AnyView`, `GeometryReader` (prefer `containerRelativeFrame()`), force unwraps.
- Don't break views into computed properties; use separate `View` structs.
- Prefer static member lookup (`.circle` not `Circle()`).
- Use `localizedStandardContains()` for user text filtering.
- When writing test suites, put mocks below the tests.
- Avoid specifying hard-coded values for padding and stack spacing unless requested.

## Testing

TDD is required. Red -> green -> refactor.

- Use Swift Testing framework (`@Test` macro, `#expect`).
- Each package has a `Tests/` directory.
- Mock protocols for services. Use `URLProtocol` subclasses for network mocking.
- Mocks go below the test cases in the same file.

## Architecture

### Modular Swift Packages

```
Shared/
  ScannerLogger/     -- os.Logger wrapper with scan-specific categories
  ScannerSecrets/    -- obfuscated Backend-Service base URL (ObfuscateMacro)
  AuthKit/           -- better-auth login, JWT token management, Keychain storage
  BarcodeKit/        -- VNDetectBarcodesRequest + VNRecognizeTextRequest wrappers
  CameraKit/         -- AVCaptureSession, photo capture, HEIF preprocessing
  CatalogClient/     -- URLSession networking to Backend-Service
  ScannerKit/        -- scan session orchestration, state machine, batch queue
  ScannerUI/         -- shared SwiftUI components
```

Dependency graph:
```
ScannerSecrets -> ObfuscateMacro (external)
ScannerLogger  -> (none)
AuthKit        -> ScannerSecrets, ScannerLogger
BarcodeKit     -> ScannerLogger
CameraKit      -> ScannerLogger
CatalogClient  -> AuthKit, ScannerLogger
ScannerKit     -> CatalogClient, CameraKit, BarcodeKit, ScannerLogger
ScannerUI      -> ScannerKit, CatalogClient
```

### Primary Workflow (Batch Capture)

Optimized for the "place, tap, flip, tap, repeat" cadence with a phone on a stand:
1. DJ places record front under camera, taps capture
2. Flips record, taps capture
3. Repeats for entire stack
4. Taps "Submit" -- all images upload to Backend-Service
5. Server processes with Gemini asynchronously
6. DJ reviews extracted data later in bulk

### State Machine

`ScanSessionManager` (in ScannerKit) drives scan workflows. Batch mode uses a queue of `BatchItem` entries.

### View Hierarchy

```
LibraryScannerApp
  LoginView (when not authenticated)
  MainTabView (when authenticated)
    Tab 1: CaptureView (batch capture, primary)
    Tab 2: ReviewView (review extracted data)
    Tab 3: HistoryView (completed scans)
```

## Environment Variables

The app uses `ScannerSecrets` for the Backend-Service base URL (obfuscated at compile time via ObfuscateMacro).

Generate secrets:
```bash
./scripts/generate_secrets.sh
```

## Relationship to Other Repos

- **Backend-Service** -- API server with Gemini integration, catalog endpoints, reviews API
- **wxyc-ios-64** -- Reference for Swift/SwiftUI patterns and conventions
- **wxyc-shared** -- Shared DTOs (not directly used by this app; types mirrored via CatalogClient)
