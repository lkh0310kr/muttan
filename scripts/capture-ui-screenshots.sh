#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/muttan.xcodeproj"
SCHEME="muttan"
BUNDLE_ID="com.muttan.app"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
OUTPUT_DIR="${1:-$ROOT_DIR/artifacts/ui-screenshots}"

DEVICE_ID="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, os, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
matches = [d for group in devices.values() for d in group if d["name"] == name and d["isAvailable"]]
if not matches:
    raise SystemExit(f"No available simulator named {name!r}")
print(matches[0]["udid"])
' "$DEVICE_NAME")"

mkdir -p "$OUTPUT_DIR"
echo "Building $SCHEME for $DEVICE_NAME ($DEVICE_ID)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$ROOT_DIR/.derivedData/ui-screenshots" \
  build

APP_PATH="$ROOT_DIR/.derivedData/ui-screenshots/Build/Products/Debug-iphonesimulator/muttan.app"

if ! xcrun simctl list devices booted | grep -q "$DEVICE_ID"; then
  xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
fi
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl status_bar "$DEVICE_ID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

for screen in home tuner progress settings; do
  echo "Capturing $screen..."
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
    "--ui-snapshot=$screen" --ui-snapshot-mode >/dev/null
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIR/$screen.png" >/dev/null
done

echo "Screenshots saved to $OUTPUT_DIR"
