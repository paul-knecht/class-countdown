#!/bin/bash
# Builds ClassCountdown and installs it into /Applications, replacing an older copy.
# Run from the project folder:  ./scripts/install.sh
set -e
cd "$(dirname "$0")/.."

echo "Building…"
xcodebuild -project ClassCountdown.xcodeproj -scheme ClassCountdown -configuration Release \
    -derivedDataPath build build > build-install.log 2>&1 || {
    echo "The build failed. See build-install.log."; exit 1; }
rm -f build-install.log

# Stop a running copy, then replace the installed app.
pkill -x ClassCountdown || true
sleep 1
rm -rf /Applications/ClassCountdown.app
cp -R build/Build/Products/Release/ClassCountdown.app /Applications/ClassCountdown.app

# Remove the built copies from the project folder. Otherwise Spotlight
# offers several apps called ClassCountdown, and it is easy to start the wrong one.
rm -rf build/Build/Products/Release/ClassCountdown.app build/Build/Products/Debug/ClassCountdown.app

open /Applications/ClassCountdown.app
echo "Installed and started /Applications/ClassCountdown.app"
echo "macOS treats a new build as a new app, so it may ask for calendar"
echo "access again. If it shows the warning symbol instead of asking, run:"
echo "  tccutil reset Calendar local.classcountdown"
echo "and start ClassCountdown again."
