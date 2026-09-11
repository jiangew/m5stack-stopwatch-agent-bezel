#!/bin/bash
# Package an already verified release executable from this clean source checkout.
# Does not install, restart services, change permissions, or touch firmware.
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo 'Usage: bash scripts/package_companion.sh RELEASE_EXECUTABLE NEW_APP_PATH' >&2
  exit 2
fi
repo=$(cd "$(dirname "$0")/.." && pwd)
binary=$1
output=$2
if [ ! -f "$binary" ] || [ ! -x "$binary" ]; then
  echo 'Release executable is missing or not executable' >&2; exit 1
fi
if [ -e "$output" ] || [ -L "$output" ]; then
  echo 'Refusing to overwrite an existing output' >&2; exit 1
fi
if [ -n "$(git -C "$repo" status --porcelain)" ]; then
  echo 'Release packaging requires a clean source checkout' >&2; exit 1
fi
commit=$(git -C "$repo" rev-parse HEAD)
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
umask 077
mkdir -p "$output/Contents/MacOS"
cp "$repo/companion/app/Info.plist" "$output/Contents/Info.plist"
cp "$binary" "$output/Contents/MacOS/codex-watch-companion"
chmod 755 "$output/Contents/MacOS/codex-watch-companion"
/usr/libexec/PlistBuddy -c "Add :AgentBezelSourceCommit string $commit" "$output/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :AgentBezelBuildTimestamp string $timestamp" "$output/Contents/Info.plist"
codesign --force --sign - --identifier io.github.codex-micro-stopwatch.companion "$output"
codesign --verify --strict "$output"
echo "Candidate verified: source=$commit built=$timestamp"
