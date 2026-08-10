#!/bin/bash
# Packages dist/Limac.app from a SwiftPM release build: universal binary,
# embedded Sparkle.framework, stamped Info.plist, ad-hoc signature.
#
# Usage: scripts/make-app.sh [version]        (default: 0.0.0)
#        LIMAC_NATIVE_ARCH=1 scripts/make-app.sh   # skip universal, faster
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.0.0}"
ARCH_FLAGS=(--arch arm64 --arch x86_64)
[ "${LIMAC_NATIVE_ARCH:-}" = "1" ] && ARCH_FLAGS=()

# ${arr[@]+...} keeps macOS bash 3.2's `set -u` happy when the array is empty.
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="dist/Limac.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_DIR/Limac" "$APP/Contents/MacOS/Limac"
cp -R "$BIN_DIR/Limac_Limac.bundle" "$APP/Contents/Resources/"
cp img/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"  # regenerate: scripts/make-icon.sh
cp scripts/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Stamp the bundle's copy, not the template — the checkout stays clean for
# CI's later commit-back step.
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

# SwiftPM stages Sparkle.framework next to the binary; fall back to the
# checksum-pinned artifact (same bits, already universal). ditto preserves
# the framework's version symlinks, which cp -RL would flatten.
FRAMEWORK="$BIN_DIR/Sparkle.framework"
[ -d "$FRAMEWORK" ] ||
    FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

# Ad-hoc sign, inside out. Never --deep: Sparkle's nested helpers must be
# signed individually, keeping the XPC services' entitlements.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
codesign -f -s - --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
codesign -f -s - --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
codesign -f -s - "$SPARKLE/Versions/B/Autoupdate"
codesign -f -s - "$SPARKLE/Versions/B/Updater.app"
codesign -f -s - "$SPARKLE"
codesign -f -s - "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built $APP (version $VERSION)"
