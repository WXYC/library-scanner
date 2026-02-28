# Library Scanner

iPhone app for photographing vinyl records and extracting metadata (label name, catalog number, DJ review text) using Google Gemini's Vision API via the WXYC Backend-Service.

## Set Up

### Prerequisites

- Xcode 16.4+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44.1+
- iOS 18.6+ device (camera features require hardware)
- Access to the WXYC Backend-Service (running locally or at `api.wxyc.org`)

### Generate Xcode Project

```bash
# Generate secrets file (requires ../secrets/secrets.txt)
./scripts/generate_secrets.sh

# Generate Xcode project from project.yml
xcodegen generate

# Open the project
open LibraryScanner.xcodeproj
```

### Secrets

The app requires a `Secrets.swift` file with the obfuscated Backend-Service base URL. This file is git-ignored and must be generated locally:

```bash
./scripts/generate_secrets.sh
```

The script reads from `../secrets/secrets.txt` and generates `Shared/ScannerSecrets/Sources/ScannerSecrets/Secrets.swift` using ObfuscateMacro.

## Architecture

### Modular Swift Packages

| Package | Purpose |
|---------|---------|
| **ScannerLogger** | os.Logger wrapper with scan-specific categories |
| **ScannerSecrets** | Obfuscated Backend-Service base URL |
| **AuthKit** | better-auth login, JWT token management, Keychain storage |
| **BarcodeKit** | UPC barcode detection via Apple Vision framework |
| **CameraKit** | AVCaptureSession, photo capture, HEIF preprocessing |
| **CatalogClient** | URLSession networking to Backend-Service |
| **ScannerKit** | Scan session orchestration, state machine, batch queue |
| **ScannerUI** | Shared SwiftUI components |

### Workflow

The primary workflow is optimized for batch capture with a phone on a stand:

1. DJ places record front under camera, taps capture
2. Flips record, taps capture
3. Repeats for entire stack
4. Taps "Submit" -- all images upload to Backend-Service
5. Server processes with Gemini asynchronously
6. DJ reviews extracted data later in bulk

### Backend Integration

All VLM (Vision Language Model) calls are routed through the Backend-Service so the Gemini API key stays server-side. The app communicates with these endpoints:

- `GET /library` -- search catalog by code, artist, title
- `POST /library/scan` -- submit images for extraction
- `POST /library/scan/batch` -- batch submission
- `GET /library/scan/batch/:jobId` -- poll batch status
- `PUT /library/reviews` -- write back approved reviews
- `PATCH /library` -- update album metadata

### Authentication

Uses the existing better-auth system via the Backend-Service auth server. JWTs are stored in the iOS Keychain and refreshed automatically.

## Development

### Running Tests

```bash
xcodebuild test \
  -scheme LibraryScanner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Code Style

See [CLAUDE.md](CLAUDE.md) for coding conventions. Key points:
- Swift 6.2 with strict concurrency
- SwiftUI with `@Observable` (no `ObservableObject`)
- TDD required (red -> green -> refactor)
- Protocol-based services for testability
