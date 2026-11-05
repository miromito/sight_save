#!/usr/bin/env bash
# Run pure Swift unit tests for SightSaveCore (no camera / AppKit).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install Xcode or Swift toolchain." >&2
  exit 1
fi

echo "==> swift test (SightSaveCore)"
swift test --package-path "$ROOT"
