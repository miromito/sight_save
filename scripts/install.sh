#!/usr/bin/env bash
# Build SightSave, copy it to /Applications, and open it.
# Safe for macOS /bin/bash 3.2 (no empty-array expansions under `set -u`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="SightSave"
DEST="/Applications/${APP_NAME}.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: SightSave can only be installed on a Mac." >&2
  exit 1
fi

chmod +x "$ROOT/scripts/build.sh" 2>/dev/null || true

echo "==> Building SightSave (this can take a few minutes the first time)…"
"$ROOT/scripts/build.sh"

if [[ ! -d "$ROOT/dist/${APP_NAME}.app" ]]; then
  echo "error: build finished but dist/${APP_NAME}.app was not found." >&2
  exit 1
fi

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$ROOT/dist/${APP_NAME}.app" "$DEST"

echo "==> Opening SightSave"
open "$DEST"

echo
echo "Done. Look for the eye icon in the menu bar (top-right of the screen)."
echo "If macOS blocks the app: System Settings → Privacy & Security → Open Anyway."
echo "Settings: click the menu bar icon → Settings…"
