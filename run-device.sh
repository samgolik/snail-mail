#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
derived_data="$project_dir/.build/DeviceDerivedData"
scheme="SnailMail"
bundle_id="${DEVICE_BUNDLE_ID:-com.samgolik.snailmail.dev}"
team_id="${TEAM_ID:-}"

if [[ -z "$team_id" ]]; then
  team_id="$(defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null | awk '
    /isFreeProvisioningTeam = 0/ { paid = 1 }
    paid && /teamID =/ { gsub(/[;\"]/ , "", $3); print $3; exit }
  ')"
fi

if [[ -z "$team_id" ]]; then
  team_id="$(defaults read com.apple.dt.Xcode IDEProvisioningTeams 2>/dev/null | awk '
    /isFreeProvisioningTeam = 1/ { personal = 1 }
    personal && /teamID =/ { gsub(/[;\"]/ , "", $3); print $3; exit }
  ')"
fi

if [[ -z "$team_id" ]]; then
  print -u2 "No Apple development team is configured on this Mac."
  print -u2 "Set one explicitly with TEAM_ID=YOUR_TEAM_ID ./run-device.sh"
  exit 1
fi

if ! xcrun --find devicectl >/dev/null 2>&1; then
  print -u2 "This workflow needs devicectl from Xcode 15 or newer."
  print -u2 "Your current command-line tools are: $(xcodebuild -version | head -n 1)"
  exit 1
fi

device_id="$(xcrun xcdevice list --timeout 5 2>/dev/null | /usr/bin/python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []
for device in devices:
    if device.get("platform") == "com.apple.platform.iphoneos" and device.get("available", True):
        print(device.get("identifier", ""))
        break
')"

if [[ -z "$device_id" ]]; then
  print -u2 "No unlocked, trusted iPhone was found over USB."
  print -u2 "Check with: xcrun xcdevice list"
  exit 1
fi

print "Building for connected iPhone $device_id with team $team_id…"
xcodebuild \
  -project "$project_dir/SnailMail.xcodeproj" \
  -scheme "$scheme" \
  -configuration Debug \
  -destination "platform=iOS,id=$device_id" \
  -derivedDataPath "$derived_data" \
  DEVELOPMENT_TEAM="$team_id" \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  build

app_path="$derived_data/Build/Products/Debug-iphoneos/SnailMail.app"

print "Installing Snail Mail…"
xcrun devicectl device install app --device "$device_id" "$app_path"
xcrun devicectl device process launch \
  --device "$device_id" \
  --terminate-existing \
  "$bundle_id"

print "Snail Mail is running on your iPhone."
