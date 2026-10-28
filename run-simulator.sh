#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
derived_data="$project_dir/.build/DerivedData"
scheme="SnailMail"
bundle_id="com.example.SnailMail"

if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
  print -u2 "Apple developer tools are unavailable. Try: xcode-select -p"
  exit 1
fi

developer_path="$(xcode-select -p 2>/dev/null || true)"
if [[ "$developer_path" != *Xcode.app* ]]; then
  print -u2 "The active developer directory does not point to Xcode: $developer_path"
  print -u2 "If Xcode is installed, run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

device_id="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
data = json.load(sys.stdin)
preferred = []
fallback = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        fallback.append(device)
        if "iPhone" in device.get("name", ""):
            preferred.append(device)
devices = preferred or fallback
print(devices[0]["udid"] if devices else "")
')"

if [[ -z "$device_id" ]]; then
  print -u2 "No available iOS Simulator device was found."
  print -u2 "Check installed runtimes with: xcrun simctl list runtimes"
  exit 1
fi

device_name="$(xcrun simctl list devices -j | /usr/bin/python3 -c '
import json, sys
device_id = sys.argv[1]
data = json.load(sys.stdin)
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == device_id:
            print(device.get("name", device_id))
            raise SystemExit
print(device_id)
' "$device_id")"

print "Building for $device_name…"
xcodebuild \
  -project "$project_dir/SnailMail.xcodeproj" \
  -scheme "$scheme" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

app_path="$derived_data/Build/Products/Debug-iphonesimulator/SnailMail.app"

print "Starting Simulator…"
xcrun simctl boot "$device_id" 2>/dev/null || true
open -a Simulator 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_path"
xcrun simctl launch "$device_id" "$bundle_id"

print "Snail Mail is running on $device_name."
