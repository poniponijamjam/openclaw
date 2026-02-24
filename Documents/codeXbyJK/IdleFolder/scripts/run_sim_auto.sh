#!/bin/zsh
set -euo pipefail

PROJECT="/Users/jam/Documents/codeXbyJK/IdleFolder/IdleFolder.xcodeproj"
SCHEME="IdleFolder"
DERIVED_DATA="/Users/jam/Documents/codeXbyJK/.deriveddata"
BUNDLE_ID="com.example.IdleFolder"
SIM_NAME="${1:-iPhone 16}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode command line tools first."
  exit 1
fi

LIST_JSON="$(mktemp)"
if ! xcrun simctl list devices available -j > "$LIST_JSON" 2>/tmp/idlefolder-simctl.err; then
  echo "Failed to query simulators."
  echo "CoreSimulator may be unavailable. Open Xcode once and try again."
  cat /tmp/idlefolder-simctl.err
  rm -f "$LIST_JSON"
  exit 1
fi

# Find available simulator UDID by exact name.
UDID=$(/usr/bin/python3 -c '
import json,sys
name=sys.argv[1]
path=sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data=json.load(f)
for _,devices in data.get("devices",{}).items():
    for d in devices:
        if d.get("name")==name and d.get("isAvailable"):
            print(d.get("udid")); raise SystemExit(0)
print("")
' "$SIM_NAME" "$LIST_JSON")
rm -f "$LIST_JSON"

if [[ -z "$UDID" ]]; then
  echo "No available simulator named: $SIM_NAME"
  echo "Try: xcrun simctl list devices available"
  exit 1
fi

STATE=$(xcrun simctl list devices 2>/dev/null | rg "$UDID" | sed -E 's/.*\((Booted|Shutdown)\).*/\1/' | head -n1 || true)
if [[ "$STATE" != "Booted" ]]; then
  xcrun simctl boot "$UDID"
fi

open -a Simulator || true
xcrun simctl bootstatus "$UDID" -b || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/IdleFolder.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app bundle not found: $APP_PATH"
  exit 1
fi

xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo "Done. App launched on simulator '$SIM_NAME' ($UDID)."
