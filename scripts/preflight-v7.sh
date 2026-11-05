#!/usr/bin/env bash
# Prepare and validate an iOS build; never installs, signs or edits an iPhone.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  echo "BLOCKED: Xcode on a Mac is required for a releasable iOS build." >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  echo "BLOCKED: Node.js is required for the contract tests." >&2
  exit 2
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/pacelab-v7-preflight.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

echo "1/4 -- Static contracts (not substitutes for UI tests)"
passed=0
for test_file in tests/*contract.mjs; do
  node "$test_file"
  passed=$((passed+1))
done
echo "PASS: $passed contract files"

echo "2/4 -- Objective-running-evidence Swift fixtures"
xcrun swiftc \
  ios/PaceLabCompanion/LocalHealthStore.swift \
  ios/PaceLabCompanion/PaceProgressEvidence.swift \
  tests/progress-evidence-fixture.swift \
  -o "$workdir/progress-fixture"
"$workdir/progress-fixture"

echo "3/4 -- Flight motion fixture"
xcrun swiftc \
  ios/PaceLabCompanion/PaceFlightMotion.swift \
  tests/flight-motion-fixture.swift \
  -o "$workdir/flight-fixture"
"$workdir/flight-fixture"

echo "4/4 -- Full iOS Simulator build (no signing, no installation)"
xcodebuild \
  -project ios/PaceLabCompanion.xcodeproj \
  -scheme PaceLabCompanion \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$workdir/Derived" \
  CODE_SIGNING_ALLOWED=NO \
  build >"$workdir/build.log" 2>&1 || {
    grep -E 'error:|warning:|BUILD FAILED' "$workdir/build.log" | tail -35 >&2
    exit 1
  }
grep 'BUILD SUCCEEDED' "$workdir/build.log" | tail -1
echo "PASS: preflight complete, but real-device E2E and privacy tests still mandatory."
