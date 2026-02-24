#!/bin/zsh
set -euo pipefail

PROJECT="/Users/jam/Documents/codeXbyJK/IdleFolder/IdleFolder.xcodeproj"
SCHEME_APP="IdleFolder"
SCHEME_TEST="IdleFolderTests"
DERIVED="/Users/jam/Documents/codeXbyJK/.deriveddata-device"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <device_udid>"
  echo "Tip: xcrun xctrace list devices"
  exit 1
fi

DEVICE_UDID="$1"
DEST="id=${DEVICE_UDID}"

# Build app for real device.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME_APP" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

# Run test bundle on real device.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME_TEST" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  test
