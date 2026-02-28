#!/bin/bash
#
# generate_secrets.sh
# Generates the Secrets.swift file from ../secrets/secrets.txt
#
# Usage: ./scripts/generate_secrets.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$PROJECT_ROOT/../secrets/secrets.txt"
OUTPUT_FILE="$PROJECT_ROOT/Shared/ScannerSecrets/Sources/ScannerSecrets/Secrets.swift"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Secrets file not found at $SECRETS_FILE"
    echo "Using default development values..."

    cat > "$OUTPUT_FILE" << 'EOF'
//
//  Secrets.swift
//  ScannerSecrets
//
//  GENERATED FILE -- DO NOT EDIT
//  Run ./scripts/generate_secrets.sh to regenerate.
//
//  Created by generate_secrets.sh.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import ObfuscateMacro

enum Secrets {
    @ObfuscatedString
    static let backendBaseURL = "https://api.wxyc.org"

    @ObfuscatedString
    static let authBaseURL = "https://api.wxyc.org/auth"
}
EOF

    echo "Generated $OUTPUT_FILE with default values"
    exit 0
fi

# Read values from secrets file
BACKEND_URL=$(grep "^LIBRARY_SCANNER_BACKEND_URL=" "$SECRETS_FILE" | cut -d'=' -f2- || echo "https://api.wxyc.org")
AUTH_URL=$(grep "^LIBRARY_SCANNER_AUTH_URL=" "$SECRETS_FILE" | cut -d'=' -f2- || echo "https://api.wxyc.org/auth")

cat > "$OUTPUT_FILE" << EOF
//
//  Secrets.swift
//  ScannerSecrets
//
//  GENERATED FILE -- DO NOT EDIT
//  Run ./scripts/generate_secrets.sh to regenerate.
//
//  Created by generate_secrets.sh.
//  Copyright (c) 2026 WXYC. All rights reserved.
//

import ObfuscateMacro

enum Secrets {
    @ObfuscatedString
    static let backendBaseURL = "${BACKEND_URL}"

    @ObfuscatedString
    static let authBaseURL = "${AUTH_URL}"
}
EOF

echo "Generated $OUTPUT_FILE"
