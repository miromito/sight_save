#!/usr/bin/env bash
# Build SightSave.app from the command line (macOS + Xcode required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData}"
DIST="${DIST_DIR:-$ROOT/dist}"
APP_NAME="SightSave"
SCHEME="SightSave"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: SightSave must be built on macOS with Xcode." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Install Xcode from the App Store, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

# Optionally regenerate the Xcode project from project.yml when XcodeGen is installed.
if command -v xcodegen >/dev/null 2>&1 && [[ -f "$ROOT/project.yml" ]]; then
  echo "==> Regenerating Xcode project with XcodeGen"
  xcodegen generate --spec "$ROOT/project.yml"
fi

echo "==> Building $APP_NAME ($CONFIGURATION)"
rm -rf "$DERIVED"
mkdir -p "$DIST"

xcodebuild \
  -project "$ROOT/SightSave.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  build

BUILT_APP="$(find "$DERIVED/Build/Products" -name "${APP_NAME}.app" -type d | head -n 1)"
if [[ -z "$BUILT_APP" ]]; then
  echo "error: built app not found under $DERIVED" >&2
  exit 1
fi

rm -rf "$DIST/${APP_NAME}.app"
cp -R "$BUILT_APP" "$DIST/${APP_NAME}.app"

echo "==> Ad-hoc codesign"
codesign --force --deep --sign - "$DIST/${APP_NAME}.app"

echo "==> Verifying signature"
codesign --verify --verbose=2 "$DIST/${APP_NAME}.app" || true

if [[ "${MAKE_ZIP:-1}" == "1" ]]; then
  echo "==> Creating zip"
  (
    cd "$DIST"
    rm -f "${APP_NAME}.zip"
    ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
  )
  echo "Zip: $DIST/${APP_NAME}.zip"
fi

echo
echo "Built: $DIST/${APP_NAME}.app"
echo "Install:  cp -R \"$DIST/${APP_NAME}.app\" /Applications/"
echo "Run:      open \"$DIST/${APP_NAME}.app\""
