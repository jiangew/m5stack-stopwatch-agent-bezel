#!/bin/bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /private/tmp/companion-package-test.XXXXXX)
mkdir -p "$scratch/source/scripts" "$scratch/source/companion/app"
cp "$repo/scripts/package_companion.sh" "$scratch/source/scripts/"
cp "$repo/companion/app/Info.plist" "$scratch/source/companion/app/"
git -C "$scratch/source" init -q
git -C "$scratch/source" add .
git -C "$scratch/source" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
# /usr/bin/true is only a packaging fixture, not a Companion validation binary.
bash "$scratch/source/scripts/package_companion.sh" /usr/bin/true "$scratch/Candidate.app"
plist="$scratch/Candidate.app/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = 0.1.4
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" = 5
test "$(/usr/libexec/PlistBuddy -c 'Print :AgentBezelSourceCommit' "$plist")" = "$(git -C "$scratch/source" rev-parse HEAD)"
/usr/libexec/PlistBuddy -c 'Print :AgentBezelBuildTimestamp' "$plist" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = io.github.codex-micro-stopwatch.companion
test "$(/usr/libexec/PlistBuddy -c 'Print :LSBackgroundOnly' "$plist")" = true
codesign --verify --strict "$scratch/Candidate.app"
if bash "$scratch/source/scripts/package_companion.sh" /usr/bin/true "$scratch/Candidate.app"; then
  echo 'FAIL: existing output accepted' >&2; exit 1
fi
touch "$scratch/source/untracked-test-file"
if bash "$scratch/source/scripts/package_companion.sh" /usr/bin/true "$scratch/Dirty.app"; then
  echo 'FAIL: dirty source accepted' >&2; exit 1
fi
test ! -e "$scratch/Dirty.app"
echo 'PASS: packaging metadata, signature, output protection, dirty-source guard'
