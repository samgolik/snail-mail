#!/bin/zsh
set -euo pipefail

bundle_id="com.samgolik.snailmail"

if ! xcrun simctl list devices booted | grep -q "(Booted)"; then
  print -u2 "No iOS Simulator is booted. Run ./run-simulator.sh first."
  exit 1
fi

print "Streaming Snail Mail diagnostics. Press control-c to stop."
print "No passwords, tokens, or letter contents are logged."
xcrun simctl spawn booted log stream \
  --style compact \
  --level debug \
  --predicate "subsystem == '$bundle_id'"
