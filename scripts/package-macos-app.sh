#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build and package Morpho as a macOS .app bundle.

Usage:
  scripts/package-macos-app.sh [options]

Options:
  --clean                         Run `swift package clean` before build.
  --output-dir <dir>              Output directory (default: dist).
  --app-name <name>               App display name and bundle folder name (default: Morpho).
  --product <name>                SwiftPM executable product/target name (default: MorphoApp).
  --bundle-id <id>                CFBundleIdentifier (default: com.zhengyuelin.morpho).
  --version <version>             CFBundleShortVersionString (default: 1.0).
  --build-number <number>         CFBundleVersion (default: 1).
  --minimum-macos <version>       LSMinimumSystemVersion (default: 15.0).
  --sign-identity <identity>      Sign with a real identity (recommended for stable TCC identity).
  --unsigned                      Skip code signing.
  --help                          Show this message.

Examples:
  scripts/package-macos-app.sh --clean
  scripts/package-macos-app.sh --output-dir dist
  scripts/package-macos-app.sh --sign-identity "Apple Development: Your Name (TEAMID)"
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLEAN_BUILD=false
OUTPUT_DIR="dist"
APP_NAME="Morpho"
PRODUCT_NAME="MorphoApp"
BUNDLE_ID="com.zhengyuelin.morpho"
APP_VERSION="1.0"
BUILD_NUMBER="1"
MINIMUM_MACOS="15.0"
SIGN_IDENTITY=""
SIGN_MODE="adhoc"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?missing value for --output-dir}"
      shift 2
      ;;
    --app-name)
      APP_NAME="${2:?missing value for --app-name}"
      shift 2
      ;;
    --product)
      PRODUCT_NAME="${2:?missing value for --product}"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:?missing value for --bundle-id}"
      shift 2
      ;;
    --version)
      APP_VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:?missing value for --build-number}"
      shift 2
      ;;
    --minimum-macos)
      MINIMUM_MACOS="${2:?missing value for --minimum-macos}"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:?missing value for --sign-identity}"
      SIGN_MODE="identity"
      shift 2
      ;;
    --unsigned)
      SIGN_MODE="none"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cd "${REPO_ROOT}"

if [[ "${CLEAN_BUILD}" == "true" ]]; then
  echo "==> Cleaning SwiftPM build artifacts"
  swift package clean
fi

echo "==> Building release product: ${PRODUCT_NAME}"
swift build -c release --product "${PRODUCT_NAME}"

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="${BIN_DIR}/${PRODUCT_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Build output not found: ${BIN_PATH}" >&2
  exit 1
fi

RESOURCE_BUNDLE_PATH="$(find "${BIN_DIR}" -maxdepth 1 -type d -name "*_${PRODUCT_NAME}.bundle" | sort | head -n 1 || true)"
if [[ -z "${RESOURCE_BUNDLE_PATH}" ]]; then
  echo "Resource bundle not found in ${BIN_DIR}" >&2
  exit 1
fi

OUTPUT_DIR_ABS="${REPO_ROOT}/${OUTPUT_DIR}"
APP_PATH="${OUTPUT_DIR_ABS}/${APP_NAME}.app"
APP_CONTENTS="${APP_PATH}/Contents"
MACOS_DIR="${APP_CONTENTS}/MacOS"
RESOURCES_DIR="${APP_CONTENTS}/Resources"
ZIP_PATH="${OUTPUT_DIR_ABS}/${APP_NAME}.app.zip"

mkdir -p "${OUTPUT_DIR_ABS}"
rm -rf "${APP_PATH}" "${ZIP_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Assembling app bundle at ${APP_PATH}"
cp "${BIN_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
cp -R "${RESOURCE_BUNDLE_PATH}" "${RESOURCES_DIR}/"

GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_TIME="$(date "+%Y-%m-%d %H:%M:%S %z")"

cat > "${APP_CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MINIMUM_MACOS}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>MorphoBuildCommit</key>
  <string>${GIT_COMMIT}</string>
  <key>MorphoBuildTime</key>
  <string>${BUILD_TIME}</string>
</dict>
</plist>
EOF

if [[ "${SIGN_MODE}" == "identity" ]]; then
  echo "==> Signing app with identity: ${SIGN_IDENTITY}"
  codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_PATH}"
elif [[ "${SIGN_MODE}" == "adhoc" ]]; then
  echo "==> Signing app with ad-hoc identity"
  codesign --force --deep --sign - "${APP_PATH}"
else
  echo "==> Skipping code signing (--unsigned)"
fi

if [[ "${SIGN_MODE}" != "none" ]]; then
  echo "==> Verifying code signature"
  codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
fi

echo "==> Creating ZIP package: ${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo ""
echo "Done."
echo "App: ${APP_PATH}"
echo "Zip: ${ZIP_PATH}"
echo "Commit: ${GIT_COMMIT}"
echo "Build Time: ${BUILD_TIME}"
echo ""
if [[ "${SIGN_MODE}" == "adhoc" ]]; then
  echo "Note: ad-hoc signature changes across builds and may trigger repeated Accessibility permission prompts."
  echo "Use --sign-identity with a stable certificate for a stable TCC identity."
fi
