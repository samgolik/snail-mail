#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
derived_data="$project_dir/.build/DeviceDerivedData"
scheme="SnailMail"
firebase_app_id="1:1047837587884:ios:3d27b8b4cd229755ba2209"
bundle_id="${DEVICE_BUNDLE_ID:-com.samgolik.snailmail.dev}"
team_id="${TEAM_ID:-}"

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
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$team_id" \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  build

app_path="$derived_data/Build/Products/Debug-iphoneos/SnailMail.app"

if ! command -v npx >/dev/null 2>&1 && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  source "$HOME/.nvm/nvm.sh"
  nvm use 22 >/dev/null
fi

token_file="$project_dir/.build/app-check-device-debug-token"
token_marker="$project_dir/.build/app-check-device-debug-token.registered"
mkdir -p "$project_dir/.build"
if [[ ! -s "$token_file" ]]; then
  uuidgen > "$token_file"
  chmod 600 "$token_file"
fi
debug_token="$(<"$token_file")"

if [[ ! -f "$token_marker" ]]; then
  print "Registering this Mac's private device-debug token with Firebase App Check…"
  npx -y firebase-tools@latest appcheck:debugtokens:create "$debug_token" \
    --project snail-mail-btc \
    --app "$firebase_app_id"
  touch "$token_marker"
fi

print "Installing Snail Mail…"
xcrun devicectl device install app --device "$device_id" "$app_path"
xcrun devicectl device process launch \
  --device "$device_id" \
  --environment-variables "{\"AppCheckDebugToken\":\"$debug_token\"}" \
  --terminate-existing \
  "$bundle_id"

print "Snail Mail is running on your iPhone."
