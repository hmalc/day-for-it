#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/dayforit.xcodeproj"
SCHEME="${SCHEME:-dayforit}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/dayforit-device}"
BUNDLE_ID="${BUNDLE_ID:-com.hmalc.dayforit}"

find_connected_device_id() {
  xcrun devicectl list devices 2>/dev/null \
    | awk '/connected/ && match($0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/) { print substr($0, RSTART, RLENGTH); exit }'
}

DEVICE_ID="${DEVICE_ID:-$(find_connected_device_id)}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "No connected iOS device found."
  echo "Plug in/unlock your iPhone, trust this Mac, enable Developer Mode, then try again."
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION) for device $DEVICE_ID..."
xattr -cr "$PROJECT_ROOT/dayforitApp" "$PROJECT_ROOT/dayforitKit/Sources" "$PROJECT_ROOT/dayforitKit/Package.swift" 2>/dev/null || true

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/dayforit.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app not found at $APP_PATH"
  exit 1
fi

echo "Installing $APP_PATH..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Installed Day For It on device $DEVICE_ID."

if [[ "${LAUNCH_AFTER_INSTALL:-1}" != "0" ]]; then
  echo "Launching $BUNDLE_ID..."
  if ! xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"; then
    echo "Installed, but launch failed. Unlock the device and open Day For It manually, or rerun this script."
  fi
fi
