#!/bin/zsh
set -u

cd "${0:A:h}"

failed=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    print "✓ $1"
  else
    print "✗ $1"
    failed=1
  fi
}

print "snail mail · testflight preflight"
check "xcode command-line tools" "xcodebuild -version"
check "firebase configuration" "test -f SnailMail/GoogleService-Info.plist"
check "firebase bundle id" "grep -q com.samgolik.snailmail SnailMail/GoogleService-Info.plist"
check "firebase app check linked" "grep -q 'FirebaseAppCheck in Frameworks' SnailMail.xcodeproj/project.pbxproj"
check "app check request header" "grep -q 'X-Firebase-AppCheck' SnailMail/MailStore.swift"
check "production app check enforcement" "grep -q 'app verification failed' firebase/functions/src/index.ts"
check "app attest production entitlement" "test -f SnailMail/SnailMail.entitlements && grep -q 'com.apple.developer.devicecheck.appattest-environment' SnailMail/SnailMail.entitlements && grep -q '<string>production</string>' SnailMail/SnailMail.entitlements"
check "clean project syntax" "plutil -lint SnailMail.xcodeproj/project.pbxproj"
check "export compliance declaration" "grep -q 'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO' SnailMail.xcodeproj/project.pbxproj"
check "1024 app icon" "sips -g pixelWidth -g pixelHeight SnailMail/Assets.xcassets/AppIcon.appiconset/AppIcon.png | grep -q '1024'"
check "backend typecheck" "npm --prefix firebase/functions run check"
check "production integration test exists" "test -f firebase/functions/test/integration.mjs"
check "closed Firestore rules" "grep -q 'allow read, write: if false' firebase/firestore.rules"
check "account deletion endpoint" "grep -q 'export const deleteAccount' firebase/functions/src/index.ts"
check "reversible blocking endpoint" "grep -q 'export const unblockUser' firebase/functions/src/index.ts"
check "connection removal endpoint" "grep -q 'export const removeFriend' firebase/functions/src/index.ts"
check "public privacy page" "test -f site/public/privacy.html"
check "public support page" "test -f site/public/support.html"
check "app store metadata" "test -f APP_STORE.md"
check "production operations runbook" "test -f OPERATIONS.md"
check "apple distribution certificate" "security find-identity -v -p codesigning | grep -q 'Apple Distribution'"

if (( failed )); then
  print "\nnot ready to upload yet; simulator development can continue."
  exit 1
fi

print "\nlocal signing prerequisites look ready."
