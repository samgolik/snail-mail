#!/bin/zsh
set -u

cd "${0:A:h}"

if ! command -v npm >/dev/null 2>&1 && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  source "$HOME/.nvm/nvm.sh"
  nvm use 22 >/dev/null
fi

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
check "node 22 toolchain" "node --version | grep -q '^v22\\.'"
check "firebase configuration" "test -f SnailMail/GoogleService-Info.plist"
check "firebase bundle id" "grep -q com.samgolik.snailmail SnailMail/GoogleService-Info.plist"
check "firebase project pinned" "grep -q '\"default\"[[:space:]]*:[[:space:]]*\"snail-mail-btc\"' .firebaserc"
check "firebase app check linked" "grep -q 'FirebaseAppCheck in Frameworks' SnailMail.xcodeproj/project.pbxproj"
check "app check request header" "grep -q 'X-Firebase-AppCheck' SnailMail/MailStore.swift"
check "production app check enforcement" "grep -q 'app verification failed' firebase/functions/src/index.ts"
check "app attest production entitlement" "test -f SnailMail/SnailMail.entitlements && grep -q 'com.apple.developer.devicecheck.appattest-environment' SnailMail/SnailMail.entitlements && grep -q '<string>production</string>' SnailMail/SnailMail.entitlements"
check "app attest limited to release" "test \"$(grep -c 'CODE_SIGN_ENTITLEMENTS = SnailMail/SnailMail.entitlements' SnailMail.xcodeproj/project.pbxproj)\" -eq 1 && grep -q '#if DEBUG' SnailMail/SnailMailApp.swift"
check "clean project syntax" "plutil -lint SnailMail.xcodeproj/project.pbxproj"
check "explicit info plists linked" "grep -q 'INFOPLIST_FILE = \"SnailMail/Info-Debug.plist\"' SnailMail.xcodeproj/project.pbxproj && grep -q 'INFOPLIST_FILE = \"SnailMail/Info-Release.plist\"' SnailMail.xcodeproj/project.pbxproj"
check "local networking limited to debug" "test \"$(plutil -extract NSAppTransportSecurity.NSAllowsLocalNetworking raw -o - SnailMail/Info-Debug.plist)\" = true && ! plutil -extract NSAppTransportSecurity raw -o - SnailMail/Info-Release.plist >/dev/null 2>&1"
check "export compliance declaration" "test \"$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - SnailMail/Info-Debug.plist)\" = false && test \"$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - SnailMail/Info-Release.plist)\" = false"
check "1024 app icon" "sips -g pixelWidth -g pixelHeight SnailMail/Assets.xcassets/AppIcon.appiconset/AppIcon.png | grep -q '1024'"
check "backend typecheck" "npm --prefix firebase/functions run check"
check "zero warm function instances" "grep -q 'minInstances: 0' firebase/functions/src/index.ts"
check "bounded function scaling" "grep -q 'maxInstances: 2' firebase/functions/src/index.ts"
check "bounded function timeout" "grep -q 'timeoutSeconds: 30' firebase/functions/src/index.ts"
check "function memory limit" "grep -q 'memory: \"256MiB\"' firebase/functions/src/index.ts"
check "production integration test exists" "test -f firebase/functions/test/integration.mjs"
check "closed Firestore rules" "grep -q 'allow read, write: if false' firebase/firestore.rules"
check "account deletion endpoint" "grep -q 'export const deleteAccount' firebase/functions/src/index.ts"
check "reversible blocking endpoint" "grep -q 'export const unblockUser' firebase/functions/src/index.ts"
check "connection removal endpoint" "grep -q 'export const removeFriend' firebase/functions/src/index.ts"
check "public privacy page" "test -f site/public/privacy.html"
check "public support page" "test -f site/public/support.html"
check "public terms and community pages" "test -f site/public/terms.html && test -f site/public/community.html"
check "versioned terms acceptance" "grep -q 'CURRENT_TERMS_VERSION' firebase/functions/src/index.ts && grep -q 'acceptTerms' SnailMail/MailStore.swift"
check "private profile fields sanitized" "grep -q 'if (!includePrivate) return shared' firebase/functions/src/index.ts"
check "app store metadata" "test -f APP_STORE.md"
check "production operations runbook" "test -f OPERATIONS.md"
check "decision record" "test -f DECISIONS.md"
check "guarded function deploy script" "test -x deploy-functions.sh && grep -q 'firebase-tools@latest' deploy-functions.sh && grep -q -- '--days 1' deploy-functions.sh"
check "apple distribution certificate" "security find-identity -v -p codesigning | grep -q 'Apple Distribution'"

if (( failed )); then
  print "\nnot ready to upload yet; simulator development can continue."
  exit 1
fi

print "\nlocal signing prerequisites look ready."
