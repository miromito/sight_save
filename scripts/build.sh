#!/usr/bin/env bash
# Build SightSave.app from the command line.
# Preferred path: SwiftPM + Command Line Tools (no full Xcode required).
# Fallback: xcodebuild when available (or FORCE_XCODEBUILD=1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData}"
DIST="${DIST_DIR:-$ROOT/dist}"
APP_NAME="SightSave"
BUNDLE_ID="com.rodionlitvinoff.SightSave"
SCHEME="SightSave"
ENTITLEMENTS="$ROOT/App/SightSave/Resources/SightSave.entitlements"
INFO_PLIST="$ROOT/App/SightSave/Resources/Info.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: SightSave must be built on macOS." >&2
  echo "  Install Command Line Tools: xcode-select --install" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

mkdir -p "$DIST"

has_xcodebuild=0
if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  has_xcodebuild=1
fi

use_xcodebuild=0
if [[ "${FORCE_XCODEBUILD:-0}" == "1" ]]; then
  if [[ "$has_xcodebuild" != "1" ]]; then
    echo "error: FORCE_XCODEBUILD=1 but xcodebuild is not usable." >&2
    exit 1
  fi
  use_xcodebuild=1
elif [[ "${FORCE_SWIFTPM:-0}" == "1" ]]; then
  use_xcodebuild=0
elif [[ "$has_xcodebuild" == "1" && "${PREFER_XCODEBUILD:-0}" == "1" ]]; then
  use_xcodebuild=1
fi

# Default: SwiftPM (works with Command Line Tools only).
# Use xcodebuild only when forced/preferred above.

codesign_app() {
  local app="$1"
  echo "==> Ad-hoc codesign"
  # Embed entitlements (camera). Skip hardened runtime by default so ad-hoc local
  # builds stay simple; set HARDENED_RUNTIME=1 to enable --options runtime.
  # Avoid empty-array "${arr[@]}" under `set -u` — unbound on macOS /bin/bash 3.2.
  if [[ -f "$ENTITLEMENTS" ]]; then
    if [[ "${HARDENED_RUNTIME:-0}" == "1" ]]; then
      codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        "$app"
    else
      codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$app"
    fi
  else
    if [[ "${HARDENED_RUNTIME:-0}" == "1" ]]; then
      codesign --force --deep --sign - --options runtime "$app"
    else
      codesign --force --deep --sign - "$app"
    fi
  fi
  echo "==> Verifying signature"
  codesign --verify --verbose=2 "$app" || true
}

make_zip() {
  if [[ "${MAKE_ZIP:-1}" != "1" ]]; then
    return 0
  fi
  echo "==> Creating zip"
  (
    cd "$DIST"
    rm -f "${APP_NAME}.zip"
    ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
  )
  echo "Zip: $DIST/${APP_NAME}.zip"
}

assemble_app_from_binary() {
  local binary="$1"
  local app="$DIST/${APP_NAME}.app"
  local contents="$app/Contents"
  local macos_dir="$contents/MacOS"

  echo "==> Assembling $app"
  rm -rf "$app"
  mkdir -p "$macos_dir"

  cp "$binary" "$macos_dir/$APP_NAME"
  chmod +x "$macos_dir/$APP_NAME"
  cp "$INFO_PLIST" "$contents/Info.plist"
  printf 'APPL????' > "$contents/PkgInfo"

  # No compiled asset catalog required — menu bar uses SF Symbols.
}

build_with_swiftpm() {
  local config_flag="-c release"
  local build_subdir="release"
  if [[ "${CONFIGURATION}" =~ ^[Dd]ebug$ ]]; then
    config_flag="-c debug"
    build_subdir="debug"
  fi

  local product="SightSaveApp"

  echo "==> Building with SwiftPM (Command Line Tools)"
  echo "    swift $(swift --version 2>&1 | head -n 1)"
  # shellcheck disable=SC2086
  swift build $config_flag --product "$product"

  local binary=""
  # Prefer swift build --show-bin-path when available.
  if bin_path="$(swift build $config_flag --show-bin-path 2>/dev/null)"; then
    if [[ -x "$bin_path/$product" ]]; then
      binary="$bin_path/$product"
    fi
  fi
  if [[ -z "$binary" ]]; then
    binary="$(find "$ROOT/.build" -type f -path "*/${build_subdir}/${product}" -perm -111 | head -n 1 || true)"
  fi
  if [[ -z "$binary" || ! -x "$binary" ]]; then
    echo "error: SwiftPM binary '$product' not found under .build/" >&2
    exit 1
  fi
  echo "    Binary: $binary"

  assemble_app_from_binary "$binary"
  codesign_app "$DIST/${APP_NAME}.app"
  make_zip
}

build_with_xcodebuild() {
  echo "==> Building with xcodebuild ($CONFIGURATION)"

  if command -v xcodegen >/dev/null 2>&1 && [[ -f "$ROOT/project.yml" ]]; then
    echo "==> Regenerating Xcode project with XcodeGen"
    xcodegen generate --spec "$ROOT/project.yml"
  fi

  rm -rf "$DERIVED"

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

  local built_app
  built_app="$(find "$DERIVED/Build/Products" -name "${APP_NAME}.app" -type d | head -n 1)"
  if [[ -z "$built_app" ]]; then
    echo "error: built app not found under $DERIVED" >&2
    exit 1
  fi

  rm -rf "$DIST/${APP_NAME}.app"
  cp -R "$built_app" "$DIST/${APP_NAME}.app"
  codesign_app "$DIST/${APP_NAME}.app"
  make_zip
}

if [[ "$use_xcodebuild" == "1" ]]; then
  build_with_xcodebuild
else
  if [[ "$has_xcodebuild" == "1" ]]; then
    echo "note: xcodebuild is available; using SwiftPM by default."
    echo "      Set PREFER_XCODEBUILD=1 or FORCE_XCODEBUILD=1 to use Xcode."
  else
    echo "note: xcodebuild not available — using SwiftPM + Command Line Tools."
  fi
  build_with_swiftpm
fi

echo
echo "Built: $DIST/${APP_NAME}.app"
echo "Bundle ID: $BUNDLE_ID"
echo "Install:  cp -R \"$DIST/${APP_NAME}.app\" /Applications/"
echo "Run:      open \"$DIST/${APP_NAME}.app\""
