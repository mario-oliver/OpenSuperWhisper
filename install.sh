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

echo "Launching..."
open "$TARGET_APP"
echo "Installed $(git rev-parse --short HEAD) ($(git rev-parse --abbrev-ref HEAD))."
