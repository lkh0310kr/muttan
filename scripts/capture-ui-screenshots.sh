#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$(find "$ROOT_DIR" -maxdepth 1 -name '*.xcodeproj' -print -quit)}"
if [[ -z "$PROJECT_PATH" ]]; then
  echo "No .xcodeproj found in $ROOT_DIR" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH" .xcodeproj)"
SCHEME="${SCHEME:-$PROJECT_NAME}"
CONFIGURATION="${CONFIGURATION:-Debug}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/artifacts/ui-screenshots}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$ROOT_DIR/.derivedData/ui-screenshots}"
DEVICE_NAME="${DEVICE_NAME:-}"
DEVICE_ID="${DEVICE_ID:-}"
CAPTURE_DELAY="${CAPTURE_DELAY:-2}"
SCREENS_CSV="${SCREENS:-practice,songs,practice-play,song-play,chords,chord-chart,chord-detail,tuner,settings}"
APPEARANCES_CSV="${APPEARANCES:-light,dark}"
STATUS_BAR_TIME="${STATUS_BAR_TIME:-9:41}"

usage() {
  cat <<'EOF'
Usage: capture-ui-screenshots.sh [output-directory] [options]

Options:
  --output DIR        Store screenshots in DIR
  --device-name NAME   Select an installed Simulator by name
  --device-id UDID     Select an installed Simulator by UDID
  --screens LIST       Comma-separated screen names (default: practice,songs,practice-play,song-play,chords,chord-chart,chord-detail,tuner,settings)
  --appearances LIST   Comma-separated themes (default: light,dark)
  --wait SECONDS       Delay after launch before capture (default: 2)
  --help               Show this help

Environment overrides: PROJECT_PATH, SCHEME, CONFIGURATION, OUTPUT_DIR,
DERIVED_DATA_DIR, DEVICE_NAME, DEVICE_ID, SCREENS, APPEARANCES,
CAPTURE_DELAY, STATUS_BAR_TIME.
EOF
}

while (($#)); do
  case "$1" in
    --device-name) DEVICE_NAME="${2:?Missing simulator name}"; shift 2 ;;
    --device-id) DEVICE_ID="${2:?Missing simulator UDID}"; shift 2 ;;
    --output) OUTPUT_DIR="${2:?Missing output directory}"; shift 2 ;;
    --screens) SCREENS_CSV="${2:?Missing screen list}"; shift 2 ;;
    --appearances) APPEARANCES_CSV="${2:?Missing appearance list}"; shift 2 ;;
    --wait) CAPTURE_DELAY="${2:?Missing delay}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ "$OUTPUT_DIR" == "$ROOT_DIR/artifacts/ui-screenshots" ]]; then
        OUTPUT_DIR="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
name = sys.argv[1]
devices = [device for group in json.load(sys.stdin)["devices"].values() for device in group if device["isAvailable"]]
matches = [device for device in devices if device["name"] == name] if name else []
if not matches:
    matches = [device for device in devices if "iPhone" in device.get("deviceTypeIdentifier", "")]
if not matches:
    raise SystemExit("No available iPhone Simulator found; pass --device-name or --device-id")
print(matches[0]["udid"])
' "$DEVICE_NAME")"
fi

IFS=',' read -r -a SCREENS <<< "$SCREENS_CSV"
IFS=',' read -r -a APPEARANCES <<< "$APPEARANCES_CSV"
if ((${#SCREENS[@]} == 0 || ${#APPEARANCES[@]} == 0)); then
  echo "Screen and appearance lists must not be empty" >&2
  exit 2
fi
for appearance in "${APPEARANCES[@]}"; do
  if [[ "$appearance" != "light" && "$appearance" != "dark" ]]; then
    echo "Unsupported appearance '$appearance'; use light or dark" >&2
    exit 2
  fi
done
if ! [[ "$CAPTURE_DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Wait must be a non-negative number of seconds" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
echo "Building $SCHEME for Simulator $DEVICE_ID..."
xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION-iphonesimulator"
APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"

if ! xcrun simctl list devices booted | grep -Fq "$DEVICE_ID"; then
  xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
fi
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl status_bar "$DEVICE_ID" override \
  --time "$STATUS_BAR_TIME" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

for appearance in "${APPEARANCES[@]}"; do
  xcrun simctl ui "$DEVICE_ID" appearance "$appearance"
  for screen in "${SCREENS[@]}"; do
    echo "Capturing $screen-$appearance..."
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
      "--ui-snapshot=$screen" "--ui-snapshot-appearance=$appearance" --ui-snapshot-mode >/dev/null
    sleep "$CAPTURE_DELAY"
    xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIR/$screen-$appearance.png" >/dev/null
  done
done

echo "Screenshots saved to $OUTPUT_DIR"
