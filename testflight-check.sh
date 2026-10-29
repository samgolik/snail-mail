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
check "clean project syntax" "plutil -lint SnailMail.xcodeproj/project.pbxproj"
check "apple distribution certificate" "security find-identity -v -p codesigning | grep -q 'Apple Distribution'"

if (( failed )); then
  print "\nnot ready to upload yet; simulator development can continue."
  exit 1
fi

print "\nlocal signing prerequisites look ready."
