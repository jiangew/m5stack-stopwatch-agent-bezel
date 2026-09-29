#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /private/tmp/companion-bundle-id-test.XXXXXX)
sources=()
for file in "$repo"/companion/Sources/CodexWatchCompanion/*.swift; do
  if [ "${file##*/}" != main.swift ]; then sources+=("$file"); fi
done

swiftc -module-cache-path "$scratch/modules" -parse-as-library \
  "${sources[@]}" "$repo/companion/StandaloneTests/BundleIDRegression.swift" \
  -o "$scratch/bundle-id-regression"
"$scratch/bundle-id-regression"
