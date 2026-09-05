#!/usr/bin/env bash
#
# Build WeReadBar as a distributable DMG.
#
# Same script is used locally for testing and inside GitHub Actions for
# the release workflow. Produces an ad-hoc-signed .app and a UDZO-compressed
# DMG suitable for upload to GitHub Releases.
#
# Usage:
#   ./scripts/build-dmg.sh [version-string]
#
# Examples:
#   ./scripts/build-dmg.sh                # default version name: dev
#   ./scripts/build-dmg.sh 0.1.0           # explicit version
#
# Prerequisites:
#   - Xcode + command-line tools
#   - xcodegen (brew install xcodegen)
#
# Output:
#   WeReadBar-<version>.dmg in repo root

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-dev}"
DIST_DIR="dist"
DMG="${DIST_DIR}/WeReadBar-${VERSION}.dmg"

echo "==> WeReadBar build-dmg  (version: ${VERSION})"

# -----------------------------------------------------------------------------
# 1. Make sure the Xcode project exists.
#    Fresh checkouts (CI) won't have WeReadBar.xcodeproj yet.
# -----------------------------------------------------------------------------
if [ ! -d WeReadBar.xcodeproj ]; then
  echo "==> WeReadBar.xcodeproj not found, generating with xcodegen…"
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "    installing xcodegen via Homebrew…"
    brew install xcodegen
  fi
  xcodegen generate
fi

# -----------------------------------------------------------------------------
# 2. Build the Release configuration.
#    CODE_SIGN_IDENTITY=- means ad-hoc signing (no Developer ID required).
# -----------------------------------------------------------------------------
echo "==> xcodebuild Release…"
xcodebuild \
  -project WeReadBar.xcodeproj \
  -scheme WeReadBar \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${VERSION}" \
  build | tail -40

APP_PATH="build/Build/Products/Release/WeReadBar.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: ${APP_PATH} was not produced. Build failed." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 3. Re-sign with ad-hoc identity and verify.
#    Build's auto-generated signature may use a different identity; this
#    normalizes it so the final binary is consistently ad-hoc-signed.
# -----------------------------------------------------------------------------
echo "==> codesign --force --deep --sign -"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

# -----------------------------------------------------------------------------
# 4. Stage for DMG.
#    Layout: WeReadBar.app + a symlink to /Applications so users can
#    drag-to-install in Finder.
# -----------------------------------------------------------------------------
STAGING="build/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# -----------------------------------------------------------------------------
# 5. Create the DMG. Output goes into `dist/` (gitignored) so the
#    project root doesn't accumulate artifacts on every build.
# -----------------------------------------------------------------------------
mkdir -p "$DIST_DIR"
echo "==> hdiutil create $DMG"
rm -f "$DMG"
hdiutil create \
  -volname "WeReadBar ${VERSION}" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

echo ""
echo "✅ Built $DMG"
ls -lh "$DMG"
echo ""
echo "Next:"
echo "  open $DMG                       # preview the dmg"
echo "  open $DMG                       # install (drag to /Applications)"
