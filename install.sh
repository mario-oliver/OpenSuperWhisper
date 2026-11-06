#!/bin/zsh
# Build OpenSuperWhisper from this checkout and install it into /Applications.
# Usage: ./install.sh            build, quit the running app, replace it, relaunch
#        ./install.sh --no-build  install the last build without rebuilding
set -euo pipefail
cd "${0:A:h}"

BUILT_APP="build/Build/Products/Debug/OpenSuperWhisper.app"
TARGET_APP="/Applications/OpenSuperWhisper.app"
BUNDLE_ID="ru.starmel.OpenSuperWhisper"

if [[ "${1:-}" != "--no-build" ]]; then
    git submodule update --init --recursive
    ./run.sh build
fi

[[ -d "$BUILT_APP" ]] || { echo "No build found at $BUILT_APP"; exit 1; }

echo "Quitting OpenSuperWhisper..."
osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
for _ in {1..10}; do
    pgrep -f "OpenSuperWhisper.app/Contents/MacOS/OpenSuperWhisper" >/dev/null || break
    sleep 0.5
done
pkill -f "OpenSuperWhisper.app/Contents/MacOS/OpenSuperWhisper" 2>/dev/null || true

echo "Installing to $TARGET_APP..."
rm -rf "$TARGET_APP"
ditto "$BUILT_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

# The build only gets a partial ad-hoc "linker" signature, so macOS can't match
# permission grants (Microphone, Accessibility) to the app. Re-sign the whole bundle
# with a real identity. A stable certificate keeps grants across rebuilds.
# Override with SIGN_IDENTITY="..." ; falls back to ad-hoc ("-") if none is found.
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "Signing with: $SIGN_IDENTITY"
# Sign nested code first, without the app's entitlements.
find "$TARGET_APP/Contents" \( -name "*.dylib" -o -name "*.framework" \) -not -path "*/Resources/*" \
    -print0 | while IFS= read -r -d '' nested; do
    codesign --force --timestamp=none --options runtime --sign "$SIGN_IDENTITY" "$nested"
done
# Then the app itself, with the hardened runtime: blocks DYLD_INSERT_LIBRARIES and
# unsigned dylibs, so other code can't borrow the app's Microphone/Accessibility grants.
# The entitlements file has no get-task-allow, so the Debug build's one is dropped.
codesign --force --timestamp=none --options runtime --sign "$SIGN_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    --entitlements OpenSuperWhisper/OpenSuperWhisper.entitlements \
    "$TARGET_APP"
codesign --verify --deep --strict "$TARGET_APP"

echo "Launching..."
open "$TARGET_APP"
echo "Installed $(git rev-parse --short HEAD) ($(git rev-parse --abbrev-ref HEAD))."
